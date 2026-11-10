// ⌘
//  TinyStock/Views/SettingsView/SettingsView.swift
//
//  Propósito: Página de Ajustes (empurrada no stack raiz): lojas, sistema, aparência e sobre. No layout
//             largo (iPad, iPhone Duo aberto) fica como os Ajustes do iPad: lista à esquerda e a página
//             escolhida à direita.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-09-08.
// ⌘

import SwiftData
import SwiftUI
import TinyStockCore
import UIKit

/// Páginas dos Ajustes, na ordem da lista. Cada uma tem o título, o ícone de vidro e a cor.
enum SettingsPage: Hashable, CaseIterable, Identifiable {
    case stores
    case notifications, calendar, backup
    case colors
    case about, privacy

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .stores:        return "stores.title"
        case .notifications: return "notifications.title"
        case .calendar:      return "settings.calendar.title"
        case .backup:        return "settings.backup.title"
        case .colors:        return "settings.color.title"
        case .about:         return "settings.about.title"
        case .privacy:       return "settings.privacy.title"
        }
    }

    var symbol: String {
        switch self {
        case .stores:        return "storefront"
        case .notifications: return "bell.badge"
        case .calendar:      return "calendar.badge.plus"
        case .backup:        return "externaldrive"
        case .colors:        return "paintpalette"
        case .about:         return "info.circle"
        case .privacy:       return "hand.raised"
        }
    }

    var color: Color {
        switch self {
        case .stores:          return .orange
        case .notifications:   return .red
        case .calendar:        return .red
        case .backup, .about:  return .gray
        case .colors:          return .pink
        case .privacy:         return .blue
        }
    }
}

struct SettingsView: View {
    @AppStorage(AppAccentColor.storageKey) private var accentColorRaw = AppAccentColor.defaultColor.rawValue
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var selectedStores: [StoreProfile]
    private let storeID: UUID

    /// Página aberta à direita no layout largo.
    @State private var widePage: SettingsPage = .stores

    init(storeID: UUID) {
        self.storeID = storeID
        _selectedStores = Query(filter: #Predicate<StoreProfile> { $0.id == storeID })
    }

    private var accentColor: Color {
        (AppAccentColor(rawValue: accentColorRaw) ?? .defaultColor).color
    }

    /// Mesma regra do Nutshell: iPad e iPhone Duo aberto.
    private func isWide(_ width: CGFloat) -> Bool {
        width >= 700 || (horizontalSizeClass == .regular && width >= 560)
    }

    var body: some View {
        GeometryReader { geo in
            if isWide(geo.size.width) {
                // As páginas que empilham outras (ex.: Lojas > loja) empilham no stack raiz, em tela cheia.
                HStack(spacing: 0) {
                    settingsList(wide: true)
                        .frame(width: geo.size.width < 744 ? 300 : 340)
                    Divider()
                        .ignoresSafeArea()
                    // Título da página pequeno na barra, para não brigar com o "Ajustes" da lista.
                    destination(for: widePage)
                        .navigationBarTitleDisplayMode(.inline)
                        .id(widePage)
                        .frame(maxWidth: .infinity)
                }
            } else {
                settingsList(wide: false)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(String(localized: "tab.settings", bundle: .tinyStockCore))
    }

    // MARK: - Lista

    private func settingsList(wide: Bool) -> some View {
        List {
            // No layout largo a barra mostra o título da página da direita; o "Ajustes" fica no topo da lista.
            if wide {
                Text(String(localized: "tab.settings", bundle: .tinyStockCore))
                    .font(.largeTitle.bold())
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
                    .accessibilityAddTraits(.isHeader)
            }

            Section(header: sectionHeader("stores.title")) {
                row(.stores, wide: wide) { storeLabel }
            }

            Section(header: sectionHeader("settings.section.system")) {
                ForEach([SettingsPage.notifications, .calendar, .backup]) { page in
                    row(page, wide: wide) { pageLabel(page) }
                }
                languageButton
            }

            Section(header: sectionHeader("settings.section.appearance")) {
                row(.colors, wide: wide) { pageLabel(.colors) }
            }

            Section(header: sectionHeader("settings.section.about")) {
                ForEach([SettingsPage.about, .privacy]) { page in
                    row(page, wide: wide) { pageLabel(page) }
                }
            }
        }
    }

    private func sectionHeader(_ key: String) -> some View {
        Text(String(localized: String.LocalizationValue(key), bundle: .tinyStockCore))
            .foregroundStyle(accentColor)
    }

    private func pageLabel(_ page: SettingsPage) -> some View {
        Label {
            Text(String(localized: String.LocalizationValue(page.titleKey), bundle: .tinyStockCore))
        } icon: {
            GlassIcon(systemName: page.symbol, color: page.color)
        }
        .foregroundStyle(.primary)
    }

    /// Foto e nome da loja atual, com "Gerenciar lojas" embaixo.
    private var storeLabel: some View {
        HStack(spacing: 12) {
            StoreImageView(imageData: selectedStores.first?.imageData)
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedStores.first?.name ?? StoreProfileService.localizedDefaultName)
                    .foregroundStyle(.primary)
                Text(String(localized: "settings.store.manage", bundle: .tinyStockCore))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Idioma abre os Ajustes do iOS na página do TinyStock (onde fica o "Idioma preferido").
    private var languageButton: some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        } label: {
            HStack {
                Label {
                    Text(String(localized: "settings.language", bundle: .tinyStockCore))
                } icon: {
                    GlassIcon(systemName: "globe", color: .blue)
                }
                .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward.app")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
        .accessibilityHint(String(localized: "settings.language.hint", bundle: .tinyStockCore))
    }

    /// No iPhone empurra a página; no layout largo só troca a página da direita e marca a linha.
    @ViewBuilder
    private func row(_ page: SettingsPage, wide: Bool, @ViewBuilder label: () -> some View) -> some View {
        if wide {
            let isSelected = widePage == page
            Button {
                widePage = page
            } label: {
                label()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(isSelected ? accentColor.opacity(0.18) : Color(.secondarySystemGroupedBackground))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            NavigationLink {
                destination(for: page)
            } label: {
                label()
            }
        }
    }

    @ViewBuilder
    private func destination(for page: SettingsPage) -> some View {
        switch page {
        case .stores:        StoresView()
        case .notifications: NotificationSettingsView()
        case .calendar:      CalendarExportSettingsView()
        case .backup:        BackupSettingsView(storeID: storeID)
        case .colors:        ColorSettingsView()
        case .about:         AboutView()
        case .privacy:       PrivacyView()
        }
    }
}

#Preview {
    NavigationStack { SettingsView(storeID: UUID()) }
        .modelContainer(for: [StoreProfile.self], inMemory: true)
}
