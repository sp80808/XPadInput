import Foundation
import CoreMIDI
import XPadCore

/// MIDI-CI (MIDI Capability Inquiry) Profile Negotiation and Discovery Engine.
///
/// Implements standard MIDI-CI MPE Profile (M2-120-UM_v2-0-3 / M2-101-UM) negotiation
/// allowing DAWs and hardware instruments to dynamically discover XPI capabilities,
/// query supported profiles, and automatically activate MPE without manual DAW zone configuration.
public final class MIDICISession: @unchecked Sendable {
    public static let shared = MIDICISession()

    // MARK: - Constants
    
    public static let midiCISubID1: UInt8 = 0x0D
    public static let universalSysExNonRealTime: UInt8 = 0x7E
    public static let universalSysExAllChannels: UInt8 = 0x7F
    
    // Sub-ID 2 Definitions
    public enum SubID2: UInt8, Sendable {
        case discoveryInquiry = 0x70
        case discoveryReply = 0x71
        case endpointInfoInquiry = 0x72
        case endpointInfoReply = 0x73
        case profileInquiry = 0x20
        case profileInquiryReply = 0x21
        case setProfileOn = 0x22
        case setProfileOff = 0x23
        case profileEnabledReport = 0x24
        case profileDisabledReport = 0x25
        case profileSpecificData = 0x2F
        case getCapabilityInquiry = 0x30
        case getCapabilityReply = 0x31
        case getPropertyDataInquiry = 0x34
        case getPropertyDataReply = 0x35
        case setPropertyDataInquiry = 0x36
        case setPropertyDataReply = 0x37
    }

    /// Standard 5-byte MIDI-CI Profile ID for MPE (M2-120-UM_v2-0-3).
    /// Format: [0x7E (Standard Profile Group), 0x01 (MPE), 0x01 (Version 1.0), 0x01 (Level 1), 0x00]
    public static let mpeProfileID: [UInt8] = [0x7E, 0x01, 0x01, 0x01, 0x00]

    // MARK: - State

    private let lock = NSLock()
    public let myMUID: UInt32
    public private(set) var remoteMUID: UInt32?
    public private(set) var isMPEProfileActive: Bool = false
    public private(set) var negotiatedBendRangeSemitones: Double = 48.0
    public private(set) var negotiatedMemberChannels: ClosedRange<UInt8> = 1...15

    public var onProfileStateChanged: ((Bool) -> Void)?

    public init(muid: UInt32? = nil) {
        // Generate a 28-bit random MUID (0x00000000 to 0x0FFFFFFF)
        self.myMUID = muid ?? (UInt32.random(in: 0x0100_0000...0x0FFF_FFFF))
    }

    // MARK: - Public Processing

    /// Inspects and processes incoming Universal SysEx / MIDI-CI payloads.
    /// Returns a response SysEx byte array if a reply is required.
    public func processIncomingSysEx(_ bytes: [UInt8]) -> [UInt8]? {
        guard bytes.count >= 13,
              bytes.first == 0xF0,
              bytes.last == 0xF7,
              bytes[1] == Self.universalSysExNonRealTime,
              bytes[3] == Self.midiCISubID1 else {
            return nil
        }

        let subId2 = bytes[4]
        let version = bytes[5]
        guard version >= 0x01 else { return nil }

        let srcMUID = readMUID(bytes: bytes, offset: 6)
        let dstMUID = readMUID(bytes: bytes, offset: 10)

        // Ignore messages sent by ourselves or targeted to another specific MUID
        guard srcMUID != myMUID else { return nil }
        if dstMUID != 0x0FFF_FFFF && dstMUID != myMUID {
            return nil
        }

        lock.lock()
        self.remoteMUID = srcMUID
        lock.unlock()

        switch subId2 {
        case SubID2.discoveryInquiry.rawValue:
            return buildDiscoveryReply(targetMUID: srcMUID)

        case SubID2.profileInquiry.rawValue:
            return buildProfileInquiryReply(targetMUID: srcMUID)

        case SubID2.setProfileOn.rawValue:
            return handleSetProfileOn(bytes: bytes, targetMUID: srcMUID)

        case SubID2.setProfileOff.rawValue:
            return handleSetProfileOff(bytes: bytes, targetMUID: srcMUID)

        case SubID2.profileSpecificData.rawValue:
            return handleProfileSpecificData(bytes: bytes, targetMUID: srcMUID)

        case SubID2.getCapabilityInquiry.rawValue:
            return buildPropertyCapabilityReply(targetMUID: srcMUID)

        case SubID2.getPropertyDataInquiry.rawValue:
            return handleGetPropertyDataInquiry(bytes: bytes, targetMUID: srcMUID)

        default:
            return nil
        }
    }

    // MARK: - Message Builders & Handlers

