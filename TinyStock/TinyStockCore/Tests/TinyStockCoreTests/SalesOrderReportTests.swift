// Proposito: Validar isolamento, datas, retratos financeiros e filas dos relatorios de pedidos.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-05.

import Foundation
import Testing
@testable import TinyStockCore

@MainActor
struct SalesOrderReportTests {
    private let storeID = UUID()

    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: "America/New_York")!
        return result
    }

    private func date(_ month: Int = 9, _ day: Int = 5, hour: Int = 12, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func order(
        status: SalesOrderStatus = .readyToShip,
        day: Int = 5,
        quantity: Int = 2,
        price: Decimal = 50,
        cost: Decimal = 20,
        fee: Decimal = 10,
        channel: SalesChannel = .direct,
        productID: UUID = UUID(),
        name: String = "Produto"
    ) -> SalesOrder {
        let order = SalesOrder(
            storeID: storeID, channel: channel, status: status, orderedAt: date(9, day),
            channelFeePercentage: 99, channelFeeAmount: fee
        )
        order.items = [SalesOrderItem(
            storeID: storeID, productID: productID, productName: name,
            unitPrice: price, unitCost: cost, quantity: quantity
        )]
        return order
    }

    private func summary(
        _ orders: [SalesOrder],
        range: SalesOrderReportRange = .preset(.today)
    ) -> SalesOrderReportSummary {
        .init(orders: orders, storeID: storeID, range: range, reference: date(), calendar: calendar)
    }

    @Test func resumoVazioZeraTotaisEFilas() {
        let report = summary([])
        #expect(report.storeID == storeID)
        #expect(report.received.isEmpty)
        #expect(report.received.orderCount == 0)
        #expect(report.received.unitCount == 0)
        #expect(report.received.revenue == 0)
        #expect(report.received.cost == 0)
        #expect(report.received.channelFees == 0)
        #expect(report.received.grossProfit == 0)
        #expect(report.received.netProfit == 0)
        #expect(report.dispatched.isEmpty)
        #expect(report.completed.orderCount == 0)
        #expect(report.cancelled.orderCount == 0)
        #expect(report.operations.toProduce.orderCount == 0)
        #expect(report.operations.readyToShip.orderCount == 0)
        #expect(report.operations.overdue.orderCount == 0)
        #expect(report.dayGroups.isEmpty)
        #expect(report.channelGroups.isEmpty)
        #expect(report.bestSellingProducts().isEmpty)
    }

    @Test func lojaIsolaFinancasRankingsEventosEFilas() {
        let own = order()
        let foreign = SalesOrderStatus.allCases.map { status in
            let value = order(status: status, quantity: 99, channel: .shopee)
            value.storeID = UUID()
            value.productionDueAt = date(9, 1)
            value.shippingDueAt = date(9, 1)
            value.shippedAt = date()
            value.completedAt = date()
            value.cancelledAt = date()
            return value
        }
        let report = summary([own] + foreign)
        #expect(report.received.orderIDs == [own.id])
        #expect(report.received.revenue == 100)
        #expect(report.bestSellingProducts().count == 1)
        #expect(report.channelGroups.map(\.id.rawValue) == ["direct"])
        #expect(report.dayGroups.first?.totals.orderIDs == [own.id])
        #expect(report.dispatched.isEmpty)
        #expect(report.completed.orderCount == 0)
        #expect(report.cancelled.orderCount == 0)
        #expect(report.operations.readyToShip.orderIDs == [own.id])
        #expect(report.operations.toProduce.orderCount == 0)
        #expect(report.operations.overdue.orderCount == 0)
    }

    @Test func recebidosUsamDataDaVendaEExcluemCanceladosEDesconhecidos() {
        let orders = SalesOrderStatus.allCases.map { order(status: $0) }
        let unknown = order()
        unknown.statusRawValue = "future-status"
        let outside = order(day: 4)
        outside.shippingDueAt = date()
        outside.updatedAt = date()
        let report = summary(orders + [unknown, outside])
        #expect(report.received.orderCount == 6)
        #expect(report.received.unitCount == 12)
        #expect(report.received.revenue == 600)
        #expect(report.received.cost == 240)
        #expect(report.received.channelFees == 60)
        #expect(report.received.grossProfit == 360)
        #expect(report.received.netProfit == 300)
        #expect(report.operations.unknownStatus.orderIDs == [unknown.id])
        #expect(report.bestSellingProducts(limit: 99).count == 6)
        #expect(report.dayGroups.first?.totals == report.received)
        #expect(report.channelGroups.first?.totals == report.received)
    }

    @Test func valoresDecimaisETaxaSalvaPreservamPrejuizo() {
        let value = order(quantity: 3, price: Decimal(string: "10.10")!, cost: Decimal(string: "11.25")!, fee: 2)
        let report = summary([value])
        #expect(report.received.revenue == Decimal(string: "30.30"))
        #expect(report.received.cost == Decimal(string: "33.75"))
        #expect(report.received.channelFees == 2)
        #expect(report.received.netProfit == Decimal(string: "-5.45"))
        #expect(report.channelGroups.first?.totals.netProfit == report.received.netProfit)
    }

    @Test func resultadoEhRetratoImutavelSemAlterarPedido() {
        let value = order()
        let report = summary([value])
        #expect(value.status == .readyToShip)
        #expect(value.channelFeeAmount == 10)
        value.items?.first?.unitPrice = 999
        value.items?.first?.productName = "Renomeado"
        value.channelFeeAmount = 0
        value.statusRawValue = SalesOrderStatus.cancelled.rawValue
        #expect(report.received.revenue == 100)
        #expect(report.received.netProfit == 50)
        #expect(report.bestSellingProducts().first?.productName == "Produto")
        #expect(summary([value]).received.isEmpty)
    }

    @Test func quantidadesAgregadasNaoEstouramInt() {
        let first = order(quantity: Int.max, price: 1, cost: 0, fee: 0)
        let second = order(quantity: Int.max, price: 1, cost: 0, fee: 0, productID: first.items!.first!.productID)
        let expected = Decimal(Int.max) * 2
        let report = summary([first, second])
        #expect(report.received.unitCount == expected)
        #expect(report.received.revenue == expected)
        #expect(report.operations.readyToShip.unitCount == expected)
        #expect(report.bestSellingProducts().first?.quantity == expected)
    }

    @Test func despachoUsaDataEfetivaEIncluiPedidoJaConcluido() {
        let shipped = order(status: .shipped, day: 1)
        shipped.shippedAt = date()
        let completed = order(status: .completed, day: 2)
        completed.shippedAt = date()
        completed.completedAt = date(9, 6)
        let planned = order()
        planned.shippingDueAt = date()
        let olderShipment = order(status: .completed)
        olderShipment.shippedAt = date(9, 4)
        olderShipment.completedAt = date()
        let report = summary([shipped, completed, planned, olderShipment])
        #expect(Set(report.dispatched.orderIDs) == Set([shipped.id, completed.id]))
        #expect(report.dispatched.revenue == 200)
        #expect(report.dispatched.netProfit == 100)
        #expect(report.completed.orderIDs == [olderShipment.id])
        #expect(Set(report.received.orderIDs) == Set([planned.id, olderShipment.id]))
    }

    @Test func datasEfetivasAusentesNaoUsamPrazoOuAtualizacaoComoFallback() {
        let orders = [SalesOrderStatus.shipped, .completed, .cancelled].map { status in
            let value = order(status: status)
            value.updatedAt = date()
            value.shippingDueAt = date()
            return value
        }
        let report = summary(orders, range: .preset(.allTime))
        #expect(report.dispatched.isEmpty)
        #expect(report.completed.orderCount == 0)
        #expect(report.cancelled.orderCount == 0)
        #expect(report.received.orderCount == 2)
    }

    @Test func cancelamentoContaNoDiaEfetivoSemSomarValoresPreservados() {
        let recentCancellation = order(status: .cancelled, day: 1)
        recentCancellation.cancelledAt = date()
        let oldCancellation = order(status: .cancelled)
        oldCancellation.cancelledAt = date(9, 4)
        oldCancellation.shippedAt = date()
        let report = summary([recentCancellation, oldCancellation])
        #expect(report.cancelled.orderIDs == [recentCancellation.id])
        #expect(report.cancelled.unitCount == 2)
        #expect(report.received.isEmpty)
        #expect(report.dispatched.isEmpty)
        #expect(recentCancellation.total == 100)
        #expect(recentCancellation.netProfit == 50)
    }

    @Test func filasAtuaisIndependemDoPeriodoFinanceiro() {
        let awaiting = order(status: .awaitingProduction, day: 1)
        awaiting.productionDueAt = date(9, 4)
        awaiting.shippingDueAt = date(9, 8)
        let producing = order(status: .inProduction, day: 2, quantity: 3)
        producing.productionDueAt = date(9, 5, hour: 0)
        let ready = order(day: 2)
        ready.shippingDueAt = date(9, 4)
        let shipped = order(status: .shipped, day: 2)
        shipped.shippingDueAt = date(9, 4)
        let fresh = order(status: .new, day: 1)
        let orders = [awaiting, producing, ready, shipped, fresh, order(status: .cancelled, day: 1), order(status: .completed, day: 1)]
        let report = summary(orders)
        #expect(report.received.isEmpty)
        #expect(report.operations == summary(orders, range: .preset(.allTime)).operations)
        #expect(report.operations.newOrders.orderIDs == [fresh.id])
        #expect(report.operations.awaitingProduction.orderIDs == [awaiting.id])
        #expect(report.operations.inProduction.orderIDs == [producing.id])
        #expect(report.operations.toProduce.orderCount == 2)
        #expect(report.operations.toProduce.unitCount == 5)
        #expect(report.operations.readyToShip.orderIDs == [ready.id])
        #expect(report.operations.shipped.orderIDs == [shipped.id])
        #expect(Set(report.operations.overdue.orderIDs) == Set([awaiting.id, ready.id]))
    }

    @Test func rankingAgrupaVariacoesPorIDEMantemNomeMaisRecente() throws {
        let productID = UUID()
        let old = order(day: 4, productID: productID, name: "Antigo")
        let recent = order(productID: productID, name: "Atual")
        recent.items?.append(SalesOrderItem(storeID: storeID, productID: productID, productName: "Atual", variantName: "Outra", unitPrice: 20, unitCost: 5, quantity: 1, position: 1))
        let sameName = order(quantity: 1, name: "Atual")
        let report = summary([old, recent, sameName], range: .preset(.lastSevenDays))
        let ranking = try #require(report.bestSellingProducts().first)
        #expect(ranking.productID == productID)
        #expect(ranking.productName == "Atual")
        #expect(ranking.quantity == 5)
        #expect(ranking.revenue == 220)
        #expect(ranking.cost == 85)
        #expect(ranking.grossProfit == 135)
        #expect(report.bestSellingProducts().count == 2)
    }

    @Test func rankingRespeitaQuantidadeReceitaNomeIDELimite() {
        let values = [
            order(quantity: 2, price: 50, name: "B"),
            order(quantity: 2, price: 50, name: "A"),
            order(quantity: 3, price: 1, name: "C"),
            order(quantity: 2, price: 60, name: "D"),
            order(quantity: 2, price: 50, name: "A")
        ]
        let report = summary(values)
        #expect(report.bestSellingProducts(limit: 99).map(\.productName) == ["C", "D", "A", "A", "B"])
        #expect(report.bestSellingProducts().count == 3)
        #expect(report.bestSellingProducts(limit: 0).isEmpty)
        #expect(report.bestSellingProducts(limit: -1).isEmpty)
        #expect(report.bestSellingProducts(limit: 99) == summary(values.reversed()).bestSellingProducts(limit: 99))
    }

    @Test func nomesEmpatadosNaDataUsamIDEstavelDoPedido() {
        let first = order(name: "Primeiro")
        first.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let second = order(productID: first.items!.first!.productID, name: "Segundo")
        second.id = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        #expect(summary([second, first]).bestSellingProducts().first?.productName == "Primeiro")
    }

    @Test func canaisSeparamCustomizadosEDesconhecidosSemPerderTotais() {
        let direct = order()
        direct.customChannelName = "Ignorar"
        let shopee = order(channel: .shopee)
        let mercadoLivre = order(channel: .mercadoLivre)
        let otherA = order(channel: .other)
        otherA.customChannelName = " Feira "
        let otherB = order(channel: .other)
        otherB.customChannelName = "Feira"
        let otherC = order(channel: .other)
        otherC.customChannelName = "Site"
        let unknown = order()
        unknown.channelRawValue = "future-channel"
        let report = summary([direct, shopee, mercadoLivre, otherA, otherB, otherC, unknown])
        #expect(report.channelGroups.count == 6)
        #expect(report.channelGroups.first?.displayName == "Feira")
        #expect(report.channelGroups.first?.totals.orderCount == 2)
        #expect(report.channelGroups.contains { $0.id.rawValue == "future-channel" })
        #expect(report.channelGroups.allSatisfy { !$0.displayName.isEmpty })
        #expect(report.channelGroups.reduce(Decimal.zero) { $0 + $1.totals.revenue } == report.received.revenue)
        #expect(report.channelGroups.reduce(Decimal.zero) { $0 + $1.totals.netProfit } == report.received.netProfit)
    }

    @Test func agrupamentoDiarioUsaDiaLocalEReconciliaTotais() {
        let late = order()
        late.orderedAt = date(9, 5, hour: 23)
        let early = order()
        early.orderedAt = date(9, 5, hour: 0)
        let old = order(day: 4)
        let report = summary([old, late, early], range: .preset(.lastSevenDays))
        #expect(report.dayGroups.map(\.day) == [date(9, 5, hour: 0), date(9, 4, hour: 0)])
        #expect(report.dayGroups.first?.totals.orderCount == 2)
        #expect(report.dayGroups.reduce(Decimal.zero) { $0 + $1.totals.revenue } == report.received.revenue)
        #expect(report.dayGroups.reduce(Decimal.zero) { $0 + $1.totals.netProfit } == report.received.netProfit)
    }

    @Test func recortesRapidosFiltramPedidosNosLimites() {
        let today = order()
        let tomorrow = order(day: 6)
        tomorrow.orderedAt = date(9, 6, hour: 0)
        let monthStart = order(day: 1)
        monthStart.orderedAt = date(9, 1, hour: 0)
        let sixDaysAgo = order()
        sixDaysAgo.orderedAt = date(8, 30, hour: 0)
        let sevenDaysAgo = order()
        sevenDaysAgo.orderedAt = date(8, 29, hour: 23)
        let nextMonth = order()
        nextMonth.orderedAt = date(10, 1, hour: 0)
        let values = [today, tomorrow, monthStart, sixDaysAgo, sevenDaysAgo, nextMonth]
        #expect(summary(values).received.orderIDs == [today.id])
        #expect(Set(summary(values, range: .preset(.lastSevenDays)).received.orderIDs) == Set([today.id, monthStart.id, sixDaysAgo.id]))
        #expect(Set(summary(values, range: .preset(.currentMonth)).received.orderIDs) == Set([today.id, tomorrow.id, monthStart.id]))
        #expect(summary(values, range: .preset(.allTime)).received.orderCount == 6)
    }

    @Test func personalizadoIncluiDiasCompletosENaoIncluiProximaMeiaNoite() {
        let range = SalesOrderReportRange.custom(start: date(9, 4, hour: 22), end: date(9, 5, hour: 1))
        #expect(range.contains(date(9, 4, hour: 0), calendar: calendar))
        #expect(range.contains(date(9, 5, hour: 23), calendar: calendar))
        #expect(!range.contains(date(9, 6, hour: 0), calendar: calendar))
        #expect(!range.contains(date(9, 3, hour: 23), calendar: calendar))
        #expect(summary([order(day: 3), order(day: 4), order(day: 5), order(day: 6)], range: range).received.orderCount == 2)
    }

    @Test func personalizadoInvertidoFicaVazioMasMesmoDiaEhValido() {
        let invalid = SalesOrderReportRange.custom(start: date(9, 6), end: date(9, 4))
        #expect(invalid.dateInterval(calendar: calendar) == nil)
        #expect(summary([order()], range: invalid).received.isEmpty)
        let sameDay = SalesOrderReportRange.custom(start: date(9, 5, hour: 23), end: date(9, 5, hour: 0))
        #expect(summary([order()], range: sameDay).received.orderCount == 1)
    }

    @Test func personalizadoRespeitaHorarioDeVeraoEAnoBissexto() throws {
        let spring = SalesOrderReportRange.custom(start: date(3, 8), end: date(3, 8))
        let autumn = SalesOrderReportRange.custom(start: date(11, 1), end: date(11, 1))
        #expect(try #require(spring.dateInterval(calendar: calendar)).duration == 23 * 60 * 60)
        #expect(try #require(autumn.dateInterval(calendar: calendar)).duration == 25 * 60 * 60)
        let leap = SalesOrderReportRange.custom(start: date(2, 28, year: 2028), end: date(2, 29, year: 2028))
        #expect(leap.contains(date(2, 29, hour: 23, year: 2028), calendar: calendar))
        #expect(!leap.contains(date(3, 1, hour: 0, year: 2028), calendar: calendar))
    }
}
