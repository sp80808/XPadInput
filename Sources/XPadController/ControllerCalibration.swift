import Foundation
import XPadCore

// MARK: - Hardware Calibration Data Structures

/// Calibration offsets and reachable bounds for an individual analog thumbstick.
public struct StickCalibration: Codable, Sendable, Equatable {
    public var restCenterX: Float
    public var restCenterY: Float
    public var driftRadius: Float
    public var minX: Float
    public var maxX: Float
    public var minY: Float
    public var maxY: Float
    public var maxRadius: Float
    public var invertX: Bool
    public var invertY: Bool
    public var sensitivityX: Float
    public var sensitivityY: Float

    public init(
        restCenterX: Float = 0.0,
        restCenterY: Float = 0.0,
        driftRadius: Float = 0.04,
        minX: Float = -1.0,
        maxX: Float = 1.0,
        minY: Float = -1.0,
        maxY: Float = 1.0,
        maxRadius: Float = 1.0,
        invertX: Bool = false,
        invertY: Bool = false,
        sensitivityX: Float = 1.0,
        sensitivityY: Float = 1.0
    ) {
        self.restCenterX = restCenterX
        self.restCenterY = restCenterY
        self.driftRadius = driftRadius
        self.minX = minX
        self.maxX = maxX
        self.minY = minY
        self.maxY = maxY
        self.maxRadius = maxRadius
        self.invertX = invertX
        self.invertY = invertY
        self.sensitivityX = sensitivityX
        self.sensitivityY = sensitivityY
    }

    /// Calibrates raw hardware values into a normalized [-1.0 ... 1.0] range.
    public func calibrate(rawX: Float, rawY: Float) -> (x: Float, y: Float) {
        // 1. Subtract rest center offset
        var cx = rawX - restCenterX
        var cy = rawY - restCenterY

        // 2. Deadzone suppression for measured center drift
        let currentRadius = sqrt(cx * cx + cy * cy)
        if currentRadius < driftRadius {
            return (0, 0)
        }

        // 3. Rescale outward past drift deadzone
        let scaledRadius = (currentRadius - driftRadius) / max(0.001, (maxRadius - driftRadius))
        let ratio = max(0.0, min(1.0, scaledRadius)) / currentRadius
        cx *= ratio
        cy *= ratio

        // 4. Sensitivity & Inversion
        if invertX { cx = -cx }
        if invertY { cy = -cy }
        cx = max(-1.0, min(1.0, cx * sensitivityX))
        cy = max(-1.0, min(1.0, cy * sensitivityY))

        return (cx, cy)
    }
}

/// Calibration thresholds for an analog trigger.
public struct TriggerCalibration: Codable, Sendable, Equatable {
    public var restMin: Float
    public var travelMax: Float
    public var sensitivity: Float

    public init(restMin: Float = 0.0, travelMax: Float = 1.0, sensitivity: Float = 1.0) {
        self.restMin = restMin
        self.travelMax = travelMax
        self.sensitivity = sensitivity
    }

    public func calibrate(rawValue: Float) -> Float {
        guard rawValue > restMin else { return 0 }
        let travel = max(0.001, travelMax - restMin)
        let normalized = (rawValue - restMin) / travel
        return max(0.0, min(1.0, normalized * sensitivity))
    }
}

/// A complete hardware calibration profile for a specific controller device.
public struct ControllerHardwareCalibration: Codable, Sendable, Equatable {
    public var controllerIdentifier: String
    public var leftStick: StickCalibration
    public var rightStick: StickCalibration
    public var leftTrigger: TriggerCalibration
    public var rightTrigger: TriggerCalibration

    public init(
        controllerIdentifier: String = "default_gamepad",
        leftStick: StickCalibration = StickCalibration(),
        rightStick: StickCalibration = StickCalibration(),
        leftTrigger: TriggerCalibration = TriggerCalibration(),
        rightTrigger: TriggerCalibration = TriggerCalibration()
    ) {
        self.controllerIdentifier = controllerIdentifier
        self.leftStick = leftStick
        self.rightStick = rightStick
        self.leftTrigger = leftTrigger
        self.rightTrigger = rightTrigger
    }
}

// MARK: - Interactive Calibration Wizard State Machine

public enum CalibrationWizardStep: Sendable, Equatable {
    case idle
    case measuringRest(samples: Int)
    case measuringRange(maxLeftR: Float, maxRightR: Float)
    case completed
}

public final class CalibrationWizard: @unchecked Sendable {
    public private(set) var currentStep: CalibrationWizardStep = .idle
    private var restLeftSamples: [(Float, Float)] = []
    private var restRightSamples: [(Float, Float)] = []
    private var observedMaxLeftRadius: Float = 0.0
    private var observedMaxRightRadius: Float = 0.0

    public init() {}

    public func start() {
        currentStep = .measuringRest(samples: 0)
        restLeftSamples.removeAll()
        restRightSamples.removeAll()
        observedMaxLeftRadius = 0.0
        observedMaxRightRadius = 0.0
    }

