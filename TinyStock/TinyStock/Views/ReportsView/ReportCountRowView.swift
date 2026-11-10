// Proposito: Mostrar a quantidade de eventos operacionais ocorridos no periodo.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-06.

import SwiftUI

struct ReportCountRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let count: Int
    let symbolName: String
    let tint: Color

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    rowTitle
                    countText
                }
            } else {
                HStack(spacing: 12) {
                    rowTitle
                    Spacer(minLength: 12)
                    countText
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var rowTitle: some View {
        HStack(spacing: 12) {
            GlassIcon(systemName: symbolName, color: tint)
            Text(title).font(.headline)
        }
    }

    private var countText: some View {
        Text(count, format: .number)
            .font(.headline)
            .monospacedDigit()
    }
}
