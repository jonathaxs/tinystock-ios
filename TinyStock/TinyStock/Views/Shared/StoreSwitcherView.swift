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
    @State private var editingStore: StoreProfile?

    private var stores: [StoreProfile] {
        StoreProfileService.orderedForDisplay(storedStores)
    }

    private var selectedStore: StoreProfile? {
        stores.first { $0.id == storeSession.selectedStoreID }
    }

    private var otherStores: [StoreProfile] {
        stores.filter { $0.id != storeSession.selectedStoreID }
    }

    var body: some View {
        Menu {
            // A loja atual fica no topo com o lapis; tocar nela abre a mesma edicao de Ajustes.
            if let selectedStore {
                Section(String(localized: "store.switcher.current", bundle: .tinyStockCore)) {
                    Button { editingStore = selectedStore } label: {
                        Label(selectedStore.name, systemImage: "pencil")
                    }
                    .accessibilityHint(String(localized: "store.form.title.edit", bundle: .tinyStockCore))
                }
            }
            if !otherStores.isEmpty {
                Section(String(localized: "store.switcher.others", bundle: .tinyStockCore)) {
                    ForEach(otherStores) { store in
                        Button(store.name) { try? storeSession.select(store) }
                    }
                }
            }
        } label: {
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
        .sheet(item: $editingStore) { StoreFormView(store: $0) }
    }
}
