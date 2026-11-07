// ⌘
//  TinyStockCoreTests/ProductVariantTests.swift
//
//  Propósito: Validar o isolamento e as regras das variações de produto.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-27.
// ⌘

import Foundation
import SwiftData
import Testing
@testable import TinyStockCore

@Suite(.serialized)
@MainActor
struct ProductVariantTests {

    @Test func criacaoHerdaProdutoELoja() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = Product(storeID: UUID(), name: "Produto principal")
        context.insert(product)
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        let variant = try ProductVariantService.create(
            for: product,
            name: "  Preta  ",
            initialQuantity: 2,
            date: date,
            in: context
        )

        #expect(variant.storeID == product.storeID)
        #expect(variant.productID == product.id)
        #expect(variant.name == "Preta")
        #expect(variant.quantity == 2)
        #expect(variant.createdAt == date)
        #expect(variant.updatedAt == date)
        #expect(variant.belongs(to: product))
    }

    @Test func consultaIsolaProdutoELoja() throws {
        let context = try TestDatabase.makeCleanContext()
        let first = Product(storeID: UUID(), name: "Caneca")
        let second = Product(storeID: UUID(), name: "Caneca")
        context.insert(first)
        context.insert(second)

        try ProductVariantService.create(for: first, name: "Branca", initialQuantity: 2, in: context)
        try ProductVariantService.create(for: first, name: "Verde", initialQuantity: 1, in: context)
        try ProductVariantService.create(for: second, name: "Branca", initialQuantity: 9, in: context)

        let firstVariants = try ProductVariantService.variants(for: first, in: context)

        #expect(firstVariants.map(\.name) == ["Branca", "Verde"])
        #expect(firstVariants.allSatisfy { $0.storeID == first.storeID })
        #expect(firstVariants.allSatisfy { $0.productID == first.id })
    }

    @Test func nomeDuplicadoNoMesmoProdutoEhRecusado() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = Product(storeID: UUID(), name: "Produto principal")
        context.insert(product)

        try ProductVariantService.create(for: product, name: "Vermelha", in: context)

        #expect(throws: ProductVariantError.duplicateName) {
            try ProductVariantService.create(for: product, name: "vermelha", in: context)
        }
    }

    @Test func produtosDiferentesPodemRepetirNomeDaVariacao() throws {
        let context = try TestDatabase.makeCleanContext()
        let storeID = UUID()
        let first = Product(storeID: storeID, name: "Caneca")
        let second = Product(storeID: storeID, name: "Camiseta")
        context.insert(first)
        context.insert(second)

        try ProductVariantService.create(for: first, name: "Branca", in: context)
        try ProductVariantService.create(for: second, name: "Branca", in: context)

        #expect(try context.fetchCount(FetchDescriptor<ProductVariant>()) == 2)
    }

    @Test func nomeVazioEQuantidadeNegativaSaoRecusados() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = Product(storeID: UUID(), name: "Produto principal")
        context.insert(product)

        #expect(throws: ProductVariantError.emptyName) {
            try ProductVariantService.create(for: product, name: "   ", in: context)
        }

        #expect(throws: ProductVariantError.negativeQuantity) {
            try ProductVariantService.create(
                for: product,
                name: "Edição limitada",
                initialQuantity: -1,
                in: context
            )
        }
    }

    @Test func renomearPreservaSaldoECriacao() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = Product(storeID: UUID(), name: "Caneca")
        context.insert(product)
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let variant = try ProductVariantService.create(
            for: product,
            name: "Branca",
            initialQuantity: 3,
            date: createdAt,
            in: context
        )

        try ProductVariantService.rename(
            variant,
            to: "Verde",
            for: product,
            date: updatedAt,
            in: context
        )

        #expect(variant.name == "Verde")
        #expect(variant.quantity == 3)
        #expect(variant.createdAt == createdAt)
        #expect(variant.updatedAt == updatedAt)
    }

    @Test func produtoErradoNaoPodeRenomearVariacao() throws {
        let context = try TestDatabase.makeCleanContext()
        let first = Product(storeID: UUID(), name: "Caneca")
        let second = Product(storeID: UUID(), name: "Camiseta")
        context.insert(first)
        context.insert(second)
        let variant = try ProductVariantService.create(for: first, name: "Branca", in: context)

        #expect(throws: ProductVariantError.productMismatch) {
            try ProductVariantService.rename(
                variant,
                to: "Verde",
                for: second,
                in: context
            )
        }
    }

    @Test func totalSomaSomenteAsVariacoesDoProduto() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = Product(storeID: UUID(), name: "Produto principal")
        let other = Product(storeID: UUID(), name: "Caneca")
        context.insert(product)
        context.insert(other)

        try ProductVariantService.create(for: product, name: "Preta", initialQuantity: 2, in: context)
        try ProductVariantService.create(for: product, name: "Vermelha", initialQuantity: 1, in: context)
        try ProductVariantService.create(for: other, name: "Branca", initialQuantity: 20, in: context)

        #expect(try ProductVariantService.totalQuantity(for: product, in: context) == 3)
    }

    @Test func todoErroTemMensagemLocalizada() {
        let errors: [ProductVariantError] = [
            .emptyName,
            .duplicateName,
            .negativeQuantity,
            .productMismatch
        ]

        for error in errors {
            #expect(!error.localizedMessage.isEmpty)
        }
    }
}
