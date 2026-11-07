// ⌘
//  TinyStockCoreTests/SaleCartTests.swift
//
//  Propósito: Testes do carrinho da venda: soma de linhas, limite do estoque e totais.
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
struct SaleCartTests {

    // MARK: - Apoio

    func makeContext() throws -> ModelContext {
        try TestDatabase.makeCleanContext()
    }

    // MARK: - Carrinho vazio

    @Test func carrinhoNasceVazio() {
        let carrinho = SaleCart()

        #expect(carrinho.isEmpty)
        #expect(carrinho.unitCount == 0)
        #expect(carrinho.total == 0)
        #expect(carrinho.profit == 0)
    }

    // MARK: - Adicionar

    @Test func adicionarProdutoCriaUmaLinhaComUmaUnidade() {
        let produto = Product(name: "Produto A", quantity: 10, costPrice: 20, salePrice: 45)
        var carrinho = SaleCart()

        carrinho.add(produto)

        #expect(carrinho.lines.count == 1)
        #expect(carrinho.quantity(of: produto) == 1)
        #expect(carrinho.total == 45)
    }

    @Test func mesmoProdutoDuasVezesViraUmaLinhaSo() {
        let produto = Product(name: "Produto A", quantity: 10, salePrice: 45)
        var carrinho = SaleCart()

        carrinho.add(produto)
        carrinho.add(produto)

        #expect(carrinho.lines.count == 1, "produto repetido soma, não empilha")
        #expect(carrinho.quantity(of: produto) == 2)
    }

    @Test func produtosDiferentesViramLinhasDiferentesNaOrdemEscolhida() {
        let produtoA = Product(name: "Produto A", quantity: 10, salePrice: 45)
        let produtoB = Product(name: "Produto B", quantity: 10, salePrice: 90)
        var carrinho = SaleCart()

        carrinho.add(produtoB)
        carrinho.add(produtoA)

        #expect(carrinho.lines.map(\.product.name) == ["Produto B", "Produto A"])
    }

    // MARK: - Limite do estoque

    @Test func carrinhoNaoPassaDoEstoque() {
        let produto = Product(name: "Produto D", quantity: 2, salePrice: 25)
        var carrinho = SaleCart()

        carrinho.add(produto, quantity: 7)

        #expect(carrinho.quantity(of: produto) == 2, "entra só o que cabe no estoque")
    }

    @Test func adicionarComOEstoqueJaTodoNoCarrinhoNaoFazNada() {
        let produto = Product(name: "Produto D", quantity: 2, salePrice: 25)
        var carrinho = SaleCart()

        carrinho.add(produto, quantity: 2)
        let coube = carrinho.add(produto)

        #expect(coube == false, "a interface precisa receber o resultado da tentativa")
        #expect(carrinho.quantity(of: produto) == 2)
    }

    @Test func oQueSobraDoEstoqueDescontaOCarrinho() {
        let produto = Product(name: "Produto B", quantity: 5, salePrice: 90)
        var carrinho = SaleCart()

        #expect(carrinho.remainingStock(of: produto) == 5)

        carrinho.add(produto, quantity: 3)

        #expect(carrinho.remainingStock(of: produto) == 2)
    }

    @Test func quantidadeAcimaDoEstoqueParaNoEstoque() {
        let produto = Product(name: "Produto C", quantity: 4, salePrice: 30)
        var carrinho = SaleCart()

        carrinho.add(produto)
        carrinho.setQuantity(99, for: produto)

        #expect(carrinho.quantity(of: produto) == 4)
    }

    // MARK: - Remover

    @Test func quantidadeZeradaTiraOProdutoDoCarrinho() {
        let produto = Product(name: "Produto A", quantity: 10, salePrice: 45)
        var carrinho = SaleCart()

        carrinho.add(produto, quantity: 3)
        carrinho.setQuantity(0, for: produto)

        #expect(carrinho.isEmpty)
    }

