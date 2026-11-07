// ⌘
//  TinyStockCoreTests/ICloudBackupManagerTests.swift
//
//  Propósito: Testar o arquivo usado pelo backup do iCloud Drive sem depender de uma conta Apple.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-17.
// ⌘

import Testing
import Foundation
@testable import TinyStockCore

@Suite(.serialized)
struct ICloudBackupManagerTests {
    func temporaryFolder() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    }

    @Test func salvarCriaAPastaEOArquivo() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let data = Data("backup tiny stock".utf8)

        try await ICloudBackupManager.save(data, in: folder)

        let fileURL = folder.appending(path: ICloudBackupManager.filename)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        #expect(try Data(contentsOf: fileURL) == data)
    }

    @Test func segundoBackupSubstituiOPrimeiro() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try await ICloudBackupManager.save(Data("primeiro".utf8), in: folder)
        try await ICloudBackupManager.save(Data("segundo".utf8), in: folder)

        #expect(try await ICloudBackupManager.load(from: folder) == Data("segundo".utf8))
    }

    @Test func carregarPastaSemBackupDevolveNil() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(try await ICloudBackupManager.load(from: folder) == nil)
    }

    @Test func dataDoUltimoBackupExisteDepoisDeSalvar() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(await ICloudBackupManager.lastBackupDate(in: folder) == nil)
        try await ICloudBackupManager.save(Data("backup".utf8), in: folder)
        #expect(await ICloudBackupManager.lastBackupDate(in: folder) != nil)
    }

    @Test func configuracaoUsaContainerEArquivoDoTinyStock() {
        #expect(ICloudBackupManager.containerIdentifier == "iCloud.com.jonathaxs.TinyStock")
        #expect(ICloudBackupManager.filename == "TinyStock-Backup.json")

        let url = URL(fileURLWithPath: "/tmp/TinyStock-Test.store")
        let configuration = TinyStockPersistence.cloudConfiguration(
            schema: TinyStockPersistence.schema,
            url: url
        )
        #expect(configuration.url == url)
        #expect(configuration.cloudKitContainerIdentifier == ICloudBackupManager.containerIdentifier)
    }

    @Test func todoErroTemMensagemLocalizada() {
        #expect(ICloudBackupManager.ICloudError.unavailable.localizedDescription.isEmpty == false)
        #expect(ICloudBackupManager.ICloudError.downloadTimeout.localizedDescription.isEmpty == false)
    }
}
