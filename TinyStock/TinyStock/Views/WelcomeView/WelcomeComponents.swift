// ⌘
//  TinyStock/Views/WelcomeView/WelcomeComponents.swift
//
//  Propósito: Peças da apresentação inicial: etapas, cabeçalho com emoji em vidro, barra de progresso,
//             botão Continuar e o espaço que as etapas reservam para os botões do rodapé subirem.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-11-07.
// ⌘

import SwiftUI
import TinyStockCore

// MARK: - Etapas

enum WelcomeStep: Int, CaseIterable {
    case start, about, store, ready

    var emoji: String {
        switch self {
        case .start: "📦"
        case .about: "✨"
        case .store: "🛍️"
        case .ready: "🚀"
        }
    }

    var title: String {
        switch self {
        case .start: String(localized: "welcome.step.start.title", bundle: .tinyStockCore)
        case .about: String(localized: "welcome.step.about.title", bundle: .tinyStockCore)
        case .store: String(localized: "welcome.step.store.title", bundle: .tinyStockCore)
        case .ready: String(localized: "welcome.step.ready.title", bundle: .tinyStockCore)
        }
    }

    var subtitle: String {
        switch self {
        case .start: String(localized: "welcome.step.start.subtitle", bundle: .tinyStockCore)
        case .about: ""
        case .store: String(localized: "welcome.step.store.subtitle", bundle: .tinyStockCore)
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
            Text(step.emoji)
                .font(.system(size: 44))
                .frame(width: 88, height: 88)
                .background(Circle().fill(accentColor.opacity(0.15)))
                .appGlass(in: Circle())
                // Decorativo: o título logo abaixo já diz a etapa.
                .accessibilityHidden(true)
                .padding(.bottom, 4)

            Text(step.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            if !step.subtitle.isEmpty {
                Text(step.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Barra de progresso

struct WelcomeProgressBar: View {
    let currentStep: WelcomeStep
    let activeColor: Color

    var body: some View {
        let steps = WelcomeStep.allCases
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
