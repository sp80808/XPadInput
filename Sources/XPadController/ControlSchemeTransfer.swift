import Foundation
import XPadCore

// MARK: - Control Scheme Transfer Types

/// Versioned schema container for exporting and importing XPadInput control schemes.
public struct ControlSchemeArchive: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var exportedAt: Date
    public var appVersion: String
    public var scheme: ControlScheme
    public var metadata: [String: String]

    public init(
        schemaVersion: Int = currentSchemaVersion,
        exportedAt: Date = Date(),
        appVersion: String = "0.0.04",
        scheme: ControlScheme,
        metadata: [String: String] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.scheme = scheme
        self.metadata = metadata
    }
}

/// Result of importing a control scheme archive, including diagnostic migration details.
public struct ControlSchemeImportResult: Sendable, Equatable {
    public var scheme: ControlScheme
    public var schemaVersion: Int
    public var exportedAt: Date?
    public var warnings: [String]

    public init(
        scheme: ControlScheme,
        schemaVersion: Int,
        exportedAt: Date? = nil,
        warnings: [String] = []
    ) {
        self.scheme = scheme
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.warnings = warnings
    }
}

/// Typed transfer errors for scheme import/export operations.
public enum ControlSchemeTransferError: LocalizedError, Sendable, Equatable {
    case unsupportedSchemaVersion(Int)
    case corruptedData(String)
    case missingScheme

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            return "Unsupported control scheme archive version (\(version)). Please update XPadInput."
        case .corruptedData(let message):
            return "Failed to parse control scheme archive: \(message)"
        case .missingScheme:
            return "The archive does not contain a valid control scheme definition."
        }
    }
}

// MARK: - Control Scheme Transfer Service

/// Handles robust serialization, deserialization, migration, and diagnostic reporting for ControlScheme archives.
public enum ControlSchemeTransfer {
    private nonisolated(unsafe) static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Exports a ControlScheme wrapped in a versioned archive as UTF-8 JSON Data.
    public static func exportArchive(
        _ scheme: ControlScheme,
        appVersion: String = "0.0.04",
        metadata: [String: String] = [:]
    ) throws -> Data {
        let archive = ControlSchemeArchive(
            schemaVersion: ControlSchemeArchive.currentSchemaVersion,
            exportedAt: Date(),
            appVersion: appVersion,
            scheme: scheme,
            metadata: metadata
        )
        return try encoder.encode(archive)
    }

    /// Exports a ControlScheme wrapped in a versioned archive as a UTF-8 JSON string.
    public static func exportJSON(
        _ scheme: ControlScheme,
        appVersion: String = "0.0.04",
        metadata: [String: String] = [:]
    ) throws -> String {
        let data = try exportArchive(scheme, appVersion: appVersion, metadata: metadata)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ControlSchemeTransferError.corruptedData("Failed to encode UTF-8 string.")
        }
        return jsonString
    }

    /// Imports a control scheme from raw archive Data with tolerant fallback to bare ControlScheme format.
    public static func importArchive(from data: Data) throws -> ControlSchemeImportResult {
        var warnings: [String] = []

        // 1. Attempt standard versioned archive decoding
        if let archive = try? decoder.decode(ControlSchemeArchive.self, from: data) {
            guard archive.schemaVersion <= ControlSchemeArchive.currentSchemaVersion else {
                throw ControlSchemeTransferError.unsupportedSchemaVersion(archive.schemaVersion)
            }
            return ControlSchemeImportResult(
                scheme: archive.scheme,
                schemaVersion: archive.schemaVersion,
                exportedAt: archive.exportedAt,
                warnings: warnings
            )
        }

        // 2. Tolerant fallback: bare ControlScheme JSON object without archive envelope
        if let bareScheme = try? decoder.decode(ControlScheme.self, from: data) {
            warnings.append("Legacy or unversioned control scheme format detected; migrated to Schema v1.")
            return ControlSchemeImportResult(
                scheme: bareScheme,
                schemaVersion: 1,
                exportedAt: nil,
                warnings: warnings
            )
        }

        // 3. Tolerant fallback: try tolerant JSON dictionary inspection to diagnose specific error
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ControlSchemeTransferError.corruptedData("Data is not a valid JSON dictionary.")
        }

        if let schemaVer = jsonObject["schemaVersion"] as? Int, schemaVer > ControlSchemeArchive.currentSchemaVersion {
            throw ControlSchemeTransferError.unsupportedSchemaVersion(schemaVer)
        }

        throw ControlSchemeTransferError.corruptedData("Missing valid 'scheme' property in archive.")
    }

    /// Imports a control scheme from a JSON string.
    public static func importArchive(from jsonString: String) throws -> ControlSchemeImportResult {
        guard let data = jsonString.data(using: .utf8) else {
            throw ControlSchemeTransferError.corruptedData("Input string could not be encoded to UTF-8.")
        }
        return try importArchive(from: data)
    }
}
