import SwiftUI
import XPadCore
import XPadController

/// A high-performance 4-player multi-controller jamming hub and HUD.
public struct MultiControllerJammingBarView: View {
    public var jammingManager: MultiControllerJammingManager

    public init(jammingManager: MultiControllerJammingManager) {
        self.jammingManager = jammingManager
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.3.sequence.fill")
                        .foregroundStyle(Color.green)
                    Text("4-Player Ensemble Jamming")
                        .font(.caption.bold())
                }

                Spacer()

                HStack(spacing: 8) {
                    Text("Sync: \(jammingManager.currentKey.displayName) \(jammingManager.currentScale.type.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(jammingManager.activeChord.displayName)
                        .font(.caption2.bold())
                        .foregroundStyle(Color.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 10) {
                ForEach(PlayerSlotId.allCases) { slot in
                    if let player = jammingManager.players[slot] {
                        playerSlotCard(player: player)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: XTheme.radiusMedium)
                .fill(XTheme.surface.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: XTheme.radiusMedium)
                        .stroke(XTheme.border, lineWidth: 1)
                )
        )
    }

    private func playerSlotCard(player: PlayerAssignment) -> some View {
        let color = Color(hex: player.slot.defaultColorHex)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(player.isConnected ? color : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .xGlow(isActive: player.isConnected, color: color)

                Text(player.slot.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)

                Spacer()

                Text("Ch \(player.midiChannel + 1)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(XTheme.textTertiary)
            }

            // Role Picker Menu & Simulate Trigger
            HStack(spacing: 4) {
                Menu {
                    ForEach(JamTrackRole.allCases) { role in
                        Button(action: {
                            withAnimation(XTheme.quickAnimation) {
                                jammingManager.setRole(role, for: player.slot)
                            }
                        }) {
                            HStack {
                                Text(role.rawValue)
                                if player.role == role {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(player.role.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 7))
                    }
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .menuStyle(.borderlessButton)

                Spacer()

                // Test Trigger Button
                Button {
                    simulatePlayerStrike(slot: player.slot)
                } label: {
                    Image(systemName: "hand.point.up.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(color)
                        .padding(4)
                        .background(color.opacity(0.18))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Test trigger \(player.slot.rawValue) note")
            }

            HStack {
                Text(player.controllerName)
                    .font(.system(size: 9))
                    .foregroundStyle(XTheme.textTertiary)
                    .lineLimit(1)
                Spacer()
                if player.isConnected {
                    Image(systemName: "battery.100")
                        .font(.system(size: 8))
                        .foregroundStyle(XTheme.emerald.opacity(0.8))
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: XTheme.radiusSmall)
                .fill(color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: XTheme.radiusSmall)
                .stroke(player.isConnected ? color.opacity(0.35) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func simulatePlayerStrike(slot: PlayerSlotId) {
        jammingManager.injectPlayerState(slot: slot) { state in
            state.buttonA = true
            state.rightTrigger = ProcessedTriggerState(rawValue: 0.9, value: 0.9, isPressed: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            jammingManager.injectPlayerState(slot: slot) { state in
                state.buttonA = false
                state.rightTrigger = ProcessedTriggerState(rawValue: 0.0, value: 0.0, isPressed: false)
            }
        }
    }
}
