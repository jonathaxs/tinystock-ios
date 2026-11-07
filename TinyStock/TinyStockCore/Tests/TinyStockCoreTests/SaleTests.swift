// ⌘
//  TinyStockCoreTests/SaleTests.swift
//
//  Propósito: Testes do registro de venda, cobrindo baixa de estoque, bloqueio e totais.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-11.
// ⌘

import Testing
import Foundation
import SwiftData
@testable import TinyStockCore

/// Serializada e com banco compartilhado: ver [TestDatabase] para o porquê.
@Suite(.serialized)
@MainActor
struct SaleTests {

    // MARK: - Apoio

    /// Banco limpo, compartilhado com as outras suítes do processo.
    func makeContext() throws -> ModelContext {
        try TestDatabase.makeCleanContext()
    }

    func money(cents: Int) -> Decimal {
        Decimal(cents) / 100
    }

    // MARK: - Baixa de estoque

    @Test func vendaDaBaixaNoEstoque() throws {
        let context = try makeContext()
        let produto = Product(name: "Produto A", quantity: 12, costPrice: 20, salePrice: 45)
        context.insert(produto)

        try SaleService.register(
            lines: [SaleLine(product: produto, quantity: 3)],
            paymentMethod: .pix,
            in: context
        )

        #expect(produto.quantity == 9)
    }

    @Test func vendaDoEstoqueInteiroDeixaZerado() throws {
        let context = try makeContext()
        let produto = Product(name: "Tapete Redondo", quantity: 4, salePrice: 90)
        context.insert(produto)

        try SaleService.register(
            lines: [SaleLine(product: produto, quantity: 4)],
            paymentMethod: .cash,
            in: context
        )

        #expect(produto.quantity == 0)
    }

    @Test func vendaAtualizaADataDeEdicaoDoProduto() throws {
        let context = try makeContext()
        let antes = Date(timeIntervalSince1970: 1_700_000_000)
        let produto = Product(name: "Produto B", quantity: 5, salePrice: 30, updatedAt: antes)
        context.insert(produto)

        try SaleService.register(
            lines: [SaleLine(product: produto, quantity: 1)],
            paymentMethod: .pix,
            in: context
        )

        #expect(produto.updatedAt > antes)
    }

    // MARK: - Bloqueios

