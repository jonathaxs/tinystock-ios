// ⌘
//  TinyStock/Views/HomeView/HomePageButtons.swift
//
//  Propósito: Botões da Início, só com ícone: troca o catálogo entre lista e grade e abre Relatórios,
//             Calendário e Ajustes pelo AppRouter. Ficam numa linha de botões redondos de vidro (iPhone,
//             iPad em pé), na coluna de vidro do iPad deitado (HomeSideRail) ou na barra vertical do
//             sistema no iPhone Duo dobrado.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-11-07.
// ⌘

import SwiftUI
import TinyStockCore

/// Os botões da Início, na ordem da linha do Nutshell (lista/grade primeiro, Ajustes por último). É também a
/// ordem da coluna, de cima para baixo.
enum HomeRailItem: CaseIterable, Identifiable {
    case viewMode, reports, calendar, settings
    var id: Self { self }
}

/// Um botão da Início, só o ícone na cor de destaque.
struct HomeRailButton: View {

    let item: HomeRailItem
    /// Cheio na coluna (como a barra do sistema); só o contorno na linha de botões redondos.
    var filled: Bool = true
    /// Tamanho travado do ícone na linha de botões redondos (nil na coluna).
    var iconSize: CGSize? = nil

    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppAccentColor.storageKey) private var accentColorRaw = AppAccentColor.defaultColor.rawValue
    @AppStorage(CatalogViewMode.storageKey) private var viewMode: CatalogViewMode = .list

    private var accentColor: Color {
        (AppAccentColor(rawValue: accentColorRaw) ?? .defaultColor).color
    }

    var body: some View {
        Button(action: open) {
            Image(systemName: symbolName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(accentColor)
                .frame(width: iconSize?.width, height: iconSize?.height)
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel(title)
    }

    private var symbolName: String {
        let fill = filled ? ".fill" : ""
        switch item {
        // Ícone do modo para onde vai: em lista, o de grade; em grade, o de lista.
        case .viewMode: return viewMode.switchSymbolName
        case .reports: return "chart.bar" + fill
        // O calendário não tem versão cheia.
        case .calendar: return "calendar"
        case .settings: return "gearshape" + fill
        }
    }

    private var title: String {
        switch item {
        case .viewMode: viewMode.switchAccessibilityLabel
        case .reports: String(localized: "tab.reports", bundle: .tinyStockCore)
        case .calendar: String(localized: "tab.sales", bundle: .tinyStockCore)
        case .settings: String(localized: "tab.settings", bundle: .tinyStockCore)
        }
    }

    private func open() {
        switch item {
        case .viewMode:
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.82)) {
                viewMode = viewMode.next
            }
        case .reports: router.present(.reports)
        case .calendar: router.present(.calendar)
        case .settings: router.open(.settings)
        }
    }
}

/// Os botões numa linha centralizada de botões redondos de vidro.
struct HomePageButtons: View {

    @AppStorage(AppAccentColor.storageKey) private var accentColorRaw = AppAccentColor.defaultColor.rawValue

    private var accentColor: Color {
        (AppAccentColor(rawValue: accentColorRaw) ?? .defaultColor).color
    }

    /// Conteúdo de cada botão. Com quatro botões ainda cabe folgado no 13 mini.
    private static let iconSize = CGSize(width: 30, height: 20)

    var body: some View {
        HStack(spacing: 10) {
            ForEach(HomeRailItem.allCases) { item in
                HomeRailButton(item: item, filled: false, iconSize: Self.iconSize)
                    .appSecondaryButton(accentColor, circle: true)
                    .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Coluna própria da Início no iPad deitado: os botões empilhados numa cápsula de vidro, como a barra
/// vertical do iPhone Duo.
struct HomeSideRail: View {

    var body: some View {
        VStack(spacing: 4) {
            ForEach(HomeRailItem.allCases) { item in
                HomeRailButton(item: item)
                    .buttonStyle(.plain)
                    .frame(width: 48, height: 48)
                    .contentShape(Circle())
            }
        }
        .padding(6)
        .appGlass(in: Capsule())
    }
}
