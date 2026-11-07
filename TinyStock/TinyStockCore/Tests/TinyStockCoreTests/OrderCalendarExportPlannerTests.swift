// Proposito: Validar os eventos oferecidos para producao e despacho.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-09.

import Foundation
import Testing
@testable import TinyStockCore

@MainActor
struct OrderCalendarExportPlannerTests {
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: "America/New_York")!
        return result
    }

    private func date(_ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    @Test func pedidoEmProducaoOfereceOsDoisEventos() {
        let order = makeOrder(status: .awaitingProduction)
        let drafts = OrderCalendarExportPlanner.drafts(for: order, storeName: "Loja Teste", calendar: calendar)

        #expect(drafts.map(\.kind) == [.production, .shipping])
        #expect(drafts.map(\.startDate) == [calendar.startOfDay(for: date(3, 8)), calendar.startOfDay(for: date(3, 10))])
    }

    @Test func pedidoProntoOfereceSomenteDespacho() {
        let order = makeOrder(status: .readyToShip)
        let drafts = OrderCalendarExportPlanner.drafts(for: order, storeName: "Loja Teste", calendar: calendar)

        #expect(drafts.map(\.kind) == [.shipping])
    }

    @Test func estadosSemPrazoOperacionalNaoOferecemEventos() {
        for status in [SalesOrderStatus.new, .shipped, .completed, .cancelled] {
            let order = makeOrder(status: status)
            #expect(OrderCalendarExportPlanner.drafts(for: order, storeName: "Loja", calendar: calendar).isEmpty)
        }

        let unknown = makeOrder(status: .awaitingProduction)
        unknown.statusRawValue = "future-status"
        #expect(OrderCalendarExportPlanner.drafts(for: unknown, storeName: "Loja", calendar: calendar).isEmpty)
    }

    @Test func prazoAusenteNaoCriaEventoIncompleto() {
        let order = makeOrder(status: .inProduction)
        order.productionDueAt = nil
        let drafts = OrderCalendarExportPlanner.drafts(for: order, storeName: "Loja", calendar: calendar)

        #expect(drafts.map(\.kind) == [.shipping])
    }

    @Test func eventoUsaDiaLocalMesmoNaMudancaDeHorario() throws {
        let order = makeOrder(status: .awaitingProduction)
        order.shippingDueAt = nil
        let draft = try #require(OrderCalendarExportPlanner.drafts(
            for: order, storeName: "Loja", calendar: calendar
        ).first)

        #expect(calendar.component(.hour, from: draft.startDate) == 0)
        #expect(calendar.component(.day, from: draft.startDate) == 8)
        #expect(calendar.component(.day, from: draft.endDate) == 9)
        #expect(draft.endDate.timeIntervalSince(draft.startDate) == 23 * 60 * 60)
    }

    @Test func conteudoIdentificaPedidoELoja() throws {
        let order = makeOrder(status: .awaitingProduction)
        let draft = try #require(OrderCalendarExportPlanner.drafts(
            for: order, storeName: "Loja Principal", calendar: calendar
        ).first)

        #expect(draft.id == "\(order.id.uuidString).production")
        #expect(draft.title.contains("Produto Premium"))
        #expect(draft.notes.contains("Loja Principal"))
        #expect(draft.notes.contains("Ana"))
        #expect(draft.notes.contains("PED-42"))
        #expect(draft.notes.contains(order.channelDisplayName))
    }

    private func makeOrder(status: SalesOrderStatus) -> SalesOrder {
        let order = SalesOrder(
            channel: .shopee,
            fulfillment: .production,
            status: status,
            buyerName: "Ana",
            externalReference: "PED-42",
            productionDueAt: date(3, 8),
            shippingDueAt: date(3, 10)
        )
        order.items = [
            SalesOrderItem(productName: "Produto Premium", variantName: "Preta", quantity: 1),
            SalesOrderItem(productName: "Produto Secundário", variantName: "Edição especial", quantity: 1, position: 1)
        ]
        return order
    }
}
