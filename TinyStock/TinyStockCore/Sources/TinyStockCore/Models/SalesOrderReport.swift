// Proposito: Resumir pedidos por loja, separando vendas do periodo e pendencias atuais.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-05.

import Foundation

public enum SalesOrderReportRange: Equatable, Sendable {
    case preset(SalesReportPeriod)
    /// As duas datas escolhidas representam dias inteiros, inclusive o ultimo dia.
    case custom(start: Date, end: Date)

    public func dateInterval(relativeTo reference: Date = Date(), calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .preset(let period):
            return period.dateInterval(relativeTo: reference, calendar: calendar)
        case .custom(let start, let end):
            guard start.timeIntervalSinceReferenceDate.isFinite,
                  end.timeIntervalSinceReferenceDate.isFinite else { return nil }
            let firstDay = calendar.startOfDay(for: start)
            let lastDay = calendar.startOfDay(for: end)
            guard firstDay <= lastDay,
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: lastDay) else { return nil }
            return DateInterval(start: firstDay, end: nextDay)
        }
    }

    /// Intervalos invertidos nao viram "todo o historico". O limite final e exclusivo.
    public func contains(_ date: Date, relativeTo reference: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard date.timeIntervalSinceReferenceDate.isFinite else { return false }
        guard let interval = dateInterval(relativeTo: reference, calendar: calendar) else {
            return self == .preset(.allTime)
        }
        return date >= interval.start && date < interval.end
    }
}

/// Valores independentes do contexto do SwiftData. Recriar o resumo apos uma alteracao de pedido.
public struct SalesOrderReportTotals: Equatable, Sendable {
    public let orderIDs: [UUID]
    public let unitCount: Decimal
    public let revenue: Decimal
    public let cost: Decimal
    public let channelFees: Decimal

    public var orderCount: Int { orderIDs.count }
    public var grossProfit: Decimal { revenue - cost }
    public var netProfit: Decimal { grossProfit - channelFees }
    public var isEmpty: Bool { orderIDs.isEmpty }

    fileprivate init(orders: [SalesOrder]) {
        orderIDs = orders.map(\.id)
        unitCount = orders.reduce(0) { $0 + $1.totalQuantity }
        revenue = orders.reduce(0) { $0 + $1.total }
        cost = orders.reduce(0) { $0 + $1.totalCost }
        // O valor salvo pode incluir arredondamento. Nao recalcular usando a porcentagem.
        channelFees = orders.reduce(0) { $0 + $1.channelFeeAmount }
    }
}

public struct SalesOrderReportQueue: Equatable, Sendable {
    public let orderIDs: [UUID]
    public let unitCount: Decimal
    public var orderCount: Int { orderIDs.count }

    fileprivate init(orders: [SalesOrder]) {
        orderIDs = orders.map(\.id)
        unitCount = orders.reduce(0) { $0 + $1.totalQuantity }
    }
}

/// Filas atuais da loja inteira, sem o recorte financeiro. Atrasados se sobrepoem as outras filas.
public struct SalesOrderOperationalSummary: Equatable, Sendable {
    public let newOrders: SalesOrderReportQueue
    public let awaitingProduction: SalesOrderReportQueue
    public let inProduction: SalesOrderReportQueue
    public let toProduce: SalesOrderReportQueue
    public let readyToShip: SalesOrderReportQueue
    public let shipped: SalesOrderReportQueue
    public let overdue: SalesOrderReportQueue
    public let unknownStatus: SalesOrderReportQueue

    fileprivate init(orders: [SalesOrder], reference: Date, calendar: Calendar) {
        newOrders = .init(orders: orders.filter { $0.status == .new })
        awaitingProduction = .init(orders: orders.filter { $0.status == .awaitingProduction })
        inProduction = .init(orders: orders.filter { $0.status == .inProduction })
        toProduce = .init(orders: orders.filter { $0.status == .awaitingProduction || $0.status == .inProduction })
        readyToShip = .init(orders: orders.filter { $0.status == .readyToShip })
        shipped = .init(orders: orders.filter { $0.status == .shipped })
        overdue = .init(orders: orders.filter { SalesOrderSchedule.isOverdue($0, now: reference, calendar: calendar) })
        unknownStatus = .init(orders: orders.filter { $0.status == nil })
    }
}

public struct SalesOrderReportDay: Identifiable, Equatable, Sendable {
    public let day: Date
    public let totals: SalesOrderReportTotals
    public var id: Date { day }
}

/// Variacoes do mesmo produto sao somadas pelo ID, nunca pelo nome ou pelo catalogo atual.
public struct SalesOrderProductRanking: Identifiable, Equatable, Sendable {
    public let productID: UUID
    public let productName: String
    public let quantity: Decimal
    public let revenue: Decimal
    public let cost: Decimal
    public var id: UUID { productID }
    // Taxas pertencem ao pedido; nao ha rateio arbitrario de lucro liquido por produto.
    public var grossProfit: Decimal { revenue - cost }

