// ⌘
//  TinyStock/Views/SettingsView/DataBackupSections.swift
//
//  Propósito: Apresentar as ações de backup local e no iCloud Drive.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-09-12.
// ⌘

import SwiftUI
import TinyStockCore

struct ICloudBackupSection: View {
    let isAvailable: Bool
    let lastBackup: Date?
    let isSaving: Bool
    let isRestoring: Bool
    let onSave: () -> Void
    let onRestore: () -> Void

    var body: some View {
        Section {
            if isAvailable {
                Button(action: onSave) {
                    actionLabel(
                        titleKey: "settings.backup.icloud.save",
                        systemImage: "icloud.and.arrow.up",
                        isRunning: isSaving
                    )
                }
                .disabled(isSaving || isRestoring)

                Button(action: onRestore) {
                    actionLabel(
                        titleKey: "settings.backup.icloud.restore",
                        systemImage: "icloud.and.arrow.down",
                        isRunning: isRestoring
                    )
                }
                .disabled(isSaving || isRestoring)
            } else {
                Label(
                    String(localized: "settings.backup.icloud.unavailable", bundle: .tinyStockCore),
                    systemImage: "icloud.slash"
                )
                .foregroundStyle(.secondary)
            }
        } header: {
            Text(
                String(
                    localized: "settings.backup.icloud.section",
                    bundle: .tinyStockCore
                )
            )
        } footer: {
            footer
        }
    }

    private func actionLabel(
        titleKey: String.LocalizationValue,
        systemImage: String,
        isRunning: Bool
    ) -> some View {
        HStack {
            Label(String(localized: titleKey, bundle: .tinyStockCore), systemImage: systemImage)

            if isRunning {
                Spacer()
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let lastBackup {
            Text(
                String(
                    format: String(localized: "settings.backup.icloud.lastBackup", bundle: .tinyStockCore),
                    lastBackup.formatted(date: .abbreviated, time: .shortened)
                )
            )
        } else if isAvailable {
            Text(String(localized: "settings.backup.icloud.noBackup", bundle: .tinyStockCore))
        } else {
            Text(String(localized: "settings.backup.icloud.unavailable.footer", bundle: .tinyStockCore))
        }
    }
}

struct BackupFileSection: View {
    let onExport: () -> Void
    let onImport: () -> Void

    var body: some View {
        Section {
            Button(action: onExport) {
                Label(
                    String(localized: "settings.backup.export", bundle: .tinyStockCore),
                    systemImage: "square.and.arrow.up"
                )
            }

            Button(action: onImport) {
                Label(
                    String(localized: "settings.backup.import", bundle: .tinyStockCore),
                    systemImage: "square.and.arrow.down"
                )
            }
        } header: {
            Text(String(localized: "settings.backup.file.section", bundle: .tinyStockCore))
        } footer: {
            Text(String(localized: "settings.backup.section.footer", bundle: .tinyStockCore))
        }
    }
}
