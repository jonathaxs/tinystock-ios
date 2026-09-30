// Proposito: Folha inferior com as acoes de um produto em botoes grandes.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-29.

import SwiftUI
import TinyStockCore

struct ProductActionsSheet: View {
    enum Action {
        case details, sale, stockEntry, newVariant, editVariant, edit
    }

    @Environment(\.dismiss) private var dismiss
    let product: Product
    let quantity: Decimal
    let onSelect: (Action) -> Void
    @State private var contentHeight: CGFloat = 480

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ProductRowView(product: product, quantity: quantity)
                    .padding(.bottom, 4)
                actionButton(.details, "products.details", "info.circle")
                actionButton(.sale, "sale.new.title", "cart.badge.plus")
                actionButton(.stockEntry, "stock.entry.new", "shippingbox.and.arrow.backward")
                actionButton(.newVariant, "stock.entry.newVariant", "plus.square.on.square")
                actionButton(.editVariant, "product.variant.edit.title", "square.and.pencil")
                actionButton(.edit, "product.form.title.edit", "pencil")
                Button(String(localized: "common.cancel", bundle: .tinyStockCore)) { dismiss() }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 12)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        // A altura acompanha o conteudo; com letras maiores a folha pode abrir por inteiro.
        .presentationDetents([.height(contentHeight), .large])
        .presentationDragIndicator(.visible)
    }

    private func actionButton(_ action: Action, _ titleKey: String, _ systemImage: String) -> some View {
        Button {
            onSelect(action)
        } label: {
            Label(String(localized: String.LocalizationValue(titleKey), bundle: .tinyStockCore),
                  systemImage: systemImage)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 4)
        }
        .buttonStyle(ActionButtonStyle())
    }
}

/// Fundo em bloco com cantos arredondados, no padrao das folhas de acao do sistema.
private struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundStyle(.tint)
            .background(.fill.tertiary, in: .rect(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(.rect(cornerRadius: 16))
    }
}

#Preview {
    Text("Catalogo")
        .sheet(isPresented: .constant(true)) {
            ProductActionsSheet(product: Product(name: "Bolsa", salePrice: 60), quantity: 3) { _ in }
        }
}
