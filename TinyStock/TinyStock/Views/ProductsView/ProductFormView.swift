// TinyStock/Views/ProductsView/ProductFormView.swift
//
// Proposito: Formulario de produto com foto e variacoes, sem gravacao antes de salvar.
//
// Created by Jonathas Motta (@jonathaxs) on 2026-08-08.

import SwiftData
import SwiftUI
import TinyStockCore

/// Mantem os campos em memoria ate a confirmacao do cadastro ou da edicao.
struct ProductFormView: View {
    enum PriceField: Hashable, Identifiable {
        case sale, cost
        var id: Self { self }
    }

    /// Campos de texto na ordem da tela, para as setas do teclado.
    enum Field: Hashable {
        case name, variation, sale, cost
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let editingProduct: Product?
    private let storeID: UUID
    private let initialFocus: PriceField?
    @FocusState private var focusedField: Field?

    @State private var name: String
    @State private var costPriceText: String
    @State private var salePriceText: String
    @State private var imageData: Data?
    @State private var hasVariations: Bool
    @State private var initialVariationName = ""
    @State private var initialQuantityText: String
    @State private var variants: [ProductVariantInput] = []
    @State private var editingVariant: ProductVariantInput?
    @State private var didLoadVariants = false
    @State private var errorMessage: String?
    @State private var isLoadingPhoto = false

    init(storeID: UUID, product: Product? = nil, initialFocus: PriceField? = nil) {
        self.storeID = storeID
        editingProduct = product
        self.initialFocus = initialFocus
        _name = State(initialValue: product?.name ?? "")
        _costPriceText = State(initialValue: CurrencyFormatter.editableText(from: product?.costPrice ?? 0))
        _salePriceText = State(initialValue: CurrencyFormatter.editableText(from: product?.salePrice ?? 0))
        _imageData = State(initialValue: product?.imageData)
        // Produto novo comeca com variacao ligada; o switch deixa cadastrar sem variacao.
        _hasVariations = State(initialValue: product == nil)
        _initialQuantityText = State(initialValue: product == nil ? "1" : "0")
    }

    private func price(from text: String) -> Decimal? {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : CurrencyFormatter.decimal(from: text)
    }

