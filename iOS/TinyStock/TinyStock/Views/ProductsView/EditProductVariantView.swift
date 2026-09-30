// Proposito: Renomear uma variacao e corrigir seu saldo com ajuste registrado no historico.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-29.

import SwiftData
import SwiftUI
import TinyStockCore

struct EditProductVariantView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let product: Product
    private let initialVariantID: UUID?
    @Query private var variants: [ProductVariant]
    @State private var selectedVariantID: UUID?
    @State private var name = ""
    @State private var quantity = 0
    @State private var didLoad = false
    @State private var errorMessage: String?

    init(product: Product, variantID: UUID? = nil) {
        self.product = product
        initialVariantID = variantID
        let productID = product.id
        let storeID = product.storeID
        _variants = Query(filter: #Predicate<ProductVariant> {
            $0.productID == productID && $0.storeID == storeID
        }, sort: \ProductVariant.name)
    }

    private var selectedVariant: ProductVariant? {
        variants.first { $0.id == selectedVariantID }
    }

    /// Produto antigo sem variacoes: a variacao interna nao tem nome, so o saldo e editavel.
    private var usesInternalVariant: Bool {
        selectedVariant?.isDefault == true
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasChanges: Bool {
        guard let selectedVariant else { return false }
        let renamed = !usesInternalVariant && trimmedName != selectedVariant.name
        return renamed || quantity != selectedVariant.quantity
    }

    private var canSave: Bool {
        hasChanges && (usesInternalVariant || !trimmedName.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                ProductSheetHeader(product: product)
                // Cada campo tem o proprio cabecalho para deixar claro o que pode ser tocado e alterado.
                if variants.count > 1 {
                    Section(String(localized: "product.form.variant.title", bundle: .tinyStockCore)) {
                        Picker(String(localized: "product.form.variant.title", bundle: .tinyStockCore),
                               selection: $selectedVariantID) {
                            ForEach(variants) { variant in
                                Text(variantLabel(variant)).tag(Optional(variant.id))
                            }
                        }
                        .labelsHidden()
                    }
                }
                if !usesInternalVariant {
                    Section(String(localized: "product.variant.edit.name", bundle: .tinyStockCore)) {
                        TextField(String(localized: "product.form.variant.name", bundle: .tinyStockCore), text: $name)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                    }
                }
                // Aceita zero para desfazer uma entrada feita por engano.
                Section(String(localized: "product.variant.edit.stock", bundle: .tinyStockCore)) {
                    StockQuantityPicker(
                        title: String(localized: "product.variant.edit.stock", bundle: .tinyStockCore),
                        quantity: $quantity,
                        range: 0...max(100, selectedVariant?.quantity ?? 0),
                        showsTitle: false
                    )
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(String(localized: "product.variant.edit.title", bundle: .tinyStockCore))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", bundle: .tinyStockCore)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save", bundle: .tinyStockCore), action: save)
                        .disabled(!canSave)
                }
            }
            .alert(String(localized: "product.form.error.title", bundle: .tinyStockCore), isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button(String(localized: "common.ok", bundle: .tinyStockCore)) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .task {
            guard !didLoad else { return }
            selectedVariantID = initialVariantID ?? variants.first?.id
            loadFields()
            didLoad = true
        }
        .onChange(of: selectedVariantID) { _, _ in loadFields() }
    }

    private func loadFields() {
        guard let selectedVariant else { return }
        name = selectedVariant.isDefault ? "" : selectedVariant.name
        quantity = selectedVariant.quantity
    }

    private func variantLabel(_ variant: ProductVariant) -> String {
        let format = String(localized: "order.form.variant.option", bundle: .tinyStockCore)
        return String(format: format, variant.name, variant.quantity.formatted())
    }

    private func save() {
        guard canSave, let selectedVariant else { return }
        // Salva pendencias anteriores antes do lote para nao desfaze-las caso esta edicao falhe.
        do { try modelContext.save() } catch {
            errorMessage = error.localizedDescription
            return
        }
        do {
            if !usesInternalVariant, trimmedName != selectedVariant.name {
                try ProductVariantService.rename(selectedVariant, to: trimmedName, for: product, in: modelContext)
            }
            if quantity != selectedVariant.quantity {
                try StockService.registerAdjustment(newQuantity: quantity, to: selectedVariant,
                                                    product: product, in: modelContext)
            }
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            if let error = error as? ProductVariantError {
                errorMessage = error.localizedMessage
            } else if let error = error as? StockError {
                errorMessage = error.localizedMessage
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    EditProductVariantView(product: Product(name: "Bolsa"))
        .modelContainer(for: [Product.self, ProductVariant.self, StockMovement.self], inMemory: true)
}
