// Proposito: Folha inferior com botoes grandes, usada para acoes e escolhas em todo o app.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-29.

import SwiftUI
import TinyStockCore

/// Botoes grandes em blocos, com Cancelar no fim e altura ajustada ao conteudo.
struct BottomActionSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @ViewBuilder let content: Content
    @State private var contentHeight: CGFloat = 480

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                content
                Button(String(localized: "common.cancel", bundle: .tinyStockCore)) { dismiss() }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 12)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        // A altura acompanha o conteudo; com letras maiores a folha pode abrir por inteiro.
        .presentationDetents([.height(contentHeight), .large])
        .presentationDragIndicator(.visible)
    }
}

/// Titulo discreto no topo da folha, para escolhas que precisam de contexto.
struct BottomActionSheetTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

struct SheetActionButton: View {
    let title: String
    let systemImage: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.title3.weight(.semibold))
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .buttonStyle(SheetActionButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Fundo em bloco com cantos arredondados, no padrao das folhas de acao do sistema.
struct SheetActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundStyle(.tint)
            .background(.fill.tertiary, in: .rect(cornerRadius: 16))
            .opacity(configuration.isPressed || !isEnabled ? 0.5 : 1)
            .contentShape(.rect(cornerRadius: 16))
    }
}

/// Subtitulo tocavel logo abaixo do titulo grande, que abre uma folha de escolha.
struct TitleSelectorButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.bold))
                    .accessibilityHidden(true)
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(.tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))
        .listRowSeparator(.hidden)
    }
}
