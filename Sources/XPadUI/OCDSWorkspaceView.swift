import SwiftUI
import XPadCore
import XPadController

/// Dedicated interface for inspecting, editing, importing, and exporting Open Controller Definition Standard (OCDS) profiles.
public struct OCDSProfileManagerView: View {
    @State private var selectedProfileID: String = "sony_dualsense_mpe"
    @State private var showingSchemaSheet: Bool = false
    @State private var jsonExportText: String = ""
    @State private var showingJSONExportSheet: Bool = false
    @State private var importJSONText: String = ""
    @State private var showingImportSheet: Bool = false
    @State private var importError: String?

    private var ocdsManager = OCDSManager.shared

    public init() {}

    private var activeProfile: OCDSProfile {
        ocdsManager.profile(for: selectedProfileID) ?? ocdsManager.allProfiles.first!
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header Bar
            HStack(spacing: 12) {
                Image(systemName: "doc.badge.gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(XTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Open Controller Definition Standard (OCDS)")
                        .font(.headline)
                    Text("Universal JSON schema for community mapping, tactile resistance & 3D skinning")
                        .font(.caption)
                        .foregroundStyle(XTheme.textSecondary)
                }

                Spacer()

                Button(action: { showingSchemaSheet = true }) {
                    Label("JSON Schema v1", systemImage: "curlybraces")
                }
                .buttonStyle(.bordered)

                Button(action: exportCurrentProfile) {
                    Label("Export JSON", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)

                Button(action: { showingImportSheet = true }) {
                    Label("Import Profile", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .tint(XTheme.primary)
            }
            .padding(.horizontal)

            Divider()

            // Main Profile Inspector
            HSplitView {
                // Left Column: Profile Selector & Metadata
                VStack(alignment: .leading, spacing: 14) {
                    Text("Controller Mapping Profiles")
                        .font(.subheadline.bold())

                    Picker("Active Profile", selection: $selectedProfileID) {
                        ForEach(ocdsManager.allProfiles) { profile in
                            Text("\(profile.metadata.name) (\(profile.metadata.category))")
                                .tag(profile.id)
                        }
                    }
                    .pickerStyle(.menu)

                    // Metadata Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Profile Metadata")
                            .font(.caption.bold())
                            .foregroundStyle(XTheme.textSecondary)

                        metaRow(label: "Identifier", value: activeProfile.metadata.id)
                        metaRow(label: "Author", value: activeProfile.metadata.author)
                        metaRow(label: "Version", value: activeProfile.metadata.version)
                        metaRow(label: "Category", value: activeProfile.metadata.category)
                        if let vendor = activeProfile.metadata.targetVendor {
                            metaRow(label: "Vendor", value: vendor)
                        }
                        if !activeProfile.metadata.description.isEmpty {
                            Text(activeProfile.metadata.description)
                                .font(.caption2)
                                .foregroundStyle(XTheme.textSecondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(12)
                    .background(XTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Hardware Specs Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hardware Capabilities")
                            .font(.caption.bold())
                            .foregroundStyle(XTheme.textSecondary)

                        HStack(spacing: 8) {
                            capBadge(name: "Sticks: \(activeProfile.hardwareSpec.stickCount)", active: activeProfile.hardwareSpec.stickCount > 0)
                            capBadge(name: "Triggers: \(activeProfile.hardwareSpec.triggerCount)", active: activeProfile.hardwareSpec.triggerCount > 0)
                            capBadge(name: "Buttons: \(activeProfile.hardwareSpec.buttonCount)", active: true)
                        }

                        HStack(spacing: 8) {
                            capBadge(name: "Adaptive Triggers", active: activeProfile.hardwareSpec.hasAdaptiveTriggers)
                            capBadge(name: "IMU Motion", active: activeProfile.hardwareSpec.hasMotionIMU)
                            capBadge(name: "Touchpad", active: activeProfile.hardwareSpec.hasTouchpad)
                        }
                    }
                    .padding(12)
                    .background(XTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Spacer()
                }
                .padding()
                .frame(minWidth: 320, maxWidth: 380)

                // Right Column: Bindings, Adaptive Triggers & 3D Skin Anchors
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Section 1: Input Bindings
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Input Bindings & Curves")
                                .font(.subheadline.bold())

                            if activeProfile.inputBindings.isEmpty {
                                Text("No custom input overrides defined. Using standard fallback.")
                                    .font(.caption)
                                    .foregroundStyle(XTheme.textSecondary)
                            } else {
                                ForEach(activeProfile.inputBindings) { binding in
                                    HStack {
                                        Text(binding.source.rawValue)
                                            .font(.caption.bold())
                                            .foregroundStyle(XTheme.primary)
                                        Image(systemName: "arrow.right")
                                            .font(.caption2)
                                            .foregroundStyle(XTheme.textTertiary)
                                        Text(binding.target.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(XTheme.textSecondary)
                                        Spacer()
                                        Text("Curve: \(binding.curve) · Deadzone: \(String(format: "%.2f", binding.deadzone))")
                                            .font(.system(size: 9))
                                            .foregroundStyle(XTheme.textTertiary)
                                    }
                                    .padding(8)
                                    .background(XTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }

                        Divider()

                        // Section 2: Adaptive Trigger Profiles
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Adaptive Motor Resistance Specs")
                                .font(.subheadline.bold())

                            if activeProfile.triggerConfigs.isEmpty {
                                Text("Standard linear spring triggers (No adaptive motor profile).")
                                    .font(.caption)
                                    .foregroundStyle(XTheme.textSecondary)
                            } else {
                                ForEach(activeProfile.triggerConfigs) { trig in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(trig.trigger.rawValue)
                                                .font(.caption.bold())
                                                .foregroundStyle(XTheme.accent)
                                            Spacer()
                                            Text("Mode: \(trig.mode)")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.white)
                                        }
                                        Text("Strength: \(String(format: "%.0f%%", trig.resistiveStrength * 100)) · Range: \(String(format: "%.0f%% - %.0f%%", trig.startPosition * 100, trig.endPosition * 100))")
                                            .font(.system(size: 10))
                                            .foregroundStyle(XTheme.textSecondary)
                                    }
                                    .padding(8)
                                    .background(XTheme.accent.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }

                        Divider()

                        // Section 3: 3D Visual Skinning
                        VStack(alignment: .leading, spacing: 10) {
                            Text("3D Visual Skinning & Mesh Anchors")
                                .font(.subheadline.bold())

                            HStack(spacing: 16) {
                                colorSwatch(label: "Base", hex: activeProfile.visualSkin.baseColorHex)
                                colorSwatch(label: "Accent", hex: activeProfile.visualSkin.accentColorHex)
                                colorSwatch(label: "LED Glow", hex: activeProfile.visualSkin.ledGlowHex)
                            }

                            if !activeProfile.visualSkin.meshAnchors.isEmpty {
                                Text("Mesh Anchors: \(activeProfile.visualSkin.meshAnchors.count) elements attached")
                                    .font(.caption2)
                                    .foregroundStyle(XTheme.textSecondary)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingSchemaSheet) {
            jsonViewerSheet(title: "OCDS JSON Schema v1.0.0", text: OCDSManager.jsonSchemaV1)
        }
        .sheet(isPresented: $showingJSONExportSheet) {
            jsonViewerSheet(title: "Exported OCDS Profile JSON", text: jsonExportText)
        }
        .sheet(isPresented: $showingImportSheet) {
            importProfileSheet
        }
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(XTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.caption2.bold())
                .lineLimit(1)
        }
    }

    private func capBadge(name: String, active: Bool) -> some View {
        Text(name)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(active ? XTheme.primary : XTheme.textTertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(active ? XTheme.primary.opacity(0.12) : XTheme.surface)
            .clipShape(Capsule())
    }

    private func colorSwatch(label: String, hex: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(XTheme.textSecondary)
                Text(hex)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
        }
    }

    private func exportCurrentProfile() {
        do {
            jsonExportText = try ocdsManager.encodeToJSON(activeProfile)
            showingJSONExportSheet = true
        } catch {
            jsonExportText = "Error exporting profile: \(error.localizedDescription)"
            showingJSONExportSheet = true
        }
    }

    private func jsonViewerSheet(title: String, text: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Done") {
                    showingSchemaSheet = false
                    showingJSONExportSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            TextEditor(text: .constant(text))
                .font(.system(size: 11, design: .monospaced))
                .padding()
                .background(XTheme.canvas)
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private var importProfileSheet: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Import OCDS JSON Profile")
                    .font(.headline)
                Spacer()
                Button("Cancel") { showingImportSheet = false }
            }
            .padding()

            TextEditor(text: $importJSONText)
                .font(.system(size: 11, design: .monospaced))
                .padding()
                .background(XTheme.canvas)

            if let err = importError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(XTheme.danger)
            }

            HStack {
                Spacer()
                Button("Validate & Import") {
                    do {
                        let profile = try ocdsManager.decodeFromJSON(importJSONText)
                        try ocdsManager.registerCustomProfile(profile)
                        selectedProfileID = profile.id
                        showingImportSheet = false
                        importError = nil
                    } catch {
                        importError = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(XTheme.primary)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}
