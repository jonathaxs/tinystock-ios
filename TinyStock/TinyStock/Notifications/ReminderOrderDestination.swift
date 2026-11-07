// Proposito: Abrir um pedido de alerta sem reutilizar dados de outra loja.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-07.

import SwiftData
import SwiftUI
import TinyStockCore

struct ReminderOrderDestination: View {
    @Query private var orders: [SalesOrder]
    @Query private var stores: [StoreProfile]

    init(route: OrderReminderRoute) {
        let orderID = route.orderID
        let storeID = route.storeID
        _orders = Query(filter: #Predicate<SalesOrder> { $0.id == orderID && $0.storeID == storeID })
        _stores = Query(filter: #Predicate<StoreProfile> { $0.id == storeID && !$0.isArchived })
    }

    var body: some View {
        if !stores.isEmpty, let order = orders.first {
            SalesOrderDetailView(order: order)
        } else {
            ContentUnavailableView(
                String(localized: "notifications.order.unavailable", bundle: .tinyStockCore),
                systemImage: "calendar.badge.exclamationmark"
            )
        }
    }
}
