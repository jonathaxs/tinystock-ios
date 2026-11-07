// Proposito: Impedir divergencias entre as traducoes English e pt-BR.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-09.

import Foundation
import Testing
@testable import TinyStockCore

struct LocalizationIntegrityTests {
    @Test func idiomasPossuemAsMesmasChavesETextosPreenchidos() throws {
        let english = try localization(named: "en")
        let portuguese = try localization(named: "pt-BR")

        #expect(Set(english.keys) == Set(portuguese.keys))
        #expect(english.values.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        #expect(portuguese.values.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }

    @Test func parametrosDeFormatacaoSaoEquivalentesNosDoisIdiomas() throws {
        let english = try localization(named: "en")
        let portuguese = try localization(named: "pt-BR")

        for key in english.keys {
            let englishParameters = formatParameters(in: english[key, default: ""])
            let portugueseParameters = formatParameters(in: portuguese[key, default: ""])
            #expect(englishParameters == portugueseParameters, "Parametros divergentes em \(key)")
        }
    }

    private func localization(named language: String) throws -> [String: String] {
        let url = try #require(Bundle.tinyStockCore.url(
            forResource: "Localizable",
            withExtension: "strings",
            subdirectory: nil,
            localization: language
        ))
        let data = try Data(contentsOf: url)
        return try #require(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        )
    }

    private func formatParameters(in text: String) -> [String] {
        let expression = try? NSRegularExpression(pattern: "%[0-9]+\\$[@d]|%[@d]")
        let range = NSRange(text.startIndex..., in: text)
        return (expression?.matches(in: text, range: range) ?? []).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let parameter = String(text[range])
            return parameter.hasSuffix("@") ? "%@" : "%d"
        }.sorted()
    }
}
