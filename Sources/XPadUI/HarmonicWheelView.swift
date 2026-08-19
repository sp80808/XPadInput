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
            // Use more of the available space - reduced padding from 40 to 24
            let maxRadius = min(geo.size.width, geo.size.height) / 2 - 24
            // Chord nodes positioned further out (85% instead of 72%)
            let chordRadius = maxRadius * 0.85
            // Larger center area (40% instead of 35%)
            let innerRadius = maxRadius * 0.40
            
            ZStack {
                backgroundRings(center: center, maxRadius: maxRadius)
                selectedSector(center: center, innerRadius: innerRadius, outerRadius: maxRadius)
                chordSegments(center: center, radius: chordRadius, innerRadius: innerRadius)
                centerDisplay(center: center, innerRadius: innerRadius)
                stickIndicator(center: center, maxRadius: maxRadius)
            }
        }
    }
    
    // MARK: - Background
    
    @ViewBuilder
    private func backgroundRings(center: CGPoint, maxRadius: CGFloat) -> some View {
        let magnitude = min(1, max(0, appState.controllerManager.controllerState.leftStickMagnitude))
        let risk = CGFloat(magnitude)

        Circle()
            .stroke(XTheme.border, lineWidth: 1)
            .frame(width: maxRadius * 2, height: maxRadius * 2)
            .position(center)

        Circle()
            .stroke(XTheme.tense.opacity(0.08 + risk * 0.28), lineWidth: 1.5 + risk * 2)
            .frame(width: maxRadius * 2, height: maxRadius * 2)
            .position(center)

        Circle()
            .fill(
                RadialGradient(
                    colors: [XTheme.primary.opacity(0.05 + magnitude * 0.06), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: maxRadius
                )
            )
            .frame(width: maxRadius * 2, height: maxRadius * 2)
            .position(center)
    }

    @ViewBuilder
    private func selectedSector(center: CGPoint, innerRadius: CGFloat, outerRadius: CGFloat) -> some View {
        let chords = appState.diatonicChords
        let count = chords.count
        if count > 0, appState.selectedChordIndex >= 0, appState.selectedChordIndex < count {
            let slice = (2 * CGFloat.pi) / CGFloat(count)
            let mid = -CGFloat.pi / 2 + CGFloat(appState.selectedChordIndex) * slice
            Path { path in
                path.addArc(
                    center: center,
                    radius: outerRadius,
                    startAngle: Angle(radians: Double(mid - slice / 2)),
                    endAngle: Angle(radians: Double(mid + slice / 2)),
                    clockwise: false
                )
                path.addArc(
                    center: center,
                    radius: innerRadius,
                    startAngle: Angle(radians: Double(mid + slice / 2)),
                    endAngle: Angle(radians: Double(mid - slice / 2)),
                    clockwise: true
                )
                path.closeSubpath()
            }
            .fill(XTheme.primary.opacity(0.10))
            .animation(reduceMotion ? nil : XTheme.transitionShort, value: appState.selectedChordIndex)
        }
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
                withAnimation(reduceMotion ? nil : XTheme.springSnappy) {
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
                        .stroke(XTheme.borderActive, lineWidth: 2)
                )
                .overlay(
                    Circle()
                        .stroke(XTheme.primary.opacity(0.18), lineWidth: 1)
                        .padding(innerRadius * 0.22)
                )
                .frame(width: innerRadius * 2, height: innerRadius * 2)
            
            VStack(spacing: 6) {
                Text(appState.currentKey.displayName)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(XTheme.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .xMusicalContent(appState.currentKey.displayName)
                
                Text(appState.currentScale.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(XTheme.textSecondary)
                    .lineLimit(1)
                    .xMusicalContent(appState.currentScale.id)
            }
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
            let indicatorRadius = maxRadius * CGFloat(min(magnitude, 1.0)) * 0.85
            let x = center.x + cos(CGFloat(angle)) * indicatorRadius
            let y = center.y - sin(CGFloat(angle)) * indicatorRadius // Flip Y
            let tailX = center.x + cos(CGFloat(angle)) * indicatorRadius * 0.62
            let tailY = center.y - sin(CGFloat(angle)) * indicatorRadius * 0.62

            Path { path in
                path.move(to: center)
                path.addLine(to: CGPoint(x: x, y: y))
            }
            .stroke(XTheme.accent.opacity(0.28 + magnitude * 0.25), lineWidth: 1.5)

            Circle()
                .fill(XTheme.accent.opacity(0.22))
                .frame(width: 10, height: 10)
                .position(x: tailX, y: tailY)

            Circle()
                .fill(XTheme.accent.opacity(0.72))
                .frame(width: 14, height: 14)
                .xGlow(isActive: true, color: XTheme.accent)
                .position(x: x, y: y)
        }
    }
}

// MARK: - Chord Node

struct ChordNodeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    let chord: Chord
    let isSelected: Bool
    let tension: Double
    let key: PitchClass
    let scale: Scale

    private var character: HarmonicTensionCharacter { HarmonicTensionCharacter(tension: tension) }
    private var tensionTint: Color { XTheme.tensionColor(tension) }
    
    var body: some View {
        VStack(spacing: 3) {
            Text(chord.displayName)
                .font(.system(size: isSelected ? 16 : 14, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundColor(isSelected ? .white : XTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            HStack(spacing: 3) {
                if let roman = chord.romanNumeral(in: key, scale: scale) {
                    Text(roman)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(isSelected ? XTheme.accent : XTheme.textTertiary)
                }
                Image(systemName: character.symbolName)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(isSelected ? XTheme.accent : tensionTint.opacity(0.85))
            }
        }
        .frame(width: 68, height: 52)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? XTheme.primary.opacity(0.24) : (isHovering ? XTheme.surfaceHover : XTheme.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? XTheme.primary : tensionTint.opacity(isHovering ? 0.55 : 0.32),
                            lineWidth: isSelected ? 2 : CGFloat(character.ringWeight)
                        )
                )
        )
        .shadow(color: isSelected ? XTheme.primary.opacity(0.28) : .clear, radius: 10)
        .scaleEffect(nodeScale)
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : XTheme.hoverAnimation, value: isHovering)
        .animation(reduceMotion ? nil : XTheme.springSnappy, value: isSelected)
        .help("\(chord.displayName) · \(character.label)")
        .accessibilityLabel("\(chord.displayName), \(character.label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var nodeScale: CGFloat {
        guard !reduceMotion else { return 1 }
        if isSelected { return 1.06 }
        if isHovering { return 1.03 }
        return 1
    }
}