    public init(productID: UUID, productName: String, quantity: Decimal, revenue: Decimal, cost: Decimal) {
        self.productID = productID
        self.productName = productName
        self.quantity = quantity
        self.revenue = revenue
        self.cost = cost
    }
}

public struct SalesOrderChannelSummary: Identifiable, Equatable, Sendable {
    public struct ID: Hashable, Sendable {
        public let rawValue: String
        public let customName: String
    }

    public let id: ID
    public let totals: SalesOrderReportTotals

    public var displayName: String {
        guard let channel = SalesChannel(rawValue: id.rawValue) else {
            return String(localized: "order.channel.unknown", bundle: .tinyStockCore)
        }
        return channel == .other && !id.customName.isEmpty ? id.customName : channel.localizedName
    }
}

/// Retrato calculado com os estados atuais, nao uma reconstrucao contabil no passado.
/// Recebidos usam orderedAt; despachados usam shippedAt, mesmo quando ja concluidos.
/// Cancelados e estados desconhecidos nao compoem totais financeiros nem rankings.
/// Faturamento de pedidos nao comprova recebimento de dinheiro do marketplace.
public struct SalesOrderReportSummary: Sendable {
    public let storeID: UUID
    public let range: SalesOrderReportRange
    public let received: SalesOrderReportTotals
    public let dispatched: SalesOrderReportTotals
    public let completed: SalesOrderReportQueue
    public let cancelled: SalesOrderReportQueue
    public let operations: SalesOrderOperationalSummary
    public let dayGroups: [SalesOrderReportDay]
    public let channelGroups: [SalesOrderChannelSummary]
    private let productRankings: [SalesOrderProductRanking]

    public init(
        orders: [SalesOrder],
        storeID: UUID,
        range: SalesOrderReportRange,
        reference: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.storeID = storeID
        self.range = range
        // Defesa adicional mesmo quando a view ja usa @Query com filtro de loja.
        let scoped = orders.filter { $0.storeID == storeID }.sorted {
            $0.orderedAt == $1.orderedAt ? $0.id.uuidString < $1.id.uuidString : $0.orderedAt > $1.orderedAt
        }
        func inRange(_ date: Date?) -> Bool {
            guard let date else { return false }
            return range.contains(date, relativeTo: reference, calendar: calendar)
        }

        let valid = scoped.filter { $0.status != nil && $0.status != .cancelled }
        let receivedOrders = valid.filter { inRange($0.orderedAt) }
        received = .init(orders: receivedOrders)
        dispatched = .init(orders: valid.filter {
            ($0.status == .shipped || $0.status == .completed) && inRange($0.shippedAt)
        })
        // Uma data efetiva ausente nao e substituida por updatedAt ou por prazo planejado.
        completed = .init(orders: scoped.filter { $0.status == .completed && inRange($0.completedAt) })
        cancelled = .init(orders: scoped.filter { $0.status == .cancelled && inRange($0.cancelledAt) })
        operations = .init(orders: scoped, reference: reference, calendar: calendar)

        dayGroups = Dictionary(grouping: receivedOrders) { calendar.startOfDay(for: $0.orderedAt) }
            .map { SalesOrderReportDay(day: $0.key, totals: .init(orders: $0.value)) }
            .sorted { $0.day > $1.day }
        channelGroups = Dictionary(grouping: receivedOrders) { order in
            SalesOrderChannelSummary.ID(
                rawValue: order.channelRawValue,
                customName: order.channel == .other
                    ? order.customChannelName.trimmingCharacters(in: .whitespacesAndNewlines) : ""
            )
        }
        .map { SalesOrderChannelSummary(id: $0.key, totals: .init(orders: $0.value)) }
        .sorted {
            if $0.totals.revenue != $1.totals.revenue { return $0.totals.revenue > $1.totals.revenue }
            if $0.id.rawValue != $1.id.rawValue { return $0.id.rawValue < $1.id.rawValue }
            return $0.id.customName < $1.id.customName
        }

        var rankings: [UUID: SalesOrderProductRanking] = [:]
        for order in receivedOrders {
            for item in order.itemList {
                let current = rankings[item.productID]
                // A ordem cronologica mantem o nome do retrato mais recente, inclusive em empates.
                rankings[item.productID] = .init(
                    productID: item.productID, productName: current?.productName ?? item.productName,
                    quantity: (current?.quantity ?? 0) + Decimal(item.quantity),
                    revenue: (current?.revenue ?? 0) + item.subtotal,
                    cost: (current?.cost ?? 0) + item.subtotalCost
                )
            }
        }
        productRankings = rankings.values.sorted {
            if $0.quantity != $1.quantity { return $0.quantity > $1.quantity }
            if $0.revenue != $1.revenue { return $0.revenue > $1.revenue }
            let comparison = $0.productName.localizedStandardCompare($1.productName)
            if comparison != .orderedSame { return comparison == .orderedAscending }
            return $0.productID.uuidString < $1.productID.uuidString
        }
    }

    public func bestSellingProducts(limit: Int = 3) -> [SalesOrderProductRanking] {
        guard limit > 0 else { return [] }
        return Array(productRankings.prefix(limit))
    }
}
