// ⌘
//  TinyStockCoreTests/SaleDayGroupTests.swift
//
//  Propósito: Testes do agrupamento do histórico por dia, dos totais e dos títulos.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-12.
// ⌘

import Testing
import Foundation
import SwiftData
@testable import TinyStockCore

/// Serializada e com banco compartilhado: ver [TestDatabase] para o porquê.
@Suite(.serialized)
@MainActor
struct SaleDayGroupTests {

    // MARK: - Apoio

    let calendar = Calendar.current

    func makeContext() throws -> ModelContext {
        try TestDatabase.makeCleanContext()
    }

    /// Cria um instante relativo ao dia atual para montar o histórico do teste.
    func date(daysAgo: Int, hour: Int = 12) -> Date {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    /// Registra a venda pelo mesmo serviço usado pelo aplicativo.
    @discardableResult
    func sell(
        _ product: Product,
        quantity: Int,
        on date: Date,
        paymentMethod: PaymentMethod = .pix,
        in context: ModelContext
    ) throws -> Sale {
        try SaleService.register(
            lines: [SaleLine(product: product, quantity: quantity)],
            paymentMethod: paymentMethod,
            date: date,
            in: context
        )
    }

    // MARK: - Agrupamento

    @Test func listaVaziaNaoGeraGrupo() {
        #expect(SaleDayGroup.groups(from: []).isEmpty)
    }

    @Test func vendasDoMesmoDiaCaemNoMesmoGrupo() throws {
        let context = try makeContext()
        let produto = Product(name: "Produto A", quantity: 20, costPrice: 20, salePrice: 45)
        context.insert(produto)

        try sell(produto, quantity: 1, on: date(daysAgo: 0, hour: 9), in: context)
        try sell(produto, quantity: 2, on: date(daysAgo: 0, hour: 18), in: context)

        let grupos = SaleDayGroup.groups(from: try context.fetch(FetchDescriptor<Sale>()))

        #expect(grupos.count == 1)
        #expect(grupos.first?.sales.count == 2)
    }

    @Test func diasDiferentesViramGruposDiferentes() throws {
        let context = try makeContext()
        let produto = Product(name: "Produto B", quantity: 20, costPrice: 30, salePrice: 90)
        context.insert(produto)

        try sell(produto, quantity: 1, on: date(daysAgo: 0), in: context)
        try sell(produto, quantity: 1, on: date(daysAgo: 1), in: context)
        try sell(produto, quantity: 1, on: date(daysAgo: 5), in: context)

        let grupos = SaleDayGroup.groups(from: try context.fetch(FetchDescriptor<Sale>()))

        #expect(grupos.count == 3)
    }

    @Test func meiaNoiteEUmMinutoAindaEhOMesmoDia() throws {
        let context = try makeContext()
        let produto = Product(name: "Produto C", quantity: 20, salePrice: 30)
        context.insert(produto)

        // Os horários extremos continuam pertencendo ao mesmo dia do calendário.
        try sell(produto, quantity: 1, on: date(daysAgo: 0, hour: 0), in: context)
        try sell(produto, quantity: 1, on: date(daysAgo: 0, hour: 23), in: context)

        let grupos = SaleDayGroup.groups(from: try context.fetch(FetchDescriptor<Sale>()))

        #expect(grupos.count == 1)
    }

    // MARK: - Ordem

    @Test func grupoMaisRecenteVemPrimeiro() throws {
        let context = try makeContext()
        let produto = Product(name: "Produto A", quantity: 20, salePrice: 45)
        context.insert(produto)

        try sell(produto, quantity: 1, on: date(daysAgo: 3), in: context)
        try sell(produto, quantity: 1, on: date(daysAgo: 0), in: context)
        try sell(produto, quantity: 1, on: date(daysAgo: 1), in: context)

        let grupos = SaleDayGroup.groups(from: try context.fetch(FetchDescriptor<Sale>()))
        let dias = grupos.map(\.day)

        let primeiroDia = try #require(dias.first)

        #expect(dias == dias.sorted(by: >), "o histórico começa pelo dia mais recente")
        #expect(calendar.isDateInToday(primeiroDia))
    }

    @Test func dentroDoDiaAVendaMaisRecenteVemPrimeiro() throws {
        let context = try makeContext()
        let produto = Product(name: "Organizador de Mesa", quantity: 20, salePrice: 35)
        context.insert(produto)

        try sell(produto, quantity: 1, on: date(daysAgo: 0, hour: 8), in: context)
        try sell(produto, quantity: 2, on: date(daysAgo: 0, hour: 20), in: context)
        try sell(produto, quantity: 3, on: date(daysAgo: 0, hour: 14), in: context)

        let grupos = SaleDayGroup.groups(from: try context.fetch(FetchDescriptor<Sale>()))
        let grupo = try #require(grupos.first)
        let horas = grupo.sales.map { calendar.component(.hour, from: $0.date) }

        #expect(horas == [20, 14, 8])
    }

    // MARK: - Totais

    @Test func totalDoDiaSomaAsVendasDaqueleDia() throws {
        let context = try makeContext()
        let produto = Product(name: "Produto A", quantity: 20, costPrice: 20, salePrice: 45)
        context.insert(produto)

        try sell(produto, quantity: 2, on: date(daysAgo: 0, hour: 9), in: context)   // 90
        try sell(produto, quantity: 1, on: date(daysAgo: 0, hour: 17), in: context)  // 45
        try sell(produto, quantity: 4, on: date(daysAgo: 1), in: context)            // 180, outro dia

        let grupos = SaleDayGroup.groups(from: try context.fetch(FetchDescriptor<Sale>()))
        let hoje = try #require(grupos.first)

        #expect(hoje.total == 135)
        #expect(hoje.profit == 75)          // 45 menos 20, vezes 3
        #expect(hoje.totalQuantity == 3)
        #expect(grupos.last?.total == 180)
    }

    // MARK: - Títulos

    @Test func diaDeHojeEOntemTemTituloProprio() throws {
        let hoje = SaleDayGroup(day: calendar.startOfDay(for: Date()), sales: [])
        let ontem = SaleDayGroup(day: calendar.startOfDay(for: date(daysAgo: 1)), sales: [])
        let antigo = SaleDayGroup(day: calendar.startOfDay(for: date(daysAgo: 10)), sales: [])

        let titulos = [hoje.title(), ontem.title(), antigo.title()]

        #expect(Set(titulos).count == 3, "cada dia precisa de um cabeçalho diferente")
        #expect(titulos.allSatisfy { !$0.isEmpty })
    }

    @Test func diaComumMostraODiaDoMes() {
        let referencia = Date(timeIntervalSince1970: 1_754_956_800)  // 12/08/2025
        let dia = calendar.date(byAdding: .day, value: -4, to: referencia) ?? referencia
        let grupo = SaleDayGroup(day: calendar.startOfDay(for: dia), sales: [])

        let titulo = grupo.title(relativeTo: referencia, calendar: calendar)
        let numeroDoDia = String(calendar.component(.day, from: dia))

        #expect(titulo.contains(numeroDoDia))
    }

    @Test func tituloDeHojeNaoDependeDaHora() {
        let referencia = Date()
        let grupo = SaleDayGroup(day: calendar.startOfDay(for: referencia), sales: [])

        // A meia-noite do dia e o instante de agora são o mesmo dia, mesmo a horas de distância.
        #expect(grupo.title(relativeTo: referencia) == grupo.title(relativeTo: calendar.startOfDay(for: referencia)))
    }
}
