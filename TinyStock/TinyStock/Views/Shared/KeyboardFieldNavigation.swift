// TinyStock/Views/Shared/KeyboardFieldNavigation.swift
//
// Proposito: Barra acima do teclado com setas para o campo anterior e o proximo, e o OK que fecha.
//
// Created by Jonathas Motta (@jonathaxs) on 2026-11-20.

import SwiftUI
import TinyStockCore

/// Barra que aparece enquanto um campo do formulario tem foco. Fica na area segura de baixo (e nao na
/// barra do teclado, que no iOS 26 flutua por cima do conteudo), entao o formulario rola o campo com
/// foco ate ficar visivel acima dela. O teclado decimal dos precos nao tem tecla de retorno, e as setas
/// resolvem esse caso tambem.
private struct KeyboardFieldNavigation<Field: Hashable>: ViewModifier {
    let focus: FocusState<Field?>.Binding
    let order: [Field]

    private var index: Int? {
        focus.wrappedValue.flatMap { order.firstIndex(of: $0) }
    }

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if index != nil {
                bar.transition(.opacity)
            }
        }
    }

    private var bar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                arrow("chevron.up", label: "keyboard.previous", offset: -1)
                arrow("chevron.down", label: "keyboard.next", offset: 1)
            }
            .appGlass(in: Capsule(), interactive: true)

            Spacer()

            Button {
                focus.wrappedValue = nil
            } label: {
                Text(String(localized: "common.ok", bundle: .tinyStockCore))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
            }
            .appGlass(in: Capsule(), interactive: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func arrow(_ symbol: String, label: String, offset: Int) -> some View {
        let target = (index ?? 0) + offset
        return Button {
            focus.wrappedValue = order[target]
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 48, height: 44)
        }
        .disabled(!order.indices.contains(target))
        .accessibilityLabel(String(localized: String.LocalizationValue(label), bundle: .tinyStockCore))
    }
}

extension View {
    /// Setas e OK acima do teclado para os campos de [order], na ordem da tela.
    func keyboardFieldNavigation<Field: Hashable>(focus: FocusState<Field?>.Binding, order: [Field]) -> some View {
        modifier(KeyboardFieldNavigation(focus: focus, order: order))
    }

    /// Tecla de retorno do teclado leva ao proximo campo; no ultimo, fecha o teclado.
    func keyboardNext<Field: Hashable>(_ field: Field, focus: FocusState<Field?>.Binding,
                                       order: [Field]) -> some View {
        let isLast = order.last == field
        return focused(focus, equals: field)
            .submitLabel(isLast ? .done : .next)
            .onSubmit {
                guard let index = order.firstIndex(of: field) else { return }
                focus.wrappedValue = isLast ? nil : order[index + 1]
            }
    }
}
