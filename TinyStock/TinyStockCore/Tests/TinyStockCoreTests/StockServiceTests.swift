// ⌘
//  TinyStockCoreTests/StockServiceTests.swift
//
//  Propósito: Validar entradas, ajustes, reversões e isolamento do estoque.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-28.
// ⌘

import Foundation
import SwiftData
import Testing
@testable import TinyStockCore

@Suite(.serialized)
@MainActor
struct StockServiceTests {

    private func makeProductAndVariant(
        initialQuantity: Int = 0,
        in context: ModelContext
    ) throws -> (Product, ProductVariant) {
        let product = Product(storeID: UUID(), name: "Produto principal")
        context.insert(product)
        let variant = try ProductVariantService.create(
            for: product,
            name: "Preta",
            initialQuantity: initialQuantity,
            in: context
        )
        return (product, variant)
    }

    @Test func estoqueInicialGeraMovimentacao() throws {
        let context = try TestDatabase.makeCleanContext()
        let (product, variant) = try makeProductAndVariant(initialQuantity: 3, in: context)

        let movements = try StockService.movements(
            for: variant,
            product: product,
            in: context
        )

        let movement = try #require(movements.first)
        #expect(movements.count == 1)
        #expect(movement.kind == .initialStock)
        #expect(movement.quantityDelta == 3)
        #expect(movement.balanceAfter == 3)
        #expect(variant.quantity == 3)
    }

    @Test func variacaoZeradaNaoCriaMovimentacaoInicial() throws {
        let context = try TestDatabase.makeCleanContext()
        let (product, variant) = try makeProductAndVariant(in: context)

        #expect(try StockService.movements(for: variant, product: product, in: context).isEmpty)
        #expect(variant.quantity == 0)
    }

    @Test func entradaSomaAoSaldoEGuardaReferencia() throws {
        let context = try TestDatabase.makeCleanContext()
        let (product, variant) = try makeProductAndVariant(initialQuantity: 2, in: context)
        let referenceID = UUID()
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        let movement = try StockService.registerEntry(
            quantity: 4,
            to: variant,
            product: product,
            note: "  Nova entrada  ",
            referenceID: referenceID,
            date: date,
            in: context
        )

        #expect(variant.quantity == 6)
        #expect(variant.updatedAt == date)
        #expect(movement.kind == .entry)
        #expect(movement.quantityDelta == 4)
        #expect(movement.balanceAfter == 6)
        #expect(movement.note == "Nova entrada")
        #expect(movement.referenceID == referenceID)
    }

    @Test func ajustePodeAumentarOuReduzirOSaldo() throws {
        let context = try TestDatabase.makeCleanContext()
        let (product, variant) = try makeProductAndVariant(initialQuantity: 5, in: context)

        let increase = try StockService.registerAdjustment(
            newQuantity: 8,
            to: variant,
            product: product,
            in: context
        )
        let decrease = try StockService.registerAdjustment(
            newQuantity: 3,
            to: variant,
            product: product,
            in: context
        )

        #expect(increase.quantityDelta == 3)
        #expect(increase.balanceAfter == 8)
        #expect(decrease.quantityDelta == -5)
        #expect(decrease.balanceAfter == 3)
        #expect(variant.quantity == 3)
    }

