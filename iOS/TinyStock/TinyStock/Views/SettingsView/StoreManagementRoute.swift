// ⌘
//  TinyStock/Views/SettingsView/StoreManagementRoute.swift
//
//  Propósito: Representar as rotas e confirmações do gerenciamento de lojas.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-09-12.
// ⌘

import Foundation
import TinyStockCore

struct StoreFormRoute: Identifiable {
    let id = UUID()
    let store: StoreProfile?
}

struct StoreTrashRequest: Identifiable {
    let id: UUID
    let store: StoreProfile
    let storeName: String

    init(store: StoreProfile) {
        id = store.id
        self.store = store
        storeName = store.name
    }
}

struct StoreDeletionRequest: Identifiable {
    let id: UUID
    let store: StoreProfile
    let storeName: String
    let summary: StoreDeletionSummary

    init(store: StoreProfile, summary: StoreDeletionSummary) {
        id = store.id
        self.store = store
        storeName = store.name
        self.summary = summary
    }
}
