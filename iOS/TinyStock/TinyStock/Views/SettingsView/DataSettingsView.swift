// ⌘
//  TinyStock/Views/SettingsView/DataSettingsView.swift
//
//  Propósito: Compor as opções de sincronização e backup.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-07.
// ⌘

import SwiftData
import SwiftUI
import TinyStockCore
import UniformTypeIdentifiers

struct DataSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(StoreSession.self) private var storeSession

    @State private var backupCoordinator = DataBackupCoordinator()

    private let storeID: UUID

    init(storeID: UUID) {
        self.storeID = storeID
    }

    var body: some View {
        @Bindable var backupCoordinator = backupCoordinator

        List {
            CloudSyncStatusSection()

            ICloudBackupSection(
                isAvailable: backupCoordinator.isICloudAvailable,
                lastBackup: backupCoordinator.iCloudLastBackup,
                isSaving: backupCoordinator.isSavingToICloud,
                isRestoring: backupCoordinator.isRestoringFromICloud,
                onSave: saveToICloud,
                onRestore: { backupCoordinator.isConfirmingICloudRestore = true }
            )

            BackupFileSection(
                onExport: prepareExport,
                onImport: { backupCoordinator.isImporting = true }
            )
        }
        .navigationTitle(String(localized: "settings.data.title", bundle: .tinyStockCore))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await backupCoordinator.refreshICloudStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await backupCoordinator.refreshICloudStatus() }
        }
        .fileExporter(
            isPresented: $backupCoordinator.isExporting,
            document: backupCoordinator.exportDocument ?? BackupDocument(data: Data()),
            contentType: .json,
            defaultFilename: backupCoordinator.exportFilename,
            onCompletion: backupCoordinator.handleExportResult
        )
        .fileImporter(
            isPresented: $backupCoordinator.isImporting,
            allowedContentTypes: [.json],
            onCompletion: backupCoordinator.handleImportResult
        )
        .alert(
            String(localized: "settings.backup.import.confirm.title", bundle: .tinyStockCore),
            isPresented: $backupCoordinator.isConfirmingImport
        ) {
            Button(
                String(localized: "settings.backup.import.confirm.action", bundle: .tinyStockCore),
                role: .destructive,
                action: restorePendingBackup
            )
            Button(String(localized: "common.cancel", bundle: .tinyStockCore), role: .cancel) {
                backupCoordinator.cancelPendingImport()
            }
        } message: {
            if let payload = backupCoordinator.pendingPayload {
                Text(backupCoordinator.importConfirmationMessage(for: payload))
            }
        }
        .alert(
            String(localized: "settings.backup.icloud.restore.confirm.title", bundle: .tinyStockCore),
            isPresented: $backupCoordinator.isConfirmingICloudRestore
        ) {
            Button(
                String(localized: "settings.backup.icloud.restore", bundle: .tinyStockCore),
                role: .destructive,
                action: restoreFromICloud
            )
            Button(String(localized: "common.cancel", bundle: .tinyStockCore), role: .cancel) { }
        } message: {
            Text(String(localized: "settings.backup.icloud.restore.confirm.message", bundle: .tinyStockCore))
        }
        .alert(item: $backupCoordinator.presentedMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text(String(localized: "common.ok", bundle: .tinyStockCore)))
            )
        }
    }

    private func prepareExport() {
        backupCoordinator.prepareExport(
            from: modelContext,
            selectedStoreID: storeSession.selectedStoreID
        )
    }

    private func restorePendingBackup() {
        backupCoordinator.restorePendingBackup(
            into: modelContext,
            storeID: storeID,
            storeSession: storeSession
        )
    }

    private func saveToICloud() {
        Task {
            await backupCoordinator.saveToICloud(
                from: modelContext,
                selectedStoreID: storeSession.selectedStoreID
            )
        }
    }

    private func restoreFromICloud() {
        Task {
            await backupCoordinator.restoreFromICloud(
                into: modelContext,
                storeID: storeID,
                storeSession: storeSession
            )
        }
    }
}

#Preview {
    let storeID = UUID()
    DataSettingsView(storeID: storeID)
        .environment(StoreSession(selectedStoreID: storeID))
        .modelContainer(
            for: [
                StoreProfile.self, Product.self, ProductVariant.self, StockMovement.self,
                Sale.self, SaleItem.self, SalesOrder.self, SalesOrderItem.self
            ],
            inMemory: true
        )
}
