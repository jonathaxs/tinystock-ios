// ⌘
//  TinyStock/Views/Shared/StoreImageView.swift
//
//  Propósito: Exibir a imagem de uma loja com um placeholder consistente.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-25.
// ⌘

import SwiftUI

struct StoreImageView: View {

    let imageData: Data?
    var side: CGFloat = 44

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(.secondarySystemFill)

                    Image(systemName: "storefront")
                        .font(.system(size: side * 0.4))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: side / 4.5))
        .accessibilityHidden(true)
    }
}

#Preview {
    StoreImageView(imageData: nil, side: 72)
        .padding()
}
