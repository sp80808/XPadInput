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
            let availableWidth = geo.size.width
            let availableHeight = geo.size.height
            let size = min(availableWidth, availableHeight)
            let center = CGPoint(x: availableWidth / 2, y: availableHeight / 2)
            
            // Continuous proportional node sizing based on available viewport
            let nodeWidth: CGFloat = max(44, min(86, size * 0.20))
            let nodeHeight: CGFloat = max(34, min(64, size * 0.15))
            
            // Maximize radius dynamically without clipping outer nodes
            let maxRadius = max(40, (size / 2) - 4)
            let chordRadius = max(32, (size / 2) - (nodeWidth / 2) - 4)
            let innerRadius = max(22, min(58, chordRadius * 0.42))
            
            ZStack {
                // Background rings
                backgroundRings(center: center, maxRadius: maxRadius, chordRadius: chordRadius)
                
                // Connecting lines & Chord segments
                chordSegments(
                    center: center,
                    radius: chordRadius,
                    innerRadius: innerRadius,
                    nodeWidth: nodeWidth,
                    nodeHeight: nodeHeight
                )
                
                // Center info
                centerDisplay(center: center, innerRadius: innerRadius)
                
                // Left stick indicator
                stickIndicator(center: center, maxRadius: chordRadius)
            }
        }
    }
    
    // MARK: - Background
    
    @ViewBuilder
    private func backgroundRings(center: CGPoint, maxRadius: CGFloat, chordRadius: CGFloat) -> some View {
        // Outer subtle perimeter ring
        Circle()
            .stroke(XTheme.border.opacity(0.4), lineWidth: 1)
            .frame(width: maxRadius * 2, height: maxRadius * 2)
            .position(center)

        // Orbital track passing through chords
        Circle()
            .stroke(XTheme.border.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(width: chordRadius * 2, height: chordRadius * 2)
            .position(center)
        
        // Subtle ambient radial glow
        Circle()
            .fill(
                RadialGradient(
                    colors: [XTheme.primary.opacity(0.04), .clear],
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
    private func chordSegments(
        center: CGPoint,
        radius: CGFloat,
        innerRadius: CGFloat,
        nodeWidth: CGFloat,
        nodeHeight: CGFloat
    ) -> some View {
        let chords = appState.diatonicChords
        let count = chords.count
        if count > 0 {
            let sliceAngle = (2 * CGFloat.pi) / CGFloat(count)

            ForEach(0..<count, id: \.self) { index in
                let chord = chords[index]
                let isSelected = index == appState.selectedChordIndex
                let tension = chord.tension(in: appState.currentKey, scale: appState.currentScale)
                
                // Angle: start from top (-π/2), proceed clockwise
                let angle = -CGFloat.pi / 2 + CGFloat(index) * sliceAngle
                
                let x = center.x + cos(angle) * radius
                let y = center.y + sin(angle) * radius
                
                // Connecting line from center circle perimeter to node
                Path { path in
                    let startX = center.x + cos(angle) * innerRadius
                    let startY = center.y + sin(angle) * innerRadius
                    path.move(to: CGPoint(x: startX, y: startY))
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                .stroke(
                    isSelected ? XTheme.primary.opacity(0.55) : XTheme.border.opacity(0.7),
                    lineWidth: isSelected ? 2 : 1
                )
                
                // Chord node
                ChordNodeView(
                    chord: chord,
                    isSelected: isSelected,
                    tension: tension,
                    key: appState.currentKey,
                    scale: appState.currentScale,
                    width: nodeWidth,
                    height: nodeHeight
                )
                .position(x: x, y: y)
                .onTapGesture {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                        appState.selectedChordIndex = index
                        appState.currentChord = chord
                    }
                }
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
                        .stroke(XTheme.borderActive, lineWidth: 2)
                )
                .frame(width: innerRadius * 2, height: innerRadius * 2)
                .shadow(color: XTheme.ambientShadow, radius: 8)
            
            VStack(spacing: 2) {
                Text(appState.currentKey.displayName)
                    .font(.system(size: max(13, min(28, innerRadius * 0.58)), weight: .bold, design: .rounded))
                    .foregroundColor(XTheme.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
                Text(appState.currentScale.shortDisplayName)
                    .font(.system(size: max(8, min(12, innerRadius * 0.25)), weight: .semibold))
                    .foregroundColor(XTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: innerRadius * 1.8)
        }
        .position(center)
    }
    
    // MARK: - Stick Indicator
    
    @ViewBuilder
    private func stickIndicator(center: CGPoint, maxRadius: CGFloat) -> some View {
        let state = appState.controllerManager.performanceState
        let magnitude = state.leftStickMagnitude
        let angle = state.leftStickAngle
        
        if magnitude > 0.1 {
            let indicatorRadius = maxRadius * CGFloat(min(magnitude, 1.0))
            let x = center.x + cos(CGFloat(angle)) * indicatorRadius
            let y = center.y - sin(CGFloat(angle)) * indicatorRadius // Flip Y
            let dotSize: CGFloat = max(9, min(14, maxRadius * 0.12))
            
            Circle()
                .fill(XTheme.accent.opacity(0.75))
                .frame(width: dotSize, height: dotSize)
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
    var width: CGFloat = 68
    var height: CGFloat = 52
    @State private var pulse: Bool = false
    
    var body: some View {
        let cornerRadius = max(6, min(12, height * 0.22))
        let mainFontSize = max(10, min(17, isSelected ? height * 0.35 : height * 0.31))
        let romanFontSize = max(7, min(11, height * 0.22))
        
        VStack(spacing: max(1, height * 0.05)) {
            Text(chord.displayName)
                .font(.system(size: mainFontSize, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundColor(isSelected ? .white : XTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            
            if let roman = chord.romanNumeral(in: key, scale: scale) {
                Text(roman)
                    .font(.system(size: romanFontSize, weight: .semibold, design: .monospaced))
                    .foregroundColor(isSelected ? XTheme.accent : XTheme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(width: width, height: height)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isSelected ? XTheme.primary.opacity(0.24) : XTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                isSelected ? XTheme.primary : XTheme.tensionColor(tension).opacity(0.35),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                if isSelected && !reduceMotion {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(XTheme.primary.opacity(pulse ? 0 : 0.45), lineWidth: 3)
                        .scaleEffect(pulse ? 1.18 : 1.0)
                        .opacity(pulse ? 0 : 0.6)
                }
            }
        )
        .shadow(color: isSelected ? XTheme.primary.opacity(0.32) : .clear, radius: 10)
        .scaleEffect(isSelected && !reduceMotion ? 1.05 : 1.0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isSelected)
        .onChange(of: isSelected) { _, newSelected in
            guard newSelected && !reduceMotion else { return }
            pulse = true
            withAnimation(.easeOut(duration: 0.7)) {
                pulse = false
            }
        }
    }
}
