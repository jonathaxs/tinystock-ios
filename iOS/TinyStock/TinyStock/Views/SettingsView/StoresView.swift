// ⌘
//  TinyStock/Views/SettingsView/StoresView.swift
//
//  Propósito: Selecionar, ordenar e gerenciar as lojas ativas do TinyStock.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-25.
// ⌘

import SwiftData
import SwiftUI
import TinyStockCore

struct StoresView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(StoreSession.self) private var storeSession
    @Query private var stores: [StoreProfile]

    @State private var formRoute: StoreFormRoute?
    @State private var trashRequest: StoreTrashRequest?
    @State private var errorMessage: String?

    private var activeStores: [StoreProfile] {
        StoreProfileService.orderedForDisplay(stores.filter(\.isActive))
    }

    private var archivedStoreCount: Int {
        stores.lazy.filter { $0.lifecycleState == .archived }.count
    }

    private var trashedStoreCount: Int {
        stores.lazy.filter(\.isTrashed).count
    }

    var body: some View {
        List {
            activeStoresSection
            organizationSection
        }
        .navigationTitle(String(localized: "stores.title", bundle: .tinyStockCore))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                EditButton()

                Button {
                    formRoute = StoreFormRoute(store: nil)
                } label: {
                    Label(
                        String(localized: "stores.add", bundle: .tinyStockCore),
                        systemImage: "plus"
                    )
                }
            }
        }
        .sheet(item: $formRoute) { route in
            StoreFormView(store: route.store)
        }
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

    private var activeStoresSection: some View {
        Section {
            ForEach(activeStores) { store in
                activeStoreRow(store)
                    .deleteDisabled(activeStores.count == 1)
            }
            .onMove(perform: moveActiveStores)
            .onDelete { requestTrash(from: activeStores, at: $0) }
        } header: {
            Text(String(localized: "stores.section.active", bundle: .tinyStockCore))
        } footer: {
            Text(String(localized: "stores.section.footer", bundle: .tinyStockCore))
        }
    }

    private var organizationSection: some View {
        Section(String(localized: "stores.section.organization", bundle: .tinyStockCore)) {
            NavigationLink {
                ArchivedStoresView()
            } label: {
                managementDestinationLabel(
                    titleKey: "stores.archived.title",
                    systemImage: "archivebox",
                    count: archivedStoreCount
                )
            }

            NavigationLink {
                TrashedStoresView()
            } label: {
                managementDestinationLabel(
                    titleKey: "stores.trash.title",
                    systemImage: "trash",
                    count: trashedStoreCount
                )
            }
        }
    }

    private func activeStoreRow(_ store: StoreProfile) -> some View {
        HStack(spacing: 4) {
            Button {
                select(store)
            } label: {
                StoreManagementRow(
                    store: store,
                    isSelected: store.id == storeSession.selectedStoreID
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint(String(localized: "stores.select.hint", bundle: .tinyStockCore))
            .accessibilityAddTraits(
                store.id == storeSession.selectedStoreID ? [.isSelected] : []
            )

            Menu {
                Button {
                    formRoute = StoreFormRoute(store: store)
                } label: {
                    Label(
                        String(localized: "common.edit", bundle: .tinyStockCore),
                        systemImage: "pencil"
                    )
                }

                Button {
                    archive(store)
                } label: {
                    Label(
                        String(localized: "stores.archive", bundle: .tinyStockCore),
                        systemImage: "archivebox"
                    )
                }
                .disabled(activeStores.count == 1)

                Button(role: .destructive) {
                    trashRequest = StoreTrashRequest(store: store)
                } label: {
                    Label(
                        String(localized: "stores.moveToTrash", bundle: .tinyStockCore),
                        systemImage: "trash"
                    )
                }
                .disabled(activeStores.count == 1)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel(actionsAccessibilityLabel(for: store))
        }
    }

    private func managementDestinationLabel(
        titleKey: String.LocalizationValue,
        systemImage: String,
        count: Int
    ) -> some View {
        Label {
            HStack {
                Text(String(localized: titleKey, bundle: .tinyStockCore))
                Spacer()
                Text(count, format: .number)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }

    private func actionsAccessibilityLabel(for store: StoreProfile) -> String {
        String(
            format: String(localized: "stores.actions.accessibility", bundle: .tinyStockCore),
            store.name
        )
    }

    private func select(_ store: StoreProfile) {
        do {
            try storeSession.select(store)
        } catch let error as StoreProfileError {
            errorMessage = error.localizedMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func archive(_ store: StoreProfile) {
        deactivate(store) {
            try StoreProfileService.archive(store, in: modelContext)
        }
    }

    private func moveToTrash(_ store: StoreProfile) {
        deactivate(store) {
            try StoreProfileService.moveToTrash(store, in: modelContext)
        }
        trashRequest = nil
    }

    private func deactivate(
        _ store: StoreProfile,
        operation: () throws -> Void
    ) {
        let wasSelected = store.id == storeSession.selectedStoreID
        let replacement = activeStores.first { $0.id != store.id }

        do {
            try operation()
            try modelContext.save()

            if wasSelected, let replacement {
                try storeSession.select(replacement)
            }
        } catch let error as StoreProfileError {
            modelContext.rollback()
            errorMessage = error.localizedMessage
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func requestTrash(from stores: [StoreProfile], at offsets: IndexSet) {
        guard let index = offsets.first, stores.indices.contains(index) else { return }
        trashRequest = StoreTrashRequest(store: stores[index])
    }

    private func moveActiveStores(from source: IndexSet, to destination: Int) {
        var reorderedStores = activeStores
        reorderedStores.move(fromOffsets: source, toOffset: destination)

        do {
            try StoreProfileService.setDisplayOrder(reorderedStores)
            try modelContext.save()
        } catch let error as StoreProfileError {
            modelContext.rollback()
            errorMessage = error.localizedMessage
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
