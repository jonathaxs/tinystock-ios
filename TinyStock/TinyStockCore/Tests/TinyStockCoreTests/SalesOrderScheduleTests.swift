// Proposito: Validar prazos por dia, contagem de pedidos e limites da grade mensal.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-05.

import Foundation
import Testing
@testable import TinyStockCore

@MainActor
struct SalesOrderScheduleTests {
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: "America/New_York")!
        result.firstWeekday = 2
        return result
    }

    private func date(_ month: Int, _ day: Int, hour: Int = 12, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test func producaoApareceNosDoisPrazosSemDuplicarNoMesmoDia() {
        let order = SalesOrder(fulfillment: .production, productionDueAt: date(9, 5), shippingDueAt: date(9, 7))
        #expect(SalesOrderSchedule.orders(on: date(9, 5), from: [order], calendar: calendar).count == 1)
        #expect(SalesOrderSchedule.orders(on: date(9, 7), from: [order], calendar: calendar).count == 1)
        #expect(SalesOrderSchedule.orders(on: date(9, 6), from: [order], calendar: calendar).isEmpty)
        order.shippingDueAt = date(9, 5, hour: 23)
        let counts = SalesOrderSchedule.countsByDay(from: [order], calendar: calendar)
        #expect(counts == [calendar.startOfDay(for: date(9, 5)): 1])
    }

    @Test func produzidoRemoveCompromissoDeProducaoEDespachadoUsaDataEfetiva() {
        let order = SalesOrder(fulfillment: .production, productionDueAt: date(9, 5), shippingDueAt: date(9, 7))
        order.statusRawValue = SalesOrderStatus.readyToShip.rawValue
        #expect(SalesOrderSchedule.orders(on: date(9, 5), from: [order], calendar: calendar).isEmpty)
        #expect(SalesOrderSchedule.entries(for: order).map(\.kind) == [.shipping])
        order.statusRawValue = SalesOrderStatus.shipped.rawValue
        order.shippedAt = date(9, 6)
        #expect(SalesOrderSchedule.entries(for: order).first?.date == date(9, 6))
        #expect(SalesOrderSchedule.orders(on: date(9, 7), from: [order], calendar: calendar).isEmpty)
    }

    @Test func concluidosCanceladosEDesconhecidosContinuamConsultaveis() {
        let order = SalesOrder(status: .completed, orderedAt: date(9, 1), updatedAt: date(9, 8))
        order.completedAt = date(9, 7)
        #expect(SalesOrderSchedule.entries(for: order).first?.date == date(9, 7))
        order.statusRawValue = SalesOrderStatus.cancelled.rawValue
        order.cancelledAt = date(9, 4)
        #expect(SalesOrderSchedule.entries(for: order).first?.date == date(9, 4))
        order.cancelledAt = nil
        #expect(SalesOrderSchedule.entries(for: order).first?.date == date(9, 8))
        order.statusRawValue = "future-status"
        #expect(SalesOrderSchedule.entries(for: order).first?.date == date(9, 1))
    }

    @Test func atrasoComecaNoDiaSeguinteENaoContinuaAposDespacho() {
        let order = SalesOrder(shippingDueAt: date(9, 5, hour: 0))
        #expect(!SalesOrderSchedule.isOverdue(order, now: date(9, 5, hour: 23), calendar: calendar))
        #expect(SalesOrderSchedule.isOverdue(order, now: date(9, 6, hour: 0), calendar: calendar))
        order.statusRawValue = SalesOrderStatus.shipped.rawValue
        #expect(!SalesOrderSchedule.isOverdue(order, now: date(9, 6), calendar: calendar))
        order.statusRawValue = SalesOrderStatus.cancelled.rawValue
        #expect(!SalesOrderSchedule.isOverdue(order, now: date(9, 6), calendar: calendar))
    }

    @Test func atrasoDeProducaoPermaneceMesmoComDespachoFuturo() {
        let order = SalesOrder(fulfillment: .production, productionDueAt: date(9, 4), shippingDueAt: date(9, 7))
        #expect(SalesOrderSchedule.isOverdue(order, now: date(9, 5), calendar: calendar))
        order.statusRawValue = SalesOrderStatus.readyToShip.rawValue
        #expect(!SalesOrderSchedule.isOverdue(order, now: date(9, 5), calendar: calendar))
    }

    @Test func contagemUsaDiaLocalENaoDiaUTC() {
        let order = SalesOrder(shippingDueAt: date(9, 5, hour: 23))
        let counts = SalesOrderSchedule.countsByDay(from: [order], calendar: calendar)
        #expect(counts[calendar.startOfDay(for: date(9, 5))] == 1)
        #expect(counts[calendar.startOfDay(for: date(9, 6))] == nil)
    }

    @Test func gradeIncluiBissextoESemanasCompletas() {
        let days = SalesOrderSchedule.monthDays(containing: date(2, 15, year: 2028), calendar: calendar)
        #expect(days.count.isMultiple(of: 7))
        #expect(calendar.component(.weekday, from: days.first!) == 2)
        #expect(days.filter { calendar.component(.month, from: $0) == 2 }.count == 29)
        #expect(Set(days).count == days.count)
        var sundayCalendar = calendar
        sundayCalendar.firstWeekday = 1
        let sundayDays = SalesOrderSchedule.monthDays(containing: date(9, 5), calendar: sundayCalendar)
        #expect(sundayCalendar.component(.weekday, from: sundayDays.first!) == 1)
    }

    @Test func gradeAtravessaHorarioDeVeraoSemPularDia() {
        let days = SalesOrderSchedule.monthDays(containing: date(3, 15), calendar: calendar)
        let march = days.filter { calendar.component(.month, from: $0) == 3 }
        #expect(march.map { calendar.component(.day, from: $0) } == Array(1...31))
        #expect(march.allSatisfy { calendar.component(.hour, from: $0) == 0 })
        #expect(march.contains { day in
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return false }
            return next.timeIntervalSince(day) == 23 * 60 * 60
        })
    }
}
