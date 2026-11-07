// Proposito: Agrupar e ordenar os pedidos exibidos na fila operacional.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-17.

import Foundation
import TinyStockCore

struct SalesOrderQueueSection: Identifiable {
    let id: String
    let title: String
    let orders: [SalesOrder]

    static func make(from orders: [SalesOrder]) -> [SalesOrderQueueSection] {
        var result = SalesOrderStatus.allCases.compactMap { status in
            makeSection(for: status, from: orders)
        }
        let unknown = orders.filter { $0.status == nil }

        if !unknown.isEmpty {
            result.append(
                SalesOrderQueueSection(
                    id: "unknown",
                    title: String(localized: "order.queue.unknown", bundle: .tinyStockCore),
                    orders: sorted(unknown, terminal: false)
                )
            )
        }
        return result
    }

    private static func makeSection(
        for status: SalesOrderStatus,
        from orders: [SalesOrder]
    ) -> SalesOrderQueueSection? {
        let matches = orders.filter { $0.status == status }
        guard !matches.isEmpty else { return nil }

        return SalesOrderQueueSection(
            id: status.rawValue,
            title: status.localizedName,
            orders: sorted(matches, terminal: status.isTerminal)
        )
    }

    private static func sorted(_ orders: [SalesOrder], terminal: Bool) -> [SalesOrder] {
        orders.sorted {
            let left = SalesOrderPresentation.queueDate(for: $0)
            let right = SalesOrderPresentation.queueDate(for: $1)
            if left == right { return $0.id.uuidString < $1.id.uuidString }
            return terminal ? left > right : left < right
        }
    }
}
