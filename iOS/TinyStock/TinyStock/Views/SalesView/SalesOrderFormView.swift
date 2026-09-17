// Proposito: Registrar um pedido de um produto e uma variacao pelo catalogo.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-01.

import SwiftUI
import SwiftData
import TinyStockCore

struct SalesOrderFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let product: Product
    // O mesmo ID acompanha todas as tentativas deste rascunho e impede uma segunda baixa.
    @State private var draftID = UUID()
    @Query private var variants: [ProductVariant]

    @State private var selectedVariantID: UUID?
    @State private var fulfillment: OrderFulfillment = .readyStock
    @State private var quantity = 1
    @State private var channel: SalesChannel = .direct
    @State private var customChannelName = ""
    @State private var buyerName = ""
    @State private var externalReference = ""
    @State private var orderedAt = Date()
    @State private var productionDueAt = Date()
    @State private var shippingDueAt = Date()
    @State private var channelFeeText = ""
    @State private var note = ""
    @State private var didPrepareDraft = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(product: Product) {
        self.product = product
        let productID = product.id
        let storeID = product.storeID
        _variants = Query(filter: #Predicate<ProductVariant> {
            $0.productID == productID && $0.storeID == storeID
        }, sort: \ProductVariant.name)
    }

    private var selectedVariant: ProductVariant? {
        variants.first { $0.id == selectedVariantID }
    }

    private var usesInternalVariant: Bool {
        variants.count == 1 && variants.first?.isDefault == true
    }

    private var channelFeePercentage: Decimal? {
        let cleanText = channelFeeText.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanText.isEmpty ? 0 : CurrencyFormatter.decimal(from: cleanText)
    }

    private var subtotal: Decimal { product.salePrice * Decimal(quantity) }
    private var grossProfit: Decimal { (product.salePrice - product.costPrice) * Decimal(quantity) }
    private var channelFee: Decimal {
        guard let channelFeePercentage else { return 0 }
        return (try? ChannelFeeCalculator.fee(on: subtotal, percentage: channelFeePercentage)) ?? 0
    }
    private var netProfit: Decimal { grossProfit - channelFee }

    private var quantityLimit: Int {
        fulfillment == .readyStock ? max(1, selectedVariant?.quantity ?? 0) : 9_999
    }

    private var canSave: Bool {
        guard selectedVariant != nil, quantity > 0,
              let channelFeePercentage, channelFeePercentage >= 0, channelFeePercentage <= 100 else { return false }
        if fulfillment == .readyStock { return (selectedVariant?.quantity ?? 0) >= quantity }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                productSection
                fulfillmentSection
                customerSection
                datesSection
                channelSection
                summarySection
                notesSection
            }
            .navigationTitle(String(localized: "order.form.title", bundle: .tinyStockCore))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", bundle: .tinyStockCore)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "order.form.save", bundle: .tinyStockCore), action: save)
                        .disabled(!canSave || isSaving)
                }
            }
            .alert(String(localized: "order.form.error.title", bundle: .tinyStockCore), isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button(String(localized: "common.ok", bundle: .tinyStockCore)) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .task { prepareDraftIfNeeded() }
        .onChange(of: fulfillment) { _, _ in adjustSelectionForFulfillment() }
        .onChange(of: selectedVariantID) { _, _ in clampQuantity() }
        .onChange(of: orderedAt) { _, _ in clampDeadlines() }
        .onChange(of: shippingDueAt) { _, _ in clampDeadlines() }
    }

    private var productSection: some View {
        Section(String(localized: "order.form.section.product", bundle: .tinyStockCore)) {
            HStack(spacing: 12) {
                ProductImageView(imageData: product.imageData, side: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name).font(.headline)
                    Text(product.salePrice.currencyText).foregroundStyle(.secondary)
                }
            }
            if variants.isEmpty {
                Label(String(localized: "order.form.noVariants", bundle: .tinyStockCore), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            } else {
                if !usesInternalVariant {
                    Picker(String(localized: "product.form.variant.title", bundle: .tinyStockCore), selection: $selectedVariantID) {
                        ForEach(variants) { variant in
                            Text(variantLabel(variant)).tag(Optional(variant.id))
                        }
                    }
                }
                Stepper(value: $quantity, in: 1...quantityLimit) {
                    LabeledContent(String(localized: "order.form.quantity", bundle: .tinyStockCore)) {
                        Text(quantity, format: .number).monospacedDigit()
                    }
                }
                if let selectedVariant {
                    LabeledContent(String(localized: "product.form.variant.available", bundle: .tinyStockCore)) {
                        Text(selectedVariant.quantity, format: .number).monospacedDigit()
                    }
                }
            }
        }
    }

    private var fulfillmentSection: some View {
        Section {
            Picker(String(localized: "order.form.fulfillment", bundle: .tinyStockCore), selection: $fulfillment) {
                ForEach(OrderFulfillment.allCases, id: \.self) { option in
                    Text(option.localizedName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        } footer: {
            Text(String(localized: fulfillment == .readyStock ? "order.form.fulfillment.ready.footer" : "order.form.fulfillment.production.footer", bundle: .tinyStockCore))
        }
    }

    private var customerSection: some View {
        Section(String(localized: "order.form.section.customer", bundle: .tinyStockCore)) {
            TextField(String(localized: "order.form.buyer", bundle: .tinyStockCore), text: $buyerName)
                .textInputAutocapitalization(.words)
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
                ForEach(SalesChannel.allCases, id: \.self) { option in
                    Text(option.localizedName).tag(option)
                }
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

    private var summarySection: some View {
        Section(String(localized: "order.form.section.summary", bundle: .tinyStockCore)) {
            LabeledContent(String(localized: "order.form.total", bundle: .tinyStockCore)) { Text(subtotal.currencyText) }
            LabeledContent(String(localized: "order.form.fee", bundle: .tinyStockCore)) { Text(channelFee.currencyText) }
            LabeledContent(String(localized: "order.form.netProfit", bundle: .tinyStockCore)) {
                Text(netProfit.currencyText).fontWeight(.semibold)
            }
        }
    }

    private var notesSection: some View {
        Section(String(localized: "order.form.section.notes", bundle: .tinyStockCore)) {
            TextField(String(localized: "order.form.note", bundle: .tinyStockCore), text: $note, axis: .vertical)
                .lineLimit(2...5)
        }
    }

    private var startOfOrderDay: Date { Calendar.current.startOfDay(for: orderedAt) }
    private var endOfShippingDay: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: Calendar.current.startOfDay(for: shippingDueAt)) ?? shippingDueAt
    }

    private var safeEndOfShippingDay: Date { max(startOfOrderDay, endOfShippingDay) }

    private func variantLabel(_ variant: ProductVariant) -> String {
        let format = String(localized: "order.form.variant.option", bundle: .tinyStockCore)
        return String(format: format, variant.name, variant.quantity.formatted())
    }

    private func prepareDraftIfNeeded() {
        guard !didPrepareDraft else { return }
        let calendar = Calendar.current
        productionDueAt = calendar.date(byAdding: .day, value: 1, to: orderedAt) ?? orderedAt
        shippingDueAt = calendar.date(byAdding: .day, value: 2, to: orderedAt) ?? orderedAt
        selectedVariantID = variants.first(where: { $0.quantity > 0 })?.id ?? variants.first?.id
        didPrepareDraft = true
    }

    private func adjustSelectionForFulfillment() {
        if fulfillment == .readyStock, (selectedVariant?.quantity ?? 0) == 0 {
            selectedVariantID = variants.first(where: { $0.quantity > 0 })?.id ?? selectedVariantID
        }
        clampQuantity()
    }

    private func clampQuantity() {
        quantity = min(max(1, quantity), quantityLimit)
    }

    private func clampDeadlines() {
        if shippingDueAt < startOfOrderDay { shippingDueAt = startOfOrderDay }
        productionDueAt = min(max(productionDueAt, startOfOrderDay), safeEndOfShippingDay)
    }

    private func save() {
        guard canSave, let selectedVariant, let channelFeePercentage else { return }
        isSaving = true
        do {
            try SalesOrderService.register(
                id: draftID,
                storeID: product.storeID,
                lines: [SalesOrderLine(productID: product.id, variantID: selectedVariant.id, quantity: quantity)],
                fulfillment: fulfillment,
                channel: channel,
                customChannelName: customChannelName,
                buyerName: buyerName,
                externalReference: externalReference,
                orderedAt: orderedAt,
                productionDueAt: fulfillment == .production ? productionDueAt : nil,
                shippingDueAt: shippingDueAt,
                note: note,
                channelFeePercentage: channelFeePercentage,
                in: modelContext
            )
            dismiss()
        } catch {
            isSaving = false
            errorMessage = (error as? SalesOrderError)?.localizedMessage ?? error.localizedDescription
        }
    }
}

#Preview {
    SalesOrderFormView(product: Product(name: "Caneca", costPrice: 12, salePrice: 35))
        .modelContainer(for: [StoreProfile.self, Product.self, ProductVariant.self, StockMovement.self, SalesOrder.self, SalesOrderItem.self], inMemory: true)
}
