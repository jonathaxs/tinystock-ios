// Proposito: Definir as cores de destaque disponiveis e sua persistencia.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-19.

import Foundation

public enum AppAccentColor: String, CaseIterable, Sendable {
    case green
    case blue
    case purple
    case red
    case orange
    case yellow
    case cyan
    case pink

    public static let storageKey = "app.accentColor"
    public static let defaultColor: AppAccentColor = .green

    public var localizedName: String {
        switch self {
        case .green: String(localized: "color.green", bundle: .tinyStockCore)
        case .blue: String(localized: "color.blue", bundle: .tinyStockCore)
        case .purple: String(localized: "color.purple", bundle: .tinyStockCore)
        case .red: String(localized: "color.red", bundle: .tinyStockCore)
        case .orange: String(localized: "color.orange", bundle: .tinyStockCore)
        case .yellow: String(localized: "color.yellow", bundle: .tinyStockCore)
        case .cyan: String(localized: "color.cyan", bundle: .tinyStockCore)
        case .pink: String(localized: "color.pink", bundle: .tinyStockCore)
        }
    }
}
