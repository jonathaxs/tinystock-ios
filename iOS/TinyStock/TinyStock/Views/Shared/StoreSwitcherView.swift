// ⌘
//  TinyStock/Views/Shared/StoreSwitcherView.swift
//
//  Propósito: Trocar ou editar rapidamente a loja ativa sem sair da tela atual.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-25.
// ⌘

import SwiftData
import SwiftUI
import TinyStockCore

struct StoreSwitcherView: View {

    @Environment(StoreSession.self) private var storeSession
    @Query(filter: #Predicate<StoreProfile> { !$0.isArchived && $0.trashedAt == nil })
    private var storedStores: [StoreProfile]
    @State private var isPresentingStores = false
    @State private var pendingEdit: StoreProfile?
    @State private var editingStore: StoreProfile?

    private var stores: [StoreProfile] {
        StoreProfileService.orderedForDisplay(storedStores)
    }

    private var selectedStore: StoreProfile? {
        stores.first { $0.id == storeSession.selectedStoreID }
    }

    var body: some View {
        Button { isPresentingStores = true } label: {
            Label(
                selectedStore?.name ?? StoreProfileService.localizedDefaultName,
                systemImage: "storefront"
            )
            .lineLimit(1)
        }
        .accessibilityLabel(
            String(localized: "store.switcher.accessibility", bundle: .tinyStockCore)
        )
        .accessibilityValue(selectedStore?.name ?? StoreProfileService.localizedDefaultName)
        // A edicao so abre depois que a folha de lojas termina de fechar.
        .sheet(isPresented: $isPresentingStores, onDismiss: {
            editingStore = pendingEdit
            pendingEdit = nil
        }) { storesSheet }
        .sheet(item: $editingStore) { StoreFormView(store: $0) }
    }

    private var storesSheet: some View {
        BottomActionSheet {
            BottomActionSheetTitle(title: String(localized: "stores.title", bundle: .tinyStockCore))
            ForEach(stores) { store in
                HStack(spacing: 8) {
                    SheetActionButton(title: store.name, systemImage: "storefront",
                                      isSelected: store.id == storeSession.selectedStoreID) {
                        try? storeSession.select(store)
                        isPresentingStores = false
                    }
                    // Abre a mesma edicao disponivel em Ajustes, sem trocar de aba.
                    Button {
                        pendingEdit = store
                        isPresentingStores = false
                    } label: {
                        Image(systemName: "pencil")
                            .font(.title3.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(SheetActionButtonStyle())
                    .accessibilityLabel(String(localized: "store.form.title.edit", bundle: .tinyStockCore))
                    .accessibilityValue(store.name)
                }
            }
        }
    }
}
