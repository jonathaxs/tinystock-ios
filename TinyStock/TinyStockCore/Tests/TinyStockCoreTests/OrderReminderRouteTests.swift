// Proposito: Validar abertura de pedidos a partir do conteudo de alertas locais.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-07.

import Foundation
import Testing
@testable import TinyStockCore

@MainActor
@Suite(.serialized)
struct OrderReminderRouteTests {
    private func reminder(storeID: UUID = UUID(), orderID: UUID = UUID()) -> OrderReminder {
        OrderReminder(
            storeID: storeID, orderID: orderID, kind: .production, timing: .dueDay,
            fireDate: Date(), title: "Producao", body: "Produto", soundEnabled: true
        )
    }

    @Test func conteudoDoAdaptadorAbreIDsCertosEPermiteToquesRepetidos() throws {
        let reminder = reminder()
        let request = try SystemOrderReminderCenter.request(for: reminder)
        let first = try #require(OrderReminderRoute(identifier: request.identifier, userInfo: request.content.userInfo))
        let second = try #require(OrderReminderRoute(identifier: request.identifier, userInfo: request.content.userInfo))
        #expect(first.storeID == reminder.storeID)
        #expect(first.orderID == reminder.orderID)
        #expect(first.id != second.id)
    }

    @Test func identificadoresIncompletosOuDeOutraFuncaoSaoRecusados() throws {
        let request = try SystemOrderReminderCenter.request(for: reminder())
        for identifier in ["other.feature", OrderReminder.identifierPrefix, request.identifier + ".extra",
                           request.identifier.replacingOccurrences(of: ".production.", with: ".unknown.")] {
            #expect(OrderReminderRoute(identifier: identifier, userInfo: request.content.userInfo) == nil)
        }
        #expect(OrderReminderRoute(identifier: request.identifier, userInfo: [:]) == nil)
        for key in ["storeID", "orderID", "reminderKind"] {
            var payload = request.content.userInfo
            payload[key] = UUID().uuidString
            #expect(OrderReminderRoute(identifier: request.identifier, userInfo: payload) == nil)
        }
    }

    @Test func destinoExigePedidoNaLojaAtivaENaoRestauraArquivada() throws {
        let context = try TestDatabase.makeCleanContext()
        let store = StoreProfile(name: "Loja do pedido")
        let order = SalesOrder(storeID: store.id)
        context.insert(store)
        context.insert(order)
        try context.save()
        let request = try SystemOrderReminderCenter.request(for: reminder(storeID: store.id, orderID: order.id))
        let route = try #require(OrderReminderRoute(identifier: request.identifier, userInfo: request.content.userInfo))
        let destination = try #require(try route.resolve(in: context))
        #expect(destination.store.id == store.id)
        #expect(destination.order.id == order.id)
        store.isArchived = true
        #expect(try route.resolve(in: context) == nil)
        #expect(store.isArchived)
        store.isArchived = false
        order.storeID = UUID()
        #expect(try route.resolve(in: context) == nil)
        order.storeID = store.id
        context.delete(order)
        try context.save()
        #expect(try route.resolve(in: context) == nil)
        context.delete(store)
        try context.save()
        #expect(try route.resolve(in: context) == nil)
    }
}
