// ⌘
//  TinyStock/Views/Shared/SheetToolbarButtons.swift
//
//  Propósito: Botões do topo das sheets com o ícone do sistema (X), que no iPhone Duo dobrado vão
//             para a barra vertical ao lado da tela.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-11-07.
// ⌘

import SwiftUI
import TinyStockCore

/// Fechar uma sheet. O título vira o nome lido pelo VoiceOver.
struct SheetCloseButton: View {

    var title: String = String(localized: "common.close", bundle: .tinyStockCore)
    let action: () -> Void

    var body: some View {
        Button(role: .close, action: action)
            .accessibilityLabel(title)
    }
}
