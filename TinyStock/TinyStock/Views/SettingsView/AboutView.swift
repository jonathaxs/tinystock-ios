// Proposito: Apresentar identidade, versao, privacidade e contato do TinyStock.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-08.

import SwiftUI
import TinyStockCore
import UIKit

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    appIcon
                    Text("TinyStock")
                        .font(.title2.bold())
                    Text(versionText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                Text(String(localized: "settings.about.description", bundle: .tinyStockCore))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section(String(localized: "settings.about.information", bundle: .tinyStockCore)) {
                NavigationLink {
                    PrivacyView()
                } label: {
                    Label(String(localized: "settings.privacy.title", bundle: .tinyStockCore), systemImage: "hand.raised")
                }
            }

            Section(String(localized: "settings.about.developer", bundle: .tinyStockCore)) {
                Link(destination: URL(string: "mailto:jonathasmrt@me.com")!) {
                    Label(String(localized: "settings.about.feedback", bundle: .tinyStockCore), systemImage: "envelope")
                }
                Link(destination: URL(string: "https://jonathasmotta.com")!) {
                    Label(String(localized: "settings.about.website", bundle: .tinyStockCore), systemImage: "globe")
                }
            }
        }
        .navigationTitle(String(localized: "settings.about.title", bundle: .tinyStockCore))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var appIcon: some View {
        let size: CGFloat = 80
        if let image = AppMetadata.icon {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .accessibilityHidden(true)
        } else {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 42))
                .frame(width: size, height: size)
                .background(.tint, in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        }
    }

    private var versionText: String {
        String(
            format: String(localized: "settings.about.versionBuild", bundle: .tinyStockCore),
            AppMetadata.version, AppMetadata.build
        )
    }
}

private enum AppMetadata {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }

    static var icon: UIImage? {
        guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let names = primary["CFBundleIconFiles"] as? [String],
              let name = names.last else { return nil }
        return UIImage(named: name)
    }
}
