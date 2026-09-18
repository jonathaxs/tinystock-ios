// ⌘
//  TinyStock/Views/SettingsView/TrashedStoresView.swift
//
//  Propósito: Restaurar ou excluir definitivamente lojas mantidas na lixeira.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-09-17.
// ⌘

import SwiftData
import SwiftUI
import TinyStockCore

struct TrashedStoresView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(StoreSession.self) private var storeSession
    @Query private var stores: [StoreProfile]

    @State private var deletionRequest: StoreDeletionRequest?
    @State private var errorMessage: String?

    private var trashedStores: [StoreProfile] {
        StoreProfileService.orderedTrashedForDisplay(stores)
    }

    var body: some View {
        List {
            if trashedStores.isEmpty {
                ContentUnavailableView(
                    String(localized: "stores.trash.empty.title", bundle: .tinyStockCore),
                    systemImage: "trash",
                    description: Text(
                        String(localized: "stores.trash.empty.message", bundle: .tinyStockCore)
                    )
                )
            } else {
                Section {
                    ForEach(trashedStores) { store in
                        trashedStoreRow(store)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    restore(store)
                                } label: {
                                    Label(
                                        String(
                                            localized: "stores.restore",
                                            bundle: .tinyStockCore
                                        ),
                                        systemImage: "arrow.uturn.backward"
                                    )
                                }
                                .tint(.accentColor)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    requestPermanentDeletion(store)
                                } label: {
                                    Label(
                                        String(localized: "common.delete", bundle: .tinyStockCore),
                                        systemImage: "trash.slash"
                                    )
                                }
                            }
                    }
                } footer: {
                    Text(String(localized: "stores.trash.footer", bundle: .tinyStockCore))
                }
            }
        }
        .navigationTitle(String(localized: "stores.trash.title", bundle: .tinyStockCore))
        .alert(
            String(localized: "stores.delete.confirm.title", bundle: .tinyStockCore),
            isPresented: Binding(
                get: { deletionRequest != nil },
                set: { if !$0 { deletionRequest = nil } }
            ),
            presenting: deletionRequest
        ) { request in
            Button(
                String(localized: "common.delete", bundle: .tinyStockCore),
                role: .destructive
            ) {
                deletePermanently(request.store)
            }
            Button(String(localized: "common.cancel", bundle: .tinyStockCore), role: .cancel) {}
        } message: { request in
            Text(deletionMessage(for: request))
        }
        .storeOperationErrorAlert(message: $errorMessage)
    }

    private func trashedStoreRow(_ store: StoreProfile) -> some View {
        HStack(spacing: 4) {
            StoreManagementRow(
                store: store,
                detail: expirationText(for: store)
            )
            .opacity(0.75)

            Menu {
                Button {
                    restore(store)
                } label: {
                    Label(
                        String(localized: "stores.restore", bundle: .tinyStockCore),
                        systemImage: "arrow.uturn.backward"
                    )
                }

                Button(role: .destructive) {
                    requestPermanentDeletion(store)
                } label: {
                    Label(
                        String(localized: "stores.deletePermanently", bundle: .tinyStockCore),
                        systemImage: "trash.slash"
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel(actionsAccessibilityLabel(for: store))
        }
    }

    private func expirationText(for store: StoreProfile) -> String? {
        guard let expiration = StoreProfileService.trashExpirationDate(for: store) else {
            return nil
        }
        let formattedDate = expiration.formatted(date: .abbreviated, time: .omitted)
        return String(
            format: String(localized: "stores.trash.expires", bundle: .tinyStockCore),
            formattedDate
        )
    }

    private func restore(_ store: StoreProfile) {
        do {
            try StoreProfileService.restoreFromTrash(store)
            try modelContext.save()
        } catch let error as StoreProfileError {
            modelContext.rollback()
            errorMessage = error.localizedMessage
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func requestPermanentDeletion(_ store: StoreProfile) {
        do {
            let summary = try StoreProfileService.deletionSummary(for: store, in: modelContext)
            deletionRequest = StoreDeletionRequest(store: store, summary: summary)
        } catch let error as StoreProfileError {
            errorMessage = error.localizedMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deletePermanently(_ store: StoreProfile) {
        let selectedStore = stores.first { $0.id == storeSession.selectedStoreID && $0.isActive }

        do {
            let replacement = try StoreProfileService.deletePermanently(store, in: modelContext)
            try modelContext.save()

            if let selectedStore {
                try storeSession.select(selectedStore)
            } else if let replacement {
                try storeSession.select(replacement)
            }
            deletionRequest = nil
        } catch let error as StoreProfileError {
            modelContext.rollback()
            errorMessage = error.localizedMessage
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func deletionMessage(for request: StoreDeletionRequest) -> String {
        String(
            format: String(
                localized: "stores.delete.confirm.message",
                bundle: .tinyStockCore
            ),
            locale: .autoupdatingCurrent,
            request.storeName,
            request.summary.productCount.formatted(),
            request.summary.variantCount.formatted(),
            request.summary.stockMovementCount.formatted(),
            request.summary.orderCount.formatted()
        )
    }

    private func actionsAccessibilityLabel(for store: StoreProfile) -> String {
        String(
            format: String(localized: "stores.actions.accessibility", bundle: .tinyStockCore),
            store.name
        )
    }
}
