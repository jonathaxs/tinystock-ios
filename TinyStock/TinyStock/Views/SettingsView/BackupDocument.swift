// ⌘
//  TinyStock/Views/SettingsView/BackupDocument.swift
//
//  Propósito: Adaptar os dados JSON do backup ao seletor de arquivos do SwiftUI.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-16.
// ⌘

import SwiftUI
import UniformTypeIdentifiers

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
