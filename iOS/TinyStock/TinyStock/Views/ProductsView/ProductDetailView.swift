// Proposito: Exibir foto, estoque por variacao, precos e potencial de venda de um produto.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-26.

import SwiftData
import SwiftUI
import TinyStockCore

struct ProductDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let product: Product
    @Query private var variants: [ProductVariant]
    @State private var editingVariant: ProductVariant?
    @State private var editFocus: ProductFormView.PriceField?
    @State private var isEditingProduct = false

    init(product: Product) {
        self.product = product
        let productID = product.id
        let storeID = product.storeID
        _variants = Query(filter: #Predicate<ProductVariant> {
            $0.productID == productID && $0.storeID == storeID
        }, sort: \ProductVariant.name)
    }

    private var usesInternalVariant: Bool {
        variants.count == 1 && variants.first?.isDefault == true
    }

    private var totalStock: Int {
        variants.reduce(0) { $0 + $1.quantity }
    }

    private var unitProfit: Decimal { product.salePrice - product.costPrice }

    var body: some View {
        NavigationStack {
            List {
                // Foto e nome lado a lado; a linha inteira abre a edicao, onde fica o seletor de foto.
                Section {
                    Button { isEditingProduct = true } label: {
                        HStack(spacing: 16) {
                            ProductImageView(imageData: product.imageData, side: 80)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.name)
                                    .font(.title3.bold())
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(String(localized: "product.form.title.edit", bundle: .tinyStockCore))
                                    .font(.subheadline)
                                    .foregroundStyle(.tint)
                            }
                            Spacer(minLength: 0)
                            chevron
                        }
                        .contentShape(Rectangle())
                    }
                    .foregroundStyle(.primary)
                }
                Section(String(localized: "product.details.stock", bundle: .tinyStockCore)) {
                    // Valores na cor de destaque e seta indicam linhas que abrem uma acao.
                    if !usesInternalVariant {
                        ForEach(variants) { variant in
                            Button { editingVariant = variant } label: {
                                LabeledContent(variant.name) {
                                    tappableValue(Text(variant.quantity, format: .number).monospacedDigit())
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                    LabeledContent(String(localized: "product.details.totalStock", bundle: .tinyStockCore)) {
                        Text(totalStock, format: .number)
                            .monospacedDigit()
                            .fontWeight(.semibold)
                    }
                }
                Section(String(localized: "product.form.section.prices", bundle: .tinyStockCore)) {
                    priceRow(String(localized: "product.form.salePrice", bundle: .tinyStockCore),
                             value: product.salePrice, field: .sale)
                    priceRow(String(localized: "product.form.costPrice", bundle: .tinyStockCore),
                             value: product.costPrice, field: .cost)
                    LabeledContent(String(localized: "product.form.unitProfit", bundle: .tinyStockCore)) {
                        Text(unitProfit.currencyText)
                            .foregroundStyle(unitProfit < 0 ? Color.red : Color.secondary)
                    }
                }
                Section {
                    LabeledContent(String(localized: "product.details.potentialRevenue", bundle: .tinyStockCore),
                                   value: (product.salePrice * Decimal(totalStock)).currencyText)
                    LabeledContent(String(localized: "product.details.potentialProfit", bundle: .tinyStockCore)) {
                        Text((unitProfit * Decimal(totalStock)).currencyText)
                            .fontWeight(.semibold)
                            .foregroundStyle(unitProfit < 0 ? Color.red : Color.primary)
                    }
                } header: {
                    Text(String(localized: "product.details.potential", bundle: .tinyStockCore))
                } footer: {
                    Text(String(localized: "product.details.potentialFooter", bundle: .tinyStockCore))
                }
            }
            .navigationTitle(String(localized: "product.details.title", bundle: .tinyStockCore))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.ok", bundle: .tinyStockCore)) { dismiss() }
                }
            }
            .sheet(item: $editingVariant) { EditProductVariantView(product: product, variantID: $0.id) }
            .sheet(isPresented: $isEditingProduct) { ProductFormView(storeID: product.storeID, product: product) }
            .sheet(item: $editFocus) {
                ProductFormView(storeID: product.storeID, product: product, initialFocus: $0)
            }
        }
    }

    private func priceRow(_ title: String, value: Decimal, field: ProductFormView.PriceField) -> some View {
        Button { editFocus = field } label: {
            LabeledContent {
                tappableValue(Text(value.currencyText))
            } label: {
                Text(title).bold()
            }
        }
        .foregroundStyle(.primary)
    }

    private func tappableValue(_ value: Text) -> some View {
        HStack(spacing: 6) {
            value.foregroundStyle(.tint)
            chevron
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}

#Preview {
    ProductDetailView(product: Product(name: "Bolsa", costPrice: 20, salePrice: 60))
        .modelContainer(for: [Product.self, ProductVariant.self, StockMovement.self], inMemory: true)
}
