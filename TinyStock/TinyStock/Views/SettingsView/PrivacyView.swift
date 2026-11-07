// Proposito: Explicar de forma direta como o TinyStock trata os dados do usuario.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-08.

import SwiftUI
import TinyStockCore

struct PrivacyView: View {
    var body: some View {
        List {
            Section {
                Label(String(localized: "settings.privacy.local.title", bundle: .tinyStockCore), systemImage: "iphone")
                Text(String(localized: "settings.privacy.local.message", bundle: .tinyStockCore))
                    .foregroundStyle(.secondary)
            }

            Section {
                Label(String(localized: "settings.privacy.icloud.title", bundle: .tinyStockCore), systemImage: "icloud")
                Text(String(localized: "settings.privacy.icloud.message", bundle: .tinyStockCore))
                    .foregroundStyle(.secondary)
            }

            Section {
                Label(String(localized: "settings.privacy.notifications.title", bundle: .tinyStockCore), systemImage: "bell")
                Text(String(localized: "settings.privacy.notifications.message", bundle: .tinyStockCore))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(String(localized: "settings.privacy.title", bundle: .tinyStockCore))
        .navigationBarTitleDisplayMode(.inline)
    }
}
