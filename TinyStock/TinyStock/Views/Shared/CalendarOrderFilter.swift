// Proposito: Compartilhar filtros ao navegar dos relatorios para o calendario.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-06.

import Foundation
import TinyStockCore

enum CalendarOrderFilter: Hashable {
    case all
    case overdue
    case production
    case status(SalesOrderStatus)

    var title: String {
        switch self {
        case .all:
            String(localized: "order.calendar.allStatuses", bundle: .tinyStockCore)
        case .overdue:
            String(localized: "order.calendar.overdue", bundle: .tinyStockCore)
        case .production:
            String(localized: "reports.operation.toProduce", bundle: .tinyStockCore)
        case .status(let status):
            status.localizedName
        }
    }

    /// Ordem das opcoes na folha de filtros do calendario.
    static var allOptions: [CalendarOrderFilter] {
        [.all, .overdue, .production] + SalesOrderStatus.allCases.map { .status($0) }
    }

    var systemImage: String {
        switch self {
        case .all: "tray.full"
        case .overdue: "exclamationmark.triangle"
        case .production: "hammer"
        case .status(let status):
            switch status {
            case .new: "sparkles"
            case .awaitingProduction: "clock"
            case .inProduction: "hammer.circle"
            case .readyToShip: "shippingbox"
            case .shipped: "shippingbox.and.arrow.forward"
            case .completed: "checkmark.seal"
            case .cancelled: "xmark.circle"
            }
        }
    }

    func includes(_ order: SalesOrder, now: Date, calendar: Calendar) -> Bool {
        switch self {
        case .all:
            true
        case .overdue:
            SalesOrderSchedule.isOverdue(order, now: now, calendar: calendar)
        case .production:
            order.status == .awaitingProduction || order.status == .inProduction
        case .status(let status):
            order.status == status
        }
    }
}
