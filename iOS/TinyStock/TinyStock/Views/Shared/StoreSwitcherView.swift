// ⌘
//  TinyStock/Views/Shared/StoreSwitcherView.swift
//
//  Propósito: Trocar rapidamente a loja ativa sem sair da tela atual.
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

    private var stores: [StoreProfile] {
        StoreProfileService.orderedForDisplay(storedStores)
    }

    private var selectedStore: StoreProfile? {
        stores.first { $0.id == storeSession.selectedStoreID }
    }

    var body: some View {
        Menu {
            ForEach(stores) { store in
                Button {
                    try? storeSession.select(store)
                } label: {
                    if store.id == storeSession.selectedStoreID {
                        Label(store.name, systemImage: "checkmark")
                    } else {
                        Text(store.name)
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
    }
}