    public func feed(rawLeftX: Float, rawLeftY: Float, rawRightX: Float, rawRightY: Float) {
        switch currentStep {
        case .measuringRest(let samples):
            restLeftSamples.append((rawLeftX, rawLeftY))
            restRightSamples.append((rawRightX, rawRightY))
            let nextCount = samples + 1
            if nextCount >= 60 { // ~1 second of samples
                currentStep = .measuringRange(maxLeftR: 0, maxRightR: 0)
            } else {
                currentStep = .measuringRest(samples: nextCount)
            }

        case .measuringRange:
            let rL = sqrt(rawLeftX * rawLeftX + rawLeftY * rawLeftY)
            let rR = sqrt(rawRightX * rawRightX + rawRightY * rawRightY)
            observedMaxLeftRadius = max(observedMaxLeftRadius, rL)
            observedMaxRightRadius = max(observedMaxRightRadius, rR)
            currentStep = .measuringRange(maxLeftR: observedMaxLeftRadius, maxRightR: observedMaxRightRadius)

        case .idle, .completed:
            break
        }
    }

    public func finish() -> ControllerHardwareCalibration {
        var cal = ControllerHardwareCalibration()

        if !restLeftSamples.isEmpty {
            let avgLX = restLeftSamples.map(\.0).reduce(0, +) / Float(restLeftSamples.count)
            let avgLY = restLeftSamples.map(\.1).reduce(0, +) / Float(restLeftSamples.count)
            let maxDriftL = restLeftSamples.map { sqrt(($0.0 - avgLX) * ($0.0 - avgLX) + ($0.1 - avgLY) * ($0.1 - avgLY)) }.max() ?? 0.04
            cal.leftStick.restCenterX = avgLX
            cal.leftStick.restCenterY = avgLY
            cal.leftStick.driftRadius = max(0.02, maxDriftL * 1.5)
        }

        if !restRightSamples.isEmpty {
            let avgRX = restRightSamples.map(\.0).reduce(0, +) / Float(restRightSamples.count)
            let avgRY = restRightSamples.map(\.1).reduce(0, +) / Float(restRightSamples.count)
            let maxDriftR = restRightSamples.map { sqrt(($0.0 - avgRX) * ($0.0 - avgRX) + ($0.1 - avgRY) * ($0.1 - avgRY)) }.max() ?? 0.04
            cal.rightStick.restCenterX = avgRX
            cal.rightStick.restCenterY = avgRY
            cal.rightStick.driftRadius = max(0.02, maxDriftR * 1.5)
        }

        cal.leftStick.maxRadius = max(0.85, min(1.15, observedMaxLeftRadius))
        cal.rightStick.maxRadius = max(0.85, min(1.15, observedMaxRightRadius))

        currentStep = .completed
        return cal
    }

    public func cancel() {
        currentStep = .idle
    }
}

// MARK: - Controller Settings Store & Persistence

public final class ControllerSettingsStore: @unchecked Sendable {
    public static let shared = ControllerSettingsStore()
    
    private let activeSchemeKey = "com.xpadinput.controls.activeSchemeId"
    private let customSchemesKey = "com.xpadinput.controls.customSchemes"
    private let calibrationsKey = "com.xpadinput.controls.calibrations"
    
    private let defaults = UserDefaults.standard

    public init() {}

    // MARK: - Scheme Storage

    public func loadActiveSchemeId() -> String {
        defaults.string(forKey: activeSchemeKey) ?? ControlSchemePreset.xpiPerformance.id
    }

    public func saveActiveSchemeId(_ id: String) {
        defaults.set(id, forKey: activeSchemeKey)
    }

    public func loadCustomSchemes() -> [ControlScheme] {
        guard let data = defaults.data(forKey: customSchemesKey) else { return [] }
        return (try? JSONDecoder().decode([ControlScheme].self, from: data)) ?? []
    }

    public func saveCustomSchemes(_ schemes: [ControlScheme]) {
        if let data = try? JSONEncoder().encode(schemes) {
            defaults.set(data, forKey: customSchemesKey)
        }
    }

    public func saveCustomScheme(_ scheme: ControlScheme) {
        var all = loadCustomSchemes()
        if let idx = all.firstIndex(where: { $0.id == scheme.id }) {
            all[idx] = scheme
        } else {
            all.append(scheme)
        }
        saveCustomSchemes(all)
    }

    public func deleteCustomScheme(id: String) {
        var all = loadCustomSchemes()
        all.removeAll(where: { $0.id == id })
        saveCustomSchemes(all)
    }

    // MARK: - Calibration Storage

    public func loadCalibration(for controllerId: String) -> ControllerHardwareCalibration {
        guard let dict = defaults.dictionary(forKey: calibrationsKey) as? [String: Data],
              let data = dict[controllerId],
              let cal = try? JSONDecoder().decode(ControllerHardwareCalibration.self, from: data) else {
            return ControllerHardwareCalibration(controllerIdentifier: controllerId)
        }
        return cal
    }

    public func saveCalibration(_ calibration: ControllerHardwareCalibration) {
        var dict = (defaults.dictionary(forKey: calibrationsKey) as? [String: Data]) ?? [:]
        if let data = try? JSONEncoder().encode(calibration) {
            dict[calibration.controllerIdentifier] = data
            defaults.set(dict, forKey: calibrationsKey)
        }
    }

    public func resetCalibration(for controllerId: String) {
        var dict = (defaults.dictionary(forKey: calibrationsKey) as? [String: Data]) ?? [:]
        dict.removeValue(forKey: controllerId)
        defaults.set(dict, forKey: calibrationsKey)
    }
}
