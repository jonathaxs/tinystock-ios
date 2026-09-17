// TinyStockCore/Tests/TinyStockCoreTests/ProductFormServiceTests.swift
//
// Proposito: Testar o cadastro completo e a preservacao dos saldos na edicao.
//
// Created by Jonathas Motta (@jonathaxs) on 2026-08-30.

import Foundation
import SwiftData
import Testing
@testable import TinyStockCore

@Suite(.serialized)
@MainActor
struct ProductFormServiceTests {
    @Test func cadastroSalvaVariacoesESaldosComHistorico() throws {
        let context = try TestDatabase.makeCleanContext()
        let storeID = UUID()
        let product = try ProductFormService.apply(
            storeID: storeID, name: " Caneca ", costPrice: 10, salePrice: 25,
            imageData: Data([1, 2]), variants: [
                ProductVariantInput(name: "Branca", initialQuantity: 2),
                ProductVariantInput(name: "Verde", initialQuantity: 0)
            ], in: context
        )
        try context.save()
        let variants = try ProductVariantService.variants(for: product, in: context)
        #expect(product.name == "Caneca")
        #expect(product.imageData == Data([1, 2]))
        #expect(variants.count == 2)
        #expect(variants.allSatisfy { $0.storeID == storeID && $0.productID == product.id })
        #expect(variants.map(\.quantity) == [2, 0])
        #expect(try context.fetchCount(FetchDescriptor<StockMovement>()) == 1)

        // Um novo contexto comprova que o conjunto sobrevive a reabertura do formulario.
        let reader = ModelContext(TestDatabase.container)
        #expect(try reader.fetchCount(FetchDescriptor<ProductVariant>()) == 2)
    }

    @Test func cadastroSemVariacoesCriaVariacaoInterna() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = try ProductFormService.apply(
            storeID: UUID(), name: "Produto", costPrice: 0, salePrice: 0,
            imageData: nil, variants: [], usesVariants: false, in: context
        )
        let variant = try #require(ProductVariantService.variants(for: product, in: context).first)

        #expect(variant.isDefault)
        #expect(variant.name == ProductVariant.internalDefaultName)
        #expect(variant.quantity == 0)
        #expect(try context.fetchCount(FetchDescriptor<StockMovement>()) == 0)

