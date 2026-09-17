// Proposito: Editar dados administrativos e prazos de um pedido em aberto.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-03.

import SwiftUI
import SwiftData
import TinyStockCore

struct SalesOrderEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var order: SalesOrder
    @State private var channel: SalesChannel
    @State private var customChannelName: String
    @State private var buyerName: String
    @State private var externalReference: String
    @State private var orderedAt: Date
    @State private var productionDueAt: Date
    @State private var shippingDueAt: Date
    @State private var trackingCode: String
    @State private var note: String
    @State private var channelFeeText: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(order: SalesOrder) {
        self.order = order
        _channel = State(initialValue: order.channel ?? .direct)
        _customChannelName = State(initialValue: order.customChannelName)
        _buyerName = State(initialValue: order.buyerName)
        _externalReference = State(initialValue: order.externalReference)
        _orderedAt = State(initialValue: order.orderedAt)
        _productionDueAt = State(initialValue: order.productionDueAt ?? order.orderedAt)
        _shippingDueAt = State(initialValue: order.shippingDueAt ?? order.orderedAt)
        _trackingCode = State(initialValue: order.trackingCode)
        _note = State(initialValue: order.note)
        _channelFeeText = State(initialValue: CurrencyFormatter.editableText(from: order.channelFeePercentage))
    }

    private var fulfillment: OrderFulfillment? { order.fulfillment }
    private var feePercentage: Decimal? {
        let clean = channelFeeText.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? 0 : CurrencyFormatter.decimal(from: clean)
    }
    private var previewFee: Decimal {
        guard let feePercentage else { return 0 }
        return (try? ChannelFeeCalculator.fee(on: order.total, percentage: feePercentage)) ?? 0
    }
    private var canSave: Bool {
        guard fulfillment != nil, order.status != nil, let feePercentage else { return false }
        return feePercentage >= 0 && feePercentage <= 100 && SalesOrderPresentation.canEdit(order)
    }

    var body: some View {
        NavigationStack {
            Form {
                itemsSection
                customerSection
                datesSection
                channelSection
                logisticsSection
                summarySection
            }
            .navigationTitle(String(localized: "order.edit.title", bundle: .tinyStockCore))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", bundle: .tinyStockCore)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save", bundle: .tinyStockCore), action: save)
                        .disabled(!canSave || isSaving)
                }
            }
            .alert(String(localized: "order.operation.error.title", bundle: .tinyStockCore), isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button(String(localized: "common.ok", bundle: .tinyStockCore)) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .onChange(of: orderedAt) { _, _ in clampDeadlines() }
        .onChange(of: shippingDueAt) { _, _ in clampDeadlines() }
    }

    private var itemsSection: some View {
        Section {
            ForEach(order.itemList) { item in
                LabeledContent {
                    Text(item.quantity, format: .number)
                } label: {
                    VStack(alignment: .leading) {
                        Text(item.productName)
                        if !item.variantName.isEmpty {
                            Text(item.variantName).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text(String(localized: "order.detail.items", bundle: .tinyStockCore))
        } footer: {
            Text(String(localized: "order.edit.items.footer", bundle: .tinyStockCore))
        }
    }

    private var customerSection: some View {
        Section(String(localized: "order.form.section.customer", bundle: .tinyStockCore)) {
            TextField(String(localized: "order.form.buyer", bundle: .tinyStockCore), text: $buyerName)
            TextField(String(localized: "order.form.reference", bundle: .tinyStockCore), text: $externalReference)
                .textInputAutocapitalization(.never)
        }
    }

    private var datesSection: some View {
        Section(String(localized: "order.form.section.dates", bundle: .tinyStockCore)) {
            DatePicker(String(localized: "order.form.orderedAt", bundle: .tinyStockCore), selection: $orderedAt,
                       in: ...Date(), displayedComponents: .date)
            if fulfillment == .production {
                DatePicker(String(localized: "order.form.productionDueAt", bundle: .tinyStockCore), selection: $productionDueAt,
                           in: startOfOrderDay...safeEndOfShippingDay, displayedComponents: .date)
            }
            DatePicker(String(localized: "order.form.shippingDueAt", bundle: .tinyStockCore), selection: $shippingDueAt,
                       in: startOfOrderDay..., displayedComponents: .date)
        }
    }

    private var channelSection: some View {
        Section(String(localized: "order.form.section.channel", bundle: .tinyStockCore)) {
            Picker(String(localized: "order.form.channel", bundle: .tinyStockCore), selection: $channel) {
                ForEach(SalesChannel.allCases, id: \.self) { Text($0.localizedName).tag($0) }
            }
            if channel == .other {
                TextField(String(localized: "order.form.customChannel", bundle: .tinyStockCore), text: $customChannelName)
            }
            LabeledContent(String(localized: "order.form.channelFee", bundle: .tinyStockCore)) {
                HStack(spacing: 4) {
                    TextField("0", text: $channelFeeText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 72)
                    Text(verbatim: "%").foregroundStyle(.secondary)
                }
            }
        }
    }

    private var logisticsSection: some View {
        Section(String(localized: "order.detail.additional", bundle: .tinyStockCore)) {
            TextField(String(localized: "order.edit.tracking", bundle: .tinyStockCore), text: $trackingCode)
                .textInputAutocapitalization(.characters)
            TextField(String(localized: "order.form.note", bundle: .tinyStockCore), text: $note, axis: .vertical)
                .lineLimit(2...5)
        }
    }

    private var summarySection: some View {
        Section(String(localized: "order.form.section.summary", bundle: .tinyStockCore)) {
            LabeledContent(String(localized: "order.form.total", bundle: .tinyStockCore), value: order.total.currencyText)
            LabeledContent(String(localized: "order.form.fee", bundle: .tinyStockCore), value: previewFee.currencyText)
            LabeledContent(String(localized: "order.form.netProfit", bundle: .tinyStockCore),
                           value: (order.grossProfit - previewFee).currencyText)
        }
    }

    private var startOfOrderDay: Date { Calendar.current.startOfDay(for: orderedAt) }
    private var endOfShippingDay: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1),
                              to: Calendar.current.startOfDay(for: shippingDueAt)) ?? shippingDueAt
    }
    private var safeEndOfShippingDay: Date { max(startOfOrderDay, endOfShippingDay) }

    private func clampDeadlines() {
        if shippingDueAt < startOfOrderDay { shippingDueAt = startOfOrderDay }
        productionDueAt = min(max(productionDueAt, startOfOrderDay), safeEndOfShippingDay)
    }

    private func save() {
        guard canSave, let fulfillment, let feePercentage else { return }
        isSaving = true
        let details = SalesOrderDetails(
            channel: channel,
            customChannelName: customChannelName,
            buyerName: buyerName,
            externalReference: externalReference,
            orderedAt: orderedAt,
            productionDueAt: fulfillment == .production ? productionDueAt : nil,
            shippingDueAt: shippingDueAt,
            trackingCode: trackingCode,
            note: note,
            channelFeePercentage: feePercentage
        )
        do {
            try SalesOrderService.update(id: order.id, details: details, in: modelContext)
            dismiss()
        } catch {
            isSaving = false
            errorMessage = SalesOrderPresentation.message(for: error)
        }
    }
}
