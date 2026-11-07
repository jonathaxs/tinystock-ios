// ⌘
//  TinyStockCore/Models/SalesReport.swift
//
//  Propósito: Calcular o resumo financeiro das vendas dentro de um período.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-15.
// ⌘

import Foundation

// MARK: - Período do relatório

/// Recortes de tempo rápidos para acompanhar o negócio sem precisar escolher datas manualmente.
public enum SalesReportPeriod: String, CaseIterable, Identifiable, Sendable {
    case today
    case lastSevenDays
    case currentMonth
    case allTime

    public var id: String { rawValue }

    /// Nome curto para permanecer legível no controle segmentado.
    public var localizedName: String {
        switch self {
        case .today:
            String(localized: "reports.period.today", bundle: .tinyStockCore)
        case .lastSevenDays:
            String(localized: "reports.period.sevenDays", bundle: .tinyStockCore)
        case .currentMonth:
            String(localized: "reports.period.month", bundle: .tinyStockCore)
        case .allTime:
            String(localized: "reports.period.all", bundle: .tinyStockCore)
        }
    }

    /// Intervalo fechado no início e aberto no fim. Assim uma venda exatamente à meia-noite
    /// entra no dia novo, sem ser contada duas vezes em períodos vizinhos.
    public func dateInterval(
        relativeTo reference: Date = Date(),
        calendar: Calendar = .current
    ) -> DateInterval? {
        switch self {
        case .today:
            let start = calendar.startOfDay(for: reference)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
            return DateInterval(start: start, end: end)

        case .lastSevenDays:
            let today = calendar.startOfDay(for: reference)
            guard
                let start = calendar.date(byAdding: .day, value: -6, to: today),
                let end = calendar.date(byAdding: .day, value: 1, to: today)
            else { return nil }
            return DateInterval(start: start, end: end)

        case .currentMonth:
            return calendar.dateInterval(of: .month, for: reference)

        case .allTime:
            return nil
        }
    }

    public func contains(
        _ date: Date,
        relativeTo reference: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let interval = dateInterval(relativeTo: reference, calendar: calendar) else {
            return self == .allTime
        }

        return date >= interval.start && date < interval.end
    }
}

// MARK: - Resumo financeiro

/// Vendas filtradas e somadas para a tela de relatórios.
///
/// Não é `Sendable` porque carrega models vinculados ao contexto do SwiftData.
public struct SalesReportSummary {
    public let period: SalesReportPeriod
    public let sales: [Sale]
    public let dayGroups: [SaleDayGroup]

    public init(
        sales: [Sale],
        period: SalesReportPeriod,
        reference: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.period = period
        self.sales = sales
            .filter { period.contains($0.date, relativeTo: reference, calendar: calendar) }
            .sorted { $0.date > $1.date }
        self.dayGroups = SaleDayGroup.groups(from: self.sales, calendar: calendar)
    }

    public var isEmpty: Bool { sales.isEmpty }

    /// Receita bruta, antes de descontar custo ou taxa do canal.
    public var revenue: Decimal {
        sales.reduce(0) { $0 + $1.total }
    }

    /// Lucro líquido, usando custos e taxas guardados no retrato de cada venda.
    public var profit: Decimal {
        sales.reduce(0) { $0 + $1.profit }
    }

    public var saleCount: Int { sales.count }

    public var unitCount: Int {
        sales.reduce(0) { $0 + $1.totalQuantity }
    }

    /// Produtos com mais unidades vendidas dentro do periodo selecionado.
    ///
    /// O agrupamento usa o identificador salvo no item da venda. O nome vem do retrato mais
    /// recente, entao editar ou excluir o produto atual nao apaga a historia do relatorio.
    public func bestSellingProducts(limit: Int = 3) -> [ProductSalesRanking] {
        guard limit > 0 else { return [] }

        var rankings: [UUID: ProductSalesRanking] = [:]

        for sale in sales {
            for item in sale.itemList {
                let current = rankings[item.productID]
                rankings[item.productID] = ProductSalesRanking(
                    productID: item.productID,
                    productName: current?.productName ?? item.productName,
                    quantity: (current?.quantity ?? 0) + item.quantity,
                    revenue: (current?.revenue ?? 0) + item.subtotal
                )
            }
        }

        return rankings.values
            .sorted {
                if $0.quantity != $1.quantity {
                    return $0.quantity > $1.quantity
                }

                if $0.revenue != $1.revenue {
                    return $0.revenue > $1.revenue
                }

                return $0.productName.localizedStandardCompare($1.productName) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - Produtos mais vendidos

/// Retrato agregado de um produto no ranking do periodo.
public struct ProductSalesRanking: Identifiable, Equatable, Sendable {
    public let productID: UUID
    public let productName: String
    public let quantity: Int
    public let revenue: Decimal

    public var id: UUID { productID }

    public init(
        productID: UUID,
        productName: String,
        quantity: Int,
        revenue: Decimal
    ) {
        self.productID = productID
        self.productName = productName
        self.quantity = quantity
        self.revenue = revenue
    }
}
