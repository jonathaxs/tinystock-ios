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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let editingProduct: Product?
    private let storeID: UUID

    @State private var name: String
    @State private var costPriceText: String
    @State private var salePriceText: String
    @State private var imageData: Data?
    @State private var hasVariations: Bool
    @State private var initialVariationName = ""
    @State private var initialQuantityText: String
    @State private var usesLegacyDefaultVariant = false
    @State private var variants: [ProductVariantInput] = []
    @State private var editingVariant: ProductVariantInput?
    @State private var didLoadVariants = false
    @State private var errorMessage: String?
    @State private var isLoadingPhoto = false

    init(storeID: UUID, product: Product? = nil) {
        self.storeID = storeID
        editingProduct = product
        _name = State(initialValue: product?.name ?? "")
        _costPriceText = State(initialValue: CurrencyFormatter.editableText(from: product?.costPrice ?? 0))
        _salePriceText = State(initialValue: CurrencyFormatter.editableText(from: product?.salePrice ?? 0))
        _imageData = State(initialValue: product?.imageData)
        // Produto novo sempre nasce com uma variacao nomeada, o que libera o estoque inicial.
        _hasVariations = State(initialValue: product == nil)
        _initialQuantityText = State(initialValue: product == nil ? "1" : "0")
    }

    private func price(from text: String) -> Decimal? {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : CurrencyFormatter.decimal(from: text)
    }

    private var initialQuantity: Int? {
        Int(initialQuantityText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var formVariants: [ProductVariantInput] {
        guard hasVariations, let initialQuantity else { return [] }
        if editingProduct != nil, variants.count > 1 { return variants }
        let existingID = editingProduct == nil ? nil : variants.first?.existingID
        return [ProductVariantInput(existingID: existingID, name: initialVariationName,
                                    initialQuantity: initialQuantity)]
    }

    private var usesDirectVariationFields: Bool {
        editingProduct == nil || variants.count <= 1
    }

    private var canDisableVariations: Bool {
        editingProduct == nil || variants.count <= 1
    }

    /// Na edicao, o saldo escolhido vira um ajuste de estoque registrado no historico.
    private var canEditStock: Bool {
        hasVariations
    }

    private var variationIsValid: Bool {
        guard hasVariations else { return true }
        guard usesDirectVariationFields else { return !variants.isEmpty }
        guard let initialQuantity else { return false }
        return !initialVariationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && initialQuantity >= 0
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", bundle: .tinyStockCore)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save", bundle: .tinyStockCore), action: save)
                        .disabled(!canSave)
                }
                // O teclado decimal dos precos nao tem tecla de retorno para ser fechado.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "common.ok", bundle: .tinyStockCore), action: dismissKeyboard)
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
        .task { loadVariants() }
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

    private var pricesSection: some View {
        Section(String(localized: "product.form.section.prices", bundle: .tinyStockCore)) {
            priceField(String(localized: "product.form.salePrice", bundle: .tinyStockCore), text: $salePriceText)
            priceField(String(localized: "product.form.costPrice", bundle: .tinyStockCore), text: $costPriceText)
            if let sale = price(from: salePriceText), let cost = price(from: costPriceText) {
                LabeledContent(String(localized: "product.form.unitProfit", bundle: .tinyStockCore)) {
                    Text((sale - cost).currencyText)
                        .foregroundStyle(sale < cost ? Color.red : Color.primary)
                }
            }
        }
    }

    private func priceField(_ title: String, text: Binding<String>) -> some View {
        LabeledContent(title) {
            TextField(Decimal.zero.currencyText, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(title)
        }
    }

    private var productSection: some View {
        Section {
            TextField(String(localized: "product.form.name", bundle: .tinyStockCore), text: $name)
                .textInputAutocapitalization(.words)
            // So produtos antigos, criados sem variacao, ainda precisam ativar a opcao.
            if usesLegacyDefaultVariant {
                Toggle(String(localized: "product.form.variant.enabled", bundle: .tinyStockCore), isOn: $hasVariations)
                    .disabled(!canDisableVariations)
            }
            if usesDirectVariationFields {
                TextField(String(localized: "product.form.variant.name", bundle: .tinyStockCore), text: $initialVariationName)
                    .textInputAutocapitalization(.words)
                    .disabled(!hasVariations)
                    .foregroundStyle(hasVariations ? Color.primary : Color.secondary)
                stockRow
            } else {
                ForEach(variants) { input in
                    Button { editingVariant = input } label: {
                        LabeledContent(input.name) {
                            Text(input.initialQuantity, format: .number)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                    }
                    .accessibilityHint(String(localized: "product.form.variant.edit.hint", bundle: .tinyStockCore))
                }
            }
        } footer: {
            if !canDisableVariations {
                Text(String(localized: "product.form.variant.multiple.footer", bundle: .tinyStockCore))
            } else if !hasVariations {
                Text(String(localized: "product.form.variant.disabled.footer", bundle: .tinyStockCore))
            }
        }
    }

    @ViewBuilder
    private var stockRow: some View {
        if canEditStock {
            StockQuantityPicker(title: initialStockTitle, quantity: initialQuantitySelection,
                                range: 0...max(100, initialQuantity ?? 0))
        } else {
            LabeledContent(initialStockTitle) {
                Text(initialQuantityText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
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

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
                usesLegacyDefaultVariant = storedVariants.contains(where: \.isDefault)
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
