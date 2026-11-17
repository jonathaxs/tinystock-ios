// Proposito: Apresentar identidade, versao e contato do TinyStock (a privacidade fica nos Ajustes).
// Cinco toques no icone reabrem as boas-vindas.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-08.

import SwiftUI
import TinyStockCore
import UIKit

struct AboutView: View {

    @AppStorage(AppAccentColor.storageKey) private var accentColorRaw = AppAccentColor.defaultColor.rawValue
    @AppStorage(WelcomeStorage.didCompleteKey) private var didCompleteWelcome = true
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Toques seguidos no ícone reabrem as boas-vindas.
    @State private var iconTapCount = 0
    @State private var lastIconTap: Date?
    @State private var iconScale: CGFloat = 1

    private static let feedbackURL = URL(string: "mailto:contato@jonathasmotta.com")!
    private static let iconTapGoal = 5
    private static let iconTapWindow: TimeInterval = 2

    private var accentColor: Color {
        (AppAccentColor(rawValue: accentColorRaw) ?? .defaultColor).color
    }

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

            Section {
                HStack {
                    Spacer()
                    Button {
                        openURL(Self.feedbackURL)
                    } label: {
                        Label(String(localized: "settings.about.feedback", bundle: .tinyStockCore), systemImage: "envelope")
                            .font(.headline)
                            .padding(.vertical, 4)
                    }
                    .appSecondaryButton(accentColor)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listSectionSpacing(.compact)
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
                .scaleEffect(iconScale)
                .onTapGesture(perform: registerIconTap)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 42))
                .frame(width: size, height: size)
                .background(.tint, in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .foregroundStyle(.white)
                .scaleEffect(iconScale)
                .onTapGesture(perform: registerIconTap)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Reabrir as boas-vindas

    /// 5 toques seguidos no ícone (no máximo 2 s entre eles) voltam para a WelcomeView.
    private func registerIconTap() {
        bounceIcon()
        let now = Date()
        if let last = lastIconTap, now.timeIntervalSince(last) > Self.iconTapWindow {
            iconTapCount = 0
        }
        lastIconTap = now
        iconTapCount += 1

        if iconTapCount >= Self.iconTapGoal {
            iconTapCount = 0
            lastIconTap = nil
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            didCompleteWelcome = false
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    /// Cada toque dá um pulinho no ícone.
    private func bounceIcon() {
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.18, dampingFraction: 0.6)) { iconScale = 1.18 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { iconScale = 1 }
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
