import SwiftUI
import XPadCore
import XPadAudio

/// Control panel and live VU level visualizer for the CoreAudio Virtual Audio Driver and loopback capture.
public struct VirtualAudioView: View {
    @State private var virtualDriver = VirtualAudioDriver.shared
    @State private var loopbackEngine = VirtualAudioLoopbackEngine.shared
    @State private var isRecordingStem: Bool = false
    @State private var recordedURL: URL?
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showRecordingSuccess: Bool = false
    @State private var recordingError: String?
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(virtualDriver.isEnabled ? XTheme.primary : XTheme.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CoreAudio Virtual Audio Driver")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(XTheme.textPrimary)
                        Text("Direct loopback stream for OBS, DAWs, and system capture")
                            .font(.system(size: 10))
                            .foregroundColor(XTheme.textSecondary)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { virtualDriver.isEnabled },
                    set: { enabled in
                        virtualDriver.setEnabled(enabled)
                        if enabled {
                            AudioEngine.shared.attachLoopback()
                        }
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // Stereo VU Meter Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("LOOPBACK LEVEL MONITOR")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(XTheme.textTertiary)
                    Spacer()
                    Text(String(format: "L: %.1f dB  |  R: %.1f dB", virtualDriver.levelMeter.peakLeftDB, virtualDriver.levelMeter.peakRightDB))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(XTheme.textSecondary)
                }
                
                // Left & Right VU Bars
                VStack(spacing: 4) {
                    vuBar(label: "L", level: virtualDriver.levelMeter.linearLevelLeft)
                    vuBar(label: "R", level: virtualDriver.levelMeter.linearLevelRight)
                }
            }
            .padding(10)
            .background(XTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Settings Grid
            HStack(spacing: 12) {
                // Buffer Size Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Buffer Latency")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(XTheme.textSecondary)
                    Picker("", selection: Binding(
                        get: { virtualDriver.bufferSize },
                        set: { virtualDriver.setBufferSize($0) }
                    )) {
                        ForEach(VirtualAudioBufferSize.allCases) { size in
                            Text(size.displayLabel).tag(size)
                        }
                    }
                    .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Sample Rate Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sample Rate")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(XTheme.textSecondary)
                    Picker("", selection: Binding(
                        get: { virtualDriver.sampleRate },
                        set: { virtualDriver.setSampleRate($0) }
                    )) {
                        ForEach(VirtualAudioSampleRate.allCases) { rate in
                            Text(rate.displayLabel).tag(rate)
                        }
                    }
                    .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Stem Recorder Section
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Zero-Loss WAV Stem Capture")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(XTheme.textPrimary)
                    if isRecordingStem {
                        Text(String(format: "Recording: %.1fs (%llu frames)", recordingDuration, loopbackEngine.recorder.recordedFrames))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(XTheme.recording)
                    } else if let error = recordingError {
                        Text(error)
                            .font(.system(size: 9))
                            .foregroundColor(XTheme.warning)
                            .lineLimit(2)
                    } else if let url = recordedURL {
                        Text("Saved: \(url.lastPathComponent)")
                            .font(.system(size: 9))
                            .foregroundColor(XTheme.primary)
                            .lineLimit(1)
                    } else {
                        Text("Capture continuous 32-bit float master stream to disk")
                            .font(.system(size: 9))
                            .foregroundColor(XTheme.textTertiary)
                    }
                }
                
                Spacer()
                
                Button {
                    toggleRecording()
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isRecordingStem ? XTheme.recording : XTheme.textTertiary)
                            .frame(width: 8, height: 8)
                        Text(isRecordingStem ? "Stop Capture" : "Start Capture")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isRecordingStem ? XTheme.recording.opacity(0.2) : XTheme.surface)
                    .foregroundColor(isRecordingStem ? XTheme.recording : XTheme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(XTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(XTheme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func vuBar(label: String, level: Float) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(XTheme.textTertiary)
                .frame(width: 10)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.black.opacity(0.4))
                        .frame(height: 8)
                    
                    let width = max(0, min(geo.size.width, geo.size.width * CGFloat(level)))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [XTheme.stable, XTheme.primary, level > 0.85 ? XTheme.tense : XTheme.primary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
    
    private func toggleRecording() {
        if isRecordingStem {
            recordedURL = loopbackEngine.stopCapture()
            if let writeError = loopbackEngine.recorder.lastWriteErrorDescription {
                recordingError = "Capture failed: \(writeError)"
                recordedURL = nil
            }
            isRecordingStem = false
            timer?.invalidate()
            timer = nil
        } else {
            do {
                if !virtualDriver.isEnabled {
                    virtualDriver.setEnabled(true)
                    AudioEngine.shared.attachLoopback()
                }
                recordedURL = try loopbackEngine.startCapture()
                recordingError = nil
                isRecordingStem = true
                recordingDuration = 0
                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    recordingDuration += 0.1
                    if let writeError = loopbackEngine.recorder.lastWriteErrorDescription {
                        recordingError = "Capture failed: \(writeError)"
                        recordedURL = nil
                        isRecordingStem = false
                        timer?.invalidate()
                        timer = nil
                    }
                }
            } catch {
                print("⚠️ Failed to start stem recording: \(error)")
                recordingError = "Failed to start capture: \(error.localizedDescription)"
            }
        }
    }
}