    @Test func removerPeloIndiceTiraALinhaCerta() {
        let produtoA = Product(name: "Produto A", quantity: 10, salePrice: 45)
        let produtoB = Product(name: "Produto B", quantity: 10, salePrice: 90)
        let produtoC = Product(name: "Produto C", quantity: 10, salePrice: 30)
        var carrinho = SaleCart()

        carrinho.add(produtoA)
        carrinho.add(produtoB)
        carrinho.add(produtoC)
        carrinho.remove(atOffsets: IndexSet(integer: 1))

        #expect(carrinho.lines.map(\.product.name) == ["Produto A", "Produto C"])
    }

    // MARK: - Totais

    @Test func totalELucroSomamTodasAsLinhas() {
        let produtoA = Product(name: "Produto A", quantity: 10, costPrice: 20, salePrice: 45)
        let produtoB = Product(name: "Produto B", quantity: 10, costPrice: 30, salePrice: 90)
        var carrinho = SaleCart()

        carrinho.add(produtoA, quantity: 2)
        carrinho.add(produtoB)

        #expect(carrinho.total == 180)     // 45 x 2 mais 90
        #expect(carrinho.profit == 110)    // 25 x 2 mais 60
        #expect(carrinho.unitCount == 3)
    }

    @Test func taxaDoCanalMostraOLucroLiquidoAntesDeFechar() {
        let produto = Product(name: "Produto E", quantity: 5, costPrice: 40, salePrice: 100)
        var carrinho = SaleCart()
        carrinho.add(produto)

        #expect(carrinho.channelFee(percentage: 14) == 14)
        #expect(carrinho.netProfit(channelFeePercentage: 14) == 46)
    }

    // MARK: - Fechamento da venda

    @Test func carrinhoFechaVendaComVariosProdutos() throws {
        let context = try makeContext()
        let produtoA = Product(name: "Produto A", quantity: 10, costPrice: 20, salePrice: 45)
        let produtoB = Product(name: "Produto B", quantity: 4, costPrice: 30, salePrice: 90)
        context.insert(produtoA)
        context.insert(produtoB)

        var carrinho = SaleCart()
        carrinho.add(produtoA, quantity: 2)
        carrinho.add(produtoB, quantity: 1)

        let venda = try SaleService.register(
            lines: carrinho.lines,
            paymentMethod: .shopee,
            in: context
        )

        #expect(venda.itemList.count == 2)
        #expect(venda.total == 180)
        #expect(venda.totalQuantity == 3)
        #expect(produtoA.quantity == 8, "cada produto dá baixa do que foi vendido")
        #expect(produtoB.quantity == 3)
    }

    @Test func itensDaVendaSaemSempreNaMesmaOrdem() throws {
        let context = try makeContext()
        let produtoB = Product(name: "Produto B", quantity: 10, salePrice: 90)
        let produtoA = Product(name: "Produto A", quantity: 10, salePrice: 45)
        context.insert(produtoB)
        context.insert(produtoA)

        var carrinho = SaleCart()
        carrinho.add(produtoB)
        carrinho.add(produtoA)

        let venda = try SaleService.register(
            lines: carrinho.lines,
            paymentMethod: .pix,
            in: context
        )

        // A relação do SwiftData não preserva ordem, então a lista aplica ordenação estável.
        #expect(venda.itemList.map(\.productName) == ["Produto A", "Produto B"])
    }

    @Test func carrinhoMontadoNoLimiteFechaAVenda() throws {
        let context = try makeContext()
        let produto = Product(name: "Produto D", quantity: 3, salePrice: 25)
        context.insert(produto)

        var carrinho = SaleCart()
        carrinho.add(produto, quantity: 2)
        carrinho.add(produto, quantity: 5)   // trava em 3, que é o estoque

        // O serviço não pode recusar uma venda que o carrinho deixou montar.
        let venda = try SaleService.register(
            lines: carrinho.lines,
            paymentMethod: .cash,
            in: context
        )

        #expect(venda.totalQuantity == 3)
        #expect(produto.quantity == 0)
    }
}
