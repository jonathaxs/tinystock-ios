// ⌘
//  TinyStock/Views/Shared/AppStyle.swift
//
//  Propósito: Camada de estilo única do app: medidas, cards sólidos, vidro só nos controles e
//             componentes reutilizáveis (rótulo de seção, card agrupado, ícones e botões - / +).
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-11-07.
// ⌘

import SwiftUI

// MARK: - Medidas compartilhadas

enum AppStyle {
    /// Raio dos cards (cantos contínuos, como no sistema).
    static let cardRadius: CGFloat = 22
    /// Espaço horizontal das telas.
    static let horizontalPadding: CGFloat = 20
}

// MARK: - Rótulo de seção

/// Título pequeno acima de um card agrupado.
struct AppSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Card agrupado com divisores

/// Card no estilo lista agrupada: junta as linhas num bloco só, com divisor entre elas.
struct AppGroupedCard<Content: View>: View {

    /// Recuo do divisor, alinhado ao texto depois do ícone.
    var dividerInset: CGFloat = 52
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { subviews in
                ForEach(subviews) { subview in
                    if subview.id != subviews.first?.id {
                        Divider().padding(.leading, dividerInset)
                    }
                    subview
                }
            }
        }
        .appCard()
    }
}

// MARK: - Modificadores de estilo

extension View {

    /// Fundo de card sólido. Selecionado ganha tom e borda da cor de destaque.
    func appCard(isSelected: Bool = false, accentColor: Color = .accentColor) -> some View {
        let shape = RoundedRectangle(cornerRadius: AppStyle.cardRadius, style: .continuous)
        return self
            .background {
                ZStack {
                    shape.fill(Color(.secondarySystemGroupedBackground))
                    if isSelected { shape.fill(accentColor.opacity(0.12)) }
                }
            }
            .overlay {
                shape.strokeBorder(isSelected ? accentColor : .clear, lineWidth: 2)
            }
            .clipShape(shape)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    /// Vidro (Liquid Glass) na forma pedida. Só para controles; conteúdo fica em card sólido.
    func appGlass<S: Shape>(in shape: S) -> some View {
        glassEffect(.regular, in: shape)
    }

    /// Botão principal em cápsula de vidro com cor.
    func appProminentButton(_ color: Color, size: ControlSize = .large) -> some View {
        buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .controlSize(size)
            .tint(color)
    }

    /// Botão secundário em cápsula de vidro neutro. `circle` deixa redondo (botões só de ícone).
    func appSecondaryButton(_ color: Color, circle: Bool = false) -> some View {
        buttonStyle(.glass)
            .buttonBorderShape(circle ? .circle : .capsule)
            .controlSize(.large)
            .tint(color)
    }

    /// Botão redondo de vidro. O tamanho vem do conteúdo.
    func appCircleButton() -> some View {
        buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .tint(.primary)
    }
}

// MARK: - IconBadge

/// SF Symbol branco num quadrado colorido, como nos Ajustes do sistema.
struct IconBadge: View {

    let systemName: String
    let color: Color
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - GlassIcon

/// Símbolo na cor pedida dentro de um círculo de vidro, para linhas de lista.
struct GlassIcon: View {

    let systemName: String
    let color: Color
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(Circle().fill(color.opacity(0.14)))
            .appGlass(in: Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - RoundStepButton

/// Botão redondo de vidro com -, + ou lixeira.
struct RoundStepButton: View {

    enum Kind {
        case minus, plus, trash

        var symbolName: String {
            switch self {
            case .minus: "minus"
            case .plus: "plus"
            case .trash: "trash"
            }
        }
    }

    let kind: Kind
    var size: CGFloat = 44
    var color: Color = .accentColor
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        // O estilo .glass soma respiro em volta do botão; aqui o vidro vai direto no círculo,
        // com o tamanho exato pedido.
        Button(action: action) {
            Image(systemName: kind.symbolName)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .tint(color)
        .disabled(!isEnabled)
    }
}
