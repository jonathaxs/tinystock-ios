// Proposito: Cadastrar uma nova variacao em um produto existente, com estoque inicial.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-26.

import SwiftData
import SwiftUI
import TinyStockCore

struct NewProductVariantView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var products: [Product]
    @Query private var variants: [ProductVariant]
    @State private var productID: UUID?
    @State private var name = ""
    @State private var quantity = 1
    @State private var errorMessage: String?

    init(storeID: UUID, productID: UUID? = nil) {
        _products = Query(filter: #Predicate<Product> { $0.storeID == storeID },
                          sort: [SortDescriptor(\Product.sortOrder), SortDescriptor(\Product.name)])
        _variants = Query(filter: #Predicate<ProductVariant> { $0.storeID == storeID })
        _productID = State(initialValue: productID)
    }

    private var selectedProduct: Product? {
        products.first { $0.id == productID }
    }

    /// Um produto sem variacoes precisa ativar a opcao na edicao antes de receber outra.
    private var selectedUsesDefaultVariant: Bool {
        variants.contains { $0.productID == productID && $0.isDefault }
    }

    private var canSave: Bool {
        selectedProduct != nil && !selectedUsesDefaultVariant
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Cada campo tem o proprio cabecalho para deixar claro o que pode ser tocado e alterado.
                Section {
                    Picker(String(localized: "order.form.section.product", bundle: .tinyStockCore), selection: $productID) {
                        ForEach(products) { product in
                            Text(product.name).tag(Optional(product.id))
                        }
                    }
                    .labelsHidden()
                } header: {
                    Text(String(localized: "order.form.section.product", bundle: .tinyStockCore))
                } footer: {
                    if selectedUsesDefaultVariant {
                        Text(String(localized: "product.variant.new.defaultFooter", bundle: .tinyStockCore))
                    }
                }
                Section(String(localized: "product.variant.edit.name", bundle: .tinyStockCore)) {
                    TextField(String(localized: "product.form.variant.name", bundle: .tinyStockCore), text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                }
                Section(String(localized: "product.form.variant.initialStock", bundle: .tinyStockCore)) {
                    StockQuantityPicker(
                        title: String(localized: "product.form.variant.initialStock", bundle: .tinyStockCore),
                        quantity: $quantity,
                        showsTitle: false
                    )
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(String(localized: "stock.entry.newVariant", bundle: .tinyStockCore))
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
            // Aberta pelo botao de adicionar, a tela comeca pelo primeiro produto do catalogo.
            if productID == nil { productID = products.first?.id }
        }
    }

    private func save() {
        guard canSave, let selectedProduct else { return }
        // Salva pendencias anteriores antes do lote para nao desfaze-las caso este cadastro falhe.
        do { try modelContext.save() } catch {
            errorMessage = error.localizedDescription
            return
        }
        do {
            try ProductVariantService.create(for: selectedProduct, name: name,
                                             initialQuantity: quantity, in: modelContext)
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
    NewProductVariantView(storeID: UUID())
        .modelContainer(for: [Product.self, ProductVariant.self, StockMovement.self], inMemory: true)
}
