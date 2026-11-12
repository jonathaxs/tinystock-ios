// ⌘
//  TinyStock/Views/Shared/FormStyle.swift
//
//  Propósito: Peças dos formulários no estilo novo: cabeçalho de seção na cor de destaque, como nos
//             Ajustes, e a quantidade com - / + no lugar da roleta.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-11-12.
// ⌘

import SwiftUI
import TinyStockCore

// MARK: - Cabeçalho de seção

/// Título de seção de `Form` ou `List` na cor de destaque.
struct FormHeader: View {
    let title: String

    var body: some View {
        Text(title).foregroundStyle(.tint)
    }
}

extension Section where Parent == FormHeader, Content: View, Footer == EmptyView {
    /// Seção com o título na cor de destaque.
    init(tinted title: String, @ViewBuilder content: () -> Content) {
        self.init(content: content, header: { FormHeader(title: title) })
    }
}

extension Section where Parent == FormHeader, Content: View, Footer: View {
    /// Seção com o título na cor de destaque e um rodapé.
    init(tinted title: String, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.init(content: content, header: { FormHeader(title: title) }, footer: footer)
    }
}

// MARK: - Quantidade com - / +

/// Quantidade com botões redondos - e + e o número no meio, que também aceita digitar.
/// O título não aparece (já está no cabeçalho da seção), mas é o nome do campo no VoiceOver.
struct StockQuantityStepper: View {

    let title: String
    @Binding var quantity: Int
    var range: ClosedRange<Int> = 0...999_999

    @State private var text = ""
    @FocusState private var isEditing: Bool

    var body: some View {
        HStack(spacing: 12) {
            RoundStepButton(kind: .minus, isEnabled: quantity > range.lowerBound) { step(-1) }
                .accessibilityLabel(String(localized: "common.decrease", bundle: .tinyStockCore))
            TextField(range.lowerBound.formatted(), text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.tint)
                .focused($isEditing)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(title)
            RoundStepButton(kind: .plus, isEnabled: quantity < range.upperBound) { step(1) }
                .accessibilityLabel(String(localized: "common.increase", bundle: .tinyStockCore))
        }
        .padding(.vertical, 4)
        .onAppear { text = String(quantity) }
        .onChange(of: quantity) { _, newValue in
            if Int(text) != newValue { text = String(newValue) }
        }
        .onChange(of: text) { _, newValue in
            // Só dígitos; o valor vale na hora, sem esperar o teclado fechar.
            let digits = newValue.filter(\.isNumber)
            if digits != newValue { text = digits; return }
            guard let value = Int(digits) else { return }
            let clamped = min(max(value, range.lowerBound), range.upperBound)
            if clamped != value { text = String(clamped) }
            if clamped != quantity { quantity = clamped }
        }
        .onChange(of: isEditing) { _, editing in
            // Campo apagado volta para o valor atual ao sair.
            if !editing { text = String(quantity) }
        }
    }

    private func step(_ delta: Int) {
        let next = min(max(quantity + delta, range.lowerBound), range.upperBound)
        guard next != quantity else { return }
        quantity = next
        text = String(next)
    }
}
