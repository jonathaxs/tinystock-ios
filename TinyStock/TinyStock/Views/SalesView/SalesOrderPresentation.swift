// Proposito: Centralizar textos e a proxima acao exibida para cada pedido.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-03.

import SwiftUI
import TinyStockCore

struct SalesOrderQuickAction {
    let status: SalesOrderStatus
    let title: String
    let systemImage: String
    let tint: Color
}

enum SalesOrderPresentation {
    static func quickAction(for order: SalesOrder) -> SalesOrderQuickAction? {
        switch order.status {
        case .awaitingProduction, .inProduction:
            SalesOrderQuickAction(
                status: .readyToShip,
                title: String(localized: "order.action.produced", bundle: .tinyStockCore),
                systemImage: "checkmark.circle",
                tint: .green
            )
        case .readyToShip:
            SalesOrderQuickAction(
                status: .shipped,
                title: String(localized: "order.action.shipped", bundle: .tinyStockCore),
                systemImage: "shippingbox.and.arrow.forward",
                tint: .blue
            )
        case .shipped:
            SalesOrderQuickAction(
                status: .completed,
                title: String(localized: "order.action.completed", bundle: .tinyStockCore),
                systemImage: "checkmark.seal",
                tint: .green
            )
        case .new, .completed, .cancelled, .none:
            nil
        }
    }

    static func canEdit(_ order: SalesOrder) -> Bool {
        guard let status = order.status else { return false }
        return !status.isTerminal && status != .shipped
    }

    static func canCancel(_ order: SalesOrder) -> Bool {
        order.canTransition(to: .cancelled)
    }

    static func queueDate(for order: SalesOrder) -> Date {
        switch order.status {
        case .awaitingProduction, .inProduction:
            order.productionDueAt ?? order.shippingDueAt ?? order.orderedAt
        case .readyToShip:
            order.shippingDueAt ?? order.orderedAt
        case .shipped:
            order.shippedAt ?? order.updatedAt
        case .completed:
            order.completedAt ?? order.updatedAt
        case .cancelled:
            order.cancelledAt ?? order.updatedAt
        case .new, .none:
            order.orderedAt
        }
    }

    static func deadlineTitle(for order: SalesOrder) -> String {
        let date = queueDate(for: order).formatted(date: .abbreviated, time: .omitted)
        let format: String
        switch order.status {
        case .awaitingProduction, .inProduction:
            format = String(localized: "order.queue.productionDate", bundle: .tinyStockCore)
        case .readyToShip:
            format = String(localized: "order.queue.shippingDate", bundle: .tinyStockCore)
        case .shipped:
            format = String(localized: "order.queue.shippedDate", bundle: .tinyStockCore)
        case .completed:
            format = String(localized: "order.queue.completedDate", bundle: .tinyStockCore)
        case .cancelled:
            format = String(localized: "order.queue.cancelledDate", bundle: .tinyStockCore)
        case .new, .none:
            format = String(localized: "order.queue.orderDate", bundle: .tinyStockCore)
        }
        return String(format: format, date)
    }

    static func calendarTitle(for entry: SalesOrderScheduleEntry) -> String {
        let format: String
        switch entry.kind {
        case .production: format = String(localized: "order.queue.productionDate", bundle: .tinyStockCore)
        case .shipping: format = String(localized: "order.queue.shippingDate", bundle: .tinyStockCore)
        case .shipped: format = String(localized: "order.queue.shippedDate", bundle: .tinyStockCore)
        case .completed: format = String(localized: "order.queue.completedDate", bundle: .tinyStockCore)
        case .cancelled: format = String(localized: "order.queue.cancelledDate", bundle: .tinyStockCore)
        case .ordered: format = String(localized: "order.queue.orderDate", bundle: .tinyStockCore)
        }
        return String(format: format, entry.date.formatted(date: .abbreviated, time: .omitted))
    }

    static func message(for error: Error) -> String {
        if let error = error as? SalesOrderManagementError { return error.localizedMessage }
        if let error = error as? SalesOrderError { return error.localizedMessage }
        return error.localizedDescription
    }
}
