// ⌘
//  TinyStock/Views/Shared/AppStyle.swift
//
//  Propósito: Camada de estilo única do app: medidas, cards sólidos, vidro só nos controles e
//             componentes reutilizáveis (rótulo de seção, card agrupado, ícones e botões - / +).
//             Liquid Glass no iOS 26+; material translúcido e botões padrão no iOS 18.
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

/// Título pequeno acima de um card agrupado. `tinted` usa a cor de destaque, como nos Ajustes.
struct AppSectionLabel: View {
    let text: String
    var tinted = false

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tinted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
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
    /// Antes do iOS 26, material translúcido. `interactive` reage ao toque (só no vidro).
    @ViewBuilder
    func appGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }

    /// Botão principal em cápsula (vidro com cor no iOS 26+).
    @ViewBuilder
    func appProminentButton(_ color: Color, size: ControlSize = .large) -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(size)
                .tint(color)
        } else {
            buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(size)
                .tint(color)
        }
    }

    /// Botão secundário em cápsula (vidro neutro no iOS 26+). `circle` deixa redondo (botões só de ícone).
    @ViewBuilder
    func appSecondaryButton(_ color: Color, circle: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
                .buttonBorderShape(circle ? .circle : .capsule)
                .controlSize(.large)
                .tint(color)
        } else {
            buttonStyle(.bordered)
                .buttonBorderShape(circle ? .circle : .capsule)
                .controlSize(.large)
                .tint(color)
        }
    }

    /// Botão de vidro neutro no tamanho do contexto (iOS 26+); botão padrão no iOS 18.
    @ViewBuilder
    func appGlassButton() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    /// Subtítulo da barra de navegação. Só existe a partir do iOS 26; antes, fica só o título.
    @ViewBuilder
    func appNavigationSubtitle(_ subtitle: String) -> some View {
        if #available(iOS 26.0, *) {
            navigationSubtitle(subtitle)
        } else {
            self
        }
    }

    /// Botão redondo (vidro no iOS 26+). O tamanho vem do conteúdo.
    @ViewBuilder
    func appCircleButton() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .tint(.primary)
        } else {
            buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(.primary)
        }
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
                // A cor fixa do simbolo apagaria o visual de desativado do sistema.
                .opacity(isEnabled ? 1 : 0.35)
                .frame(width: size, height: size)
                // Vidro sem .interactive(): o interativo fica com o toque e a acao nao roda dentro de
                // uma linha de Form.
                .appGlass(in: Circle())
                .contentShape(Circle())
        }
        // Borderless: dentro de uma linha de Form o toque chega a cada botao, e nao a linha inteira.
        .buttonStyle(.borderless)
        .tint(color)
        .disabled(!isEnabled)
    }
}

// MARK: - AppMenuRow

/// Linha de vidro arredondada que abre um menu: ícone, rótulo à esquerda e valor atual à direita.
/// Usada no período dos Relatórios e no filtro do Calendário.
struct AppMenuRow<MenuContent: View>: View {

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let systemName: String
    let title: String
    let value: String
    @ViewBuilder var menuContent: MenuContent

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 24, style: .continuous) }

    var body: some View {
        Menu {
            menuContent
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).foregroundStyle(.secondary)
                        Text(value)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: systemName)
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        Text(title)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                        Spacer(minLength: 12)
                        Text(value)
                            .lineLimit(1)
                            .multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .frame(minHeight: 48)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .appGlass(in: shape, interactive: true)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}
