// ⌘
//  TinyStock/Views/MainView.swift
//
//  Propósito: Hospeda o NavigationStack raiz, com a Início de raiz, e roteia pelo AppRouter:
//             Relatórios e Calendário em sheet, Ajustes como página. Inclui a abertura de pedidos
//             pelas notificações.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-07.
// ⌘

import SwiftUI
import SwiftData
import TinyStockCore

// MARK: - Tela principal
struct MainView: View {

    @Environment(StoreSession.self) private var storeSession
    @Environment(OrderReminderRouter.self) private var reminderRouter
    @Environment(\.modelContext) private var modelContext

    @AppStorage(AppAccentColor.storageKey) private var accentColorRaw = AppAccentColor.defaultColor.rawValue
    @Query private var stores: [StoreProfile]
    @State private var router = AppRouter()
    @State private var reminderError: String?

    private var accentColor: AppAccentColor {
        AppAccentColor(rawValue: accentColorRaw) ?? .defaultColor
    }

    private var storeName: String {
        stores.first { $0.id == storeSession.selectedStoreID }?.name ?? StoreProfileService.localizedDefaultName
    }

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            ProductsView(storeID: storeSession.selectedStoreID)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .settings: SettingsView(storeID: storeSession.selectedStoreID)
                    }
                }
        }
        // Relatórios e Calendário: cada sheet tem seu próprio stack (Calendário → pedido).
        .sheet(item: $router.sheet) { sheet in
            NavigationStack {
                sheetRoot(sheet)
                    // A loja atual fica visível, já que a troca de loja acontece na Início.
                    .navigationSubtitle(storeName)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            SheetCloseButton { router.sheet = nil }
                        }
                    }
            }
            .environment(router)
            .tint(accentColor.color)
        }
        .environment(router)
        .tint(accentColor.color)
        .onChange(of: reminderRouter.request, initial: true) { _, route in
            guard let route else { return }
            reminderRouter.request = nil
            do {
                guard let destination = try route.resolve(in: modelContext) else {
                    reminderError = String(localized: "notifications.order.unavailable", bundle: .tinyStockCore)
                    return
                }
                try storeSession.select(destination.store)
                router.openOrder(route)
            } catch {
                reminderError = String(localized: "notifications.order.error", bundle: .tinyStockCore)
            }
        }
        .onChange(of: storeSession.selectedStoreID) { _, storeID in
            if router.reminderRoute?.storeID != storeID { router.reminderRoute = nil }
        }
        .alert(String(localized: "notifications.title", bundle: .tinyStockCore), isPresented: Binding(
            get: { reminderError != nil }, set: { if !$0 { reminderError = nil } }
        )) {
            Button(String(localized: "common.ok", bundle: .tinyStockCore)) { reminderError = nil }
        } message: { Text(reminderError ?? "") }
    }

    // MARK: - Destinos

    @ViewBuilder
    private func sheetRoot(_ sheet: AppSheet) -> some View {
        @Bindable var router = router
        switch sheet {
        case .reports:
            ReportsView(storeID: storeSession.selectedStoreID) { filter in
                router.openCalendar(filter: filter)
            }
        case .calendar:
            SalesView(
                storeID: storeSession.selectedStoreID,
                filterRequest: $router.calendarFilterRequest,
                reminderRoute: $router.reminderRoute
            )
            .id(storeSession.selectedStoreID)
        }
    }
}

#Preview {
    let storeID = UUID()

    MainView()
        .environment(StoreSession(selectedStoreID: storeID))
        .environment(OrderReminderRouter())
        .modelContainer(for: [StoreProfile.self, Product.self, ProductVariant.self, StockMovement.self, Sale.self, SaleItem.self, SalesOrder.self, SalesOrderItem.self], inMemory: true)
}
