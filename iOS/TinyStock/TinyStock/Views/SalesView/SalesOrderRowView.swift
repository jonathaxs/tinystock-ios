// Proposito: Resumir um pedido na fila operacional.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-03.

import SwiftUI
import TinyStockCore

struct SalesOrderRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.calendar) private var calendar
    let order: SalesOrder
    var selectedDate: Date? = nil
    var now: Date = Date()

    private var deadlineTitles: [String] {
        guard let selectedDate else { return [SalesOrderPresentation.deadlineTitle(for: order)] }
        return SalesOrderSchedule.entries(for: order)
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .map { SalesOrderPresentation.calendarTitle(for: $0) }
    }

    private var firstItem: SalesOrderItem? { order.itemList.first }
    private var title: String {
        guard let firstItem else { return String(localized: "order.queue.untitled", bundle: .tinyStockCore) }
        guard order.itemList.count > 1 else { return firstItem.productName }
        return String(
            format: String(localized: "order.queue.moreItems", bundle: .tinyStockCore),
            firstItem.productName, (order.itemList.count - 1).formatted()
        )
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    mainInformation
                    financialInformation
                }
            } else {
                HStack(spacing: 12) {
                    mainInformation
                    Spacer(minLength: 8)
                    financialInformation
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    private var mainInformation: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
            if let firstItem {
                Text(itemMetadata(firstItem))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            ForEach(Array(deadlineTitles.enumerated()), id: \.offset) { _, title in
                Label(title, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if SalesOrderSchedule.isOverdue(order, now: now, calendar: calendar) {
                Label(String(localized: "order.calendar.overdueBadge", bundle: .tinyStockCore), systemImage: "exclamationmark.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
    }

    private func itemMetadata(_ item: SalesOrderItem) -> String {
        if item.variantName.isEmpty {
            let format = String(localized: "order.queue.quantityMetadata", bundle: .tinyStockCore)
            return String(format: format, order.totalQuantity.formatted())
        }
        let format = String(localized: "order.queue.itemMetadata", bundle: .tinyStockCore)
        return String(format: format, item.variantName, order.totalQuantity.formatted())
    }

    private var financialInformation: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 3) {
            Text(order.total.currencyText).fontWeight(.semibold)
            Text(order.buyerName.isEmpty ? order.channelDisplayName : order.buyerName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}
