// ⌘
//  TinyStock/Views/HomeView/HomeHeroView.swift
//
//  Propósito: Resumo da loja no topo da Início: a caixa do ícone com produtos, unidades em estoque e
//             pedidos em aberto por etapa, mais uma frase curta de status. Tocar na caixa explica os números.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-11-07.
// ⌘

import SwiftData
import SwiftUI
import TinyStockCore

/// Números da loja que a caixa mostra.
struct HomeSummary: Equatable {
    var products = 0
    var units = 0
    var outOfStock = 0
    var production = 0
    var readyToShip = 0
    var shipped = 0
    var overdue = 0

    var openOrders: Int { production + readyToShip + shipped }

    init() {}

    init(products: [Product], variants: [ProductVariant], orders: [SalesOrder], now: Date, calendar: Calendar) {
        self.products = products.count
        for product in products {
            let quantity = variants.filter { $0.belongs(to: product) }.reduce(0) { $0 + $1.quantity }
            units += quantity
            if quantity <= 0 { outOfStock += 1 }
        }
        for order in orders {
            guard let status = order.status else { continue }
            switch status {
            case .new:
                // Pedido recém-criado segue para produção ou envio conforme o tipo.
                if order.fulfillment == .production { production += 1 } else { readyToShip += 1 }
            case .awaitingProduction, .inProduction: production += 1
            case .readyToShip: readyToShip += 1
            case .shipped: shipped += 1
            case .completed, .cancelled: break
            }
            if SalesOrderSchedule.isOverdue(order, now: now, calendar: calendar) { overdue += 1 }
        }
    }
}

struct HomeHeroView: View {

    let products: [Product]
    let variants: [ProductVariant]

    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var orders: [SalesOrder]
    @State private var growth: CGFloat = 0
    @State private var showsInfo = false

    init(storeID: UUID, products: [Product], variants: [ProductVariant]) {
        self.products = products
        self.variants = variants
        _orders = Query(filter: #Predicate<SalesOrder> { $0.storeID == storeID })
    }

    var body: some View {
        // Recalcula atrasos quando a tela cruza a meia-noite.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let summary = HomeSummary(products: products, variants: variants, orders: orders,
                                      now: context.date, calendar: calendar)
            content(summary)
        }
    }

    private func content(_ summary: HomeSummary) -> some View {
        VStack(spacing: 6) {
            Button { showsInfo = true } label: {
                StockBoxView(
                    leftValue: summary.products,
                    leftLabel: String(localized: "home.box.products", bundle: .tinyStockCore),
                    rightValue: summary.units,
                    rightLabel: String(localized: "home.box.units", bundle: .tinyStockCore),
                    bars: bars(for: summary),
                    growth: growth
                )
            }
            .buttonStyle(.plain)
            .adaptivePopover(isPresented: $showsInfo) {
                HomeBoxInfoPopover(summary: summary, graphite: StockBoxView.graphitePalette(for: colorScheme))
            }
            .accessibilityLabel(accessibilityText(summary))
            .accessibilityHint(String(localized: "home.box.hint", bundle: .tinyStockCore))

            Text(statusText(summary))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard growth == 0 else { return }
            if reduceMotion {
                growth = 1
            } else {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15)) { growth = 1 }
            }
        }
    }

    private func bars(for summary: HomeSummary) -> [StockBoxBar] {
        [
            StockBoxBar(value: summary.production, palette: StockBoxView.tealPalette),
            StockBoxBar(value: summary.readyToShip, palette: StockBoxView.graphitePalette(for: colorScheme)),
            StockBoxBar(value: summary.shipped, palette: StockBoxView.deepTealPalette)
        ]
    }

    /// Uma frase só, do que mais pede atenção para o que menos pede.
    private func statusText(_ summary: HomeSummary) -> String {
        if summary.products == 0 {
            return String(localized: "home.status.empty", bundle: .tinyStockCore)
        }
        if summary.overdue > 0 {
            return String(format: String(localized: "home.status.overdue", bundle: .tinyStockCore), summary.overdue)
        }
        if summary.outOfStock > 0 {
            return String(format: String(localized: "home.status.outOfStock", bundle: .tinyStockCore), summary.outOfStock)
        }
        if summary.openOrders > 0 {
            return String(format: String(localized: "home.status.open", bundle: .tinyStockCore), summary.openOrders)
        }
        return String(localized: "home.status.allGood", bundle: .tinyStockCore)
    }

    private func accessibilityText(_ summary: HomeSummary) -> String {
        String(format: String(localized: "home.box.a11y", bundle: .tinyStockCore),
               summary.products, summary.units, summary.production, summary.readyToShip, summary.shipped)
    }
}

// MARK: - Balão explicativo

/// Explica cada número da caixa na mesma disposição dela: os pedidos das barras em cima e o catálogo
/// dos lados embaixo (produtos à esquerda, estoque à direita).
private struct HomeBoxInfoPopover: View {

    let summary: HomeSummary
    let graphite: StockBoxView.BarPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "home.box.info.title", bundle: .tinyStockCore))
                .font(.headline)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            AppSectionLabel(text: String(localized: "home.box.info.orders", bundle: .tinyStockCore))
            HStack(spacing: 8) {
                tile(StockBoxView.tealPalette.right, "home.box.info.production", summary.production)
                tile(graphite.right, "home.box.info.ready", summary.readyToShip)
                tile(StockBoxView.deepTealPalette.right, "home.box.info.shipped", summary.shipped)
            }

            AppSectionLabel(text: String(localized: "home.box.info.catalog", bundle: .tinyStockCore))
            HStack(spacing: 8) {
                tile(StockBoxView.leftLegend, "home.box.info.products", summary.products)
                tile(StockBoxView.rightLegend, "home.box.info.units", summary.units)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func tile(_ color: Color, _ titleKey: String, _ value: Int) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color.gradient)
                .frame(width: 22, height: 8)
                .accessibilityHidden(true)
            Text(value, format: .number)
                .font(.title2.weight(.bold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(String(localized: String.LocalizationValue(titleKey), bundle: .tinyStockCore))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
