// ⌘
//  TinyStock/Views/SettingsView/ArchivedStoresView.swift
//
//  Propósito: Restaurar lojas arquivadas ou movê-las para a lixeira.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-09-17.
// ⌘

import SwiftData
import SwiftUI
import TinyStockCore

struct ArchivedStoresView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var stores: [StoreProfile]

    @State private var trashRequest: StoreTrashRequest?
    @State private var errorMessage: String?

    private var archivedStores: [StoreProfile] {
        StoreProfileService.orderedArchivedForDisplay(stores)
    }

    var body: some View {
        List {
            if archivedStores.isEmpty {
                ContentUnavailableView(
                    String(localized: "stores.archived.empty.title", bundle: .tinyStockCore),
                    systemImage: "archivebox",
                    description: Text(
                        String(
                            localized: "stores.archived.empty.message",
                            bundle: .tinyStockCore
                        )
                    )
                )
            } else {
                ForEach(archivedStores) { store in
                    archivedStoreRow(store)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                restore(store)
                            } label: {
                                Label(
                                    String(localized: "stores.restore", bundle: .tinyStockCore),
                                    systemImage: "arrow.uturn.backward"
                                )
                            }
                            .tint(.accentColor)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                trashRequest = StoreTrashRequest(store: store)
                            } label: {
                                Label(
                                    String(
                                        localized: "stores.moveToTrash",
                                        bundle: .tinyStockCore
                                    ),
                                    systemImage: "trash"
                                )
                            }
                        }
                }
            }
        }
        .navigationTitle(
            String(localized: "stores.archived.title", bundle: .tinyStockCore)
        )
        .alert(
            String(localized: "stores.trash.confirm.title", bundle: .tinyStockCore),
            isPresented: Binding(
                get: { trashRequest != nil },
                set: { if !$0 { trashRequest = nil } }
            ),
            presenting: trashRequest
        ) { request in
            Button(
                String(localized: "stores.moveToTrash", bundle: .tinyStockCore),
                role: .destructive
            ) {
                moveToTrash(request.store)
            }
            Button(String(localized: "common.cancel", bundle: .tinyStockCore), role: .cancel) {}
        } message: { request in
            Text(
                String(
                    format: String(
                        localized: "stores.trash.confirm.message",
                        bundle: .tinyStockCore
                    ),
                    request.storeName
                )
            )
        }
        .storeOperationErrorAlert(message: $errorMessage)
    }

    private func archivedStoreRow(_ store: StoreProfile) -> some View {
        HStack(spacing: 4) {
            StoreManagementRow(store: store)
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
                    trashRequest = StoreTrashRequest(store: store)
                } label: {
                    Label(
                        String(localized: "stores.moveToTrash", bundle: .tinyStockCore),
                        systemImage: "trash"
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

    private func restore(_ store: StoreProfile) {
        StoreProfileService.restore(store)
        saveChanges()
    }

    private func moveToTrash(_ store: StoreProfile) {
        do {
            try StoreProfileService.moveToTrash(store, in: modelContext)
            try modelContext.save()
            trashRequest = nil
        } catch let error as StoreProfileError {
            modelContext.rollback()
            errorMessage = error.localizedMessage
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func actionsAccessibilityLabel(for store: StoreProfile) -> String {
        String(
            format: String(localized: "stores.actions.accessibility", bundle: .tinyStockCore),
            store.name
        )
    }
}
