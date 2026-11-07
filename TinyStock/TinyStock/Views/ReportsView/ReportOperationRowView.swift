// Proposito: Exibir uma fila atual e abrir seu filtro no calendario.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-06.

import SwiftUI
import TinyStockCore

struct ReportOperationRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let orderCount: Int
    let unitCount: Decimal
    let symbolName: String
    let tint: Color

    private var detail: String {
        let orders = orderCount == 1
            ? String(format: String(localized: "reports.count.orders.one", bundle: .tinyStockCore), orderCount)
            : String(format: String(localized: "reports.count.orders.other", bundle: .tinyStockCore), orderCount)
        let units = String(
            format: String(localized: "reports.count.units", bundle: .tinyStockCore),
            unitCount.formatted(.number.precision(.fractionLength(0)))
        )
        return "\(orders) · \(units)"
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        icon
                        Text(title).font(.headline)
                        Spacer(minLength: 8)
                        chevron
                    }
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 12) {
                    icon
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.headline)
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    Text(orderCount, format: .number)
                        .font(.title3.bold())
                        .monospacedDigit()
                        .accessibilityHidden(true)
                    chevron
                }
            }
        }
        .padding(16)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(String(localized: "reports.operation.openCalendar", bundle: .tinyStockCore))
    }

    private var icon: some View {
        Image(systemName: symbolName)
            .foregroundStyle(tint)
            .frame(width: 24)
            .accessibilityHidden(true)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.bold())
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}
