// ⌘
//  TinyStock/Views/SettingsView/DataBackupCoordinator.swift
//
//  Propósito: Coordenar exportação, importação e backup no iCloud Drive.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-09-12.
// ⌘

import Foundation
import Observation
import SwiftData
import TinyStockCore

@MainActor
@Observable
final class DataBackupCoordinator {
    var exportDocument: BackupDocument?
    var exportFilename = ""
    var isExporting = false
    var isImporting = false
    var pendingPayload: BackupPayload?
    var isConfirmingImport = false
    var presentedMessage: DataBackupMessage?

    var isICloudAvailable = ICloudBackupManager.isSignedIn
    var iCloudLastBackup: Date?
    var isSavingToICloud = false
    var isRestoringFromICloud = false
    var isConfirmingICloudRestore = false

    func refreshICloudStatus() async {
        isICloudAvailable = ICloudBackupManager.isSignedIn
        iCloudLastBackup = isICloudAvailable
            ? await ICloudBackupManager.lastBackupDate()
            : nil
    }

    func prepareExport(from context: ModelContext, selectedStoreID: UUID) {
        do {
            let data = try BackupManager.export(
                from: context,
                selectedStoreID: selectedStoreID
            )
            exportDocument = BackupDocument(data: data)
            exportFilename = BackupManager.suggestedFilename()
            isExporting = true
        } catch {
            show(error)
        }
    }

    func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            showMessage(
                titleKey: "settings.backup.success.title",
                messageKey: "settings.backup.export.success"
            )
        case .failure(let error):
            show(error)
        }
    }

    func handleImportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            prepareImport(from: url)
        case .failure(let error):
            show(error)
        }
    }

    func cancelPendingImport() {
        pendingPayload = nil
    }

    func restorePendingBackup(
        into context: ModelContext,
        storeID: UUID,
        storeSession: StoreSession
    ) {
        guard let pendingPayload else { return }

        do {
            let result = try BackupManager.apply(
                pendingPayload,
                into: context,
                storeID: storeID
            )
            try selectRestoredStore(result.selectedStoreID, in: context, storeSession: storeSession)
            self.pendingPayload = nil
            showMessage(
                titleKey: "settings.backup.success.title",
                messageKey: result.migratedLegacyBackup
                    ? "settings.backup.restore.legacy.success"
                    : "settings.backup.import.success"
            )
        } catch {
            show(error)
        }
    }

    func saveToICloud(from context: ModelContext, selectedStoreID: UUID) async {
        isSavingToICloud = true
        defer { isSavingToICloud = false }

        do {
            let data = try BackupManager.export(
                from: context,
                selectedStoreID: selectedStoreID
            )
            try await ICloudBackupManager.save(data)
            await refreshICloudStatus()
            showMessage(
                titleKey: "settings.backup.success.title",
                messageKey: "settings.backup.icloud.save.success"
            )
        } catch {
            show(error)
        }
    }

    func restoreFromICloud(
        into context: ModelContext,
        storeID: UUID,
        storeSession: StoreSession
    ) async {
        isRestoringFromICloud = true
        defer { isRestoringFromICloud = false }

        do {
            guard let data = try await ICloudBackupManager.load() else {
                showMessage(
                    titleKey: "settings.backup.error.title",
                    messageKey: "settings.backup.icloud.noBackup"
                )
                return
            }

            let payload = try BackupManager.decode(data)
            let result = try BackupManager.apply(payload, into: context, storeID: storeID)
            try selectRestoredStore(result.selectedStoreID, in: context, storeSession: storeSession)
            await refreshICloudStatus()
            showMessage(
                titleKey: "settings.backup.success.title",
                messageKey: result.migratedLegacyBackup
                    ? "settings.backup.restore.legacy.success"
                    : "settings.backup.icloud.restore.success"
            )
        } catch {
            show(error)
        }
    }

    func importConfirmationMessage(for payload: BackupPayload) -> String {
        if payload.isLegacy {
            return String(
                format: String(localized: "settings.backup.import.confirm.legacy", bundle: .tinyStockCore),
                payload.products.count,
                payload.sales.count
            )
        }

        let summary = payload.summary
        return String(
            format: String(localized: "settings.backup.import.confirm.message.v2", bundle: .tinyStockCore),
            summary.storeCount,
            summary.productCount,
            summary.variantCount,
            summary.orderCount
        )
    }

    private func prepareImport(from url: URL) {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            pendingPayload = try BackupManager.decode(data)
            isConfirmingImport = true
        } catch {
            show(error)
        }
    }

    private func selectRestoredStore(
        _ id: UUID,
        in context: ModelContext,
        storeSession: StoreSession
    ) throws {
        let restoredID = id
        let descriptor = FetchDescriptor<StoreProfile>(predicate: #Predicate {
            $0.id == restoredID && !$0.isArchived
        })
        guard let store = try context.fetch(descriptor).first else {
            throw BackupError.invalidFile
        }
        try storeSession.select(store)
    }

    private func showMessage(
        titleKey: String.LocalizationValue,
        messageKey: String.LocalizationValue
    ) {
        presentedMessage = DataBackupMessage(
            title: String(localized: titleKey, bundle: .tinyStockCore),
            message: String(localized: messageKey, bundle: .tinyStockCore)
        )
    }

    private func show(_ error: Error) {
        let nsError = error as NSError
        guard !(nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError) else {
            return
        }

        presentedMessage = DataBackupMessage(
            title: String(localized: "settings.backup.error.title", bundle: .tinyStockCore),
            message: error.localizedDescription
        )
    }
}

struct DataBackupMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
