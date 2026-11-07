// Proposito: Apresentar as secoes calculadas do relatorio da loja selecionada.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-17.

import SwiftUI
import TinyStockCore

struct ReportsContentView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let summary: SalesOrderReportSummary
    let openCalendar: (CalendarOrderFilter) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                operationSection(summary.operations)

                if summary.received.isEmpty {
                    emptyPeriodState
                } else {
                    receivedSection(summary.received)
                    bestSellersSection(summary.bestSellingProducts())
                    channelsSection(summary.channelGroups)
                    dailySection(summary.dayGroups)
                }

                activitySection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private func receivedSection(_ totals: SalesOrderReportTotals) -> some View {
        reportSection(title: String(localized: "reports.received.title", bundle: .tinyStockCore)) {
            LazyVGrid(columns: metricColumns, spacing: 12) {
                ReportMetricView(
                    title: String(localized: "reports.metric.revenue", bundle: .tinyStockCore),
                    value: totals.revenue.currencyText,
                    symbolName: "brazilianrealsign",
                    tint: .green
                )
                ReportMetricView(
                    title: String(localized: "reports.metric.netProfit", bundle: .tinyStockCore),
                    value: totals.netProfit.currencyText,
                    symbolName: "chart.line.uptrend.xyaxis",
                    tint: totals.netProfit < 0 ? .red : .blue
                )
                ReportMetricView(
                    title: String(localized: "reports.metric.orders", bundle: .tinyStockCore),
                    value: totals.orderCount.formatted(),
                    symbolName: "cart.fill",
                    tint: .orange
                )
                ReportMetricView(
                    title: String(localized: "reports.metric.units", bundle: .tinyStockCore),
                    value: totals.unitCount.formatted(.number.precision(.fractionLength(0))),
                    symbolName: "shippingbox.fill",
                    tint: .teal
                )
                ReportMetricView(
                    title: String(localized: "reports.metric.cost", bundle: .tinyStockCore),
                    value: totals.cost.currencyText,
                    symbolName: "wrench.and.screwdriver.fill",
                    tint: .indigo
                )
                ReportMetricView(
                    title: String(localized: "reports.metric.fees", bundle: .tinyStockCore),
                    value: totals.channelFees.currencyText,
                    symbolName: "percent",
                    tint: .pink
                )
            }
        }
    }

    private var activitySection: some View {
        reportSection(title: String(localized: "reports.activity.title", bundle: .tinyStockCore)) {
            VStack(spacing: 0) {
                ReportCountRowView(
                    title: String(localized: "reports.activity.dispatched", bundle: .tinyStockCore),
                    count: summary.dispatched.orderCount,
                    symbolName: "paperplane.fill",
                    tint: .blue
                )
                rowDivider
                ReportCountRowView(
                    title: String(localized: "reports.activity.completed", bundle: .tinyStockCore),
                    count: summary.completed.orderCount,
                    symbolName: "checkmark.circle.fill",
                    tint: .green
                )
                rowDivider
                ReportCountRowView(
                    title: String(localized: "reports.activity.cancelled", bundle: .tinyStockCore),
                    count: summary.cancelled.orderCount,
                    symbolName: "xmark.circle.fill",
                    tint: .red
                )
            }
            .groupedReportRows()
        }
    }

    private func operationSection(_ operations: SalesOrderOperationalSummary) -> some View {
        reportSection(title: String(localized: "reports.operation.title", bundle: .tinyStockCore)) {
            VStack(spacing: 0) {
                operationButton(
                    title: String(localized: "reports.operation.toProduce", bundle: .tinyStockCore),
                    queue: operations.toProduce,
                    symbolName: "hammer.fill",
                    tint: .orange,
                    filter: .production
                )
                rowDivider
                operationButton(
                    title: String(localized: "reports.operation.readyToShip", bundle: .tinyStockCore),
                    queue: operations.readyToShip,
                    symbolName: "shippingbox.fill",
                    tint: .blue,
                    filter: .status(.readyToShip)
                )
                rowDivider
                operationButton(
                    title: String(localized: "reports.operation.overdue", bundle: .tinyStockCore),
                    queue: operations.overdue,
                    symbolName: "exclamationmark.triangle.fill",
                    tint: .red,
                    filter: .overdue
                )
                rowDivider
                operationButton(
                    title: String(localized: "reports.operation.shipped", bundle: .tinyStockCore),
                    queue: operations.shipped,
                    symbolName: "paperplane.fill",
                    tint: .green,
                    filter: .status(.shipped)
                )
            }
            .groupedReportRows()
        }
    }

    private func operationButton(
        title: String,
        queue: SalesOrderReportQueue,
        symbolName: String,
        tint: Color,
        filter: CalendarOrderFilter
    ) -> some View {
        Button { openCalendar(filter) } label: {
            ReportOperationRowView(
                title: title,
                orderCount: queue.orderCount,
                unitCount: queue.unitCount,
                symbolName: symbolName,
                tint: tint
            )
        }
        .buttonStyle(.plain)
    }

    private var rowDivider: some View {
        Divider().padding(.leading, 52)
    }

    private func bestSellersSection(_ rankings: [SalesOrderProductRanking]) -> some View {
        reportSection(title: String(localized: "reports.bestSellers.title", bundle: .tinyStockCore)) {
            groupedRows(rankings) { index, ranking in
                BestSellingRowView(position: index + 1, ranking: ranking)
            }
        }
    }

    private func channelsSection(_ channels: [SalesOrderChannelSummary]) -> some View {
        reportSection(title: String(localized: "reports.channels.title", bundle: .tinyStockCore)) {
            groupedRows(channels) { _, channel in
                ReportChannelRowView(channel: channel)
            }
        }
    }

    private func dailySection(_ groups: [SalesOrderReportDay]) -> some View {
        reportSection(title: String(localized: "reports.daily.title", bundle: .tinyStockCore)) {
            groupedRows(groups) { _, group in
                ReportDayRowView(group: group)
            }
        }
    }

    private func reportSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }

    private func groupedRows<Item: Identifiable, Row: View>(
        _ items: [Item],
        @ViewBuilder row: @escaping (Int, Item) -> Row
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                row(index, item)
                if index < items.count - 1 {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .groupedReportRows()
    }

    private var metricColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    private var emptyPeriodState: some View {
        ContentUnavailableView {
            Label(
                String(localized: "reports.empty.period.title", bundle: .tinyStockCore),
                systemImage: "calendar.badge.exclamationmark"
            )
        } description: {
            Text(String(localized: "reports.empty.period.message", bundle: .tinyStockCore))
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}

private extension View {
    func groupedReportRows() -> some View {
        background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }
}