        try context.save()
        let reader = ModelContext(TestDatabase.container)
        let persisted = try #require(reader.fetch(FetchDescriptor<ProductVariant>()).first)
        #expect(persisted.isDefault)
    }

    @Test func cadastroComVariacoesExigePeloMenosUmaVariacao() throws {
        let context = try TestDatabase.makeCleanContext()
        #expect(throws: ProductFormError.missingVariation) {
            try ProductFormService.apply(storeID: UUID(), name: "Produto", costPrice: 0,
                                         salePrice: 0, imageData: nil, variants: [], in: context)
        }
        #expect(try context.fetchCount(FetchDescriptor<Product>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ProductVariant>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<StockMovement>()) == 0)
    }

    @Test func ativarEDesativarVariacaoPreservaIdentidadeSaldoEHistorico() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = try ProductFormService.apply(
            storeID: UUID(), name: "Produto", costPrice: 0, salePrice: 0,
            imageData: nil, variants: [], usesVariants: false, in: context
        )
        let variant = try #require(ProductVariantService.variants(for: product, in: context).first)
        try StockService.registerEntry(quantity: 3, to: variant, product: product, in: context)

        try ProductFormService.apply(
            to: product, storeID: product.storeID, name: product.name,
            costPrice: 0, salePrice: 0, imageData: nil,
            variants: [.init(existingID: variant.id, name: "Preta", initialQuantity: 3)],
            usesVariants: true, in: context
        )
        #expect(!variant.isDefault)
        #expect(variant.name == "Preta")
        #expect(variant.quantity == 3)

        try ProductFormService.apply(
            to: product, storeID: product.storeID, name: product.name,
            costPrice: 0, salePrice: 0, imageData: nil,
            variants: [], usesVariants: false, in: context
        )
        let stored = try ProductVariantService.variants(for: product, in: context)
        #expect(stored.map(\.id) == [variant.id])
        #expect(variant.isDefault)
        #expect(variant.name == ProductVariant.internalDefaultName)
        #expect(variant.quantity == 3)
        #expect(try context.fetchCount(FetchDescriptor<StockMovement>()) == 1)
    }

    @Test func variasVariacoesNaoPodemSerOcultadas() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = try ProductService.create(storeID: UUID(), name: "Produto", in: context)
        let first = try ProductVariantService.create(for: product, name: "Preta", in: context)
        let second = try ProductVariantService.create(for: product, name: "Branca", in: context)

        #expect(throws: ProductFormError.cannotDisableMultipleVariations) {
            try ProductFormService.apply(
                to: product, storeID: product.storeID, name: product.name,
                costPrice: 0, salePrice: 0, imageData: nil,
                variants: [], usesVariants: false, in: context
            )
        }
        #expect(!first.isDefault && !second.isDefault)
        #expect(Set([first.name, second.name]) == Set(["Preta", "Branca"]))
    }

    @Test func variacoesInvalidasNaoCriamProdutoParcial() throws {
        let context = try TestDatabase.makeCleanContext()
        let cases: [([ProductVariantInput], ProductVariantError)] = [
            ([.init(name: "Azul"), .init(name: " azul ")], .duplicateName),
            ([.init(name: "Válida"), .init(name: "  ")], .emptyName),
            ([.init(name: "Azul", initialQuantity: -1)], .negativeQuantity),
            ([.init(existingID: UUID(), name: "Azul")], .productMismatch)
        ]
        for (inputs, error) in cases {
            #expect(throws: error) {
                try ProductFormService.apply(storeID: UUID(), name: "Produto", costPrice: 0,
                                             salePrice: 0, imageData: nil, variants: inputs, in: context)
            }
            #expect(try context.fetchCount(FetchDescriptor<Product>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<ProductVariant>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<StockMovement>()) == 0)
        }
    }

    @Test func edicaoPreservaSaldoMesmoComQuantidadeAntigaNoRascunho() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = try ProductService.create(storeID: UUID(), name: "Produto", in: context)
        let variant = try ProductVariantService.create(for: product, name: "Azul", initialQuantity: 2, in: context)
        let input = ProductVariantInput(existingID: variant.id, name: "Azul claro", initialQuantity: 2)
        try StockService.registerEntry(quantity: 3, to: variant, product: product, in: context)

        try ProductFormService.apply(to: product, storeID: product.storeID, name: "Renomeado",
                                     costPrice: 1, salePrice: 3, imageData: nil, variants: [input], in: context)
        #expect(product.name == "Renomeado")
        #expect(variant.name == "Azul claro")
        #expect(variant.quantity == 5)
        #expect(try context.fetchCount(FetchDescriptor<StockMovement>()) == 2)
    }

    @Test func nomesPodemSerTrocadosSemFalsaDuplicata() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = try ProductService.create(storeID: UUID(), name: "Produto", in: context)
        let first = try ProductVariantService.create(for: product, name: "Azul", initialQuantity: 2, in: context)
        let second = try ProductVariantService.create(for: product, name: "Verde", initialQuantity: 3, in: context)
        try ProductFormService.apply(to: product, storeID: product.storeID, name: product.name,
                                     costPrice: 0, salePrice: 0, imageData: nil, variants: [
                                        .init(existingID: first.id, name: "Verde"),
                                        .init(existingID: second.id, name: "Azul"),
                                        .init(name: "Branca", initialQuantity: 1)
                                     ], in: context)
        #expect(first.name == "Verde" && first.quantity == 2)
        #expect(second.name == "Azul" && second.quantity == 3)
        #expect(try context.fetchCount(FetchDescriptor<StockMovement>()) == 3)
    }

    @Test func variacoesOmitidasSaoPreservadasEParticipamDaValidacao() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = try ProductService.create(storeID: UUID(), name: "Produto", in: context)
        let variant = try ProductVariantService.create(for: product, name: "Única", initialQuantity: 2, in: context)
        #expect(throws: ProductVariantError.duplicateName) {
            try ProductFormService.apply(to: product, storeID: product.storeID, name: "Alterado",
                                         costPrice: 0, salePrice: 0, imageData: nil,
                                         variants: [.init(name: "unica")], in: context)
        }
        #expect(product.name == "Produto")
        try ProductFormService.apply(to: product, storeID: product.storeID, name: product.name,
                                     costPrice: 0, salePrice: 0, imageData: nil, variants: [], in: context)
        #expect(variant.quantity == 2)
        #expect(try ProductVariantService.variants(for: product, in: context).count == 1)
    }

    @Test func produtoInvalidoNaoAlteraVariacoes() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = try ProductService.create(storeID: UUID(), name: "Produto", in: context)
        let variant = try ProductVariantService.create(for: product, name: "Azul", in: context)
        #expect(throws: ProductError.negativeCostPrice) {
            try ProductFormService.apply(to: product, storeID: product.storeID, name: "Alterado",
                                         costPrice: -1, salePrice: 1, imageData: nil,
                                         variants: [.init(existingID: variant.id, name: "Verde")], in: context)
        }
        #expect(product.name == "Produto")
        #expect(variant.name == "Azul")
    }

    @Test func naoPermiteMoverProdutoOuVariacaoEntreLojas() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = try ProductService.create(storeID: UUID(), name: "Produto", in: context)
        let other = try ProductService.create(storeID: UUID(), name: "Produto", in: context)
        let variant = try ProductVariantService.create(for: other, name: "Azul", in: context)
        #expect(throws: ProductVariantError.productMismatch) {
            try ProductFormService.apply(to: product, storeID: other.storeID, name: "Novo",
                                         costPrice: 0, salePrice: 0, imageData: nil, variants: [], in: context)
        }
        #expect(throws: ProductVariantError.productMismatch) {
            try ProductFormService.apply(to: product, storeID: product.storeID, name: "Novo",
                                         costPrice: 0, salePrice: 0, imageData: nil,
                                         variants: [.init(existingID: variant.id, name: "Verde")], in: context)
        }
        #expect(product.name == "Produto")
        #expect(variant.name == "Azul")
    }

    @Test func rollbackDesfazTodoOCadastroSemApagarDadosAnteriores() throws {
        let context = try TestDatabase.makeCleanContext()
        try ProductService.create(storeID: UUID(), name: "Anterior", in: context)
        try context.save()
        try ProductFormService.apply(storeID: UUID(), name: "Rascunho", costPrice: 0,
                                     salePrice: 0, imageData: nil,
                                     variants: [.init(name: "Azul", initialQuantity: 3)], in: context)
        context.rollback()
        #expect(try context.fetch(FetchDescriptor<Product>()).map(\.name) == ["Anterior"])
        #expect(try context.fetchCount(FetchDescriptor<ProductVariant>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<StockMovement>()) == 0)
    }
}
