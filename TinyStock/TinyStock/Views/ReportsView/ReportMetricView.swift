// ⌘
//  TinyStock/Views/ReportsView/ReportMetricView.swift
//
//  Propósito: Exibir uma métrica financeira ou de volume no resumo dos relatórios.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-15.
// ⌘

import SwiftUI

struct ReportMetricView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let value: String
    let symbolName: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                Image(systemName: symbolName)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)

                metricTitle
            } else {
                HStack {
                    metricTitle

                    Spacer(minLength: 8)

                    Image(systemName: symbolName)
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                }
            }

            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private var metricTitle: some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    ReportMetricView(
        title: "Total vendido",
        value: "R$ 1.240,00",
        symbolName: "brazilianrealsign",
        tint: .green
    )
    .padding()
}