    @Test func vendaAcimaDoEstoqueEhBloqueada() throws {
        let context = try makeContext()
        let produto = Product(name: "Suporte de Fone", quantity: 2, salePrice: 25)
        context.insert(produto)

        #expect(throws: SaleError.insufficientStock(productName: "Suporte de Fone", available: 2, requested: 5)) {
            try SaleService.register(
                lines: [SaleLine(product: produto, quantity: 5)],
                paymentMethod: .pix,
                in: context
            )
        }
    }

    @Test func vendaBloqueadaNaoMexeNoEstoque() throws {
        let context = try makeContext()
        let produto = Product(name: "Suporte de Fone", quantity: 2, salePrice: 25)
        context.insert(produto)

        #expect(throws: SaleError.self) {
            try SaleService.register(
                lines: [SaleLine(product: produto, quantity: 5)],
                paymentMethod: .pix,
                in: context
            )
        }

        #expect(produto.quantity == 2, "venda recusada não pode encostar no estoque")

        let vendas = try context.fetch(FetchDescriptor<Sale>())
        #expect(vendas.isEmpty, "venda recusada não pode virar registro")
    }

    @Test func vendaSemItensEhBloqueada() throws {
        let context = try makeContext()

        #expect(throws: SaleError.emptySale) {
            try SaleService.register(lines: [], paymentMethod: .pix, in: context)
        }
    }

    @Test func quantidadeZeradaEhBloqueada() throws {
        let context = try makeContext()
        let produto = Product(name: "Produto A", quantity: 10, salePrice: 45)
        context.insert(produto)

        #expect(throws: SaleError.invalidQuantity(productName: "Produto A")) {
            try SaleService.register(
                lines: [SaleLine(product: produto, quantity: 0)],
                paymentMethod: .pix,
                in: context
            )
        }
    }

    @Test func mesmoProdutoRepetidoSomaAntesDeValidarOEstoque() throws {
        let context = try makeContext()
        let produto = Product(name: "Produto A", quantity: 5, salePrice: 45)
        context.insert(produto)

        // Três mais três dá seis, e só existem cinco. Tem que barrar mesmo cada linha
        // isolada cabendo no estoque.
        #expect(throws: SaleError.insufficientStock(productName: "Produto A", available: 5, requested: 6)) {
            try SaleService.register(
                lines: [
                    SaleLine(product: produto, quantity: 3),
                    SaleLine(product: produto, quantity: 3)
                ],
                paymentMethod: .pix,
                in: context
            )
        }

        #expect(produto.quantity == 5)
    }

    @Test func mesmoProdutoRepetidoViraUmItemSo() throws {
        let context = try makeContext()
        let produto = Product(name: "Produto A", quantity: 10, costPrice: 20, salePrice: 45)
        context.insert(produto)

        let venda = try SaleService.register(
            lines: [
                SaleLine(product: produto, quantity: 2),
                SaleLine(product: produto, quantity: 3)
            ],
            paymentMethod: .pix,
            in: context
        )

        #expect(venda.itemList.count == 1)
        #expect(venda.totalQuantity == 5)
        #expect(produto.quantity == 5)
    }

    @Test func vendaHerdaALojaDoProduto() throws {
        let context = try makeContext()
        let storeID = UUID()
        let produto = Product(storeID: storeID, name: "Produto Premium", quantity: 2, salePrice: 100)
        context.insert(produto)

        let venda = try SaleService.register(
            lines: [SaleLine(product: produto, quantity: 1)],
            paymentMethod: .shopee,
            in: context
        )

        #expect(venda.storeID == storeID)
    }

    @Test func vendaNaoMisturaProdutosDeLojasDiferentes() throws {
        let context = try makeContext()
        let outroProduto = Product(storeID: UUID(), name: "Produto Premium", quantity: 2, salePrice: 100)
        let caneca = Product(storeID: UUID(), name: "Caneca", quantity: 2, salePrice: 30)
        context.insert(outroProduto)
        context.insert(caneca)

        #expect(throws: SaleError.mixedStores) {
            try SaleService.register(
                lines: [
                    SaleLine(product: outroProduto, quantity: 1),
                    SaleLine(product: caneca, quantity: 1)
                ],
                paymentMethod: .shopee,
                in: context
            )
        }
        #expect(outroProduto.quantity == 2)
        #expect(caneca.quantity == 2)
    }

    // MARK: - Retrato do produto

    @Test func itemGuardaRetratoDoProdutoNaDataDaVenda() throws {
        let context = try makeContext()
        let produto = Product(name: "Produto A", quantity: 10, costPrice: 20, salePrice: 45)
        context.insert(produto)

        let venda = try SaleService.register(
            lines: [SaleLine(product: produto, quantity: 2)],
            paymentMethod: .pix,
            in: context
        )

        // Reajuste depois da venda não pode reescrever o passado.
        produto.name = "Produto A Atualizado"
        produto.salePrice = 60
        produto.costPrice = 25

        let item = try #require(venda.itemList.first)
        #expect(item.productName == "Produto A")
        #expect(item.unitPrice == 45)
        #expect(item.unitCost == 20)
        #expect(venda.total == 90)
        #expect(venda.profit == 50)
    }

    @Test func vendaSobreviveAExclusaoDoProduto() throws {
        let context = try makeContext()
        let produto = Product(name: "Tapete Redondo", quantity: 3, costPrice: 30, salePrice: 90)
        context.insert(produto)

        let venda = try SaleService.register(
            lines: [SaleLine(product: produto, quantity: 1)],
            paymentMethod: .cash,
            in: context
        )

        context.delete(produto)

        let vendas = try context.fetch(FetchDescriptor<Sale>())
        #expect(vendas.count == 1)
        #expect(venda.itemList.first?.productName == "Tapete Redondo")
        #expect(venda.total == 90)
    }

    // MARK: - Totais

    @Test func totaisSomamTodosOsItens() throws {
        let context = try makeContext()
        let produtoA = Product(name: "Produto A", quantity: 10, costPrice: 20, salePrice: 45)
        let produtoB = Product(name: "Produto B", quantity: 10, costPrice: 30, salePrice: 90)
        context.insert(produtoA)
        context.insert(produtoB)

        let venda = try SaleService.register(
            lines: [
                SaleLine(product: produtoA, quantity: 2),
                SaleLine(product: produtoB, quantity: 1)
            ],
            paymentMethod: .shopee,
            in: context
        )

        #expect(venda.total == 180)      // 45 x 2 mais 90
        #expect(venda.totalCost == 70)   // 20 x 2 mais 30
        #expect(venda.profit == 110)
        #expect(venda.totalQuantity == 3)
        #expect(venda.itemList.count == 2)
    }

    @Test func totalLidaComCentavos() throws {
        let context = try makeContext()
        let produto = Product(
            name: "Organizador de Mesa",
            quantity: 10,
            costPrice: money(cents: 1250),
            salePrice: money(cents: 3590)
        )
        context.insert(produto)

        let venda = try SaleService.register(
            lines: [SaleLine(product: produto, quantity: 3)],
            paymentMethod: .card,
            in: context
        )

        #expect(venda.total == money(cents: 10770))
        #expect(venda.profit == money(cents: 7020))
    }

    @Test func taxaDoCanalFicaNoRetratoEDescontaDoLucroLiquido() throws {
        let context = try makeContext()
        let produto = Product(name: "Produto Premium", quantity: 5, costPrice: 40, salePrice: 100)
        context.insert(produto)

        let venda = try SaleService.register(
            lines: [SaleLine(product: produto, quantity: 1)],
            paymentMethod: .shopee,
            channelFeePercentage: 14,
            in: context
        )

        #expect(venda.channelFeePercentage == 14)
        #expect(venda.channelFeeAmount == 14)
        #expect(venda.grossProfit == 60)
        #expect(venda.netProfit == 46)
        #expect(venda.profit == 46)
    }

    @Test func taxaInvalidaNaoRegistraVendaNemBaixaEstoque() throws {
        let context = try makeContext()
        let produto = Product(name: "Produto Premium", quantity: 5, salePrice: 100)
        context.insert(produto)

        #expect(throws: SaleError.invalidChannelFeePercentage) {
            try SaleService.register(
                lines: [SaleLine(product: produto, quantity: 1)],
                paymentMethod: .shopee,
                channelFeePercentage: 101,
                in: context
            )
        }

        #expect(produto.quantity == 5)
        #expect(try context.fetch(FetchDescriptor<Sale>()).isEmpty)
    }

    // MARK: - Forma de pagamento

    @Test func formaDePagamentoVaiEVoltaComoEnum() throws {
        let context = try makeContext()
        let produto = Product(name: "Produto A", quantity: 10, salePrice: 45)
        context.insert(produto)

        let venda = try SaleService.register(
            lines: [SaleLine(product: produto, quantity: 1)],
            paymentMethod: .shopee,
            in: context
        )

        #expect(venda.paymentMethod == .shopee)
        #expect(venda.paymentMethodRawValue == "shopee")
    }

    @Test func formaDePagamentoDesconhecidaCaiNoPadrao() {
        let venda = Sale()
        venda.paymentMethodRawValue = "boleto_do_futuro"

        #expect(venda.paymentMethod == .pix, "texto estranho não pode quebrar a tela")
    }

    // MARK: - Mensagens de erro

    @Test func todoErroDeVendaTemMensagem() {
        let erros: [SaleError] = [
            .emptySale,
            .invalidQuantity(productName: "Produto A"),
            .insufficientStock(productName: "Produto A", available: 2, requested: 5),
            .invalidChannelFeePercentage,
            .mixedStores
        ]

        for erro in erros {
            #expect(!erro.localizedMessage.isEmpty)
        }
    }

    @Test func mensagemDeEstoqueMostraOQueRestaEONome() {
        let erro = SaleError.insufficientStock(productName: "Tapete Redondo", available: 3, requested: 7)
        let mensagem = erro.localizedMessage

        #expect(mensagem.contains("3"), "a pessoa precisa saber quanto ainda tem")
        #expect(mensagem.contains("Tapete Redondo"))
        #expect(!mensagem.contains("%"), "sobrou marcador de formatação sem substituir")
    }

    @Test func todaFormaDePagamentoTemNomeEIcone() {
        for method in PaymentMethod.allCases {
            #expect(!method.localizedName.isEmpty)
            #expect(!method.symbolName.isEmpty)
        }
    }

    // MARK: - Exclusão em cascata

    @Test func apagarAVendaApagaOsItens() throws {
        let context = try makeContext()
        let produto = Product(name: "Produto A", quantity: 10, salePrice: 45)
        context.insert(produto)

        let venda = try SaleService.register(
            lines: [SaleLine(product: produto, quantity: 2)],
            paymentMethod: .pix,
            in: context
        )

        context.delete(venda)
        try context.save()

        let itens = try context.fetch(FetchDescriptor<SaleItem>())
        #expect(itens.isEmpty)
    }
}
