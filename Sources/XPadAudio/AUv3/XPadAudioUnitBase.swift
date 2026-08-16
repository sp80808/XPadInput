import Foundation
import AudioToolbox
import AVFoundation

/// Base AUAudioUnit class for XPadInput AUv3 plugins providing parameter trees, bus lifecycle, and state persistence.
open class XPadAudioUnitBase: AUAudioUnit, @unchecked Sendable {
    public private(set) var parameterSnapshot = XPadAUParameterSnapshot()
    private let parameterLock = NSLock()
    private var parameterTreeObserverToken: AUParameterObserverToken?
    
    public override init(
        componentDescription: AudioComponentDescription,
        options: AudioComponentInstantiationOptions = []
    ) throws {
        try super.init(componentDescription: componentDescription, options: options)
        
        let tree = XPadAUParameterTreeBuilder.createParameterTree()
        self.parameterTree = tree
        
        // Populate initial snapshot
        for address in XPadAUParameterAddress.allCases {
            if let param = tree.parameter(withAddress: address.rawValue) {
                parameterSnapshot.update(address: address, value: param.value)
            }
        }
        
        // Observe tree parameter changes
        parameterTreeObserverToken = tree.token(byAddingParameterObserver: { [weak self] address, value in
            guard let self = self, let paramAddr = XPadAUParameterAddress(rawValue: address) else { return }
            self.parameterLock.lock()
            self.parameterSnapshot.update(address: paramAddr, value: value)
            self.parameterLock.unlock()
            self.didUpdateParameter(address: paramAddr, value: value)
        })
    }
    
    deinit {
        if let token = parameterTreeObserverToken {
            parameterTree?.removeParameterObserver(token)
        }
    }
    
    /// Hook for subclasses when a parameter changes.
    open func didUpdateParameter(address: XPadAUParameterAddress, value: AUValue) {}
    
    /// Thread-safe copy of the current parameter state.
    public func currentParameterSnapshot() -> XPadAUParameterSnapshot {
        parameterLock.lock()
        let snapshot = parameterSnapshot
        parameterLock.unlock()
        return snapshot
    }
    
    // MARK: - State Management & Presets
    
    open override var fullState: [String: Any]? {
        get {
            var state = super.fullState ?? [:]
            var paramDict: [String: Float] = [:]
            if let tree = parameterTree {
                for address in XPadAUParameterAddress.allCases {
                    if let param = tree.parameter(withAddress: address.rawValue) {
                        paramDict[param.identifier] = param.value
                    }
                }
            }
            state["XPadParameters"] = paramDict
            return state
        }
        set {
            super.fullState = newValue
            guard let dict = newValue?["XPadParameters"] as? [String: Float],
                  let tree = parameterTree else { return }
            
            for (key, val) in dict {
                for address in XPadAUParameterAddress.allCases {
                    if let param = tree.parameter(withAddress: address.rawValue), param.identifier == key {
                        param.value = val
                    }
                }
            }
        }
    }
    
    open override var supportsUserPresets: Bool {
        return true
    }
}
