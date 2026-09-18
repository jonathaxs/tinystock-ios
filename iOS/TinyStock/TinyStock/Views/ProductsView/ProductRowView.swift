// Proposito: Exibir nome, foto, preco e saldo real das variacoes.
// Created by Jonathas Motta (@jonathaxs) on 2026-08-08.

import SwiftUI
import TinyStockCore

struct ProductRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let product: Product
    let quantity: Decimal

    private var quantityText: String {
        String(format: String(localized: "products.catalog.quantity", bundle: .tinyStockCore), quantity.formatted())
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    ProductImageView(imageData: product.imageData)
                    details
                }
            } else {
                HStack(spacing: 12) {
                    ProductImageView(imageData: product.imageData)
                    details
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(quantityText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(product.salePrice.currencyText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityLabel(
                    String(localized: "product.form.salePrice", bundle: .tinyStockCore)
                )
                .accessibilityValue(product.salePrice.currencyText)
        }
    }
}

#Preview {
    List {
        ProductRowView(product: Product(name: "Caneca", salePrice: 25), quantity: 3)
        ProductRowView(product: Product(name: "Produto personalizado", salePrice: 45), quantity: 0)
    }
}
