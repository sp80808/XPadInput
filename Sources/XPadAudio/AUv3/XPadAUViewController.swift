import Foundation
import AppKit
import CoreAudioKit
import AudioToolbox
import SwiftUI

/// Audio Unit View Controller bridging AUv3 host windows (Logic Pro, Reaper, Bitwig, Cubase) to native SwiftUI views.
open class XPadAUViewController: AUViewController, @preconcurrency AUAudioUnitFactory, @unchecked Sendable {
    public var audioUnit: AUAudioUnit?
    private var hostingController: NSHostingController<AnyView>?
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        self.preferredContentSize = NSSize(width: 800, height: 520)
    }
    
    /// Embeds a SwiftUI view inside this AUViewController.
    public func setSwiftUIView<Content: View>(_ view: Content) {
        let host = NSHostingController(rootView: AnyView(view))
        self.hostingController = host
        self.addChild(host)
        host.view.frame = self.view.bounds
        host.view.autoresizingMask = [.width, .height]
        self.view.addSubview(host.view)
    }
    
    // MARK: - AUAudioUnitFactory
    
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        if componentDescription.componentType == kAudioUnitType_MusicDevice {
            let unit = try XPadAUInstrument(componentDescription: componentDescription)
            self.audioUnit = unit
            return unit
        } else {
            let unit = try XPadAUMIDIFX(componentDescription: componentDescription)
            self.audioUnit = unit
            return unit
        }
    }
}
