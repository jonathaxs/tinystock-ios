// Proposito: Exibir foto, estoque por variacao, precos e potencial de venda de um produto.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-26.

import SwiftData
import SwiftUI
import TinyStockCore

struct ProductDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let product: Product
    @Query private var variants: [ProductVariant]

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
                Section {
                    VStack(spacing: 12) {
                        ProductImageView(imageData: product.imageData, side: 160)
                        Text(product.name)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                Section(String(localized: "product.details.stock", bundle: .tinyStockCore)) {
                    if !usesInternalVariant {
                        ForEach(variants) { variant in
                            LabeledContent(variant.name) {
                                Text(variant.quantity, format: .number).monospacedDigit()
                            }
                        }
                    }
                    LabeledContent(String(localized: "product.details.totalStock", bundle: .tinyStockCore)) {
                        Text(totalStock, format: .number)
                            .monospacedDigit()
                            .fontWeight(.semibold)
                    }
                }
                Section(String(localized: "product.form.section.prices", bundle: .tinyStockCore)) {
                    LabeledContent(String(localized: "product.form.salePrice", bundle: .tinyStockCore),
                                   value: product.salePrice.currencyText)
                    LabeledContent(String(localized: "product.form.costPrice", bundle: .tinyStockCore),
                                   value: product.costPrice.currencyText)
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
        }
    }
}

#Preview {
    ProductDetailView(product: Product(name: "Bolsa", costPrice: 20, salePrice: 60))
        .modelContainer(for: [Product.self, ProductVariant.self, StockMovement.self], inMemory: true)
}
