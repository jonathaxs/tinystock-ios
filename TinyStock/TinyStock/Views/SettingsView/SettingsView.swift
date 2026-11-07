// Proposito: Organizar lojas, preferencias, sistema e informacoes do aplicativo.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-08.

import SwiftData
import SwiftUI
import TinyStockCore
import UIKit

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Query private var selectedStores: [StoreProfile]
    private let storeID: UUID

    init(storeID: UUID) {
        self.storeID = storeID
        _selectedStores = Query(filter: #Predicate<StoreProfile> { $0.id == storeID })
    }

    var body: some View {
        NavigationStack {
            List {
                storeSection

                Section(String(localized: "settings.section.preferences", bundle: .tinyStockCore)) {
                    NavigationLink {
                        ColorSettingsView()
                    } label: {
                        Label(
                            String(localized: "settings.color.title", bundle: .tinyStockCore),
                            systemImage: "paintpalette"
                        )
                    }
                }

                Section(String(localized: "settings.section.system", bundle: .tinyStockCore)) {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label(String(localized: "notifications.title", bundle: .tinyStockCore), systemImage: "bell.badge")
                    }

                    NavigationLink {
                        CalendarExportSettingsView()
                    } label: {
                        Label(String(localized: "settings.calendar.title", bundle: .tinyStockCore), systemImage: "calendar.badge.plus")
                    }

                    NavigationLink {
                        BackupSettingsView(storeID: storeID)
                    } label: {
                        Label(
                            String(localized: "settings.backup.title", bundle: .tinyStockCore),
                            systemImage: "externaldrive"
                        )
                    }

                    Button {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    } label: {
                        HStack {
                            Label(String(localized: "settings.language", bundle: .tinyStockCore), systemImage: "globe")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                    }
                    .foregroundStyle(.primary)
                    .accessibilityHint(String(localized: "settings.language.hint", bundle: .tinyStockCore))
                }

                Section(String(localized: "settings.section.about", bundle: .tinyStockCore)) {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label(String(localized: "settings.about.title", bundle: .tinyStockCore), systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle(String(localized: "tab.settings", bundle: .tinyStockCore))
        }
    }

    private var storeSection: some View {
        Section(String(localized: "settings.section.profile", bundle: .tinyStockCore)) {
            NavigationLink {
                StoresView()
            } label: {
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
            }
        }
    }
}

#Preview {
    SettingsView(storeID: UUID())
        .modelContainer(for: [StoreProfile.self], inMemory: true)
}
