// ⌘
//  TinyStock/Views/ProductsView/ProductImageView.swift
//
//  Propósito: Exibir a foto do produto, ou um espaço reservado quando ele ainda não tem foto.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-10.
// ⌘

import SwiftUI
import TinyStockCore

struct ProductImageView: View {

    let imageData: Data?

    /// Lado do quadrado. A lista usa pequeno, o detalhe usa grande.
    var side: CGFloat = 52

    private var cornerRadius: CGFloat {
        // Mantém miniaturas e imagens maiores com a mesma proporção.
        side / 4.5
    }

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        // O nome adjacente já identifica o produto para o VoiceOver.
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            Color(.secondarySystemFill)

            Image(systemName: "shippingbox")
                .font(.system(size: side * 0.4))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        ProductImageView(imageData: nil)
        ProductImageView(imageData: nil, side: 100)
    }
    .padding()
}
