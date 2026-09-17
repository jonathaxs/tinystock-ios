// Proposito: Exibir o pedido e oferecer suas operacoes validas.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-03.

import SwiftUI
import SwiftData
import TinyStockCore

struct SalesOrderDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var stores: [StoreProfile]
    @Bindable var order: SalesOrder
    @AppStorage(OrderCalendarExportSettings.isEnabledKey) private var isCalendarExportEnabled = true
    @State private var isEditing = false
    @State private var isConfirmingCancellation = false
    @State private var cancellationReason = ""
    @State private var errorMessage: String?
    @State private var selectedCalendarDraft: OrderCalendarEventDraft?

    init(order: SalesOrder) {
        self.order = order
        let storeID = order.storeID
        _stores = Query(filter: #Predicate<StoreProfile> { $0.id == storeID })
    }

    var body: some View {
        List {
            statusSection
            itemsSection
            customerSection
            datesSection
            financialSection
            additionalSection
            calendarExportSection
            actionsSection
        }
        .navigationTitle(String(localized: "order.detail.title", bundle: .tinyStockCore))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "common.edit", bundle: .tinyStockCore)) { isEditing = true }
                    .disabled(!SalesOrderPresentation.canEdit(order))
            }
        }
        .sheet(isPresented: $isEditing) { SalesOrderEditView(order: order) }
        .sheet(item: $selectedCalendarDraft) { draft in
            CalendarEventEditView(draft: draft) {
                selectedCalendarDraft = nil
            }
        }
        .alert(String(localized: "order.cancel.title", bundle: .tinyStockCore), isPresented: $isConfirmingCancellation) {
            TextField(String(localized: "order.cancel.reason", bundle: .tinyStockCore), text: $cancellationReason)
            Button(String(localized: "common.cancel", bundle: .tinyStockCore), role: .cancel) { cancellationReason = "" }
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

    private var statusSection: some View {
        Section {
            LabeledContent(String(localized: "order.detail.status", bundle: .tinyStockCore)) {
                Text(order.status?.localizedName ?? String(localized: "order.queue.unknown", bundle: .tinyStockCore))
                    .fontWeight(.semibold)
            }
            LabeledContent(String(localized: "order.form.fulfillment", bundle: .tinyStockCore)) {
                Text(order.fulfillment?.localizedName ?? String(localized: "order.queue.unknown", bundle: .tinyStockCore))
            }
        }
    }

    private var itemsSection: some View {
        Section(String(localized: "order.detail.items", bundle: .tinyStockCore)) {
            ForEach(order.itemList) { item in
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 8) {
                            itemIdentification(item)
                            itemValues(item, alignment: .leading)
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline) {
                            itemIdentification(item)
                            Spacer(minLength: 12)
                            itemValues(item, alignment: .trailing)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func itemIdentification(_ item: SalesOrderItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.productName).fontWeight(.medium)
            if !item.variantName.isEmpty {
                Text(item.variantName).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func itemValues(_ item: SalesOrderItem, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(item.subtotal.currencyText)
            Text(item.quantity, format: .number).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var customerSection: some View {
        Section(String(localized: "order.form.section.customer", bundle: .tinyStockCore)) {
            if !order.buyerName.isEmpty {
                LabeledContent(String(localized: "order.detail.buyer", bundle: .tinyStockCore), value: order.buyerName)
            }
            if !order.externalReference.isEmpty {
                LabeledContent(String(localized: "order.detail.reference", bundle: .tinyStockCore), value: order.externalReference)
            }
            LabeledContent(String(localized: "order.form.channel", bundle: .tinyStockCore), value: order.channelDisplayName)
        }
    }

    private var datesSection: some View {
        Section(String(localized: "order.form.section.dates", bundle: .tinyStockCore)) {
            dateRow("order.form.orderedAt", order.orderedAt)
            if let date = order.productionDueAt { dateRow("order.form.productionDueAt", date) }
            if let date = order.shippingDueAt { dateRow("order.form.shippingDueAt", date) }
            if let date = order.productionStartedAt { dateRow("order.detail.productionStartedAt", date, includesTime: true) }
            if let date = order.producedAt { dateRow("order.detail.producedAt", date, includesTime: true) }
            if let date = order.shippedAt { dateRow("order.detail.shippedAt", date, includesTime: true) }
            if let date = order.completedAt { dateRow("order.detail.completedAt", date, includesTime: true) }
            if let date = order.cancelledAt { dateRow("order.detail.cancelledAt", date, includesTime: true) }
        }
    }

    private var financialSection: some View {
        Section(String(localized: "order.form.section.summary", bundle: .tinyStockCore)) {
            LabeledContent(String(localized: "order.form.total", bundle: .tinyStockCore), value: order.total.currencyText)
            LabeledContent(String(localized: "order.form.fee", bundle: .tinyStockCore), value: order.channelFeeAmount.currencyText)
            LabeledContent(String(localized: "order.detail.grossProfit", bundle: .tinyStockCore), value: order.grossProfit.currencyText)
            LabeledContent(String(localized: "order.form.netProfit", bundle: .tinyStockCore), value: order.netProfit.currencyText)
        }
    }

    @ViewBuilder
    private var additionalSection: some View {
        if !order.trackingCode.isEmpty || !order.note.isEmpty || !order.cancellationReason.isEmpty {
            Section(String(localized: "order.detail.additional", bundle: .tinyStockCore)) {
                if !order.trackingCode.isEmpty {
                    LabeledContent(String(localized: "order.edit.tracking", bundle: .tinyStockCore), value: order.trackingCode)
                }
                if !order.note.isEmpty { Text(order.note) }
                if !order.cancellationReason.isEmpty {
                    LabeledContent(String(localized: "order.detail.cancellationReason", bundle: .tinyStockCore), value: order.cancellationReason)
                }
            }
        }
    }

    @ViewBuilder
    private var calendarExportSection: some View {
        if isCalendarExportEnabled && !calendarDrafts.isEmpty {
            Section(String(localized: "calendar.export.section", bundle: .tinyStockCore)) {
                ForEach(calendarDrafts) { draft in
                    Button {
                        selectedCalendarDraft = draft
                    } label: {
                        Group {
                            if dynamicTypeSize.isAccessibilitySize {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(draft.kind.localizedActionTitle, systemImage: draft.kind.symbolName)
                                    Text(draft.startDate, format: .dateTime.day().month(.abbreviated))
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                HStack {
                                    Label(draft.kind.localizedActionTitle, systemImage: draft.kind.symbolName)
                                    Spacer()
                                    Text(draft.startDate, format: .dateTime.day().month(.abbreviated))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .accessibilityHint(String(localized: "calendar.export.open.hint", bundle: .tinyStockCore))
                }
            }
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        if let action = SalesOrderPresentation.quickAction(for: order) {
            Section {
                Button { transition(to: action.status) } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
            }
        }
        if SalesOrderPresentation.canCancel(order) {
            Section {
                Button(role: .destructive) { isConfirmingCancellation = true } label: {
                    Label(String(localized: "order.action.cancel", bundle: .tinyStockCore), systemImage: "xmark.circle")
                }
            }
        }
    }

    private func dateRow(_ key: String.LocalizationValue, _ date: Date, includesTime: Bool = false) -> some View {
        LabeledContent(String(localized: key, bundle: .tinyStockCore)) {
            Text(includesTime ? date.formatted(date: .abbreviated, time: .shortened) : date.formatted(date: .abbreviated, time: .omitted))
        }
    }

    private var calendarDrafts: [OrderCalendarEventDraft] {
        OrderCalendarExportPlanner.drafts(
            for: order,
            storeName: stores.first?.name ?? StoreProfileService.localizedDefaultName,
            calendar: calendar
        )
    }

    private func transition(to status: SalesOrderStatus) {
        do {
            try SalesOrderService.transition(id: order.id, to: status, in: modelContext)
        } catch {
            errorMessage = SalesOrderPresentation.message(for: error)
        }
    }

    private func cancelOrder() {
        do {
            try SalesOrderService.cancel(id: order.id, reason: cancellationReason, in: modelContext)
            cancellationReason = ""
        } catch {
            errorMessage = SalesOrderPresentation.message(for: error)
        }
    }
}
