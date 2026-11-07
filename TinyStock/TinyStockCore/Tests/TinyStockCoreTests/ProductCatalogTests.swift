// Proposito: Validar consultas e exclusao do catalogo sem misturar lojas ou apagar vendas.
// Created by Jonathas Motta (@jonathaxs) on 2026-08-31.

import Foundation
import SwiftData
import Testing
@testable import TinyStockCore

@Suite(.serialized)
@MainActor
struct ProductCatalogTests {
    @Test func buscaEncontraNomeOuVariacaoSemCategoriaLegada() {
        let product = Product(storeID: UUID(), name: "Caneca", category: "Categoria antiga")
        let variant = ProductVariant(storeID: product.storeID, productID: product.id, name: "Única")
        #expect(product.matches(searchText: "  ", variants: []))
        #expect(product.matches(searchText: "CANECA", variants: []))
        #expect(product.matches(searchText: " unica ", variants: [variant]))
        #expect(!product.matches(searchText: "Categoria antiga", variants: [variant]))
    }

    @Test func buscaESomaIgnoramVariacoesDeOutroProdutoOuLoja() {
        let product = Product(storeID: UUID(), name: "Caneca")
        let own = ProductVariant(storeID: product.storeID, productID: product.id, name: "Branca", quantity: 2)
        let otherProduct = ProductVariant(storeID: product.storeID, productID: UUID(), name: "Verde", quantity: 7)
        let otherStore = ProductVariant(storeID: UUID(), productID: product.id, name: "Azul", quantity: 9)
        let variants = [own, otherProduct, otherStore]
        #expect(ProductVariantService.displayedQuantity(for: product, among: variants) == 2)
        #expect(!product.matches(searchText: "Verde", variants: variants))
        #expect(!product.matches(searchText: "Azul", variants: variants))
    }

    @Test func somaVisivelNaoUsaEstoqueLegadoENaoEstouraInt() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = Product(storeID: UUID(), name: "Produto", quantity: 100)
        context.insert(product)
        #expect(ProductVariantService.displayedQuantity(for: product, among: []) == 0)
        let first = try ProductVariantService.create(for: product, name: "A", initialQuantity: Int.max, in: context)
        let second = try ProductVariantService.create(for: product, name: "B", initialQuantity: 1, in: context)
        #expect(ProductVariantService.displayedQuantity(for: product, among: [first, second]) == Decimal(Int.max) + 1)
        #expect(throws: StockError.quantityOverflow) {
            try ProductVariantService.totalQuantity(for: product, in: context)
        }
    }

    @Test func exclusaoRemoveSomenteEstoqueDoProdutoEPreservaVenda() throws {
        let context = try TestDatabase.makeCleanContext()
        let first = try ProductService.create(storeID: UUID(), name: "Caneca", costPrice: 10, salePrice: 25, in: context)
        let second = try ProductService.create(storeID: UUID(), name: "Caneca", in: context)
        try ProductVariantService.create(for: first, name: "Branca", initialQuantity: 2, in: context)
        let keptVariant = try ProductVariantService.create(for: second, name: "Branca", initialQuantity: 3, in: context)
        let sale = Sale(storeID: first.storeID)
        context.insert(sale)
        let item = SaleItem.from(product: first, quantity: 1)
        context.insert(item)
        item.sale = sale
        try context.save()

        try ProductService.delete(first, in: context)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Product>()).map(\.id) == [second.id])
        #expect(try context.fetch(FetchDescriptor<ProductVariant>()).map(\.id) == [keptVariant.id])
        let movements = try context.fetch(FetchDescriptor<StockMovement>())
        #expect(movements.count == 1)
        #expect(movements.first?.productID == second.id)
        #expect(try context.fetchCount(FetchDescriptor<Sale>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SaleItem>()) == 1)
        #expect(sale.total == 25 && sale.profit == 15)
        #expect(item.productName == "Caneca")
    }

    @Test func rollbackDaExclusaoRestauraProdutoEEstoque() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = try ProductService.create(storeID: UUID(), name: "Produto", in: context)
        try ProductVariantService.create(for: product, name: "Unica", initialQuantity: 2, in: context)
        try context.save()
        try ProductService.delete(product, in: context)
        context.rollback()
        #expect(try context.fetchCount(FetchDescriptor<Product>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ProductVariant>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<StockMovement>()) == 1)
    }

    @Test func exclusaoTambemLimpaMovimentacaoSemVariacao() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = try ProductService.create(storeID: UUID(), name: "Produto", in: context)
        context.insert(StockMovement(storeID: product.storeID, productID: product.id))
        try ProductService.delete(product, in: context)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<StockMovement>()) == 0)
    }

    @Test func entradaEmNovaVariacaoRegistraRecebimentoNaoSaldoInicial() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = try ProductService.create(storeID: UUID(), name: "Caneca", in: context)
        let entry = try StockService.registerEntry(quantity: 3, for: product, variantID: nil,
                                                  newVariantName: " Verde ", note: " Recebido ", in: context)
        try context.save()
        let variant = try #require(ProductVariantService.variants(for: product, in: context).first)
        #expect(variant.name == "Verde" && variant.quantity == 3)
        #expect(entry.kind == .entry && entry.quantityDelta == 3)
        #expect(entry.note == "Recebido")
        #expect(try context.fetchCount(FetchDescriptor<StockMovement>()) == 1)
    }

    @Test func entradaExistenteReconsultaSaldoERecusaOpcaoDeOutraLoja() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = try ProductService.create(storeID: UUID(), name: "Caneca", in: context)
        let other = try ProductService.create(storeID: UUID(), name: "Caneca", in: context)
        let variant = try ProductVariantService.create(for: product, name: "Azul", initialQuantity: 2, in: context)
        try StockService.registerEntry(quantity: 3, for: product, variantID: variant.id, in: context)
        try StockService.registerEntry(quantity: 4, for: product, variantID: variant.id, in: context)
        #expect(variant.quantity == 9)
        #expect(throws: StockError.productMismatch) {
            try StockService.registerEntry(quantity: 1, for: other, variantID: variant.id, in: context)
        }
        #expect(throws: StockError.productMismatch) {
            try StockService.registerEntry(quantity: 1, for: product, variantID: UUID(), in: context)
        }
        #expect(variant.quantity == 9)
    }

    @Test func entradasInvalidasNaoCriamVariacaoNemMovimentacao() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = try ProductService.create(storeID: UUID(), name: "Caneca", in: context)
        let variant = try ProductVariantService.create(for: product, name: "Azul", initialQuantity: Int.max, in: context)
        #expect(throws: StockError.invalidQuantity) {
            try StockService.registerEntry(quantity: 0, for: product, variantID: nil, newVariantName: "Verde", in: context)
        }
        #expect(throws: ProductVariantError.duplicateName) {
            try StockService.registerEntry(quantity: 1, for: product, variantID: nil, newVariantName: "azul", in: context)
        }
        #expect(throws: StockError.quantityOverflow) {
            try StockService.registerEntry(quantity: 1, for: product, variantID: variant.id, in: context)
        }
        #expect(variant.quantity == Int.max)
        #expect(try context.fetchCount(FetchDescriptor<ProductVariant>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<StockMovement>()) == 1)
    }
}
