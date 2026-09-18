// Proposito: Exibir faturamento e lucro dos pedidos recebidos por canal.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-06.

import SwiftUI
import TinyStockCore

struct ReportChannelRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let channel: SalesOrderChannelSummary

    private var countText: String {
        channel.totals.orderCount == 1
            ? String(format: String(localized: "reports.count.orders.one", bundle: .tinyStockCore), channel.totals.orderCount)
            : String(format: String(localized: "reports.count.orders.other", bundle: .tinyStockCore), channel.totals.orderCount)
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    channelInformation
                    financialInformation
                }
            } else {
                HStack(spacing: 12) {
                    channelInformation
                    Spacer(minLength: 12)
                    financialInformation.multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    private var channelInformation: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(channel.displayName).font(.headline)
            Text(countText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var financialInformation: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
            Text(channel.totals.revenue.currencyText)
                .font(.headline)
                .monospacedDigit()
                .accessibilityLabel(
                    String(localized: "reports.metric.revenue", bundle: .tinyStockCore)
                )
                .accessibilityValue(channel.totals.revenue.currencyText)
            Text(channel.totals.netProfit.currencyText)
                .font(.subheadline)
                .foregroundStyle(channel.totals.netProfit < 0 ? Color.red : Color.secondary)
                .monospacedDigit()
                .accessibilityLabel(
                    String(localized: "reports.metric.netProfit", bundle: .tinyStockCore)
                )
                .accessibilityValue(channel.totals.netProfit.currencyText)
        }
    }
}
