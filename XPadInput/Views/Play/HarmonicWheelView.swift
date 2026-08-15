import SwiftUI

/// Interactive harmonic wheel showing chords from the active layer arranged as radial sectors.
/// Left stick position selects chords; shoulder buttons switch layers.
struct HarmonicWheelView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let maxRadius = min(geo.size.width, geo.size.height) / 2 - 30
            let outerRadius = maxRadius * 0.92
            let innerRadius = maxRadius * 0.32

            ZStack {
                // Background
                backgroundRings(center: center, outerRadius: outerRadius, innerRadius: innerRadius)

                // Sector slices for active layer
                sectorSlices(center: center, outerRadius: outerRadius, innerRadius: innerRadius)

                // Center info
                centerDisplay(center: center, innerRadius: innerRadius)

                // Left stick position indicator
                stickIndicator(center: center, maxRadius: outerRadius)

                // Layer badge ribbon
                layerRibbon(geo: geo)
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private func backgroundRings(center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat) -> some View {
        // Outer glow
        Circle()
            .fill(
                RadialGradient(
                    colors: [layerColor(appState.activeLayer).opacity(0.04), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: outerRadius
                )
            )
            .frame(width: outerRadius * 2, height: outerRadius * 2)
            .position(center)

        // Outer ring
        Circle()
            .stroke(layerColor(appState.activeLayer).opacity(0.15), lineWidth: 1)
            .frame(width: outerRadius * 2, height: outerRadius * 2)
            .position(center)

        // Mid ring
        Circle()
            .stroke(XTheme.border, lineWidth: 0.5)
            .frame(width: (outerRadius + innerRadius), height: (outerRadius + innerRadius))
            .position(center)
    }

    // MARK: - Sector Slices

    @ViewBuilder
    private func sectorSlices(center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat) -> some View {
        if let sectors = appState.harmonicWheel?.sectorsByLayer[appState.activeLayer] {
            let count = sectors.count
            let sliceAngle = (2.0 * Double.pi) / Double(count)

            ForEach(sectors) { sector in
                let isHighlighted = (appState.highlightedSector?.id == sector.id
                    && appState.highlightedSector?.layer == sector.layer)
                let isCurrent = appState.currentChord.map { c in
                    c.root == sector.chord.root && c.quality == sector.chord.quality
                } ?? false

                let startAngle = Angle(radians: sector.angle - sliceAngle / 2 + .pi / 2)
                let endAngle = Angle(radians: sector.angle + sliceAngle / 2 + .pi / 2)
                let layerCol = layerColor(sector.layer)

                let fillColor: Color = isCurrent ? layerCol.opacity(0.4) :
                                        isHighlighted ? layerCol.opacity(0.2) :
                                        XTheme.surfaceElevated.opacity(0.5)

                let strokeColor: Color = isCurrent ? layerCol :
                                          isHighlighted ? layerCol.opacity(0.5) :
                                          XTheme.border.opacity(0.6)

                // Slice arc
                SectorArc(
                    startAngle: startAngle,
                    endAngle: endAngle,
                    innerRadius: innerRadius + 3,
                    outerRadius: outerRadius - 3
                )
                .fill(fillColor)
                .position(center)
                .overlay(
                    SectorArc(
                        startAngle: startAngle,
                        endAngle: endAngle,
                        innerRadius: innerRadius + 3,
                        outerRadius: outerRadius - 3
                    )
                    .stroke(strokeColor, lineWidth: isCurrent ? 2.0 : 0.5)
                    .position(center)
                )
                .onTapGesture {
                    withAnimation(XTheme.springAnimation) {
                        appState.currentChord = sector.chord
                        appState.highlightedSector = sector
                    }
                }

                // Label
                let labelRadius = (innerRadius + outerRadius) / 2
                let labelAngle = sector.angle
                let labelX = center.x + labelRadius * CGFloat(cos(labelAngle))
                let labelY = center.y + labelRadius * CGFloat(sin(labelAngle))

                VStack(spacing: 1) {
                    Text(sector.romanNumeral)
                        .font(.system(size: isCurrent ? 13 : 10.5,
                                      weight: isCurrent ? .bold : .semibold,
                                      design: .monospaced))
                        .foregroundColor(isCurrent ? .white : XTheme.textPrimary)

                    Text(sector.chord.displayName)
                        .font(.system(size: isCurrent ? 10 : 8.5, weight: .medium))
                        .foregroundColor(isCurrent ? .white.opacity(0.85) : XTheme.textSecondary)

                    // Harmonic function hint
                    if isCurrent {
                        Text(sector.harmonicFunction)
                            .font(.system(size: 7))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .position(x: labelX, y: labelY)
                .animation(XTheme.quickAnimation, value: isCurrent)
            }
        } else {
            // Fallback: show diatonic chord nodes
            fallbackChordNodes(center: center, outerRadius: outerRadius)
        }
    }

    @ViewBuilder
    private func fallbackChordNodes(center: CGPoint, outerRadius: CGFloat) -> some View {
        let chords = appState.diatonicChords
        let count = chords.count
        if count > 0 {
            let sliceAngle = (2 * CGFloat.pi) / CGFloat(count)
            let radius = outerRadius * 0.72
            ForEach(0..<count, id: \.self) { index in
                let chord = chords[index]
                let isSelected = index == appState.selectedChordIndex
                let angle = -CGFloat.pi / 2 + CGFloat(index) * sliceAngle
                let x = center.x + cos(angle) * radius
                let y = center.y + sin(angle) * radius

                ChordNodeView(
                    chord: chord,
                    isSelected: isSelected,
                    tension: chord.tension(in: appState.currentKey, scale: appState.currentScale),
                    key: appState.currentKey,
                    scale: appState.currentScale
                )
                .position(x: x, y: y)
                .onTapGesture {
                    withAnimation(XTheme.springAnimation) {
                        appState.selectedChordIndex = index
                        appState.currentChord = chord
                    }
                }
            }
        }
    }

    // MARK: - Center Display

    @ViewBuilder
    private func centerDisplay(center: CGPoint, innerRadius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(XTheme.surface)
                .overlay(
                    Circle()
                        .stroke(layerColor(appState.activeLayer).opacity(0.5), lineWidth: 1.5)
                )
                .frame(width: innerRadius * 2, height: innerRadius * 2)
                .shadow(color: layerColor(appState.activeLayer).opacity(0.15), radius: 16)

            VStack(spacing: 4) {
                // Current chord being played
                if let chord = appState.currentChord {
                    Text(chord.displayName)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(XTheme.textPrimary)
                        .contentTransition(.numericText())
                } else {
                    Text(appState.currentKey.displayName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(XTheme.primary)
                }

                Text(appState.currentScale.name
                    .replacingOccurrences(of: " (Ionian)", with: "")
                    .replacingOccurrences(of: " (Aeolian)", with: ""))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(XTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Roman numeral of current chord
                if let chord = appState.currentChord,
                   let roman = chord.romanNumeral(in: appState.currentKey, scale: appState.currentScale) {
                    Text(roman)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(layerColor(appState.activeLayer))
                        .padding(.top, 1)
                }
            }
        }
        .position(center)
    }

    // MARK: - Stick Indicator

    @ViewBuilder
    private func stickIndicator(center: CGPoint, maxRadius: CGFloat) -> some View {
        let state = appState.controllerManager.controllerState
        let mag = state.leftStickMagnitude
        let angle = state.leftStickAngle

        if mag > 0.1 {
            let indicatorRadius = maxRadius * CGFloat(min(mag, 1.0)) * 0.85
            let x = center.x + cos(CGFloat(angle)) * indicatorRadius
            let y = center.y - sin(CGFloat(angle)) * indicatorRadius

            // Direction line from centre
            Path { path in
                path.move(to: center)
                path.addLine(to: CGPoint(x: x, y: y))
            }
            .stroke(layerColor(appState.activeLayer).opacity(0.2), lineWidth: 1)

            // Dot
            Circle()
                .fill(XTheme.accent.opacity(0.7))
                .frame(width: 12, height: 12)
                .xGlow(isActive: true, color: XTheme.accent)
                .position(x: x, y: y)
                .animation(.linear(duration: 0.04), value: x)
                .animation(.linear(duration: 0.04), value: y)
        }
    }

    // MARK: - Layer Ribbon

    @ViewBuilder
    private func layerRibbon(geo: GeometryProxy) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 4) {
                ForEach(WheelLayer.allCases) { layer in
                    let isActive = appState.activeLayer == layer
                    Text(layer.shortName)
                        .font(.system(size: 9, weight: isActive ? .bold : .medium, design: .monospaced))
                        .foregroundColor(isActive ? .white : XTheme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(isActive ? layerColor(layer).opacity(0.6) : XTheme.surface)
                        )
                        .onTapGesture {
                            withAnimation(XTheme.springAnimation) {
                                appState.activeLayer = layer
                            }
                        }
                }
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Layer Colors

    private func layerColor(_ layer: WheelLayer) -> Color {
        switch layer {
        case .diatonic: return XTheme.stable
        case .colour:   return XTheme.colourful
        case .borrowed: return XTheme.natural
        case .tension:  return XTheme.tense
        case .mediant:  return XTheme.strong
        }
    }
}

// MARK: - Sector Arc Shape

struct SectorArc: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: 0, y: 0)

        p.addArc(center: center, radius: innerRadius,
                 startAngle: startAngle, endAngle: endAngle, clockwise: false)
        p.addArc(center: center, radius: outerRadius,
                 startAngle: endAngle, endAngle: startAngle, clockwise: true)
        p.closeSubpath()

        return p
    }
}

// MARK: - Chord Node (fallback mode)

struct ChordNodeView: View {
    let chord: Chord
    let isSelected: Bool
    let tension: Double
    let key: PitchClass
    let scale: Scale

    var body: some View {
        VStack(spacing: 3) {
            Text(chord.displayName)
                .font(.system(size: isSelected ? 16 : 13,
                              weight: isSelected ? .bold : .semibold,
                              design: .rounded))
                .foregroundColor(isSelected ? .white : XTheme.textPrimary)

            if let roman = chord.romanNumeral(in: key, scale: scale) {
                Text(roman)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(isSelected ? XTheme.accent : XTheme.textTertiary)
            }
        }
        .frame(width: isSelected ? 64 : 54, height: isSelected ? 46 : 38)
        .background(
            RoundedRectangle(cornerRadius: isSelected ? 12 : 10)
                .fill(isSelected ? XTheme.primary.opacity(0.25) : XTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: isSelected ? 12 : 10)
                        .stroke(
                            isSelected ? XTheme.primary : XTheme.tensionColor(tension).opacity(0.3),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
        )
        .xGlow(isActive: isSelected, color: XTheme.primary)
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(XTheme.springAnimation, value: isSelected)
    }
}
