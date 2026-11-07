// ⌘
//  TinyStock/Views/ReportsView/ReportDayRowView.swift
//
//  Propósito: Detalhar o total e o lucro de um dia dentro do relatório.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-15.
// ⌘

import SwiftUI
import TinyStockCore

struct ReportDayRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let group: SalesOrderReportDay

    private var salesCountText: String {
        if group.totals.orderCount == 1 {
            return String(
                format: String(localized: "reports.count.orders.one", bundle: .tinyStockCore),
                group.totals.orderCount
            )
        }

        return String(
            format: String(localized: "reports.count.orders.other", bundle: .tinyStockCore),
            group.totals.orderCount
        )
    }

    private var profitText: String {
        String(
            format: String(localized: "reports.daily.profit", bundle: .tinyStockCore),
            group.totals.netProfit.currencyText
        )
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    dayInformation
                    financialInformation
                }
            } else {
                HStack(spacing: 12) {
                    dayInformation

                    Spacer(minLength: 12)

                    financialInformation
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    private var dayInformation: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.day.formatted(date: .abbreviated, time: .omitted))
                .font(.headline)

            Text(salesCountText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var financialInformation: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
            Text(group.totals.revenue.currencyText)
                .font(.headline)
                .monospacedDigit()
                .accessibilityLabel(
                    String(localized: "reports.metric.revenue", bundle: .tinyStockCore)
                )
                .accessibilityValue(group.totals.revenue.currencyText)

            Text(profitText)
                .font(.subheadline)
                .foregroundStyle(group.totals.netProfit < 0 ? Color.red : Color.secondary)
                .monospacedDigit()
                .accessibilityLabel(
                    String(localized: "reports.metric.netProfit", bundle: .tinyStockCore)
                )
                .accessibilityValue(group.totals.netProfit.currencyText)
        }
    }
}