    /// Builds a MIDI-CI Discovery Inquiry message to broadcast to external DAWs / devices.
    public func buildDiscoveryInquiry() -> [UInt8] {
        var msg: [UInt8] = [
            0xF0,
            Self.universalSysExNonRealTime,
            Self.universalSysExAllChannels,
            Self.midiCISubID1,
            SubID2.discoveryInquiry.rawValue,
            0x02 // MIDI-CI Version 2.0
        ]
        msg.append(contentsOf: writeMUID(myMUID))
        msg.append(contentsOf: writeMUID(0x0FFF_FFFF)) // Broadcast MUID
        
        // Device Manufacturer ID (SysEx 3-byte ID for XPI: 0x00, 0x21, 0x48)
        msg.append(contentsOf: [0x00, 0x21, 0x48])
        // Device Family (0x01, 0x00) & Model Number (0x01, 0x00)
        msg.append(contentsOf: [0x01, 0x00, 0x01, 0x00])
        // Software Revision Level (0x00, 0x00, 0x02, 0x00)
        msg.append(contentsOf: [0x00, 0x00, 0x02, 0x00])
        // CI Support Category Bitmap (0x7F: Profiles, Property Exchange, Process Inquiry)
        msg.append(0x7F)
        // Max SysEx message size (512 bytes: 0x00, 0x04)
        msg.append(contentsOf: [0x00, 0x04])
        
        msg.append(0xF7)
        return msg
    }

    private func buildDiscoveryReply(targetMUID: UInt32) -> [UInt8] {
        var msg: [UInt8] = [
            0xF0,
            Self.universalSysExNonRealTime,
            Self.universalSysExAllChannels,
            Self.midiCISubID1,
            SubID2.discoveryReply.rawValue,
            0x02 // MIDI-CI Version 2.0
        ]
        msg.append(contentsOf: writeMUID(myMUID))
        msg.append(contentsOf: writeMUID(targetMUID))
        
        // Device Manufacturer ID (0x00, 0x21, 0x48)
        msg.append(contentsOf: [0x00, 0x21, 0x48])
        // Device Family & Model
        msg.append(contentsOf: [0x01, 0x00, 0x01, 0x00])
        // Software Revision
        msg.append(contentsOf: [0x00, 0x00, 0x02, 0x00])
        // CI Support Category Bitmap
        msg.append(0x7F)
        // Max SysEx message size
        msg.append(contentsOf: [0x00, 0x04])
        
        msg.append(0xF7)
        return msg
    }

    private func buildProfileInquiryReply(targetMUID: UInt32) -> [UInt8] {
        var msg: [UInt8] = [
            0xF0,
            Self.universalSysExNonRealTime,
            Self.universalSysExAllChannels,
            Self.midiCISubID1,
            SubID2.profileInquiryReply.rawValue,
            0x02
        ]
        msg.append(contentsOf: writeMUID(myMUID))
        msg.append(contentsOf: writeMUID(targetMUID))

        lock.lock()
        let isEnabled = isMPEProfileActive
        lock.unlock()

        if isEnabled {
            // Enabled Profiles Count = 1
            msg.append(contentsOf: [0x01, 0x00])
            msg.append(contentsOf: Self.mpeProfileID)
            // Disabled / Available Profiles Count = 0
            msg.append(contentsOf: [0x00, 0x00])
        } else {
            // Enabled Profiles Count = 0
            msg.append(contentsOf: [0x00, 0x00])
            // Disabled / Available Profiles Count = 1 (MPE is supported and ready to be turned on)
            msg.append(contentsOf: [0x01, 0x00])
            msg.append(contentsOf: Self.mpeProfileID)
        }

        msg.append(0xF7)
        return msg
    }

    private func handleSetProfileOn(bytes: [UInt8], targetMUID: UInt32) -> [UInt8]? {
        guard bytes.count >= 19 else { return nil }
        let profileID = Array(bytes[14..<19])
        
        guard profileID == Self.mpeProfileID else { return nil }

        lock.lock()
        isMPEProfileActive = true
        lock.unlock()

        onProfileStateChanged?(true)

        // Return Profile Enabled Report (0x24)
        var reply: [UInt8] = [
            0xF0,
            Self.universalSysExNonRealTime,
            Self.universalSysExAllChannels,
            Self.midiCISubID1,
            SubID2.profileEnabledReport.rawValue,
            0x02
        ]
        reply.append(contentsOf: writeMUID(myMUID))
        reply.append(contentsOf: writeMUID(targetMUID))
        reply.append(contentsOf: Self.mpeProfileID)
        reply.append(0xF7)
        return reply
    }

    private func handleSetProfileOff(bytes: [UInt8], targetMUID: UInt32) -> [UInt8]? {
        guard bytes.count >= 19 else { return nil }
        let profileID = Array(bytes[14..<19])
        
        guard profileID == Self.mpeProfileID else { return nil }

        lock.lock()
        isMPEProfileActive = false
        lock.unlock()

        onProfileStateChanged?(false)

        // Return Profile Disabled Report (0x25)
        var reply: [UInt8] = [
            0xF0,
            Self.universalSysExNonRealTime,
            Self.universalSysExAllChannels,
            Self.midiCISubID1,
            SubID2.profileDisabledReport.rawValue,
            0x02
        ]
        reply.append(contentsOf: writeMUID(myMUID))
        reply.append(contentsOf: writeMUID(targetMUID))
        reply.append(contentsOf: Self.mpeProfileID)
        reply.append(0xF7)
        return reply
    }