    @Test func entradaInvalidaEAjusteSemMudancaSaoRecusados() throws {
        let context = try TestDatabase.makeCleanContext()
        let (product, variant) = try makeProductAndVariant(initialQuantity: 2, in: context)

        #expect(throws: StockError.invalidQuantity) {
            try StockService.registerEntry(
                quantity: 0,
                to: variant,
                product: product,
                in: context
            )
        }
        #expect(throws: StockError.noChange) {
            try StockService.registerAdjustment(
                newQuantity: 2,
                to: variant,
                product: product,
                in: context
            )
        }
        #expect(throws: StockError.negativeBalance) {
            try StockService.registerAdjustment(
                newQuantity: -1,
                to: variant,
                product: product,
                in: context
            )
        }
    }

    @Test func reversaoDesfazEntradaSemApagarHistorico() throws {
        let context = try TestDatabase.makeCleanContext()
        let (product, variant) = try makeProductAndVariant(initialQuantity: 2, in: context)
        let entry = try StockService.registerEntry(
            quantity: 3,
            to: variant,
            product: product,
            in: context
        )
        let reversedAt = Date(timeIntervalSince1970: 1_800_000_000)

        let reversal = try StockService.reverse(
            entry,
            for: variant,
            product: product,
            note: "Entrada duplicada",
            date: reversedAt,
            in: context
        )

        #expect(variant.quantity == 2)
        #expect(entry.reversedAt == reversedAt)
        #expect(reversal.kind == .reversal)
        #expect(reversal.quantityDelta == -3)
        #expect(reversal.balanceAfter == 2)
        #expect(reversal.reversedMovementID == entry.id)
        #expect(reversal.note == "Entrada duplicada")
        #expect(try StockService.movements(for: variant, product: product, in: context).count == 3)
        #expect(throws: StockError.reversalNotAllowed) {
            try StockService.reverse(
                reversal,
                for: variant,
                product: product,
                in: context
            )
        }
    }

    @Test func mesmaMovimentacaoNaoPodeSerRevertidaDuasVezes() throws {
        let context = try TestDatabase.makeCleanContext()
        let (product, variant) = try makeProductAndVariant(in: context)
        let entry = try StockService.registerEntry(
            quantity: 2,
            to: variant,
            product: product,
            in: context
        )
        try StockService.reverse(entry, for: variant, product: product, in: context)

        #expect(throws: StockError.alreadyReversed) {
            try StockService.reverse(entry, for: variant, product: product, in: context)
        }
    }

    @Test func reversaoQueDeixariaSaldoNegativoEhBloqueada() throws {
        let context = try TestDatabase.makeCleanContext()
        let (product, variant) = try makeProductAndVariant(in: context)
        let entry = try StockService.registerEntry(
            quantity: 5,
            to: variant,
            product: product,
            in: context
        )
        try StockService.registerAdjustment(
            newQuantity: 2,
            to: variant,
            product: product,
            in: context
        )

        #expect(throws: StockError.negativeBalance) {
            try StockService.reverse(entry, for: variant, product: product, in: context)
        }
        #expect(variant.quantity == 2)
        #expect(entry.reversedAt == nil)
    }

    @Test func produtoOuMovimentacaoDeOutroEscopoSaoRecusados() throws {
        let context = try TestDatabase.makeCleanContext()
        let (firstProduct, firstVariant) = try makeProductAndVariant(in: context)
        let (secondProduct, secondVariant) = try makeProductAndVariant(in: context)
        let entry = try StockService.registerEntry(
            quantity: 1,
            to: firstVariant,
            product: firstProduct,
            in: context
        )

        #expect(throws: StockError.productMismatch) {
            try StockService.registerEntry(
                quantity: 1,
                to: firstVariant,
                product: secondProduct,
                in: context
            )
        }
        #expect(throws: StockError.movementMismatch) {
            try StockService.reverse(
                entry,
                for: secondVariant,
                product: secondProduct,
                in: context
            )
        }
    }

    @Test func historicoFicaIsoladoEOrdenadoDoMaisRecente() throws {
        let context = try TestDatabase.makeCleanContext()
        let (product, variant) = try makeProductAndVariant(in: context)
        let (otherProduct, otherVariant) = try makeProductAndVariant(in: context)
        let older = Date(timeIntervalSince1970: 1_700_000_000)
        let newer = Date(timeIntervalSince1970: 1_800_000_000)

        let first = try StockService.registerEntry(
            quantity: 1,
            to: variant,
            product: product,
            date: older,
            in: context
        )
        let second = try StockService.registerEntry(
            quantity: 2,
            to: variant,
            product: product,
            date: newer,
            in: context
        )
        try StockService.registerEntry(
            quantity: 9,
            to: otherVariant,
            product: otherProduct,
            date: newer,
            in: context
        )

        let movements = try StockService.movements(for: variant, product: product, in: context)

        #expect(movements.map(\.id) == [second.id, first.id])
        #expect(movements.allSatisfy { $0.variantID != otherVariant.id })
    }

    @Test func todoErroTemMensagemLocalizada() {
        let errors: [StockError] = [
            .invalidQuantity,
            .negativeBalance,
            .noChange,
            .quantityOverflow,
            .productMismatch,
            .movementMismatch,
            .alreadyReversed,
            .reversalNotAllowed,
            .orderManagedMovement
        ]

        for error in errors {
            #expect(!error.localizedMessage.isEmpty)
        }
    }
}
