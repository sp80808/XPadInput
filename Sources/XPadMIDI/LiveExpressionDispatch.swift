import Foundation
import XPadCore

/// Routes live pressure and timbre to MPE or conventional MIDI without
/// collapsing values to 7-bit before the MIDI 2 transport boundary.
///
/// `AppState.applyExpression` is the live caller; this type exists so the
/// routing rules can be tested independently of SwiftUI. See GitHub #15.
public enum LiveExpressionDispatch {
    public static func sendPressure(
        mpe: MPEManager,
        midi: MIDIEngine,
        destination: DestinationCapabilityProfile,
        preferredPressureMode: PressureMIDIMode,
        note: UInt8,
        ports: [VirtualPort],
        normalizedPressure: Double
    ) {
        if destination.supportsMPE {
            mpe.setPressure(for: note, normalizedPressure: normalizedPressure)
            return
        }

        for port in ports {
            switch destination.resolvedPressureMode(preferred: preferredPressureMode).mode {
            case .mpePressure, .channelPressure:
                midi.sendChannelPressure(
                    port: port,
                    channel: 0,
                    normalizedPressure: normalizedPressure
                )
            case .polyPressure:
                midi.sendPolyPressure(
                    port: port,
                    channel: 0,
                    note: note,
                    normalizedPressure: normalizedPressure
                )
            case .cc11:
                midi.sendCC(
                    port: port,
                    channel: 0,
                    controller: 11,
                    normalizedValue: normalizedPressure
                )
            }
        }
    }

    public static func sendTimbre(
        mpe: MPEManager,
        midi: MIDIEngine,
        destination: DestinationCapabilityProfile,
        note: UInt8,
        ports: [VirtualPort],
        normalizedTimbre: Double
    ) {
        if destination.supportsMPE {
            mpe.setTimbre(for: note, normalizedValue: normalizedTimbre)
            return
        }

        guard destination.supportsCC74 else { return }

        for port in ports {
            midi.sendTimbreCC74(
                port: port,
                channel: 0,
                normalizedValue: normalizedTimbre
            )
        }
    }
}
