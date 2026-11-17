import Foundation

/// Manages the installation of AUv3 and VST3 plugins into the standard macOS system directories.
public final class PluginInstaller: @unchecked Sendable {
    public enum Status: Equatable {
        case unknown
        case notInstalled
        case installed
        case failed(String)
    }

    public enum InstallationMethod: String {
        case symlink
        case copy
    }

    public static let shared = PluginInstaller()

    private let fileManager = FileManager.default

    private init() {}

    /// Plugin formats whose bundle actually ships next to this build.
    public var availablePluginTypes: [PluginType] {
        [PluginType.au, .vst3].filter { isSourceBundleAvailable($0) }
    }

    /// True only when at least one host-loadable bundle exists to install.
    /// Release UI must gate any "Install" affordance on this (#84).
    public var hasInstallableBundles: Bool {
        !availablePluginTypes.isEmpty
    }

    public func isSourceBundleAvailable(_ type: PluginType) -> Bool {
        fileManager.fileExists(atPath: sourceURL(for: type).path)
    }

    /// `.installed` only when bundles ship with this build and every one of them is installed.
    public var status: Status {
        let available = availablePluginTypes
        guard !available.isEmpty else { return .notInstalled }
        return available.allSatisfy { isPluginInstalled(type: $0) } ? .installed : .notInstalled
    }

    public enum PluginType {
        case au
        case vst3

        var bundleExtension: String {
            switch self {
            case .au: return "component"
            case .vst3: return "vst3"
            }
        }

        var bundleName: String {
            "XPI.\(bundleExtension)"
        }

        var destinationDirectory: URL? {
            let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            switch self {
            case .au:
                return library?.appendingPathComponent("Audio/Plug-Ins/Components")
            case .vst3:
                return library?.appendingPathComponent("Audio/Plug-Ins/VST3")
            }
        }
    }

    private func sourceURL(for type: PluginType) -> URL {
        Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent(type.bundleName)
    }

    private func isPluginInstalled(type: PluginType) -> Bool {
        guard let destDir = type.destinationDirectory else { return false }
        let destURL = destDir.appendingPathComponent(type.bundleName)
        return fileManager.fileExists(atPath: destURL.path)
    }

    public func install(method: InstallationMethod = .symlink) -> Status {
        // Preflight before touching anything: never remove a known-good bundle
        // or report success for a format that has no source bundle.
        let installable = availablePluginTypes
        guard !installable.isEmpty else {
            return .failed("This build does not include AU or VST3 plugin bundles. Use XPI as a standalone app and select its virtual MIDI sources in your DAW.")
        }
        do {
            for type in installable {
                try installPlugin(type: type, method: method)
            }
            return .installed
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func installPlugin(type: PluginType, method: InstallationMethod) throws {
        guard let destDir = type.destinationDirectory else {
            throw NSError(domain: "PluginInstaller", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not locate destination directory."])
        }

        // Built plugin bundle is expected next to the main executable
        let bundleSource = sourceURL(for: type)

        if !fileManager.fileExists(atPath: bundleSource.path) {
             throw NSError(domain: "PluginInstaller", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not find plugin bundle at \(bundleSource.path). Ensure it's built and located next to the main app."])
        }

        if !fileManager.fileExists(atPath: destDir.path) {
            try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
        }

        let destURL = destDir.appendingPathComponent(type.bundleName)

        if fileManager.fileExists(atPath: destURL.path) {
            try fileManager.removeItem(at: destURL)
        }

        switch method {
        case .symlink:
            try fileManager.createSymbolicLink(at: destURL, withDestinationURL: bundleSource)
        case .copy:
            try fileManager.copyItem(at: bundleSource, to: destURL)
        }
    }
}
