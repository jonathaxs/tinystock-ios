// ⌘
//  TinyStock/Views/HomeView/HomePageButtons.swift
//
//  Propósito: Linha de botões redondos de vidro da Início, só com ícone: troca o catálogo entre lista e
//             grade e abre Relatórios, Calendário e Ajustes pelo AppRouter.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-11-07.
// ⌘

import SwiftUI
import TinyStockCore

/// Os botões da Início, na ordem da linha do Nutshell (lista/grade primeiro, Ajustes por último).
enum HomeRailItem: CaseIterable, Identifiable {
    case viewMode, reports, calendar, settings
    var id: Self { self }

    /// Ícone fixo de cada botão. O de lista/grade depende do modo atual (`CatalogViewMode`).
    var symbolName: String {
        switch self {
        case .viewMode: CatalogViewMode.list.switchSymbolName
        case .reports: "chart.bar"
        case .calendar: "calendar"
        case .settings: "gearshape"
        }
    }

    var title: String {
        switch self {
        case .viewMode: CatalogViewMode.list.switchAccessibilityLabel
        case .reports: String(localized: "tab.reports", bundle: .tinyStockCore)
        case .calendar: String(localized: "tab.sales", bundle: .tinyStockCore)
        case .settings: String(localized: "tab.settings", bundle: .tinyStockCore)
        }
    }
}

/// Os botões numa linha centralizada.
struct HomePageButtons: View {

    @Environment(AppRouter.self) private var router
    @AppStorage(AppAccentColor.storageKey) private var accentColorRaw = AppAccentColor.defaultColor.rawValue
    @AppStorage(CatalogViewMode.storageKey) private var viewMode: CatalogViewMode = .list
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accentColor: Color {
        (AppAccentColor(rawValue: accentColorRaw) ?? .defaultColor).color
    }

    /// Conteúdo de cada botão. Com quatro botões ainda cabe folgado no 13 mini.
    private static let iconSize = CGSize(width: 30, height: 20)

    var body: some View {
        HStack(spacing: 10) {
            ForEach(HomeRailItem.allCases) { item in
                Button { open(item) } label: {
                    Image(systemName: symbolName(item))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: Self.iconSize.width, height: Self.iconSize.height)
                        .contentTransition(.symbolEffect(.replace))
                }
                .appSecondaryButton(accentColor, circle: true)
                .controlSize(.regular)
                .accessibilityLabel(title(item))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func symbolName(_ item: HomeRailItem) -> String {
        item == .viewMode ? viewMode.switchSymbolName : item.symbolName
    }

    private func title(_ item: HomeRailItem) -> String {
        item == .viewMode ? viewMode.switchAccessibilityLabel : item.title
    }

    private func open(_ item: HomeRailItem) {
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
