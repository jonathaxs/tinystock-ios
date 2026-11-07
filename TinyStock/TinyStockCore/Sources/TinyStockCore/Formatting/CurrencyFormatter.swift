// ⌘
//  TinyStockCore/Formatting/CurrencyFormatter.swift
//
//  Propósito: Exibir e interpretar valores em dinheiro no padrão brasileiro (real).
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-08.
// ⌘

import Foundation

// MARK: - Formatador de moeda

/// Centraliza tudo que envolve dinheiro no TinyStock: transformar um `Decimal` em
/// texto para apresentação e leitura do valor digitado pelo usuário.
///
/// Mora no Core porque a mesma regra serve o app, os testes e o futuro alvo watchOS.
public enum CurrencyFormatter {

    /// Código ISO da moeda. O app trabalha só em real por enquanto.
    public static let currencyCode = "BRL"

    // MARK: - Exibição

    /// Devolve o valor formatado para apresentação, por exemplo "R$ 45,00".
    ///
    /// A locale entra como parâmetro (e não fixa) por dois motivos: respeitar o
    /// idioma do aparelho na separação de milhar e permitir teste determinístico.
    public static func string(from value: Decimal, locale: Locale = .autoupdatingCurrent) -> String {
        value.formatted(.currency(code: currencyCode).locale(locale))
    }

    /// Devolve o valor para preencher um campo de formulário, por exemplo "45,90".
    ///
    /// Diferente do `string(from:)`, aqui não entra símbolo de moeda nem separador de
    /// milhar, porque o campo precisa continuar legível e fácil de corrigir no teclado.
    /// Zero volta como texto vazio, assim o campo mostra o placeholder em vez de "0,00".
    public static func editableText(from value: Decimal, locale: Locale = .autoupdatingCurrent) -> String {
        guard value != 0 else { return "" }

        return value.formatted(
            .number
                .precision(.fractionLength(2))
                .grouping(.never)
                .locale(locale)
        )
    }

    // MARK: - Leitura do que o usuário digitou

    /// Converte o texto digitado em `Decimal`, aceitando vírgula ou ponto como separador decimal.
    /// Devolve nil quando não sobra nenhum dígito, ou seja, campo vazio ou só símbolo.
    ///
    /// A regra não depende do locale do aparelho, porque o teclado numérico
    /// do iPhone às vezes oferece ponto mesmo com o sistema em português. O critério é a
    /// quantidade de dígitos depois do último separador:
    ///
    /// - até 2 dígitos, ele é o separador decimal, então "1.50" vira um e cinquenta;
    /// - 3 ou mais, ele é separador de milhar, então "1.500" vira mil e quinhentos.
    public static func decimal(from text: String) -> Decimal? {
        // O sinal negativo só conta quando vem antes de tudo.
        let isNegative = text.trimmingCharacters(in: .whitespaces).hasPrefix("-")

        // 1. Mantém apenas dígitos e separadores. Símbolo de moeda, espaço e letra caem fora.
        let cleaned = text.filter { $0.isNumber || $0 == "," || $0 == "." }
        guard cleaned.contains(where: \.isNumber) else { return nil }

        // 2. Quebra em parte inteira e centavos, aplicando a regra dos 2 dígitos.
        var integerPart = cleaned
        var decimalPart = ""

        if let separator = cleaned.lastIndex(where: { $0 == "," || $0 == "." }) {
            let afterSeparator = cleaned[cleaned.index(after: separator)...]
            if afterSeparator.count <= 2 {
                integerPart = String(cleaned[..<separator])
                decimalPart = String(afterSeparator)
            }
        }

        // 3. O separador que sobrou na parte inteira é milhar e pode sumir.
        integerPart = integerPart.filter(\.isNumber)

        // 4. Monta o formato neutro para a leitura não depender do locale.
        let sign = isNegative ? "-" : ""
        let normalized = "\(sign)\(integerPart.isEmpty ? "0" : integerPart).\(decimalPart.isEmpty ? "0" : decimalPart)"

        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }
}

// MARK: - Atalho de uso

public extension Decimal {

    /// Texto do valor no formato de moeda usado pelo aplicativo.
    var currencyText: String {
        CurrencyFormatter.string(from: self)
    }
}