    private func handleProfileSpecificData(bytes: [UInt8], targetMUID: UInt32) -> [UInt8]? {
        guard bytes.count >= 21 else { return nil }
        let profileID = Array(bytes[14..<19])
        guard profileID == Self.mpeProfileID else { return nil }

        // Parse MPE Configuration (Length + Payload)
        let dataLength = Int(bytes[19]) | (Int(bytes[20]) << 7)
        if bytes.count >= 21 + dataLength {
            let dataPayload = Array(bytes[21..<(21 + dataLength)])
            if let bendRange = dataPayload.first {
                let clamped = min(max(Double(bendRange & 0x7F), 1.0), 96.0)
                lock.lock()
                self.negotiatedBendRangeSemitones = clamped
                lock.unlock()
            }
        }

        return nil
    }

    private func buildPropertyCapabilityReply(targetMUID: UInt32) -> [UInt8] {
        var msg: [UInt8] = [
            0xF0,
            Self.universalSysExNonRealTime,
            Self.universalSysExAllChannels,
            Self.midiCISubID1,
            SubID2.getCapabilityReply.rawValue,
            0x02
        ]
        msg.append(contentsOf: writeMUID(myMUID))
        msg.append(contentsOf: writeMUID(targetMUID))
        // Max simultaneous Property Exchange requests (e.g. 4)
        msg.append(0x04)
        // Major / Minor PE Version supported (Version 1.0 = 0x01)
        msg.append(0x01)
        msg.append(0xF7)
        return msg
    }

    private func handleGetPropertyDataInquiry(bytes: [UInt8], targetMUID: UInt32) -> [UInt8]? {
        guard bytes.count >= 16 else { return nil }
        let requestId = bytes[14]
        
        // Extract JSON header / resource name if present
        let headerLength = Int(bytes[15]) | (Int(bytes[16]) << 7)
        var resourceName = "ResourceList"
        if bytes.count >= 17 + headerLength {
            let headerBytes = Array(bytes[17..<(17 + headerLength)])
            if let headerStr = String(bytes: headerBytes, encoding: .utf8),
               headerStr.contains("DeviceInfo") {
                resourceName = "DeviceInfo"
            } else if let headerStr = String(bytes: headerBytes, encoding: .utf8),
                      headerStr.contains("MPEConfiguration") {
                resourceName = "MPEConfiguration"
            }
        }

        let jsonPayload: String
        switch resourceName {
        case "DeviceInfo":
            jsonPayload = "{\"manufacturer\":\"XPadInput\",\"model\":\"XPI Workstation\",\"version\":\"0.0.02\",\"midiVersion\":\"2.0\",\"mpeSupported\":true}"
        case "MPEConfiguration":
            jsonPayload = "{\"masterChannel\":0,\"memberChannels\":\"1-15\",\"pitchBendRange\":48,\"perNotePitchBend\":true,\"perNotePressure\":true,\"perNoteTimbre\":true}"
        default:
            jsonPayload = "[{\"resource\":\"DeviceInfo\",\"canGet\":true},{\"resource\":\"MPEConfiguration\",\"canGet\":true},{\"resource\":\"ResourceList\",\"canGet\":true}]"
        }

        guard let payloadData = jsonPayload.data(using: .utf8) else { return nil }
        let payloadBytes = [UInt8](payloadData)

        var reply: [UInt8] = [
            0xF0,
            Self.universalSysExNonRealTime,
            Self.universalSysExAllChannels,
            Self.midiCISubID1,
            SubID2.getPropertyDataReply.rawValue,
            0x02
        ]
        reply.append(contentsOf: writeMUID(myMUID))
        reply.append(contentsOf: writeMUID(targetMUID))
        reply.append(requestId)
        // Status code: 200 OK (0x00, 0xC8 = 200 in 7-bit)
        reply.append(contentsOf: [0x00, 0x01, 0x48])
        // Data length in 7-bit little endian
        reply.append(UInt8(payloadBytes.count & 0x7F))
        reply.append(UInt8((payloadBytes.count >> 7) & 0x7F))
        reply.append(contentsOf: payloadBytes)
        reply.append(0xF7)
        return reply
    }

    // MARK: - MUID Serialization Helpers (7-bit little-endian)

    private func readMUID(bytes: [UInt8], offset: Int) -> UInt32 {
        guard bytes.count >= offset + 4 else { return 0 }
        let b0 = UInt32(bytes[offset] & 0x7F)
        let b1 = UInt32(bytes[offset + 1] & 0x7F) << 7
        let b2 = UInt32(bytes[offset + 2] & 0x7F) << 14
        let b3 = UInt32(bytes[offset + 3] & 0x7F) << 21
        return b0 | b1 | b2 | b3
    }

    private func writeMUID(_ muid: UInt32) -> [UInt8] {
        return [
            UInt8(muid & 0x7F),
            UInt8((muid >> 7) & 0x7F),
            UInt8((muid >> 14) & 0x7F),
            UInt8((muid >> 21) & 0x7F)
        ]
    }
}
