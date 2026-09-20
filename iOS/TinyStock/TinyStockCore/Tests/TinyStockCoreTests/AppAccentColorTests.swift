// Proposito: Validar a configuracao persistente das cores de destaque.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-19.

import Testing
@testable import TinyStockCore

struct AppAccentColorTests {
    @Test func verdePermaneceComoCorPadrao() {
        #expect(AppAccentColor.defaultColor == .green)
    }

    @Test func todasAsCoresPossuemNomeLocalizado() {
        #expect(AppAccentColor.allCases.count == 8)
        #expect(AppAccentColor.allCases.allSatisfy { !$0.localizedName.isEmpty })
    }
}
