// ⌘
//  TinyStockCoreTests/SalesReportTests.swift
//
//  Propósito: Testes dos períodos e totais do relatório financeiro.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-15.
// ⌘

import Testing
import Foundation
import SwiftData
@testable import TinyStockCore

/// Serializada e com banco compartilhado: ver [TestDatabase] para o porquê.
@Suite(.serialized)
@MainActor
struct SalesReportTests {

    let calendar = Calendar(identifier: .gregorian)
    let reference = Date(timeIntervalSince1970: 1_786_742_200) // 15/08/2026 15:30 UTC

    func makeContext() throws -> ModelContext {
        try TestDatabase.makeCleanContext()
    }

    func date(daysFromReference: Int, hour: Int = 12) -> Date {
        let shifted = calendar.date(byAdding: .day, value: daysFromReference, to: reference) ?? reference
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: shifted) ?? shifted
    }

    @discardableResult
    func sell(
        _ product: Product,
        quantity: Int,
        daysFromReference: Int,
        in context: ModelContext
    ) throws -> Sale {
        try SaleService.register(
            lines: [SaleLine(product: product, quantity: quantity)],
            paymentMethod: .pix,
            date: date(daysFromReference: daysFromReference),
            in: context
        )
    }

    // MARK: - Períodos

    @Test func hojeAceitaDoInicioAteAntesDaProximaMeiaNoite() {
        let start = calendar.startOfDay(for: reference)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? reference

        #expect(SalesReportPeriod.today.contains(start, relativeTo: reference, calendar: calendar))
        #expect(SalesReportPeriod.today.contains(end.addingTimeInterval(-1), relativeTo: reference, calendar: calendar))
        #expect(!SalesReportPeriod.today.contains(end, relativeTo: reference, calendar: calendar))
    }

    @Test func seteDiasIncluemHojeEMaisSeisDias() {
        #expect(SalesReportPeriod.lastSevenDays.contains(date(daysFromReference: 0), relativeTo: reference, calendar: calendar))
        #expect(SalesReportPeriod.lastSevenDays.contains(date(daysFromReference: -6), relativeTo: reference, calendar: calendar))
        #expect(!SalesReportPeriod.lastSevenDays.contains(date(daysFromReference: -7), relativeTo: reference, calendar: calendar))
    }

    @Test func mesAtualNaoAceitaODiaPrimeiroDoMesSeguinte() throws {
        let interval = try #require(SalesReportPeriod.currentMonth.dateInterval(relativeTo: reference, calendar: calendar))

        #expect(SalesReportPeriod.currentMonth.contains(interval.start, relativeTo: reference, calendar: calendar))
        #expect(!SalesReportPeriod.currentMonth.contains(interval.end, relativeTo: reference, calendar: calendar))
    }

    @Test func tudoAceitaQualquerData() {
        #expect(SalesReportPeriod.allTime.contains(.distantPast, relativeTo: reference, calendar: calendar))
        #expect(SalesReportPeriod.allTime.contains(.distantFuture, relativeTo: reference, calendar: calendar))
    }

    // MARK: - Totais

    @Test func resumoSomaApenasAsVendasDoPeriodo() throws {
        let context = try makeContext()
        let product = Product(name: "Produto A", quantity: 30, costPrice: 20, salePrice: 45)
        context.insert(product)

        try sell(product, quantity: 2, daysFromReference: 0, in: context)
        try sell(product, quantity: 1, daysFromReference: -3, in: context)
        try sell(product, quantity: 4, daysFromReference: -8, in: context)

        let summary = SalesReportSummary(
            sales: try context.fetch(FetchDescriptor<Sale>()),
            period: .lastSevenDays,
            reference: reference,
            calendar: calendar
        )

        #expect(summary.revenue == 135)
        #expect(summary.profit == 75)
        #expect(summary.saleCount == 2)
        #expect(summary.unitCount == 3)
        #expect(summary.dayGroups.count == 2)
    }

    @Test func resumoVazioTemTodosOsTotaisZerados() {
        let summary = SalesReportSummary(sales: [], period: .currentMonth, reference: reference, calendar: calendar)

        #expect(summary.isEmpty)
        #expect(summary.revenue == 0)
        #expect(summary.profit == 0)
        #expect(summary.saleCount == 0)
        #expect(summary.unitCount == 0)
        #expect(summary.dayGroups.isEmpty)
    }

    @Test func resumoFinanceiroDescontaTaxasDoLucro() throws {
        let context = try makeContext()
        let product = Product(name: "Produto E", quantity: 5, costPrice: 40, salePrice: 100)
        context.insert(product)

        try SaleService.register(
            lines: [SaleLine(product: product, quantity: 1)],
            paymentMethod: .shopee,
            date: reference,
            channelFeePercentage: 14,
            in: context
        )

        let summary = SalesReportSummary(
            sales: try context.fetch(FetchDescriptor<Sale>()),
            period: .allTime,
            reference: reference,
            calendar: calendar
        )

        #expect(summary.revenue == 100)
        #expect(summary.profit == 46)
    }

    // MARK: - Produtos mais vendidos

    @Test func rankingSomaOMesmoProdutoEmVendasDiferentes() throws {
        let context = try makeContext()
        let product = Product(name: "Produto A", quantity: 20, costPrice: 20, salePrice: 45)
        context.insert(product)

        try sell(product, quantity: 2, daysFromReference: 0, in: context)
        try sell(product, quantity: 3, daysFromReference: -1, in: context)

        let summary = SalesReportSummary(
            sales: try context.fetch(FetchDescriptor<Sale>()),
            period: .allTime,
            reference: reference,
            calendar: calendar
        )
        let ranking = try #require(summary.bestSellingProducts().first)

        #expect(ranking.productID == product.id)
        #expect(ranking.productName == "Produto A")
        #expect(ranking.quantity == 5)
        #expect(ranking.revenue == 225)
    }

    @Test func rankingUsaApenasAsVendasDoPeriodo() throws {
        let context = try makeContext()
        let recent = Product(name: "Produto recente", quantity: 10, salePrice: 25)
        let old = Product(name: "Produto antigo", quantity: 20, salePrice: 90)
        context.insert(recent)
        context.insert(old)

        try sell(recent, quantity: 2, daysFromReference: 0, in: context)
        try sell(old, quantity: 10, daysFromReference: -8, in: context)

        let summary = SalesReportSummary(
            sales: try context.fetch(FetchDescriptor<Sale>()),
            period: .lastSevenDays,
            reference: reference,
            calendar: calendar
        )

        #expect(summary.bestSellingProducts().map(\.productName) == ["Produto recente"])
    }

    @Test func rankingPrefereQuantidadeEDesempataPorReceita() throws {
        let context = try makeContext()
        let first = Product(name: "Produto C", quantity: 20, salePrice: 20)
        let second = Product(name: "Chaveiro", quantity: 20, salePrice: 10)
        let third = Product(name: "Porta Copo", quantity: 20, salePrice: 50)
        context.insert(first)
        context.insert(second)
        context.insert(third)

        try sell(first, quantity: 4, daysFromReference: 0, in: context)
        try sell(second, quantity: 5, daysFromReference: 0, in: context)
        try sell(third, quantity: 4, daysFromReference: 0, in: context)

        let summary = SalesReportSummary(
            sales: try context.fetch(FetchDescriptor<Sale>()),
            period: .allTime,
            reference: reference,
            calendar: calendar
        )

        #expect(summary.bestSellingProducts().map(\.productName) == ["Chaveiro", "Porta Copo", "Produto C"])
    }

    @Test func rankingRespeitaOLimiteSolicitado() throws {
        let context = try makeContext()

        for index in 1...5 {
            let product = Product(name: "Produto \(index)", quantity: 10, salePrice: 10)
            context.insert(product)
            try sell(product, quantity: index, daysFromReference: 0, in: context)
        }

        let summary = SalesReportSummary(
            sales: try context.fetch(FetchDescriptor<Sale>()),
            period: .allTime,
            reference: reference,
            calendar: calendar
        )

        #expect(summary.bestSellingProducts(limit: 3).map(\.quantity) == [5, 4, 3])
        #expect(summary.bestSellingProducts(limit: 0).isEmpty)
    }

    @Test func rankingMantemONomeMaisRecenteDaVenda() throws {
        let context = try makeContext()
        let product = Product(name: "Suporte", quantity: 10, salePrice: 25)
        context.insert(product)

        try sell(product, quantity: 1, daysFromReference: -1, in: context)
        product.name = "Suporte de Fone"
        try sell(product, quantity: 1, daysFromReference: 0, in: context)

        let summary = SalesReportSummary(
            sales: try context.fetch(FetchDescriptor<Sale>()),
            period: .allTime,
            reference: reference,
            calendar: calendar
        )

        #expect(summary.bestSellingProducts().first?.productName == "Suporte de Fone")
    }

    @Test func diasDoResumoVemDoMaisRecenteProMaisAntigo() throws {
        let context = try makeContext()
        let product = Product(name: "Tapete Redondo", quantity: 10, costPrice: 30, salePrice: 90)
        context.insert(product)

        try sell(product, quantity: 1, daysFromReference: -4, in: context)
        try sell(product, quantity: 1, daysFromReference: 0, in: context)
        try sell(product, quantity: 1, daysFromReference: -2, in: context)

        let summary = SalesReportSummary(
            sales: try context.fetch(FetchDescriptor<Sale>()),
            period: .allTime,
            reference: reference,
            calendar: calendar
        )

        let days = summary.dayGroups.map(\.day)
        #expect(days == days.sorted(by: >))
    }

    @Test func todoPeriodoTemNomeCurto() {
        for period in SalesReportPeriod.allCases {
            #expect(!period.localizedName.isEmpty)
            #expect(period.localizedName.count <= 10)
        }
    }
}
