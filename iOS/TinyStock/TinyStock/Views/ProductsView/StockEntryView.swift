// Proposito: Registrar recebimento de unidades em uma variacao existente ou nova.
// Created by Jonathas Motta (@jonathaxs) on 2026-08-31.

import SwiftUI
import SwiftData
import TinyStockCore

struct StockEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let product: Product
    @Query private var variants: [ProductVariant]
    @State private var selectedVariantID: UUID?
    @State private var newVariantName = ""
    @State private var quantityText = "1"
    @State private var note = ""
    @State private var didSelectInitialVariant = false
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

    private var quantity: Int? { Int(quantityText.trimmingCharacters(in: .whitespacesAndNewlines)) }

    private var resultingBalance: Int? {
        guard let quantity, quantity > 0 else { return nil }
        let result = (selectedVariant?.quantity ?? 0).addingReportingOverflow(quantity)
        return result.overflow ? nil : result.partialValue
    }

    private var canSave: Bool {
        guard resultingBalance != nil else { return false }
        if selectedVariantID != nil { return selectedVariant != nil }
        return !newVariantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(product.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                    if !usesInternalVariant {
                        Picker(String(localized: "product.form.variant.title", bundle: .tinyStockCore), selection: $selectedVariantID) {
                            ForEach(variants) { variant in
                                Text(variant.name).tag(Optional(variant.id))
                            }
                            Text(String(localized: "stock.entry.newVariant", bundle: .tinyStockCore))
                                .tag(Optional<UUID>.none)
                        }
                        if selectedVariantID == nil {
                            TextField(String(localized: "product.form.variant.name", bundle: .tinyStockCore), text: $newVariantName)
                                .textInputAutocapitalization(.words)
                        }
                    }
                }
                Section {
                    LabeledContent(String(localized: "stock.entry.quantity", bundle: .tinyStockCore)) {
                        TextField("1", text: $quantityText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel(String(localized: "stock.entry.quantity", bundle: .tinyStockCore))
                    }
                    LabeledContent(String(localized: "product.form.variant.available", bundle: .tinyStockCore)) {
                        Text(selectedVariant?.quantity ?? 0, format: .number)
                    }
                    if let resultingBalance {
                        LabeledContent(String(localized: "stock.entry.result", bundle: .tinyStockCore)) {
                            Text(resultingBalance, format: .number)
                        }
                    }
                }
                Section {
                    TextField(String(localized: "stock.entry.note", bundle: .tinyStockCore), text: $note, axis: .vertical)
                }
            }
            .navigationTitle(String(localized: "stock.entry.title", bundle: .tinyStockCore))
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
            .alert(String(localized: "stock.entry.error", bundle: .tinyStockCore), isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button(String(localized: "common.ok", bundle: .tinyStockCore)) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .task {
            guard !didSelectInitialVariant else { return }
            selectedVariantID = variants.first?.id
            didSelectInitialVariant = true
        }
    }

    private func save() {
        guard canSave, let quantity else { return }
        // O rascunho nao grava nada. Salva pendencias anteriores antes do lote de entrada.
        do { try modelContext.save() } catch {
            errorMessage = error.localizedDescription
            return
        }
        do {
            try StockService.registerEntry(quantity: quantity, for: product, variantID: selectedVariantID,
                                           newVariantName: newVariantName, note: note, in: modelContext)
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            if let error = error as? StockError {
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
    StockEntryView(product: Product(name: "Caneca"))
        .modelContainer(for: [Product.self, ProductVariant.self, StockMovement.self], inMemory: true)
}
