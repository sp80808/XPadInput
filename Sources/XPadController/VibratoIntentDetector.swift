import Foundation

public enum VibratoIntentSource: String, Sendable, Equatable {
    case none
    case stick
    case gyro
    case trigger
}

public struct VibratoIntent: Sendable, Equatable {
    public var confidence: Double
    public var rateHz: Double
    public var amplitude: Double
    public var source: VibratoIntentSource
    public var isPeriodic: Bool

    public init(
        confidence: Double = 0,
        rateHz: Double = 5.2,
        amplitude: Double = 0,
        source: VibratoIntentSource = .none,
        isPeriodic: Bool = false
    ) {
        self.confidence = confidence
        self.rateHz = rateHz
        self.amplitude = amplitude
        self.source = source
        self.isPeriodic = isPeriodic
    }
}

/// Bounded periodic-intent detector. History is a fixed ring; the live path never grows.
public struct VibratoIntentDetector: Sendable {
    public static let capacity = 48
    public var enterConfidence: Double
    public var exitConfidence: Double

    private var stick: [Double]
    private var gyro: [Double]
    private var count: Int
    private var head: Int
    private var lastConfidence: Double
    private var lastRate: Double

    public init(enterConfidence: Double = 0.42, exitConfidence: Double = 0.28) {
        self.enterConfidence = enterConfidence
        self.exitConfidence = exitConfidence
        self.stick = Array(repeating: 0, count: Self.capacity)
        self.gyro = Array(repeating: 0, count: Self.capacity)
        self.count = 0
        self.head = 0
        self.lastConfidence = 0
        self.lastRate = 5.2
    }

    public mutating func reset() {
        stick = Array(repeating: 0, count: Self.capacity)
        gyro = Array(repeating: 0, count: Self.capacity)
        count = 0
        head = 0
        lastConfidence = 0
        lastRate = 5.2
    }

    public mutating func process(
        stickX: Double,
        gyroPitch: Double,
        gyroYaw: Double,
        triggerMicro: Double,
        allowStick: Bool,
        allowGyro: Bool,
        dt: TimeInterval
    ) -> VibratoIntent {
        let gyroSigned = gyroPitch * 0.65 + gyroYaw * 0.35
        push(stickX, into: &stick)
        push(gyroSigned, into: &gyro)
        count = min(Self.capacity, count + 1)

        let stickAnalysis = allowStick ? analyze(stick, dt: dt) : ChannelAnalysis()
        let gyroAnalysis = allowGyro ? analyze(gyro, dt: dt) : ChannelAnalysis()
        let triggerAmp = min(1, abs(triggerMicro) * 2)
        let triggerPeriodic = triggerAmp > 0.12 && stickAnalysis.isPeriodic

        let stickScore = stickAnalysis.score
        let gyroScore = gyroAnalysis.score
        let source: VibratoIntentSource
        let chosen: ChannelAnalysis
        if stickScore >= gyroScore && stickScore > 0.05 {
            source = .stick
            chosen = stickAnalysis
        } else if gyroScore > 0.05 {
            source = .gyro
            chosen = gyroAnalysis
        } else if triggerPeriodic {
            source = .trigger
            chosen = stickAnalysis
        } else {
            source = .none
            chosen = ChannelAnalysis()
        }

        var confidence = chosen.score
        if source == .trigger { confidence = min(1, confidence * 0.6 + triggerAmp * 0.2) }

        if lastConfidence >= enterConfidence {
            if confidence < exitConfidence { lastConfidence = confidence }
            else { lastConfidence = lastConfidence * 0.6 + confidence * 0.4 }
        } else {
            lastConfidence = lastConfidence * 0.7 + confidence * 0.3
        }

        if chosen.rateHz > 2.5 && chosen.rateHz < 9.5 {
            lastRate = lastRate * 0.7 + chosen.rateHz * 0.3
        }

        let active = lastConfidence >= enterConfidence && chosen.isPeriodic
        return VibratoIntent(
            confidence: min(1, lastConfidence),
            rateHz: lastRate,
            amplitude: chosen.amplitude,
            source: active ? source : .none,
            isPeriodic: active
        )
    }

    private mutating func push(_ value: Double, into buffer: inout [Double]) {
        buffer[head] = value
        head = (head + 1) % Self.capacity
    }

    private func analyze(_ buffer: [Double], dt: TimeInterval) -> ChannelAnalysis {
        guard count >= 16, dt > 0.0005 else { return ChannelAnalysis() }
        let n = count
        var samples = [Double](repeating: 0, count: n)
        let start = (head - n + Self.capacity) % Self.capacity
        for i in 0..<n {
            samples[i] = buffer[(start + i) % Self.capacity]
        }

        var mean = 0.0
        for s in samples { mean += s }
        mean /= Double(n)
        var energy = 0.0
        var crossings = 0
        var lastSign = samples[0] - mean
        var reversalGaps: [Int] = []
        reversalGaps.reserveCapacity(8)
        var lastCross = 0
        for i in 0..<n {
            let centered = samples[i] - mean
            energy += centered * centered
            if lastSign == 0 { lastSign = centered }
            if lastSign * centered < 0 {
                crossings += 1
                if i > lastCross { reversalGaps.append(i - lastCross) }
                lastCross = i
                lastSign = centered
            } else if centered != 0 {
                lastSign = centered
            }
        }
        let amplitude = sqrt(energy / Double(n))
        guard amplitude > 0.012, crossings >= 3 else {
            return ChannelAnalysis(amplitude: amplitude)
        }

        let sampleHz = 1.0 / dt
        let minLag = max(3, Int(sampleHz / 9.5))
        let maxLag = min(n / 2, max(minLag + 1, Int(sampleHz / 2.8)))
        var bestLag = minLag
        var bestCorr = -1.0
        for lag in minLag...maxLag {
            var num = 0.0
            var denA = 0.0
            var denB = 0.0
            let limit = n - lag
            for i in 0..<limit {
                let a = samples[i] - mean
                let b = samples[i + lag] - mean
                num += a * b
                denA += a * a
                denB += b * b
            }
            let den = sqrt(denA * denB)
            guard den > 1e-9 else { continue }
            let corr = num / den
            if corr > bestCorr {
                bestCorr = corr
                bestLag = lag
            }
        }

        let rate = sampleHz / Double(max(1, bestLag))
        let gapRegularity: Double
        if reversalGaps.count >= 2 {
            let avg = Double(reversalGaps.reduce(0, +)) / Double(reversalGaps.count)
            var varsum = 0.0
            for g in reversalGaps { varsum += pow(Double(g) - avg, 2) }
            let cv = sqrt(varsum / Double(reversalGaps.count)) / max(1, avg)
            gapRegularity = max(0, 1 - cv)
        } else {
            gapRegularity = 0
        }

        let inBand = rate >= 2.8 && rate <= 9.2
        let score = max(0, min(1, bestCorr * 0.55 + gapRegularity * 0.35 + (inBand ? 0.15 : 0)))
        return ChannelAnalysis(
            score: score,
            rateHz: rate,
            amplitude: amplitude,
            isPeriodic: inBand && bestCorr > 0.35 && crossings >= 3
        )
    }

    private struct ChannelAnalysis {
        var score: Double = 0
        var rateHz: Double = 5.2
        var amplitude: Double = 0
        var isPeriodic: Bool = false
    }
}
