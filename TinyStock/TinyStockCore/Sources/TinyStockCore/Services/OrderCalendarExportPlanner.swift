// Proposito: Montar eventos de producao e despacho sem depender do EventKit.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-09.

import Foundation

public enum OrderCalendarExportPlanner {

    public static func drafts(
        for order: SalesOrder,
        storeName: String,
        calendar: Calendar = .current
    ) -> [OrderCalendarEventDraft] {
        guard let status = order.status else { return [] }

        let deadlines: [(OrderCalendarEventKind, Date?)]
        switch status {
        case .awaitingProduction, .inProduction:
            deadlines = [(.production, order.productionDueAt), (.shipping, order.shippingDueAt)]
        case .readyToShip:
            deadlines = [(.shipping, order.shippingDueAt)]
        case .new, .shipped, .completed, .cancelled:
            deadlines = []
        }

        let subject = subject(for: order)
        let notes = notes(for: order, storeName: storeName)
        return deadlines.compactMap { kind, deadline in
            guard let deadline else { return nil }
            let startDate = calendar.startOfDay(for: deadline)
            guard let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) else {
                return nil
            }
            return OrderCalendarEventDraft(
                orderID: order.id,
                kind: kind,
                title: title(kind: kind, subject: subject),
                notes: notes,
                startDate: startDate,
                endDate: endDate
            )
        }
    }

    private static func subject(for order: SalesOrder) -> String {
        var names: [String] = []
        for item in order.itemList {
            let name = item.productName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty && !names.contains(name) { names.append(name) }
        }
        guard let first = names.first else {
            return String(localized: "calendar.export.subject.fallback", bundle: .tinyStockCore)
        }
        guard names.count > 1 else { return first }
        return String(
            format: String(localized: "calendar.export.subject.multiple", bundle: .tinyStockCore),
            locale: .autoupdatingCurrent,
            first,
            names.count - 1
        )
    }

    private static func title(kind: OrderCalendarEventKind, subject: String) -> String {
        let format = switch kind {
        case .production:
            String(localized: "calendar.export.production.title", bundle: .tinyStockCore)
        case .shipping:
            String(localized: "calendar.export.shipping.title", bundle: .tinyStockCore)
        }
        return String(format: format, locale: .autoupdatingCurrent, subject)
    }

    private static func notes(for order: SalesOrder, storeName: String) -> String {
        var lines = [localizedLine("calendar.export.notes.store", value: storeName)]
        if !order.buyerName.isEmpty {
            lines.append(localizedLine("calendar.export.notes.buyer", value: order.buyerName))
        }
        if !order.externalReference.isEmpty {
            lines.append(localizedLine("calendar.export.notes.reference", value: order.externalReference))
        }
        lines.append(localizedLine("calendar.export.notes.channel", value: order.channelDisplayName))
        return lines.joined(separator: "\n")
    }

    private static func localizedLine(_ key: String.LocalizationValue, value: String) -> String {
        String(
            format: String(localized: key, bundle: .tinyStockCore),
            locale: .autoupdatingCurrent,
            value
        )
    }
}
