// Proposito: Escolher uma quantidade de estoque pela roleta, fechando o teclado ao abrir.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-26.

import SwiftUI

/// Linha com o valor atual que revela a roleta ao ser tocada, sem depender do teclado.
struct StockQuantityPicker: View {
    let title: String
    @Binding var quantity: Int
    var range: ClosedRange<Int> = 0...100
    @State private var isExpanded = false

    var body: some View {
        Button {
            // A roleta fica abaixo dos campos de texto e seria coberta pelo teclado aberto.
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            withAnimation { isExpanded.toggle() }
        } label: {
            LabeledContent(title) {
                Text(quantity, format: .number)
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.primary)
        if isExpanded {
            Picker(title, selection: $quantity) {
                ForEach(range, id: \.self) { value in
                    Text(value, format: .number).tag(value)
                }
            }
            .pickerStyle(.wheel)
        }
    }
}
