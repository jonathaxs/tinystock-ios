// Proposito: Identificar o produto no topo das folhas de estoque e variacao.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-29.

import SwiftUI
import TinyStockCore

struct ProductSheetHeader: View {
    let product: Product

    var body: some View {
        Section {
            HStack(spacing: 12) {
                ProductImageView(imageData: product.imageData, side: 48)
                Text(product.name)
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            .accessibilityElement(children: .combine)
        }
    }
}
