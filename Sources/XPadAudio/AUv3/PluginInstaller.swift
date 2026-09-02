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

    public var status: Status {
        let auStatus = isPluginInstalled(type: .au)
        let vst3Status = isPluginInstalled(type: .vst3)

        if auStatus && vst3Status {
            return .installed
        } else {
            return .notInstalled
        }
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

    private func isPluginInstalled(type: PluginType) -> Bool {
        guard let destDir = type.destinationDirectory else { return false }
        let destURL = destDir.appendingPathComponent(type.bundleName)
        return fileManager.fileExists(atPath: destURL.path)
    }

    public func install(method: InstallationMethod = .symlink) -> Status {
        do {
            try installPlugin(type: .au, method: method)
            try installPlugin(type: .vst3, method: method)
            return .installed
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func installPlugin(type: PluginType, method: InstallationMethod) throws {
        guard let destDir = type.destinationDirectory else {
            throw NSError(domain: "PluginInstaller", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not locate destination directory."])
        }

        // Try to find the built plugin bundle next to the main executable
        let bundleURL = Bundle.main.bundleURL
        let sourceURL = bundleURL.deletingLastPathComponent().appendingPathComponent(type.bundleName)

        if !fileManager.fileExists(atPath: sourceURL.path) {
             throw NSError(domain: "PluginInstaller", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not find plugin bundle at \(sourceURL.path). Ensure it's built and located next to the main app."])
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
            try fileManager.createSymbolicLink(at: destURL, withDestinationURL: sourceURL)
        case .copy:
            try fileManager.copyItem(at: sourceURL, to: destURL)
        }
    }
}
