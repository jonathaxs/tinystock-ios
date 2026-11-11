// Proposito: Mostrar resultados por periodo e a operacao atual da loja selecionada.
// Created by Jonathas Motta (@jonathaxs) on 2026-08-07.

import SwiftUI
import SwiftData
import TinyStockCore

struct ReportsView: View {
    @Environment(\.calendar) private var calendar
    private let storeID: UUID
    private let openCalendar: (CalendarOrderFilter) -> Void
    @Query private var orders: [SalesOrder]

    @State private var selectedPeriod: SalesReportPeriod = .currentMonth
    @State private var usesCustomPeriod = false
    @State private var customStart = Date()
    @State private var customEnd = Date()
    @State private var showsCustomPeriod = false

    init(storeID: UUID, openCalendar: @escaping (CalendarOrderFilter) -> Void = { _ in }) {
        self.storeID = storeID
        self.openCalendar = openCalendar
        _orders = Query(
            filter: #Predicate<SalesOrder> { $0.storeID == storeID },
            sort: \SalesOrder.orderedAt,
            order: .reverse
        )
    }

    private var reportRange: SalesOrderReportRange {
        usesCustomPeriod
            ? .custom(start: customStart, end: customEnd)
            : .preset(selectedPeriod)
    }

    private var periodTitle: String {
        guard usesCustomPeriod else { return selectedPeriod.localizedName }
        let start = customStart.formatted(date: .abbreviated, time: .omitted)
        let end = customEnd.formatted(date: .abbreviated, time: .omitted)
        return "\(start) - \(end)"
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            reportBody(now: context.date)
        }
        .navigationTitle(String(localized: "tab.reports", bundle: .tinyStockCore))
        .sheet(isPresented: $showsCustomPeriod) {
            ReportCustomPeriodView(initialStart: customStart, initialEnd: customEnd) { start, end in
                customStart = start
                customEnd = end
                usesCustomPeriod = true
            }
        }
        .onChange(of: storeID) { _, _ in
            selectedPeriod = .currentMonth
            usesCustomPeriod = false
            customStart = Date()
            customEnd = Date()
        }
    }

    private func reportBody(now: Date) -> some View {
        let summary = SalesOrderReportSummary(
            orders: orders,
            storeID: storeID,
            range: reportRange,
            reference: now,
            calendar: calendar
        )
        return Group {
            if orders.isEmpty {
                noDataState
            } else {
                VStack(spacing: 0) {
                    periodMenu
                    ReportsContentView(summary: summary, openCalendar: openCalendar)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var periodMenu: some View {
        AppMenuRow(
            systemName: "calendar",
            title: String(localized: "reports.period.label", bundle: .tinyStockCore),
            value: periodTitle
        ) {
            Picker(String(localized: "reports.period.label", bundle: .tinyStockCore), selection: presetSelection) {
                ForEach(SalesReportPeriod.allCases) { period in
                    Text(period.localizedName).tag(Optional(period))
                }
            }
            .pickerStyle(.inline)
            Divider()
            Button {
                showsCustomPeriod = true
            } label: {
                if usesCustomPeriod {
                    Label(String(localized: "reports.period.custom", bundle: .tinyStockCore), systemImage: "checkmark")
                } else {
                    Text(String(localized: "reports.period.custom", bundle: .tinyStockCore))
                }
            }
        }
        .padding(.horizontal, AppStyle.horizontalPadding)
        .padding(.vertical, 8)
    }

    /// Periodo pronto escolhido no menu; nil quando o periodo personalizado esta ativo.
    private var presetSelection: Binding<SalesReportPeriod?> {
        Binding(
            get: { usesCustomPeriod ? nil : selectedPeriod },
            set: { period in
                guard let period else { return }
                selectedPeriod = period
                usesCustomPeriod = false
            }
        )
    }

    private var noDataState: some View {
        ContentUnavailableView {
            Label(String(localized: "reports.placeholder.title", bundle: .tinyStockCore), systemImage: "chart.bar")
        } description: {
            Text(String(localized: "reports.placeholder.message", bundle: .tinyStockCore))
        }
    }

}

#Preview {
    let storeID = UUID()
    NavigationStack { ReportsView(storeID: storeID) }
        .environment(StoreSession(selectedStoreID: storeID))
        .modelContainer(for: [StoreProfile.self, Product.self, ProductVariant.self, StockMovement.self, SalesOrder.self, SalesOrderItem.self], inMemory: true)
}
