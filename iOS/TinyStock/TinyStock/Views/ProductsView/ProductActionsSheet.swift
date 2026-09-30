// Proposito: Folha inferior com as acoes de um produto em botoes grandes.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-29.

import SwiftUI
import TinyStockCore

struct ProductActionsSheet: View {
    enum Action {
        case details, sale, stockEntry, newVariant, editVariant, edit
    }

    let product: Product
    let quantity: Decimal
    let onSelect: (Action) -> Void

    var body: some View {
        BottomActionSheet {
            ProductRowView(product: product, quantity: quantity)
                .padding(.bottom, 4)
            button(.details, "products.details", "info.circle")
            button(.sale, "sale.new.title", "cart.badge.plus")
            button(.stockEntry, "stock.entry.new", "shippingbox.and.arrow.backward")
            button(.newVariant, "stock.entry.newVariant", "plus.square.on.square")
            button(.editVariant, "product.variant.edit.title", "square.and.pencil")
            button(.edit, "product.form.title.edit", "pencil")
        }
    }

    private func button(_ action: Action, _ titleKey: String, _ systemImage: String) -> some View {
        SheetActionButton(title: String(localized: String.LocalizationValue(titleKey), bundle: .tinyStockCore),
                          systemImage: systemImage) { onSelect(action) }
    }
}

#Preview {
    Text("Catalogo")
        .sheet(isPresented: .constant(true)) {
            ProductActionsSheet(product: Product(name: "Bolsa", salePrice: 60), quantity: 3) { _ in }
        }
}
