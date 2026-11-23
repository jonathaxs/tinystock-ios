// ⌘
//  TinyStock/Views/WelcomeView/WelcomeComponents.swift
//
//  Propósito: Peças da apresentação inicial: etapas, cabeçalho com emoji em vidro, barra de progresso,
//             botão Continuar, linha de dica e o espaço que as etapas reservam para os botões do rodapé.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-11-07.
// ⌘

import SwiftUI
import TinyStockCore

// MARK: - Etapas

enum WelcomeStep: Int, CaseIterable {
    case start, store, product, variants, ready

    /// Etapas mostradas. A parte do produto fica de fora quando a loja já tem produtos (reaberta pelo Sobre).
    static func flow(includesProductTour: Bool) -> [WelcomeStep] {
        includesProductTour ? allCases : [.start, .store, .ready]
    }

    /// Dicas do primeiro produto: têm o Pular, que vai direto para o fim.
    var isProductTour: Bool { self == .product || self == .variants }

    var emoji: String {
        switch self {
        case .start: "📦"
        case .store: "🛍️"
        case .product: "🏷️"
        case .variants: "🎨"
        case .ready: "🚀"
        }
    }

    var title: String {
        switch self {
        case .start: String(localized: "welcome.step.start.title", bundle: .tinyStockCore)
        case .store: String(localized: "welcome.step.store.title", bundle: .tinyStockCore)
        case .product: String(localized: "welcome.step.product.title", bundle: .tinyStockCore)
        case .variants: String(localized: "welcome.step.variants.title", bundle: .tinyStockCore)
        case .ready: String(localized: "welcome.step.ready.title", bundle: .tinyStockCore)
        }
    }

    var subtitle: String {
        switch self {
        case .start: String(localized: "welcome.step.start.subtitle", bundle: .tinyStockCore)
        case .store: String(localized: "welcome.step.store.subtitle", bundle: .tinyStockCore)
        case .product: String(localized: "welcome.step.product.subtitle", bundle: .tinyStockCore)
        case .variants: String(localized: "welcome.step.variants.subtitle", bundle: .tinyStockCore)
        case .ready: String(localized: "welcome.step.ready.subtitle", bundle: .tinyStockCore)
        }
    }
}

// MARK: - Cabeçalho

/// Cabeçalho centralizado de cada etapa: emoji num círculo de vidro, título grande e subtítulo.
struct WelcomeStepHeader: View {

    let step: WelcomeStep
    var accentColor: Color = .accentColor

    var body: some View {
        VStack(spacing: 12) {
            // No Tudo pronto o emoji fica menor, para os cartões e os botões caberem sem rolar.
            let side: CGFloat = step == .ready ? 64 : 88
            Text(step.emoji)
                .font(.system(size: side / 2))
                .frame(width: side, height: side)
                .background(Circle().fill(accentColor.opacity(0.15)))
                .appGlass(in: Circle())
                // Decorativo: o título logo abaixo já diz a etapa.
                .accessibilityHidden(true)
                .padding(.bottom, 4)

            Text(step.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(step.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                // No Início a frase fica estreita, pouco mais larga que o botão Começar.
                .frame(maxWidth: step == .start ? 300 : nil)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Painel do layout largo

/// Painel à esquerda no layout largo (iPad, Duo aberto): cabeçalho da etapa atual e os botões no rodapé.
/// No Início fica só o par de botões, centralizado, porque o "Olá!" já está no conteúdo à direita; ao
/// avançar os botões descem para o rodapé e o cabeçalho entra.
struct WelcomeContextPanel<Buttons: View>: View {

    let currentStep: WelcomeStep
    let accentColor: Color
    @ViewBuilder var buttons: Buttons

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isStart: Bool { currentStep == .start }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if !isStart {
                    WelcomeStepHeader(step: currentStep, accentColor: accentColor)
                        .id(currentStep)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal)

            buttons
                .frame(maxWidth: isStart ? 260 : .infinity)
                .padding(.horizontal)
                .padding(.bottom, isStart ? 0 : 24)

            // No Início um espaço igual ao de cima centraliza os botões; ao avançar ele some e os botões
            // descem para o rodapé.
            if isStart {
                Spacer(minLength: 0)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.6).ignoresSafeArea())
        // Com o teclado aberto (Sua loja) os botões continuam no rodapé do painel.
        .ignoresSafeArea(.keyboard)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.55, dampingFraction: 0.85),
                   value: currentStep)
    }
}

// MARK: - Barra de progresso

struct WelcomeProgressBar: View {
    let steps: [WelcomeStep]
    let currentStep: WelcomeStep
    let activeColor: Color

    var body: some View {
        let current = (steps.firstIndex(of: currentStep) ?? 0) + 1

        HStack(spacing: 6) {
            ForEach(0..<steps.count, id: \.self) { index in
                Capsule()
                    .fill(index < current ? activeColor : Color.secondary.opacity(0.25))
                    // A etapa atual fica mais longa, como nos indicadores do sistema.
                    .frame(maxWidth: index == current - 1 ? .infinity : nil)
                    .frame(width: index == current - 1 ? nil : 22, height: 6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "a11y.welcome.progress", bundle: .tinyStockCore),
                                   current, steps.count))
    }
}

// MARK: - Botão Continuar

struct WelcomeContinueButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .appProminentButton(color)
    }
}

// MARK: - Linha de dica

/// Ícone colorido, título e uma frase curta, como nas apresentações do sistema.
struct WelcomeTipRow<Accessory: View>: View {
    let icon: String
    let color: Color
    let key: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            IconBadge(systemName: icon, color: color, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: String.LocalizationValue(key + ".title"), bundle: .tinyStockCore))
                    .font(.headline)
                Text(String(localized: String.LocalizationValue(key + ".desc"), bundle: .tinyStockCore))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                accessory
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
    }
}

extension WelcomeTipRow where Accessory == EmptyView {
    init(icon: String, color: Color, key: String) {
        self.init(icon: icon, color: color, key: key) { EmptyView() }
    }
}

// MARK: - Espaço reservado para os botões

extension EnvironmentValues {
    /// Altura do par de botões do rodapé, para a etapa reservar o mesmo espaço.
    @Entry var welcomeButtonsHeight: CGFloat = 112
    /// Avisa a WelcomeView onde a etapa reservou o espaço dos botões.
    @Entry var welcomeButtonsSlotReporter = WelcomeButtonsSlotReporter()
}

/// Closure embrulhada num Equatable que nunca muda, para o environment não invalidar a cada atualização.
struct WelcomeButtonsSlotReporter: Equatable {
    var report: (WelcomeStep, CGRect) -> Void = { _, _ in }
    static func == (lhs: Self, rhs: Self) -> Bool { true }
}

/// Espaço vazio do tamanho dos botões. Os botões de verdade ficam no rodapé da WelcomeView e
/// deslizam até aqui (Início e Tudo pronto).
struct WelcomeButtonsSlot: View {

    let step: WelcomeStep

    @Environment(\.welcomeButtonsHeight) private var height
    @Environment(\.welcomeButtonsSlotReporter) private var reporter

    var body: some View {
        Color.clear
            .frame(height: height)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { reporter.report(step, $0) }
            .accessibilityHidden(true)
    }
}

// MARK: - Layout comum das etapas

/// Conteúdo rolável e centralizado na altura, com as margens das etapas.
struct WelcomeStepScroll<Content: View>: View {

    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                content
                    .padding(.horizontal, AppStyle.horizontalPadding)
                    .padding(.vertical)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
