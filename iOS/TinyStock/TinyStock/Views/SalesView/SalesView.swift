// Proposito: Exibir o calendario e a fila operacional de pedidos da loja selecionada.
// Created by Jonathas Motta (@jonathaxs) on 2026-08-07.

import SwiftUI
import SwiftData
import TinyStockCore

struct SalesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    private let storeID: UUID
    @Query private var orders: [SalesOrder]
    @Binding private var filterRequest: CalendarOrderFilter?
    @Binding private var reminderRoute: OrderReminderRoute?
    @State private var pendingCancellation: SalesOrder?
    @State private var cancellationReason = ""
    @State private var errorMessage: String?
    @AppStorage("orders.displayMode") private var displayMode: OrderDisplayMode = .day
    @State private var selectedDate = Date()
    @State private var filter: CalendarOrderFilter = .all

    init(
        storeID: UUID, filterRequest: Binding<CalendarOrderFilter?> = .constant(nil),
        reminderRoute: Binding<OrderReminderRoute?> = .constant(nil)
    ) {
        self.storeID = storeID
        _filterRequest = filterRequest
        _reminderRoute = reminderRoute
        _orders = Query(
            filter: #Predicate<SalesOrder> { $0.storeID == storeID },
            sort: \SalesOrder.orderedAt,
            order: .reverse
        )
    }

    private func filteredOrders(now: Date) -> [SalesOrder] {
        orders.filter { order in
            filter.includes(order, now: now, calendar: calendar)
        }
    }

    var body: some View {
        NavigationStack {
            // Recalcula atrasos e o destaque de hoje quando a tela cruza a meia-noite.
            TimelineView(.periodic(from: .now, by: 60)) { context in
                orderList(now: context.date)
            }
            .navigationTitle(String(localized: "tab.sales", bundle: .tinyStockCore))
            .navigationDestination(item: scopedReminderRoute) { route in
                ReminderOrderDestination(route: route)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { StoreSwitcherView() }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker(String(localized: "order.calendar.filter", bundle: .tinyStockCore), selection: $filter) {
                            Text(String(localized: "order.calendar.allStatuses", bundle: .tinyStockCore)).tag(CalendarOrderFilter.all)
                            Text(String(localized: "order.calendar.overdue", bundle: .tinyStockCore)).tag(CalendarOrderFilter.overdue)
                            Text(String(localized: "reports.operation.toProduce", bundle: .tinyStockCore)).tag(CalendarOrderFilter.production)
                            ForEach(SalesOrderStatus.allCases, id: \.self) { status in
                                Text(status.localizedName).tag(CalendarOrderFilter.status(status))
                            }
                        }
                    } label: {
                        Label(String(localized: "order.calendar.filter", bundle: .tinyStockCore),
                              systemImage: filter == .all ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
            .alert(String(localized: "order.cancel.title", bundle: .tinyStockCore), isPresented: Binding(
                get: { pendingCancellation != nil },
                set: { if !$0 { clearCancellation() } }
            )) {
                TextField(String(localized: "order.cancel.reason", bundle: .tinyStockCore), text: $cancellationReason)
                Button(String(localized: "common.cancel", bundle: .tinyStockCore), role: .cancel, action: clearCancellation)
                Button(String(localized: "order.action.cancel", bundle: .tinyStockCore), role: .destructive, action: cancelOrder)
            } message: {
                Text(String(localized: "order.cancel.message", bundle: .tinyStockCore))
            }
            .alert(String(localized: "order.operation.error.title", bundle: .tinyStockCore), isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button(String(localized: "common.ok", bundle: .tinyStockCore)) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .onChange(of: storeID) { _, _ in
            clearCancellation()
            errorMessage = nil
            filter = .all
            selectedDate = Date()
        }
        .onChange(of: filter) { _, newValue in
            // Atrasados costuma envolver dias anteriores ao selecionado no calendario.
            if newValue == .overdue { displayMode = .list }
        }
        .onChange(of: filterRequest, initial: true) { _, request in
            guard let request else { return }
            filter = request
            displayMode = .list
            selectedDate = Date()
            // A solicitacao e consumida para que o mesmo atalho funcione novamente depois.
            filterRequest = nil
        }
    }

    private var scopedReminderRoute: Binding<OrderReminderRoute?> {
        Binding(
            get: { reminderRoute?.storeID == storeID ? reminderRoute : nil },
            set: { route in
                // Uma pilha sendo removida nao pode limpar o destino da nova loja.
                if route != nil || reminderRoute?.storeID == storeID { reminderRoute = route }
            }
        )
    }

    private func orderList(now: Date) -> some View {
        let filtered = filteredOrders(now: now)
        let visible = displayMode == .day
            ? SalesOrderSchedule.orders(on: selectedDate, from: filtered, calendar: calendar) : filtered
        let sections = SalesOrderQueueSection.make(from: visible)
        return List {
            Section {
                Picker(String(localized: "order.calendar.mode", bundle: .tinyStockCore), selection: $displayMode) {
                    Text(String(localized: "order.calendar.day", bundle: .tinyStockCore)).tag(OrderDisplayMode.day)
                    Text(String(localized: "order.calendar.list", bundle: .tinyStockCore)).tag(OrderDisplayMode.list)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                if displayMode == .day {
                    SalesOrderCalendarView(
                        selectedDate: $selectedDate,
                        countsByDay: SalesOrderSchedule.countsByDay(from: filtered, calendar: calendar)
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            Section {
                if visible.isEmpty {
                    if orders.isEmpty {
                        emptyState
                    } else {
                        ContentUnavailableView(
                            String(localized: "order.calendar.empty", bundle: .tinyStockCore),
                            systemImage: "calendar"
                        )
                    }
                }
            } header: {
                HStack {
                    Spacer()

                    VStack(spacing: 4) {
                        if displayMode == .day {
                            Text(selectedDate, format: .dateTime.weekday(.wide).day().month(.wide).year())
                        }
                        Text(filter.title)
                    }
                    .multilineTextAlignment(.center)

                    Spacer()
                }
                .font(.subheadline)
                .textCase(nil)
                .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(sections) { section in
                Section {
                    ForEach(section.orders) { order in
                        NavigationLink {
                            SalesOrderDetailView(order: order)
                        } label: {
                            SalesOrderRowView(
                                order: order,
                                selectedDate: displayMode == .day ? selectedDate : nil,
                                now: now
                            )
                        }
                        .accessibilityHint(String(localized: "order.detail.open.hint", bundle: .tinyStockCore))
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if let action = SalesOrderPresentation.quickAction(for: order) {
                                Button { transition(order, to: action.status) } label: {
                                    Label(action.title, systemImage: action.systemImage)
                                }
                                .tint(action.tint)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if SalesOrderPresentation.canCancel(order) {
                                Button(role: .destructive) { pendingCancellation = order } label: {
                                    Label(String(localized: "order.action.cancel", bundle: .tinyStockCore), systemImage: "xmark")
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(section.title)
                        Spacer()
                        Text(section.orders.count, format: .number)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(String(localized: "order.queue.empty.title", bundle: .tinyStockCore), systemImage: "calendar.badge.clock")
        } description: {
            Text(String(localized: "order.queue.empty.message", bundle: .tinyStockCore))
        }
    }

    private func transition(_ order: SalesOrder, to status: SalesOrderStatus) {
        do {
            try SalesOrderService.transition(id: order.id, to: status, in: modelContext)
        } catch {
            errorMessage = SalesOrderPresentation.message(for: error)
        }
    }

    private func cancelOrder() {
        guard let order = pendingCancellation else { return }
        do {
            try SalesOrderService.cancel(id: order.id, reason: cancellationReason, in: modelContext)
            clearCancellation()
        } catch {
            clearCancellation()
            errorMessage = SalesOrderPresentation.message(for: error)
        }
    }

    private func clearCancellation() {
        pendingCancellation = nil
        cancellationReason = ""
    }
}

private enum OrderDisplayMode: String {
    case day, list
}

#Preview {
    let storeID = UUID()
    SalesView(storeID: storeID)
        .environment(StoreSession(selectedStoreID: storeID))
        .modelContainer(for: [StoreProfile.self, Product.self, ProductVariant.self, StockMovement.self, SalesOrder.self, SalesOrderItem.self], inMemory: true)
}
