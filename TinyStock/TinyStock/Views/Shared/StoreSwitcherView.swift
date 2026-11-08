// ⌘
//  TinyStock/Views/Shared/StoreSwitcherView.swift
//
//  Propósito: Título da Início com a loja ativa; o menu troca de loja ou edita a atual sem sair da tela.
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
            // Titulo da Inicio: foto e nome da loja atual, com a seta do menu.
            HStack(spacing: 10) {
                StoreImageView(imageData: selectedStore?.imageData, side: 34)
                Text(selectedStore?.name ?? StoreProfileService.localizedDefaultName)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Image(systemName: "chevron.down")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(localized: "store.switcher.accessibility", bundle: .tinyStockCore)
        )
        .accessibilityValue(selectedStore?.name ?? StoreProfileService.localizedDefaultName)
        .sheet(item: $editingStore) { StoreFormView(store: $0) }
    }
}
