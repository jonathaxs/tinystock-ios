// Proposito: Registrar um pedido de um produto e uma variacao, escolhidos no catalogo ou no proprio formulario.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-01.

import SwiftUI
import SwiftData
import TinyStockCore

struct SalesOrderFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let storeID: UUID
    /// Aberto pelo produto da lista, o formulario nao oferece a troca de produto.
    private let fixedProduct: Product?
    // O mesmo ID acompanha todas as tentativas deste rascunho e impede uma segunda baixa.
    @State private var draftID = UUID()
    @Query private var products: [Product]
    @Query private var storeVariants: [ProductVariant]
    @State private var productID: UUID?

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

    init(storeID: UUID, product: Product? = nil) {
        self.storeID = storeID
        fixedProduct = product
        _productID = State(initialValue: product?.id)
        _products = Query(filter: #Predicate<Product> { $0.storeID == storeID },
                          sort: [SortDescriptor(\Product.sortOrder), SortDescriptor(\Product.name)])
        _storeVariants = Query(filter: #Predicate<ProductVariant> { $0.storeID == storeID },
                               sort: \ProductVariant.name)
    }

    private var product: Product? {
        fixedProduct ?? products.first { $0.id == productID }
    }

    private var variants: [ProductVariant] {
        storeVariants.filter { $0.productID == productID }
    }

    private var hasStock: Bool {
        variants.contains { $0.quantity > 0 }
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

    private var subtotal: Decimal { (product?.salePrice ?? 0) * Decimal(quantity) }
    private var grossProfit: Decimal { ((product?.salePrice ?? 0) - (product?.costPrice ?? 0)) * Decimal(quantity) }
    private var channelFee: Decimal {
        guard let channelFeePercentage else { return 0 }
        return (try? ChannelFeeCalculator.fee(on: subtotal, percentage: channelFeePercentage)) ?? 0
    }
    private var netProfit: Decimal { grossProfit - channelFee }

    private var quantityLimit: Int {
        fulfillment == .readyStock ? max(1, selectedVariant?.quantity ?? 0) : 9_999
    }

    private var canSave: Bool {
        guard !buyerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              product != nil, selectedVariant != nil, quantity > 0,
              let channelFeePercentage, channelFeePercentage >= 0, channelFeePercentage <= 100 else { return false }
        if fulfillment == .readyStock { return (selectedVariant?.quantity ?? 0) >= quantity }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                customerSection
                productSection
                fulfillmentSection
                datesSection
                channelSection
                summarySection
                notesSection
            }
            .scrollDismissesKeyboard(.interactively)
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
                // O teclado decimal da taxa nao tem tecla de retorno para ser fechado.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "common.ok", bundle: .tinyStockCore)) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                        to: nil, from: nil, for: nil)
                    }
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
        .onChange(of: productID) { _, _ in selectInitialVariant() }
        .onChange(of: selectedVariantID) { _, _ in
            // Uma variacao sem estoque so pode ser atendida por producao.
            if fulfillment == .readyStock, (selectedVariant?.quantity ?? 0) == 0 { fulfillment = .production }
            clampQuantity()
        }
        .onChange(of: orderedAt) { _, _ in clampDeadlines() }
        .onChange(of: shippingDueAt) { _, _ in clampDeadlines() }
    }

    // Cada campo tem o proprio cabecalho para deixar claro o que pode ser tocado e alterado.
    @ViewBuilder
    private var productSection: some View {
        if let fixedProduct {
            ProductSheetHeader(product: fixedProduct)
        } else {
            Section(String(localized: "order.form.section.product", bundle: .tinyStockCore)) {
                Picker(String(localized: "order.form.section.product", bundle: .tinyStockCore), selection: $productID) {
                    ForEach(products) { product in
                        Text(product.name).tag(Optional(product.id))
                    }
                }
                .labelsHidden()
            }
        }
        if product != nil, variants.isEmpty {
            Section {
                Label(String(localized: "order.form.noVariants", bundle: .tinyStockCore), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
        } else if product != nil {
            if !usesInternalVariant {
                Section(String(localized: "product.form.variant.title", bundle: .tinyStockCore)) {
                    Picker(String(localized: "product.form.variant.title", bundle: .tinyStockCore), selection: $selectedVariantID) {
                        ForEach(variants) { variant in
                            Text(variantLabel(variant)).tag(Optional(variant.id))
                        }
                    }
                    .labelsHidden()
                }
            }
            Section {
                Stepper(value: $quantity, in: 1...quantityLimit) {
                    Text(quantity, format: .number)
                        .monospacedDigit()
                        .foregroundStyle(.tint)
                }
                .accessibilityLabel(String(localized: "order.form.quantity", bundle: .tinyStockCore))
                .accessibilityValue(Text(quantity, format: .number))
            } header: {
                Text(String(localized: "order.form.quantity", bundle: .tinyStockCore))
            } footer: {
                if let selectedVariant {
                    Text(String(format: String(localized: "products.catalog.quantity", bundle: .tinyStockCore),
                                selectedVariant.quantity.formatted()))
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
        } header: {
            Text(String(localized: "order.form.fulfillment", bundle: .tinyStockCore))
        } footer: {
            Text(String(localized: fulfillment == .readyStock ? "order.form.fulfillment.ready.footer" : "order.form.fulfillment.production.footer", bundle: .tinyStockCore))
        }
    }

    @ViewBuilder
    private var customerSection: some View {
        Section(String(localized: "order.form.section.customer", bundle: .tinyStockCore)) {
            TextField(String(localized: "order.form.buyer", bundle: .tinyStockCore), text: $buyerName)
                .textInputAutocapitalization(.words)
        }
        Section(String(localized: "order.form.section.reference", bundle: .tinyStockCore)) {
            TextField(String(localized: "order.form.optional", bundle: .tinyStockCore), text: $externalReference)
                .textInputAutocapitalization(.never)
        }
    }

    @ViewBuilder
    private var datesSection: some View {
        dateSection("order.form.orderedAtTitle") {
            DatePicker(String(localized: "order.form.orderedAtTitle", bundle: .tinyStockCore), selection: $orderedAt,
                       in: ...Date(), displayedComponents: .date)
        }
        if fulfillment == .production {
            dateSection("order.form.productionDueAtTitle") {
                DatePicker(String(localized: "order.form.productionDueAtTitle", bundle: .tinyStockCore), selection: $productionDueAt,
                           in: startOfOrderDay...safeEndOfShippingDay, displayedComponents: .date)
            }
        }
        dateSection("order.form.shippingDueAtTitle") {
            DatePicker(String(localized: "order.form.shippingDueAtTitle", bundle: .tinyStockCore), selection: $shippingDueAt,
                       in: startOfOrderDay..., displayedComponents: .date)
        }
    }

    private func dateSection(_ titleKey: String, @ViewBuilder picker: () -> some View) -> some View {
        Section(String(localized: String.LocalizationValue(titleKey), bundle: .tinyStockCore)) {
            picker()
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var channelSection: some View {
        Section(String(localized: "order.form.section.channel", bundle: .tinyStockCore)) {
            Picker(String(localized: "order.form.channel", bundle: .tinyStockCore), selection: $channel) {
                ForEach(SalesChannel.allCases, id: \.self) { option in
                    Text(option.localizedName).tag(option)
                }
            }
            .labelsHidden()
            if channel == .other {
                TextField(String(localized: "order.form.customChannel", bundle: .tinyStockCore), text: $customChannelName)
            }
        }
        Section(String(localized: "order.form.channelFee", bundle: .tinyStockCore)) {
            HStack(spacing: 4) {
                TextField("0", text: $channelFeeText)
                    .keyboardType(.decimalPad)
                    .accessibilityLabel(String(localized: "order.form.channelFee", bundle: .tinyStockCore))
                Text(verbatim: "%").foregroundStyle(.secondary)
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
            TextField(String(localized: "order.form.optional", bundle: .tinyStockCore), text: $note, axis: .vertical)
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
        // Aberto pelo botao de adicionar, o formulario comeca pelo primeiro produto do catalogo.
        if productID == nil { productID = products.first?.id }
        selectInitialVariant()
        didPrepareDraft = true
    }

    /// Sem estoque em nenhuma variacao, a venda so pode ser atendida por producao.
    private func selectInitialVariant() {
        selectedVariantID = variants.first(where: { $0.quantity > 0 })?.id ?? variants.first?.id
        if !hasStock { fulfillment = .production }
        clampQuantity()
    }

    private func adjustSelectionForFulfillment() {
        if fulfillment == .readyStock, (selectedVariant?.quantity ?? 0) == 0 {
            if hasStock {
                selectedVariantID = variants.first(where: { $0.quantity > 0 })?.id
            } else {
                fulfillment = .production
            }
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
        guard canSave, let product, let selectedVariant, let channelFeePercentage else { return }
        isSaving = true
        do {
            try SalesOrderService.register(
                id: draftID,
                storeID: storeID,
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
    SalesOrderFormView(storeID: UUID())
        .modelContainer(for: [StoreProfile.self, Product.self, ProductVariant.self, StockMovement.self, SalesOrder.self, SalesOrderItem.self], inMemory: true)
}
