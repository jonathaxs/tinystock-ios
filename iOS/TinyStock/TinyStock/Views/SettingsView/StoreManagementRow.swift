// ⌘
//  TinyStock/Views/SettingsView/StoreManagementRow.swift
//
//  Propósito: Apresentar a identificação e o estado de uma loja nas listas de gerenciamento.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-09-12.
// ⌘

import SwiftUI
import TinyStockCore

struct StoreManagementRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let store: StoreProfile
    var isSelected = false
    var detail: String?

    var body: some View {
        HStack(spacing: 12) {
            StoreImageView(imageData: store.imageData)

            VStack(alignment: .leading, spacing: 3) {
                Text(store.name)
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)

                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(
                        String(localized: "stores.current", bundle: .tinyStockCore)
                    )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(.rect)
    }
}
