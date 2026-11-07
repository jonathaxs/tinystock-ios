// Proposito: Permitir a escolha da cor de destaque usada na interface.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-19.

import SwiftUI
import TinyStockCore

struct ColorSettingsView: View {
    @AppStorage(AppAccentColor.storageKey) private var selectedRawValue = AppAccentColor.defaultColor.rawValue

    private let columns = Array(repeating: GridItem(.flexible()), count: 4)

    private var selectedColor: AppAccentColor {
        AppAccentColor(rawValue: selectedRawValue) ?? .defaultColor
    }

    var body: some View {
        List {
            Section(String(localized: "settings.color.section", bundle: .tinyStockCore)) {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(AppAccentColor.allCases, id: \.self) { color in
                        colorButton(color)
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .navigationTitle(String(localized: "settings.color.title", bundle: .tinyStockCore))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func colorButton(_ color: AppAccentColor) -> some View {
        let isSelected = selectedColor == color

        return Button {
            selectedRawValue = color.rawValue
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.color)
                        .frame(width: 52, height: 52)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.bold))
                            .foregroundStyle(color.checkmarkColor)
                    }
                }
                .overlay {
                    Circle()
                        .stroke(isSelected ? color.color : .clear, lineWidth: 2.5)
                        .padding(-4)
                }

                Text(color.localizedName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.localizedName)
        .accessibilityValue(String(
            localized: isSelected ? "accessibility.selected" : "accessibility.notSelected",
            bundle: .tinyStockCore
        ))
        .accessibilityHint(String(localized: "settings.color.hint", bundle: .tinyStockCore))
    }
}

extension AppAccentColor {
    var color: Color {
        switch self {
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .cyan: .cyan
        case .pink: .pink
        }
    }

    fileprivate var checkmarkColor: Color {
        self == .yellow || self == .cyan ? .black : .white
    }
}
