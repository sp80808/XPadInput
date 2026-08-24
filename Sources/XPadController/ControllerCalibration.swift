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

    public var isValid: Bool {
        !restCenterX.isNaN && !restCenterY.isNaN &&
        !driftRadius.isNaN && driftRadius >= 0.0 && driftRadius < 0.5 &&
        !maxRadius.isNaN && maxRadius > driftRadius && maxRadius <= 2.0 &&
        !sensitivityX.isNaN && sensitivityX > 0 &&
        !sensitivityY.isNaN && sensitivityY > 0
    }

    public mutating func validateAndRepair() {
        if restCenterX.isNaN { restCenterX = 0.0 }
        if restCenterY.isNaN { restCenterY = 0.0 }
        if driftRadius.isNaN || driftRadius < 0.0 || driftRadius >= 0.5 { driftRadius = 0.04 }
        if maxRadius.isNaN || maxRadius <= driftRadius || maxRadius > 2.0 { maxRadius = 1.0 }
        if sensitivityX.isNaN || sensitivityX <= 0.0 { sensitivityX = 1.0 }
        if sensitivityY.isNaN || sensitivityY <= 0.0 { sensitivityY = 1.0 }
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

    public var isValid: Bool {
        !restMin.isNaN && restMin >= 0.0 && restMin < 0.8 &&
        !travelMax.isNaN && travelMax > restMin && travelMax <= 1.5 &&
        !sensitivity.isNaN && sensitivity > 0.0
    }

    public mutating func validateAndRepair() {
        if restMin.isNaN || restMin < 0.0 || restMin >= 0.8 { restMin = 0.0 }
        if travelMax.isNaN || travelMax <= restMin || travelMax > 1.5 { travelMax = 1.0 }
        if sensitivity.isNaN || sensitivity <= 0.0 { sensitivity = 1.0 }
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

    public mutating func validateAndRepair() {
        leftStick.validateAndRepair()
        rightStick.validateAndRepair()
        leftTrigger.validateAndRepair()
        rightTrigger.validateAndRepair()
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
            let countL = Float(restLeftSamples.count)
            let avgLX = restLeftSamples.map(\.0).reduce(0, +) / countL
            let avgLY = restLeftSamples.map(\.1).reduce(0, +) / countL
            var maxDriftL: Float = 0.04
            for sample in restLeftSamples {
                let dx = sample.0 - avgLX
                let dy = sample.1 - avgLY
                let d = sqrt(dx * dx + dy * dy)
                if d > maxDriftL { maxDriftL = d }
            }
            cal.leftStick.restCenterX = avgLX
            cal.leftStick.restCenterY = avgLY
            cal.leftStick.driftRadius = max(0.02, min(0.35, maxDriftL * 1.5))
        }

        if !restRightSamples.isEmpty {
            let countR = Float(restRightSamples.count)
            let avgRX = restRightSamples.map(\.0).reduce(0, +) / countR
            let avgRY = restRightSamples.map(\.1).reduce(0, +) / countR
            var maxDriftR: Float = 0.04
            for sample in restRightSamples {
                let dx = sample.0 - avgRX
                let dy = sample.1 - avgRY
                let d = sqrt(dx * dx + dy * dy)
                if d > maxDriftR { maxDriftR = d }
            }
            cal.rightStick.restCenterX = avgRX
            cal.rightStick.restCenterY = avgRY
            cal.rightStick.driftRadius = max(0.02, min(0.35, maxDriftR * 1.5))
        }

        if observedMaxLeftRadius > 0.4 {
            cal.leftStick.maxRadius = max(0.85, min(1.15, observedMaxLeftRadius))
        } else {
            cal.leftStick.maxRadius = 1.0
        }

        if observedMaxRightRadius > 0.4 {
            cal.rightStick.maxRadius = max(0.85, min(1.15, observedMaxRightRadius))
        } else {
            cal.rightStick.maxRadius = 1.0
        }

        cal.validateAndRepair()
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
        do {
            return try JSONDecoder().decode([ControlScheme].self, from: data)
        } catch {
            print("⚠️ Failed to decode stored custom control schemes: \(error)")
            return []
        }
    }

    public func saveCustomSchemes(_ schemes: [ControlScheme]) {
        do {
            let data = try JSONEncoder().encode(schemes)
            defaults.set(data, forKey: customSchemesKey)
        } catch {
            print("⚠️ Failed to encode custom control schemes; changes were not saved: \(error)")
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
              let data = dict[controllerId] else {
            return ControllerHardwareCalibration(controllerIdentifier: controllerId)
        }
        do {
            var cal = try JSONDecoder().decode(ControllerHardwareCalibration.self, from: data)
            cal.validateAndRepair()
            return cal
        } catch {
            print("⚠️ Failed to decode calibration for \(controllerId); using defaults: \(error)")
            return ControllerHardwareCalibration(controllerIdentifier: controllerId)
        }
    }

    public func saveCalibration(_ calibration: ControllerHardwareCalibration) {
        do {
            let data = try JSONEncoder().encode(calibration)
            var dict = (defaults.dictionary(forKey: calibrationsKey) as? [String: Data]) ?? [:]
            dict[calibration.controllerIdentifier] = data
            defaults.set(dict, forKey: calibrationsKey)
        } catch {
            print("⚠️ Failed to encode calibration for \(calibration.controllerIdentifier); not saved: \(error)")
        }
    }

    public func resetCalibration(for controllerId: String) {
        var dict = (defaults.dictionary(forKey: calibrationsKey) as? [String: Data]) ?? [:]
        dict.removeValue(forKey: controllerId)
        defaults.set(dict, forKey: calibrationsKey)
    }

    // MARK: - Background Monitoring Storage

    private let backgroundMonitoringKey = "com.xpadinput.controls.backgroundMonitoring"

    public func loadBackgroundMonitoring() -> Bool {
        if defaults.object(forKey: backgroundMonitoringKey) == nil {
            return true // Default to true so background input works out of the box
        }
        return defaults.bool(forKey: backgroundMonitoringKey)
    }

    public func saveBackgroundMonitoring(_ enabled: Bool) {
        defaults.set(enabled, forKey: backgroundMonitoringKey)
    }
}
