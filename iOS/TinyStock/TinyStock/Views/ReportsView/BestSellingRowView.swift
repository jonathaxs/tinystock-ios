// ⌘
//  TinyStock/Views/ReportsView/BestSellingRowView.swift
//
//  Propósito: Exibir a posição e o desempenho de um produto no ranking de vendas.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-15.
// ⌘

import SwiftUI
import TinyStockCore

struct BestSellingRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let position: Int
    let ranking: SalesOrderProductRanking

    private var unitsText: String {
        if ranking.quantity == 1 {
            return String(
                format: String(localized: "reports.bestSellers.units.one", bundle: .tinyStockCore),
                ranking.quantity.formatted(.number.precision(.fractionLength(0)))
            )
        }

        return String(
            format: String(localized: "reports.bestSellers.units.other", bundle: .tinyStockCore),
            ranking.quantity.formatted(.number.precision(.fractionLength(0)))
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(position, format: .number)
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(minWidth: 24)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    productInformation
                    revenue
                }
            } else {
                productInformation

                Spacer(minLength: 12)

                revenue
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    private var productInformation: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ranking.productName)
                .font(.headline)

            Text(unitsText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var revenue: some View {
        Text(ranking.revenue.currencyText)
            .font(.headline)
            .monospacedDigit()
            .accessibilityLabel(
                String(localized: "reports.metric.revenue", bundle: .tinyStockCore)
            )
            .accessibilityValue(ranking.revenue.currencyText)
    }
}

#Preview {
    BestSellingRowView(
        position: 1,
        ranking: SalesOrderProductRanking(
            productID: UUID(),
            productName: "Produto popular",
            quantity: 12,
            revenue: 540,
            cost: 240
        )
    )
    .padding()
}
