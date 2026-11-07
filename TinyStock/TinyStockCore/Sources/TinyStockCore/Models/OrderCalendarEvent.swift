// Proposito: Representar um evento de pedido pronto para exportacao ao Calendario.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-09.

import Foundation

public enum OrderCalendarExportSettings {
    public static let isEnabledKey = "calendar.export.enabled"
}

public enum OrderCalendarEventKind: String, CaseIterable, Equatable, Sendable {
    case production
    case shipping

    public var localizedActionTitle: String {
        switch self {
        case .production:
            String(localized: "calendar.export.production.action", bundle: .tinyStockCore)
        case .shipping:
            String(localized: "calendar.export.shipping.action", bundle: .tinyStockCore)
        }
    }

    public var symbolName: String {
        switch self {
        case .production: "hammer"
        case .shipping: "shippingbox"
        }
    }
}

public struct OrderCalendarEventDraft: Identifiable, Equatable, Sendable {
    public let id: String
    public let orderID: UUID
    public let kind: OrderCalendarEventKind
    public let title: String
    public let notes: String
    public let startDate: Date
    public let endDate: Date

    public init(
        orderID: UUID,
        kind: OrderCalendarEventKind,
        title: String,
        notes: String,
        startDate: Date,
        endDate: Date
    ) {
        id = "\(orderID.uuidString).\(kind.rawValue)"
        self.orderID = orderID
        self.kind = kind
        self.title = title
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
    }
}
