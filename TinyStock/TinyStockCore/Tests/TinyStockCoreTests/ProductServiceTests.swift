// ⌘
//  TinyStockCoreTests/ProductServiceTests.swift
//
//  Propósito: Validar o cadastro canônico de produtos por loja.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-26.
// ⌘

import Foundation
import SwiftData
import Testing
@testable import TinyStockCore

@Suite(.serialized)
@MainActor
struct ProductServiceTests {

    @Test func criacaoPreservaSomenteOsDadosCanonicos() throws {
        let context = try TestDatabase.makeCleanContext()
        let storeID = UUID()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let imageData = Data([1, 2, 3])

        let product = try ProductService.create(
            storeID: storeID,
            name: "  Café Especial  ",
            costPrice: 40,
            salePrice: 100,
            imageData: imageData,
            date: date,
            in: context
        )

        #expect(product.storeID == storeID)
        #expect(product.name == "Café Especial")
        #expect(product.costPrice == 40)
        #expect(product.salePrice == 100)
        #expect(product.imageData == imageData)
        #expect(product.createdAt == date)
        #expect(product.updatedAt == date)
        #expect(product.category.isEmpty)
        #expect(product.quantity == 0)
        #expect(product.minimumStock == 0)
    }

    @Test func ordemManualEhPreservadaENovoProdutoEntraNoFim() throws {
        let context = try TestDatabase.makeCleanContext()
        let storeID = UUID()
        let bolsa = try ProductService.create(storeID: storeID, name: "Bolsa", in: context)
        let tapete = try ProductService.create(storeID: storeID, name: "Tapete", in: context)
        try context.save()

        ProductService.setDisplayOrder([tapete, bolsa])
        let touca = try ProductService.create(storeID: storeID, name: "Touca", in: context)
        try context.save()

        let ordered = try context.fetch(FetchDescriptor<Product>(
            sortBy: [SortDescriptor(\Product.sortOrder), SortDescriptor(\Product.name)]
        ))
        #expect(ordered.map(\.name) == ["Tapete", "Bolsa", "Touca"])
        #expect(touca.sortOrder == 2)
    }

    @Test func nomeVazioEhRecusado() throws {
        let context = try TestDatabase.makeCleanContext()

        #expect(throws: ProductError.emptyName) {
            try ProductService.create(storeID: UUID(), name: "   ", in: context)
        }
    }

    @Test func nomeDuplicadoNaMesmaLojaEhRecusado() throws {
        let context = try TestDatabase.makeCleanContext()
        let storeID = UUID()

        try ProductService.create(storeID: storeID, name: "Café Especial", in: context)
        try context.save()

        #expect(throws: ProductError.duplicateName) {
            try ProductService.create(storeID: storeID, name: "cafe especial", in: context)
        }
    }

    @Test func lojasDiferentesPodemUsarOMesmoNome() throws {
        let context = try TestDatabase.makeCleanContext()

        try ProductService.create(storeID: UUID(), name: "Caneca", in: context)
        try ProductService.create(storeID: UUID(), name: "Caneca", in: context)

        #expect(try context.fetchCount(FetchDescriptor<Product>()) == 2)
    }

    @Test func valoresNegativosSaoRecusados() throws {
        let context = try TestDatabase.makeCleanContext()
        let storeID = UUID()

        #expect(throws: ProductError.negativeCostPrice) {
            try ProductService.create(
                storeID: storeID,
                name: "Caneca",
                costPrice: -1,
                in: context
            )
        }

        #expect(throws: ProductError.negativeSalePrice) {
            try ProductService.create(
                storeID: storeID,
                name: "Caneca",
                salePrice: -1,
                in: context
            )
        }
    }

    @Test func edicaoPreservaLojaECriacao() throws {
        let context = try TestDatabase.makeCleanContext()
        let storeID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let product = Product(
            storeID: storeID,
            name: "Caneca",
            costPrice: 10,
            salePrice: 20,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        context.insert(product)

        try ProductService.update(
            product,
            name: "Caneca personalizada",
            costPrice: 12,
            salePrice: 30,
            imageData: nil,
            date: updatedAt,
            in: context
        )

        #expect(product.storeID == storeID)
        #expect(product.name == "Caneca personalizada")
        #expect(product.costPrice == 12)
        #expect(product.salePrice == 30)
        #expect(product.createdAt == createdAt)
        #expect(product.updatedAt == updatedAt)
    }

    @Test func todoErroTemMensagemLocalizada() {
        let errors: [ProductError] = [
            .emptyName,
            .duplicateName,
            .negativeCostPrice,
            .negativeSalePrice,
            .activeOrders
        ]

        for error in errors {
            #expect(!error.localizedMessage.isEmpty)
        }
    }
}
