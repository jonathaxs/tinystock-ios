// Proposito: Organizar os compromissos dos pedidos por dia civil, sem alterar os models.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-05.

import Foundation

public struct SalesOrderScheduleEntry: Sendable {
    public enum Kind: Sendable {
        case production, shipping, shipped, completed, cancelled, ordered
    }

    public let kind: Kind
    public let date: Date
}

public enum SalesOrderSchedule {
    /// Mantem ambos os prazos visiveis enquanto a producao esta pendente.
    /// Estados posteriores exibem apenas a proxima obrigacao ou a data efetiva do estado.
    public static func entries(for order: SalesOrder) -> [SalesOrderScheduleEntry] {
        switch order.status {
        case .awaitingProduction, .inProduction:
            var entries: [SalesOrderScheduleEntry] = []
            if let date = order.productionDueAt { entries.append(.init(kind: .production, date: date)) }
            if let date = order.shippingDueAt { entries.append(.init(kind: .shipping, date: date)) }
            return entries.isEmpty ? [.init(kind: .ordered, date: order.orderedAt)] : entries
        case .readyToShip:
            return [.init(kind: .shipping, date: order.shippingDueAt ?? order.orderedAt)]
        case .shipped:
            return [.init(kind: .shipped, date: order.shippedAt ?? order.updatedAt)]
        case .completed:
            return [.init(kind: .completed, date: order.completedAt ?? order.updatedAt)]
        case .cancelled:
            return [.init(kind: .cancelled, date: order.cancelledAt ?? order.updatedAt)]
        case .new, .none:
            return [.init(kind: .ordered, date: order.orderedAt)]
        }
    }

    public static func orders(on day: Date, from orders: [SalesOrder], calendar: Calendar = .current) -> [SalesOrder] {
        orders.filter { order in
            entries(for: order).contains { calendar.isDate($0.date, inSameDayAs: day) }
        }
    }

    public static func countsByDay(from orders: [SalesOrder], calendar: Calendar = .current) -> [Date: Int] {
        var counts: [Date: Int] = [:]
        for order in orders {
            // Producao e despacho no mesmo dia representam um unico pedido na grade.
            let days = Set(entries(for: order).map { calendar.startOfDay(for: $0.date) })
            for day in days { counts[day, default: 0] += 1 }
        }
        return counts
    }

    public static func isOverdue(_ order: SalesOrder, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let deadlines: [Date?]
        switch order.status {
        case .awaitingProduction, .inProduction:
            deadlines = [order.productionDueAt, order.shippingDueAt]
        case .readyToShip:
            deadlines = [order.shippingDueAt]
        default:
            return false
        }
        let today = calendar.startOfDay(for: now)
        return deadlines.compactMap { $0 }.contains { calendar.startOfDay(for: $0) < today }
    }

    /// Grade de semanas completas, respeitando primeiro dia da semana e horario de verao.
    public static func monthDays(containing date: Date, calendar: Calendar = .current) -> [Date] {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: month.end),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: month.start),
              let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: lastDay) else { return [] }
        var days: [Date] = []
        var current = firstWeek.start
        while current < lastWeek.end {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current), next > current else { break }
            current = next
        }
        return days
    }
}
