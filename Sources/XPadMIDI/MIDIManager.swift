import Foundation
import CoreMIDI
import XPadCore

public enum VirtualPort: String, CaseIterable, Identifiable, Sendable {
    case main = "XPadInput Main"
    case chords = "XPadInput Chords"
    case melody = "XPadInput Melody"
    case bass = "XPadInput Bass"
    case drums = "XPadInput Drums"
    case mpe = "XPadInput Expression (MPE)"

    public var id: String { rawValue }
}

public final class MIDIManager: @unchecked Sendable {
    public static let shared = MIDIManager()

    private var midiClient: MIDIClientRef = 0
    private var virtualSources: [VirtualPort: MIDIEndpointRef] = [:]
    private let queue = DispatchQueue(label: "com.xpadinput.midi", qos: .userInteractive)

    public init() {
        setupVirtualPorts()
    }

    private func setupVirtualPorts() {
        var status = MIDIClientCreateWithBlock("XPadInput Client" as CFString, &midiClient) { notification in
            // Handle CoreMIDI hardware notifications
        }
        guard status == noErr else { return }

        for port in VirtualPort.allCases {
            var endpoint: MIDIEndpointRef = 0
            status = MIDISourceCreate(midiClient, port.rawValue as CFString, &endpoint)
            if status == noErr {
                virtualSources[port] = endpoint
            }
        }
    }

    public func sendNoteOn(port: VirtualPort = .main, channel: UInt8, note: UInt8, velocity: UInt8) {
        let statusByte = 0x90 | (channel & 0x0F)
        sendBytes(port: port, bytes: [statusByte, min(127, note), min(127, velocity)])
    }

    public func sendNoteOff(port: VirtualPort = .main, channel: UInt8, note: UInt8) {
        let statusByte = 0x80 | (channel & 0x0F)
        sendBytes(port: port, bytes: [statusByte, min(127, note), 0])
    }

    public func sendPitchBend(port: VirtualPort = .main, channel: UInt8, semitoneOffset: Double, bendRangeSemitones: Double = 48.0) {
        let normalized = max(-1.0, min(1.0, semitoneOffset / bendRangeSemitones))
        let value = Int(8192.0 + normalized * 8191.0)
        let lsb = UInt8(value & 0x7F)
        let msb = UInt8((value >> 7) & 0x7F)
        let statusByte = 0xE0 | (channel & 0x0F)
        sendBytes(port: port, bytes: [statusByte, lsb, msb])
    }

    public func sendPolyPressure(port: VirtualPort = .main, channel: UInt8, note: UInt8, pressure: UInt8) {
        let statusByte = 0xA0 | (channel & 0x0F)
        sendBytes(port: port, bytes: [statusByte, min(127, note), min(127, pressure)])
    }

    public func sendCC(port: VirtualPort = .main, channel: UInt8, controller: UInt8, value: UInt8) {
        let statusByte = 0xB0 | (channel & 0x0F)
        sendBytes(port: port, bytes: [statusByte, min(127, controller), min(127, value)])
    }

    public func sendTimbreCC74(port: VirtualPort = .main, channel: UInt8, value: UInt8) {
        sendCC(port: port, channel: channel, controller: 74, value: value)
    }

    public func panic() {
        for port in VirtualPort.allCases {
            for ch in 0..<16 {
                // All Notes Off (CC 123) & All Sound Off (CC 120)
                sendCC(port: port, channel: UInt8(ch), controller: 120, value: 0)
                sendCC(port: port, channel: UInt8(ch), controller: 123, value: 0)
            }
        }
    }

    private func sendBytes(port: VirtualPort, bytes: [UInt8]) {
        guard let endpoint = virtualSources[port], !bytes.isEmpty else { return }

        queue.async {
            var packetList = MIDIPacketList()
            var packet = MIDIPacketListInit(&packetList)
            packet = MIDIPacketListAdd(&packetList, 1024, packet, 0, bytes.count, bytes)
            if packet != nil {
                MIDIReceived(endpoint, &packetList)
            }
        }
    }
}
