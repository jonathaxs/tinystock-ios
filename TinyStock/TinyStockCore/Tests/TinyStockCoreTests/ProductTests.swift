// ⌘
//  TinyStockCoreTests/ProductTests.swift
//
//  Propósito: Testes do model Product cobrindo o alerta de estoque baixo e o lucro unitário.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-07.
// ⌘

import Testing
import Foundation
import SwiftData
@testable import TinyStockCore

// MARK: - Testes do Product

@Test func lowStockLigaQuandoQuantidadeAtingeMinimo() {
    // Estoque igual ou abaixo do mínimo deve acender o alerta.
    let produto = Product(name: "Produto A", quantity: 3, minimumStock: 5)
    #expect(produto.isLowStock == true)
}

@Test func lowStockDesligaQuandoMinimoZero() {
    // Mínimo zero significa "sem alerta", mesmo com estoque zerado.
    let produto = Product(name: "Produto B", quantity: 0, minimumStock: 0)
    #expect(produto.isLowStock == false)
}

@Test func lucroUnitarioEhPrecoMenosCusto() {
    let produto = Product(name: "Produto C", costPrice: 8, salePrice: 25)
    #expect(produto.unitProfit == 17)
}

@Test func lowStockDesligaQuandoEstoqueEstaAcimaDoMinimo() {
    let produto = Product(name: "Produto D", quantity: 10, minimumStock: 3)
    #expect(produto.isLowStock == false)
}

@Test func lowStockLigaComEstoqueZeradoEMinimoDefinido() {
    // Estoque acabou de vez, que é justamente quando o alerta mais importa.
    let produto = Product(name: "Produto C", quantity: 0, minimumStock: 2)
    #expect(produto.isLowStock == true)
}

// MARK: - Busca

@Test func buscaVaziaDevolveTodosOsProdutos() {
    let produto = Product(name: "Luminária Clássica", category: "Decoração")
    #expect(produto.matches(searchText: "") == true)
    #expect(produto.matches(searchText: "   ") == true)
}

@Test func buscaEncontraPorPedacoDoNome() {
    let produto = Product(name: "Luminária Clássica", category: "Decoração")
    #expect(produto.matches(searchText: "classica") == true)
}

@Test func buscaIgnoraAcentoEMaiuscula() {
    // A busca deve aceitar o texto sem acentos e com outra capitalização.
    let produto = Product(name: "Luminária Clássica", category: "Decoração")
    #expect(produto.matches(searchText: "DECORACAO") == true)
}

@Test func buscaEncontraPelaCategoria() {
    let produto = Product(name: "Caderno", category: "Acessórios")
    #expect(produto.matches(searchText: "acessorios") == true)
}

@Test func buscaNaoEncontraOQueNaoExiste() {
    let produto = Product(name: "Luminária Clássica", category: "Decoração")
    #expect(produto.matches(searchText: "caneca") == false)
}

// MARK: - Lucro

@Test func lucroPotencialMultiplicaOLucroPelaQuantidade() {
    let produto = Product(name: "Produto A", quantity: 4, costPrice: 10, salePrice: 25)
    #expect(produto.potentialProfit == 60)
}

@Test func lucroPotencialEhZeroComEstoqueVazio() {
    let produto = Product(name: "Produto B", quantity: 0, costPrice: 30, salePrice: 90)
    #expect(produto.potentialProfit == 0)
}

// MARK: - Persistência

/// Serializada e com banco compartilhado: ver [TestDatabase] para o porquê.
@Suite(.serialized)
@MainActor
struct ProductPersistenceTests {

    @Test func produtoSalvoPodeSerLidoDeVolta() throws {
        // Banco em memória imita o que o formulário faz de verdade,
        // sem depender do banco no disco do aparelho.
        let context = try TestDatabase.makeCleanContext()

        context.insert(
            Product(name: "Luminária Clássica", category: "Decoração", quantity: 12, costPrice: 20, salePrice: 45)
        )

        let salvos = try context.fetch(FetchDescriptor<Product>())

        #expect(salvos.count == 1)
        #expect(salvos.first?.name == "Luminária Clássica")
        #expect(salvos.first?.category == "Decoração")
        #expect(salvos.first?.quantity == 12)
        #expect(salvos.first?.unitProfit == 25)
    }

    @Test func edicaoAlteraOsCamposEPreservaACriacao() throws {
        let context = try TestDatabase.makeCleanContext()

        let criadoEm = Date(timeIntervalSince1970: 1_700_000_000)
        let produto = Product(name: "Organizador", quantity: 2, salePrice: 25, createdAt: criadoEm, updatedAt: criadoEm)
        context.insert(produto)

        // Mesma operação que o formulário faz ao salvar uma edição.
        produto.name = "Organizador V2"
        produto.quantity = 10
        produto.salePrice = 30
        produto.updatedAt = Date()

        let salvos = try context.fetch(FetchDescriptor<Product>())

        #expect(salvos.count == 1, "editar não pode criar um segundo registro")
        #expect(salvos.first?.name == "Organizador V2")
        #expect(salvos.first?.quantity == 10)
        #expect(salvos.first?.createdAt == criadoEm, "a data original deve ser preservada")
        #expect(salvos.first?.updatedAt != criadoEm)
    }

    @Test func exclusaoTiraOProdutoDoEstoque() throws {
        let context = try TestDatabase.makeCleanContext()

        let removedProduct = Product(name: "Produto removido", quantity: 12)
        let remainingProduct = Product(name: "Produto mantido", quantity: 8)
        context.insert(removedProduct)
        context.insert(remainingProduct)

        context.delete(removedProduct)

        let restantes = try context.fetch(FetchDescriptor<Product>())

        #expect(restantes.count == 1)
        #expect(restantes.first?.name == "Produto mantido")
    }
}
