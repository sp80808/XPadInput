import Foundation
import AudioToolbox
import CoreAudioKit

/// Dynamic registration and factory helper for XPadInput AUv3 plugins.
public enum XPadPluginRegistrar {
    /// AudioComponentDescription for XPI Instrument (Music Device).
    public static var instrumentComponentDescription: AudioComponentDescription {
        AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: 0x78706969, // 'xpii'
            componentManufacturer: 0x58504144, // 'XPAD'
            componentFlags: 0,
            componentFlagsMask: 0
        )
    }
    
    /// AudioComponentDescription for XPI MIDI FX Processor.
    public static var midiFXComponentDescription: AudioComponentDescription {
        AudioComponentDescription(
            componentType: kAudioUnitType_MIDIProcessor,
            componentSubType: 0x7870696D, // 'xpim'
            componentManufacturer: 0x58504144, // 'XPAD'
            componentFlags: 0,
            componentFlagsMask: 0
        )
    }
    
    /// Registers AUv3 plugin subclasses dynamically with the macOS Audio Component system.
    public static func registerPluginComponents() {
        AUAudioUnit.registerSubclass(
            XPadAUInstrument.self,
            as: instrumentComponentDescription,
            name: "XPad: XPI Instrument",
            version: 0x00010000
        )
        
        AUAudioUnit.registerSubclass(
            XPadAUMIDIFX.self,
            as: midiFXComponentDescription,
            name: "XPad: XPI MIDI FX",
            version: 0x00010000
        )
    }
}

/// Standalone factory conforming to AUAudioUnitFactory for extension entrypoints.
public final class XPadAUFactory: NSObject, AUAudioUnitFactory, @unchecked Sendable {
    public func beginRequest(with context: NSExtensionContext) {}

    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        if componentDescription.componentType == kAudioUnitType_MusicDevice {
            return try XPadAUInstrument(componentDescription: componentDescription)
        } else {
            return try XPadAUMIDIFX(componentDescription: componentDescription)
        }
    }
}
