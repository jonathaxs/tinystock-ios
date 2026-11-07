// ⌘
//  TinyStock/Views/MainView.swift
//
//  Propósito: Hospeda o TabView principal e roteia pras telas de Produtos, Relatórios, Calendário e Ajustes.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-07.
// ⌘

import SwiftUI
import SwiftData
import TinyStockCore

// MARK: - Índices das abas
// Constantes centralizadas para evitar números mágicos na navegação entre abas.
extension MainView {
    enum Tab {
        // Identificam a aba salva; a ordem visual segue a declaração no TabView.
        static let products = 0
        static let sales    = 1
        static let reports  = 2
        static let settings = 3
    }
}

// MARK: - Tela principal
struct MainView: View {

    @Environment(StoreSession.self) private var storeSession
    @Environment(OrderReminderRouter.self) private var reminderRouter
    @Environment(\.modelContext) private var modelContext

    // A seleção persistida permite preservar a aba ao reabrir o aplicativo.
    @AppStorage("app.selectedTab") private var selectedTab: Int = 0
    @AppStorage(AppAccentColor.storageKey) private var accentColorRaw = AppAccentColor.defaultColor.rawValue
    @State private var calendarFilterRequest: CalendarOrderFilter?
    @State private var reminderRoute: OrderReminderRoute?
    @State private var reminderError: String?

    private var accentColor: AppAccentColor {
        AppAccentColor(rawValue: accentColorRaw) ?? .defaultColor
    }

    var body: some View {
        TabView(selection: $selectedTab) {

            ProductsView(storeID: storeSession.selectedStoreID)
                .tabItem {
                    Label(String(localized: "tab.products", bundle: .tinyStockCore), systemImage: "shippingbox.fill")
                }
                .tag(Tab.products)

            ReportsView(storeID: storeSession.selectedStoreID) { filter in
                calendarFilterRequest = filter
                selectedTab = Tab.sales
            }
                .tabItem {
                    Label(String(localized: "tab.reports", bundle: .tinyStockCore), systemImage: "chart.bar.fill")
                }
                .tag(Tab.reports)

            SalesView(
                storeID: storeSession.selectedStoreID,
                filterRequest: $calendarFilterRequest,
                reminderRoute: $reminderRoute
            )
                .id(storeSession.selectedStoreID)
                .tabItem {
                    Label(String(localized: "tab.sales", bundle: .tinyStockCore), systemImage: "calendar")
                }
                .tag(Tab.sales)

            SettingsView(storeID: storeSession.selectedStoreID)
                .tabItem {
                    Label(String(localized: "tab.settings", bundle: .tinyStockCore), systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
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
                calendarFilterRequest = .all
                selectedTab = Tab.sales
                reminderRoute = route
            } catch {
                reminderError = String(localized: "notifications.order.error", bundle: .tinyStockCore)
            }
        }
        .onChange(of: storeSession.selectedStoreID) { _, storeID in
            if reminderRoute?.storeID != storeID { reminderRoute = nil }
        }
        .alert(String(localized: "notifications.title", bundle: .tinyStockCore), isPresented: Binding(
            get: { reminderError != nil }, set: { if !$0 { reminderError = nil } }
        )) {
            Button(String(localized: "common.ok", bundle: .tinyStockCore)) { reminderError = nil }
        } message: { Text(reminderError ?? "") }
    }
}

#Preview {
    let storeID = UUID()

    MainView()
        .environment(StoreSession(selectedStoreID: storeID))
        .environment(OrderReminderRouter())
        .modelContainer(for: [StoreProfile.self, Product.self, ProductVariant.self, StockMovement.self, Sale.self, SaleItem.self, SalesOrder.self, SalesOrderItem.self], inMemory: true)
}
