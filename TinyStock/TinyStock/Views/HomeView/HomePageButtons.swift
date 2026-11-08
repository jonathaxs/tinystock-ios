// ⌘
//  TinyStock/Views/HomeView/HomePageButtons.swift
//
//  Propósito: Linha de botões redondos de vidro da Início, só com ícone, que abrem Relatórios,
//             Calendário e Ajustes pelo AppRouter.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-11-07.
// ⌘

import SwiftUI
import TinyStockCore

/// Os botões de navegação da Início, na ordem da linha (Ajustes por último).
enum HomeRailItem: CaseIterable, Identifiable {
    case reports, calendar, settings
    var id: Self { self }

    var symbolName: String {
        switch self {
        case .reports: "chart.bar"
        case .calendar: "calendar"
        case .settings: "gearshape"
        }
    }

    var title: String {
        switch self {
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

    private var accentColor: Color {
        (AppAccentColor(rawValue: accentColorRaw) ?? .defaultColor).color
    }

    /// Conteúdo de cada botão. Com quatro botões ainda cabe folgado no 13 mini.
    private static let iconSize = CGSize(width: 30, height: 20)

    var body: some View {
        HStack(spacing: 10) {
            ForEach(HomeRailItem.allCases) { item in
                Button { open(item) } label: {
                    Image(systemName: item.symbolName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: Self.iconSize.width, height: Self.iconSize.height)
                }
                .appSecondaryButton(accentColor, circle: true)
                .controlSize(.regular)
                .accessibilityLabel(item.title)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func open(_ item: HomeRailItem) {
        switch item {
        case .reports: router.present(.reports)
        case .calendar: router.present(.calendar)
        case .settings: router.open(.settings)
        }
    }
}
