// ⌘
//  TinyStockCore/Services/ICloudBackupManager.swift
//
//  Propósito: Salvar e carregar o backup JSON pelo container Documents do iCloud Drive.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-17.
// ⌘

import Foundation

public enum ICloudBackupManager {
    public static let containerIdentifier = TinyStockPersistence.cloudContainerIdentifier
    public static let filename = "TinyStock-Backup.json"

    // MARK: - Disponibilidade

    public static var isSignedIn: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private static func resolveContainerFolder() async -> URL? {
        let containerID = containerIdentifier

        return await Task.detached {
            FileManager.default
                .url(forUbiquityContainerIdentifier: containerID)?
                .appending(path: "Documents", directoryHint: .isDirectory)
        }.value
    }

    // MARK: - Interface pública

    public static func save(_ data: Data) async throws {
        guard let folderURL = await resolveContainerFolder() else {
            throw ICloudError.unavailable
        }

        try await save(data, in: folderURL)
    }

    public static func load() async throws -> Data? {
        guard let folderURL = await resolveContainerFolder() else {
            throw ICloudError.unavailable
        }

        return try await load(from: folderURL)
    }

    public static func lastBackupDate() async -> Date? {
        guard let folderURL = await resolveContainerFolder() else { return nil }
        return await lastBackupDate(in: folderURL)
    }

    // MARK: - Operações de arquivo

    /// Métodos internos recebem uma pasta explícita para poderem ser exercitados sem iCloud nos testes.
    static func save(_ data: Data, in folderURL: URL) async throws {
        let name = filename

        try await Task.detached {
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: folderURL.path) {
                try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            }

            try data.write(to: folderURL.appending(path: name), options: .atomic)
        }.value
    }

    static func load(from folderURL: URL) async throws -> Data? {
        let name = filename

        return try await Task.detached {
            let fileManager = FileManager.default
            let fileURL = folderURL.appending(path: name)

            if !fileManager.fileExists(atPath: fileURL.path) {
                let placeholderURL = placeholderURL(for: fileURL)
                guard fileManager.fileExists(atPath: placeholderURL.path) else {
                    return nil as Data?
                }

                try fileManager.startDownloadingUbiquitousItem(at: fileURL)
                let deadline = Date().addingTimeInterval(10)

                while !fileManager.fileExists(atPath: fileURL.path) {
                    guard Date() < deadline else {
                        throw ICloudError.downloadTimeout
                    }
                    try await Task.sleep(for: .milliseconds(250))
                }
            }

            return try Data(contentsOf: fileURL)
        }.value
    }

    static func lastBackupDate(in folderURL: URL) async -> Date? {
        let name = filename

        return await Task.detached {
            let fileManager = FileManager.default
            let fileURL = folderURL.appending(path: name)

            if let date = modificationDate(of: fileURL, fileManager: fileManager) {
                return date
            }

            return modificationDate(
                of: placeholderURL(for: fileURL),
                fileManager: fileManager
            )
        }.value
    }

    private static func placeholderURL(for fileURL: URL) -> URL {
        fileURL.deletingLastPathComponent()
            .appending(path: ".\(fileURL.lastPathComponent).icloud")
    }

    private static func modificationDate(of url: URL, fileManager: FileManager) -> Date? {
        guard
            fileManager.fileExists(atPath: url.path),
            let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        else { return nil }

        return attributes[.modificationDate] as? Date
    }

    // MARK: - Erros

    public enum ICloudError: LocalizedError, Equatable, Sendable {
        case unavailable
        case downloadTimeout

        public var errorDescription: String? {
            switch self {
            case .unavailable:
                String(localized: "icloud.error.unavailable", bundle: .tinyStockCore)
            case .downloadTimeout:
                String(localized: "icloud.error.downloadTimeout", bundle: .tinyStockCore)
            }
        }
    }
}