    private var initialQuantity: Int? {
        Int(initialQuantityText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Sem variacao, a unica entrada leva so o estoque da variacao interna do produto.
    private var formVariants: [ProductVariantInput] {
        guard let initialQuantity else { return [] }
        if hasVariations, editingProduct != nil, variants.count > 1 { return variants }
        let existingID = editingProduct == nil ? nil : variants.first?.existingID
        return [ProductVariantInput(existingID: existingID, name: hasVariations ? initialVariationName : "",
                                    initialQuantity: initialQuantity)]
    }

    private var fieldOrder: [Field] {
        hasVariations && usesDirectVariationFields ? [.name, .variation, .sale, .cost] : [.name, .sale, .cost]
    }

    private var usesDirectVariationFields: Bool {
        editingProduct == nil || variants.count <= 1
    }

    private var variationIsValid: Bool {
        guard usesDirectVariationFields else { return !variants.isEmpty }
        guard let initialQuantity, initialQuantity >= 0 else { return false }
        return !hasVariations || !initialVariationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSave: Bool {
        guard let cost = price(from: costPriceText), let sale = price(from: salePriceText) else { return false }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && cost >= 0 && sale >= 0 && variationIsValid && didLoadVariants && !isLoadingPhoto
    }

    private var title: String {
        editingProduct == nil
            ? String(localized: "product.form.title.new", bundle: .tinyStockCore)
            : String(localized: "product.form.title.edit", bundle: .tinyStockCore)
    }

    var body: some View {
        NavigationStack {
            Form {
                ProductPhotoEditor(
                    imageData: $imageData,
                    isProcessing: $isLoadingPhoto,
                    errorMessage: $errorMessage
                )
                productSection
                pricesSection
            }
            .scrollDismissesKeyboard(.interactively)
            .keyboardFieldNavigation(focus: $focusedField, order: fieldOrder)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCloseButton(title: String(localized: "common.cancel", bundle: .tinyStockCore)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SheetConfirmButton(action: save)
                        .disabled(!canSave)
                }
            }
            .alert(String(localized: "product.form.error.title", bundle: .tinyStockCore), isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button(String(localized: "common.ok", bundle: .tinyStockCore)) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task {
            loadVariants()
            await focusInitialPrice()
        }
        .sheet(item: $editingVariant) { input in
            ProductVariantFormView(input: input) { updated in
                if let index = variants.firstIndex(where: { $0.id == updated.id }) {
                    variants[index] = updated
                } else {
                    variants.append(updated)
                }
            }
        }
    }

    // Cada preco tem o proprio cabecalho; o lucro calculado fica no rodape do custo.
    @ViewBuilder
    private var pricesSection: some View {
        Section(tinted: String(localized: "product.form.salePrice", bundle: .tinyStockCore)) {
            priceField(String(localized: "product.form.salePrice", bundle: .tinyStockCore), text: $salePriceText, field: .sale)
        }
        Section {
            priceField(String(localized: "product.form.costPrice", bundle: .tinyStockCore), text: $costPriceText, field: .cost)
        } header: {
            FormHeader(title: String(localized: "product.form.costPrice", bundle: .tinyStockCore))
        } footer: {
            if let sale = price(from: salePriceText), let cost = price(from: costPriceText) {
                Text(String(format: String(localized: "product.form.unitProfitSummary", bundle: .tinyStockCore),
                            (sale - cost).currencyText))
                    .foregroundStyle(sale < cost ? Color.red : Color.secondary)
            }
        }
    }

    private func priceField(_ title: String, text: Binding<String>, field: PriceField) -> some View {
        TextField(Decimal.zero.currencyText, text: text)
            .keyboardType(.decimalPad)
            .focused($focusedField, equals: field == .sale ? .sale : .cost)
            .accessibilityLabel(title)
    }

    /// Aberto pelos detalhes, o formulario ja posiciona o cursor no preco tocado.
    private func focusInitialPrice() async {
        guard let initialFocus else { return }
        // O foco so e aceito depois que a folha termina de aparecer.
        try? await Task.sleep(for: .milliseconds(600))
        focusedField = initialFocus == .sale ? .sale : .cost
    }

    // Cada campo tem o proprio cabecalho para deixar claro o que pode ser tocado e alterado.
    @ViewBuilder
    private var productSection: some View {
        Section(tinted: String(localized: "product.variant.edit.name", bundle: .tinyStockCore)) {
            TextField(String(localized: "product.form.name", bundle: .tinyStockCore), text: $name)
                .textInputAutocapitalization(.words)
                .keyboardNext(.name, focus: $focusedField, order: fieldOrder)
        }
        // Com uma variacao so, o produto pode ficar sem variacao e o estoque fica nele mesmo.
        if usesDirectVariationFields {
            Section {
                Toggle(String(localized: "product.form.variant.enabled", bundle: .tinyStockCore),
                       isOn: $hasVariations.animation())
                if hasVariations {
                    TextField(String(localized: "product.form.variant.name", bundle: .tinyStockCore),
                              text: $initialVariationName)
                        .textInputAutocapitalization(.words)
                        .keyboardNext(.variation, focus: $focusedField, order: fieldOrder)
                }
            } header: {
                FormHeader(title: String(localized: "product.form.variant.title", bundle: .tinyStockCore))
            } footer: {
                if !hasVariations {
                    Text(String(localized: "product.form.variant.disabled.footer", bundle: .tinyStockCore))
                }
            }
            Section(tinted: initialStockTitle) { stockRow }
        } else {
            Section {
                ForEach(variants) { input in
                    Button { editingVariant = input } label: {
                        LabeledContent(input.name) {
                            HStack(spacing: 6) {
                                Text(input.initialQuantity, format: .number)
                                    .monospacedDigit()
                                    .foregroundStyle(.tint)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .accessibilityHidden(true)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .accessibilityHint(String(localized: "product.form.variant.edit.hint", bundle: .tinyStockCore))
                }
            } header: {
                FormHeader(title: String(localized: "product.form.variants", bundle: .tinyStockCore))
            } footer: {
                Text(String(localized: "product.form.variant.multiple.footer", bundle: .tinyStockCore))
            }
        }
    }

    /// Na edicao, o saldo escolhido vira um ajuste de estoque registrado no historico.
    private var stockRow: some View {
        StockQuantityStepper(title: initialStockTitle, quantity: initialQuantitySelection)
    }

    private var initialQuantitySelection: Binding<Int> {
        Binding(get: { initialQuantity ?? 0 }, set: { initialQuantityText = String($0) })
    }

    /// A edicao preserva os saldos; a diferenca escolhida entra como ajuste auditavel.
    private func adjustEditedStock(of product: Product) throws {
        let stored = try ProductVariantService.variants(for: product, in: modelContext)
        for input in formVariants {
            guard let variant = stored.first(where: { $0.id == input.existingID }),
                  variant.quantity != input.initialQuantity else { continue }
            try StockService.registerAdjustment(newQuantity: input.initialQuantity, to: variant,
                                                product: product, in: modelContext)
        }
    }

    private var initialStockTitle: String {
        String(localized: editingProduct == nil
               ? "product.form.variant.initialStock"
               : "product.form.variant.available", bundle: .tinyStockCore)
    }

    private func loadVariants() {
        guard !didLoadVariants else { return }
        do {
            if let editingProduct {
                let storedVariants = try ProductVariantService.variants(for: editingProduct, in: modelContext)
                variants = storedVariants.map {
                    ProductVariantInput(id: $0.id, existingID: $0.id,
                                        name: $0.isDefault ? "" : $0.name,
                                        initialQuantity: $0.quantity)
                }
                hasVariations = !storedVariants.isEmpty && !storedVariants.contains(where: \.isDefault)
                if let onlyVariant = variants.first, variants.count == 1 {
                    initialVariationName = onlyVariant.name
                    initialQuantityText = String(onlyVariant.initialQuantity)
                }
            }
            didLoadVariants = true
        } catch { errorMessage = error.localizedDescription }
    }

    private func save() {
        guard canSave, let cost = price(from: costPriceText), let sale = price(from: salePriceText) else { return }
        // Salva pendencias anteriores antes do lote para nao desfaze-las caso este cadastro falhe.
        do { try modelContext.save() } catch {
            errorMessage = error.localizedDescription
            return
        }
        do {
            let product = try ProductFormService.apply(to: editingProduct, storeID: storeID, name: name,
                                                       costPrice: cost, salePrice: sale, imageData: imageData,
                                                       variants: formVariants, usesVariants: hasVariations,
                                                       in: modelContext)
            if editingProduct != nil { try adjustEditedStock(of: product) }
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            if let error = error as? ProductError {
                errorMessage = error.localizedMessage
            } else if let error = error as? StockError {
                errorMessage = error.localizedMessage
            } else if let error = error as? ProductFormError {
                errorMessage = error.localizedMessage
            } else if let error = error as? ProductVariantError {
                errorMessage = error.localizedMessage
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ProductFormView(storeID: UUID())
        .modelContainer(for: [Product.self, ProductVariant.self, StockMovement.self], inMemory: true)
}
