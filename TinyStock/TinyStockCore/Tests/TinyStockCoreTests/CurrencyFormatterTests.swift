// ⌘
//  TinyStockCoreTests/CurrencyFormatterTests.swift
//
//  Propósito: Testes do formatador de moeda, cobrindo exibição em real e leitura do texto digitado.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-08.
// ⌘

import Testing
import Foundation
@testable import TinyStockCore

// MARK: - Apoio

/// Locale fixa para manter os resultados independentes da configuração do aparelho.
private let localeBR = Locale(identifier: "pt_BR")

/// O formatador do sistema separa símbolo e número com espaço não quebrável.
/// Trocar por espaço comum deixa a comparação legível sem enfraquecer o teste.
private func normalizedSpaces(_ text: String) -> String {
    text
        .replacingOccurrences(of: "\u{00A0}", with: " ")
        .replacingOccurrences(of: "\u{202F}", with: " ")
}

/// Monta um `Decimal` exato a partir dos centavos, evitando o erro de ponto flutuante
/// que apareceria ao escrever 1234.56 direto como literal.
private func money(cents: Int) -> Decimal {
    Decimal(cents) / 100
}

// MARK: - Exibição

@Test func formataValorInteiroComDuasCasas() {
    let texto = CurrencyFormatter.string(from: 45, locale: localeBR)
    #expect(normalizedSpaces(texto) == "R$ 45,00")
}

@Test func formataValorComCentavosESeparadorDeMilhar() {
    let texto = CurrencyFormatter.string(from: money(cents: 123456), locale: localeBR)
    #expect(normalizedSpaces(texto) == "R$ 1.234,56")
}

@Test func atalhoDoDecimalUsaOMesmoFormatador() {
    let valor = money(cents: 4500)
    #expect(valor.currencyText == CurrencyFormatter.string(from: valor))
}

// MARK: - Texto de edição

@Test func textoDeEdicaoNaoTemSimboloNemMilhar() {
    // O campo do formulário precisa ficar fácil de corrigir no teclado.
    let texto = CurrencyFormatter.editableText(from: money(cents: 123456), locale: localeBR)
    #expect(texto == "1234,56")
}

@Test func textoDeEdicaoCompletaAsCasasDecimais() {
    #expect(CurrencyFormatter.editableText(from: 45, locale: localeBR) == "45,00")
}

@Test func textoDeEdicaoDeZeroVemVazio() {
    // Vazio deixa o placeholder aparecer em vez de um "0,00" que a pessoa teria que apagar.
    #expect(CurrencyFormatter.editableText(from: 0, locale: localeBR) == "")
}

@Test func textoDeEdicaoVoltaNoParser() {
    // Abrir e salvar um produto sem editar não pode alterar o valor.
    let original = money(cents: 4590)
    let texto = CurrencyFormatter.editableText(from: original, locale: localeBR)
    #expect(CurrencyFormatter.decimal(from: texto) == original)
}

// MARK: - Leitura do texto digitado

@Test func leVirgulaComoSeparadorDecimal() {
    #expect(CurrencyFormatter.decimal(from: "45,90") == money(cents: 4590))
}

@Test func lePontoComoSeparadorDecimal() {
    // O teclado do iPhone pode oferecer ponto mesmo com o sistema em português.
    #expect(CurrencyFormatter.decimal(from: "45.90") == money(cents: 4590))
}

@Test func ignoraSimboloEEspacoDaMoeda() {
    #expect(CurrencyFormatter.decimal(from: "R$ 1.234,56") == money(cents: 123456))
}

@Test func tratraPontoComoMilharQuandoSobramTresDigitos() {
    #expect(CurrencyFormatter.decimal(from: "1.500") == 1500)
}

@Test func aceitaTextoTerminadoEmSeparador() {
    // Estado normal enquanto o usuário ainda está digitando o valor.
    #expect(CurrencyFormatter.decimal(from: "45,") == 45)
}

@Test func leValorSemSeparadorNenhum() {
    #expect(CurrencyFormatter.decimal(from: "90") == 90)
}

@Test func devolveNilQuandoNaoTemDigito() {
    #expect(CurrencyFormatter.decimal(from: "") == nil)
    #expect(CurrencyFormatter.decimal(from: "R$ ") == nil)
}

@Test func idaEVoltaPreservaOValor() {
    // Formatar e ler novamente deve preservar exatamente o mesmo Decimal.
    let original = money(cents: 8990)
    let texto = CurrencyFormatter.string(from: original, locale: localeBR)
    #expect(CurrencyFormatter.decimal(from: texto) == original)
}
