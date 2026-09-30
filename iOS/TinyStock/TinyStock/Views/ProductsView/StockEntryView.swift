// Proposito: Registrar recebimento de unidades em uma variacao existente.
// Created by Jonathas Motta (@jonathaxs) on 2026-08-31.

import SwiftUI
import SwiftData
import TinyStockCore

struct StockEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let product: Product
    private let initialVariantID: UUID?
    @Query private var variants: [ProductVariant]
    @State private var selectedVariantID: UUID?
    @State private var quantity = 1
    @State private var note = ""
    @State private var didSelectInitialVariant = false
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

    private var usesInternalVariant: Bool {
        variants.count == 1 && variants.first?.isDefault == true
    }

    private var resultingBalance: Int? {
        guard quantity > 0 else { return nil }
        let result = (selectedVariant?.quantity ?? 0).addingReportingOverflow(quantity)
        return result.overflow ? nil : result.partialValue
    }

    // Variacoes novas sao cadastradas pela opcao propria do catalogo.
    private var canSave: Bool {
        resultingBalance != nil && selectedVariant != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                ProductSheetHeader(product: product)
                // Cada campo tem o proprio cabecalho para deixar claro o que pode ser tocado e alterado.
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
                    StockQuantityPicker(
                        title: String(localized: "stock.entry.quantity", bundle: .tinyStockCore),
                        quantity: $quantity,
                        range: 1...100,
                        showsTitle: false
                    )
                } header: {
                    Text(String(localized: "stock.entry.quantity", bundle: .tinyStockCore))
                } footer: {
                    // Saldos somente informativos, calculados a partir da variacao escolhida.
                    Text(balanceSummary)
                }
                Section(String(localized: "stock.entry.note", bundle: .tinyStockCore)) {
                    TextField(String(localized: "stock.entry.notePlaceholder", bundle: .tinyStockCore),
                              text: $note, axis: .vertical)
                }
            }
            // O titulo completo nao cabe entre Cancelar e Salvar; o menu do produto mantem o nome inteiro.
            .navigationTitle(String(localized: "stock.entry.navigationTitle", bundle: .tinyStockCore))
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
            // Aberta pelos detalhes, a entrada ja comeca na variacao tocada.
            selectedVariantID = initialVariantID ?? variants.first?.id
            didSelectInitialVariant = true
        }
    }

    private var balanceSummary: String {
        let current = String(format: String(localized: "stock.entry.currentSummary", bundle: .tinyStockCore),
                             (selectedVariant?.quantity ?? 0).formatted())
        guard let resultingBalance else { return current }
        let result = String(format: String(localized: "stock.entry.resultSummary", bundle: .tinyStockCore),
                            resultingBalance.formatted())
        return current + "\n" + result
    }

    private func variantLabel(_ variant: ProductVariant) -> String {
        let format = String(localized: "order.form.variant.option", bundle: .tinyStockCore)
        return String(format: format, variant.name, variant.quantity.formatted())
    }

    private func save() {
        guard canSave else { return }
        // O rascunho nao grava nada. Salva pendencias anteriores antes do lote de entrada.
        do { try modelContext.save() } catch {
            errorMessage = error.localizedDescription
            return
        }
        do {
            try StockService.registerEntry(quantity: quantity, for: product, variantID: selectedVariantID,
                                           note: note, in: modelContext)
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
