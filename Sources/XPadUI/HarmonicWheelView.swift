import SwiftUI
import XPadCore
import XPadController

/// Interactive harmonic wheel showing diatonic chords arranged radially.
/// Left stick position selects chords; visual feedback shows selection, tension, and relationships.
struct HarmonicWheelView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let maxRadius = min(geo.size.width, geo.size.height) / 2 - 40
            let chordRadius = maxRadius * 0.72
            let innerRadius = maxRadius * 0.35
            
            ZStack {
                // Background rings
                backgroundRings(center: center, maxRadius: maxRadius)
                
                // Chord segments
                chordSegments(center: center, radius: chordRadius, innerRadius: innerRadius)
                
                // Center info
                centerDisplay(center: center, innerRadius: innerRadius)
                
                // Left stick indicator
                stickIndicator(center: center, maxRadius: maxRadius)
            }
        }
    }
    
    // MARK: - Background
    
    @ViewBuilder
    private func backgroundRings(center: CGPoint, maxRadius: CGFloat) -> some View {
        // Outer ring
        Circle()
            .stroke(XTheme.border, lineWidth: 1)
            .frame(width: maxRadius * 2, height: maxRadius * 2)
            .position(center)
        
        // Subtle radial gradient
        Circle()
            .fill(
                RadialGradient(
                    colors: [XTheme.primary.opacity(0.03), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: maxRadius
                )
            )
            .frame(width: maxRadius * 2, height: maxRadius * 2)
            .position(center)
    }
    
    // MARK: - Chord Segments
    
    @ViewBuilder
    private func chordSegments(center: CGPoint, radius: CGFloat, innerRadius: CGFloat) -> some View {
        let chords = appState.diatonicChords
        let count = chords.count
        if count > 0 {
            let sliceAngle = (2 * CGFloat.pi) / CGFloat(count)

            ForEach(0..<count, id: \.self) { index in
            let chord = chords[index]
            let isSelected = index == appState.selectedChordIndex
            let tension = chord.tension(in: appState.currentKey, scale: appState.currentScale)
            
            // Angle: start from top, go clockwise
            let angle = -CGFloat.pi / 2 + CGFloat(index) * sliceAngle
            
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            
            // Chord node
            ChordNodeView(
                chord: chord,
                isSelected: isSelected,
                tension: tension,
                key: appState.currentKey,
                scale: appState.currentScale
            )
            .position(x: x, y: y)
            .onTapGesture {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                    appState.selectedChordIndex = index
                    appState.currentChord = chord
                }
            }
            
            // Connecting line to center
            Path { path in
                path.move(to: center)
                path.addLine(to: CGPoint(x: x, y: y))
            }
            .stroke(
                isSelected ? XTheme.primary.opacity(0.4) : XTheme.border,
                lineWidth: isSelected ? 2 : 0.5
            )
            }
        }
    }
    
    // MARK: - Center
    
    @ViewBuilder
    private func centerDisplay(center: CGPoint, innerRadius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(XTheme.surface)
                .overlay(
                    Circle()
                        .stroke(XTheme.borderActive, lineWidth: 1.5)
                )
                .frame(width: innerRadius * 2, height: innerRadius * 2)
            
            VStack(spacing: 4) {
                Text(appState.currentKey.displayName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(XTheme.primary)
                
                Text(appState.currentScale.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(XTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .position(center)
    }
    
    // MARK: - Stick Indicator
    
    @ViewBuilder
    private func stickIndicator(center: CGPoint, maxRadius: CGFloat) -> some View {
        let state = appState.controllerManager.controllerState
        let magnitude = state.leftStickMagnitude
        let angle = state.leftStickAngle
        
        if magnitude > 0.1 {
            let indicatorRadius = maxRadius * CGFloat(min(magnitude, 1.0)) * 0.85
            let x = center.x + cos(CGFloat(angle)) * indicatorRadius
            let y = center.y - sin(CGFloat(angle)) * indicatorRadius // Flip Y
            
            Circle()
                .fill(XTheme.accent.opacity(0.6))
                .frame(width: 14, height: 14)
                .xGlow(isActive: true, color: XTheme.accent)
                .position(x: x, y: y)
                .animation(.linear(duration: 0.05), value: x)
                .animation(.linear(duration: 0.05), value: y)
        }
    }
}

// MARK: - Chord Node

struct ChordNodeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let chord: Chord
    let isSelected: Bool
    let tension: Double
    let key: PitchClass
    let scale: Scale
    
    var body: some View {
        VStack(spacing: 3) {
            Text(chord.displayName)
                .font(.system(size: isSelected ? 14 : 13, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundColor(isSelected ? .white : XTheme.textPrimary)
            
            if let roman = chord.romanNumeral(in: key, scale: scale) {
                Text(roman)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(isSelected ? XTheme.accent : XTheme.textTertiary)
            }
        }
        .frame(width: 58, height: 42)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? XTheme.primary.opacity(0.20) : XTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isSelected ? XTheme.primary : XTheme.tensionColor(tension).opacity(0.3),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
        )
        .shadow(color: isSelected ? XTheme.primary.opacity(0.22) : .clear, radius: 7)
        .scaleEffect(isSelected && !reduceMotion ? 1.035 : 1.0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isSelected)
    }
}
