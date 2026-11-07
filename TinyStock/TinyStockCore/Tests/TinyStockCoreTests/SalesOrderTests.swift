// Proposito: Testar retratos, totais, estados e persistencia dos pedidos operacionais.
// Created by Jonathas Motta (@jonathaxs) on 2026-08-31.

import Foundation
import SwiftData
import Testing
@testable import TinyStockCore

@Suite(.serialized)
@MainActor
struct SalesOrderTests {
    private func makeProduct(in context: ModelContext) throws -> (Product, ProductVariant) {
        let product = try ProductService.create(storeID: UUID(), name: "Caneca", costPrice: 10, salePrice: 25, in: context)
        let variant = try ProductVariantService.create(for: product, name: "Verde", initialQuantity: 3, in: context)
        return (product, variant)
    }

    @Test func atendimentoDefineEstadoInicial() {
        #expect(SalesOrder(fulfillment: .readyStock).status == .readyToShip)
        #expect(SalesOrder(fulfillment: .production).status == .awaitingProduction)
        #expect(SalesOrder(status: .new).status == .new)
    }

    @Test(arguments: SalesOrderStatus.allCases, OrderFulfillment.allCases)
    func matrizDeTransicoesRespeitaAtendimento(status: SalesOrderStatus, fulfillment: OrderFulfillment) {
        let production: [SalesOrderStatus: Set<SalesOrderStatus>] = [
            .new: [.awaitingProduction, .cancelled],
            .awaitingProduction: [.inProduction, .readyToShip, .cancelled],
            .inProduction: [.readyToShip, .cancelled],
            .readyToShip: [.shipped, .cancelled],
            .shipped: [.completed], .completed: [], .cancelled: []
        ]
        let ready: [SalesOrderStatus: Set<SalesOrderStatus>] = [
            .new: [.readyToShip, .cancelled], .awaitingProduction: [], .inProduction: [],
            .readyToShip: [.shipped, .cancelled], .shipped: [.completed], .completed: [], .cancelled: []
        ]
        let expected = (fulfillment == .production ? production : ready)[status] ?? []
        for next in SalesOrderStatus.allCases {
            #expect(status.canTransition(to: next, fulfillment: fulfillment) == expected.contains(next))
        }
        #expect(Set(status.allowedNextStatuses(for: fulfillment)) == expected)
        #expect(status.isTerminal == (status == .completed || status == .cancelled))
    }

    @Test func consultaDeTransicaoNaoMudaEstadoNemDatas() {
        let order = SalesOrder(fulfillment: .production)
        #expect(order.canTransition(to: .readyToShip))
        #expect(order.status == .awaitingProduction)
        #expect(order.producedAt == nil)
        #expect(!order.canTransition(to: .shipped))
    }

    @Test func retratoCopiaIdentidadeEValoresSemMovimentarEstoque() throws {
        let context = try TestDatabase.makeCleanContext()
        let (product, variant) = try makeProduct(in: context)
        let item = try SalesOrderItem.snapshot(product: product, variant: variant, quantity: 5, position: 2)
        #expect(item.storeID == product.storeID && item.productID == product.id && item.variantID == variant.id)
        #expect(item.productName == "Caneca" && item.variantName == "Verde")
        #expect(item.unitPrice == 25 && item.unitCost == 10 && item.quantity == 5)
        #expect(item.position == 2)
        #expect(item.subtotal == 125 && item.subtotalCost == 50 && item.grossProfit == 75)
        #expect(variant.quantity == 3)
        #expect(try context.fetchCount(FetchDescriptor<StockMovement>()) == 1)
    }

    @Test func retratoNaoExpoeNomeDaVariacaoInterna() throws {
        let context = try TestDatabase.makeCleanContext()
        let product = Product(storeID: UUID(), name: "Produto", salePrice: 20)
        let variant = ProductVariant(
            storeID: product.storeID, productID: product.id,
            name: ProductVariant.internalDefaultName, isDefault: true
        )
        context.insert(product)
        context.insert(variant)

        let item = try SalesOrderItem.snapshot(product: product, variant: variant, quantity: 1)

        #expect(item.variantName.isEmpty)
        #expect(item.variantID == variant.id)
    }

    @Test func retratoNaoMudaQuandoCatalogoEhEditado() throws {
        let context = try TestDatabase.makeCleanContext()
        let (product, variant) = try makeProduct(in: context)
        let item = try SalesOrderItem.snapshot(product: product, variant: variant, quantity: 2)
        product.name = "Nome novo"
        product.salePrice = 100
        product.costPrice = 50
        variant.name = "Outra cor"
        #expect(item.productName == "Caneca" && item.variantName == "Verde")
        #expect(item.subtotal == 50 && item.subtotalCost == 20)
    }

    @Test(arguments: [0, -1])
    func retratoRecusaQuantidadeInvalida(quantity: Int) throws {
        let context = try TestDatabase.makeCleanContext()
        let (product, variant) = try makeProduct(in: context)
        #expect(throws: SalesOrderItemError.invalidQuantity) {
            try SalesOrderItem.snapshot(product: product, variant: variant, quantity: quantity)
        }
    }

    @Test func retratoRecusaVariacaoDeOutroProdutoOuLoja() throws {
        let context = try TestDatabase.makeCleanContext()
        let (product, variant) = try makeProduct(in: context)
        variant.storeID = UUID()
        #expect(throws: SalesOrderItemError.variantMismatch) {
            try SalesOrderItem.snapshot(product: product, variant: variant, quantity: 1)
        }
        variant.storeID = product.storeID
        variant.productID = UUID()
        #expect(throws: SalesOrderItemError.variantMismatch) {
            try SalesOrderItem.snapshot(product: product, variant: variant, quantity: 1)
        }
    }

    @Test func retratoRecusaPrecosNegativos() throws {
        let context = try TestDatabase.makeCleanContext()
        let (product, variant) = try makeProduct(in: context)
        product.salePrice = -1
        #expect(throws: SalesOrderItemError.invalidPrices) {
            try SalesOrderItem.snapshot(product: product, variant: variant, quantity: 1)
        }
        product.salePrice = 0
        product.costPrice = -1
        #expect(throws: SalesOrderItemError.invalidPrices) {
            try SalesOrderItem.snapshot(product: product, variant: variant, quantity: 1)
        }
    }

    @Test func totaisSomamItensEDescontamTaxaSalvaUmaVez() throws {
        let context = try TestDatabase.makeCleanContext()
        let order = SalesOrder(channel: .shopee, channelFeePercentage: 10, channelFeeAmount: Decimal(string: "1.23")!)
        context.insert(order)
        let first = SalesOrderItem(unitPrice: Decimal(string: "2.35")!, unitCost: Decimal(string: "1.10")!, quantity: 3)
        let second = SalesOrderItem(unitPrice: Decimal(string: "5.25")!, unitCost: Decimal(string: "2.15")!, quantity: 1)
        context.insert(first)
        context.insert(second)
        order.items = [first, second]
        #expect(order.totalQuantity == 4)
        #expect(order.total == Decimal(string: "12.30"))
        #expect(order.totalCost == Decimal(string: "5.45"))
        #expect(order.grossProfit == Decimal(string: "6.85"))
        #expect(order.netProfit == Decimal(string: "5.62"))
        order.channelFeePercentage = 50
        #expect(order.netProfit == Decimal(string: "5.62"))
    }

    @Test func pedidoVazioETotalGrandeNaoCausamOverflow() throws {
        let context = try TestDatabase.makeCleanContext()
        let order = SalesOrder()
        context.insert(order)
        #expect(order.itemList.isEmpty && order.total == 0 && order.totalQuantity == 0)
        let first = SalesOrderItem(quantity: Int.max)
        let second = SalesOrderItem(quantity: 1)
        context.insert(first)
        context.insert(second)
        order.items = [first, second]
        #expect(order.totalQuantity == Decimal(Int.max) + 1)
    }

    @Test func ordenacaoDosItensIndependeDaOrdemDaRelacao() throws {
        let context = try TestDatabase.makeCleanContext()
        let order = SalesOrder()
        context.insert(order)
        let first = SalesOrderItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, position: 0)
        let second = SalesOrderItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, position: 0)
        let last = SalesOrderItem(position: 1)
        for item in [last, second, first] { context.insert(item) }
        order.items = [last, second, first]
        #expect(order.itemList.map(\.id) == [first.id, second.id, last.id])
    }

    @Test func persistenciaPreservaCamposRelacaoEEscopoDaLoja() throws {
        let context = try TestDatabase.makeCleanContext()
        let (product, variant) = try makeProduct(in: context)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let order = SalesOrder(storeID: product.storeID, channel: .other, customChannelName: "Minha plataforma",
                               fulfillment: .production, buyerName: "Comprador de teste", externalReference: "TEST-01",
                               orderedAt: date, productionDueAt: date.addingTimeInterval(86_400),
                               shippingDueAt: date.addingTimeInterval(172_800), trackingCode: "TRACK-01", note: "Teste",
                               channelFeePercentage: 10, channelFeeAmount: 5, createdAt: date, updatedAt: date)
        let item = try SalesOrderItem.snapshot(product: product, variant: variant, quantity: 2)
        context.insert(order)
        context.insert(item)
        item.order = order
        order.productionStartedAt = date
        order.producedAt = date
        order.shippedAt = date
        order.completedAt = date
        order.cancelledAt = date
        context.insert(SalesOrder(storeID: UUID()))
        try context.save()

        let reader = ModelContext(TestDatabase.container)
        let storeID = product.storeID
        let saved = try reader.fetch(FetchDescriptor<SalesOrder>(predicate: #Predicate { $0.storeID == storeID }))
        let fetched = try #require(saved.first)
        #expect(saved.count == 1 && fetched.id == order.id)
        #expect(fetched.channel == .other && fetched.channelDisplayName == "Minha plataforma")
        #expect(fetched.fulfillment == .production && fetched.status == .awaitingProduction)
        #expect(fetched.buyerName == "Comprador de teste" && fetched.externalReference == "TEST-01")
        #expect(fetched.orderedAt == date && fetched.createdAt == date && fetched.updatedAt == date)
        #expect(fetched.productionDueAt == date.addingTimeInterval(86_400))
        #expect(fetched.shippingDueAt == date.addingTimeInterval(172_800))
        #expect(fetched.productionStartedAt == date && fetched.producedAt == date && fetched.shippedAt == date)
        #expect(fetched.completedAt == date && fetched.cancelledAt == date)
        #expect(fetched.trackingCode == "TRACK-01" && fetched.note == "Teste")
        #expect(fetched.channelFeeAmount == 5 && fetched.channelFeePercentage == 10)
        #expect(fetched.total == 50 && fetched.netProfit == 25)
        #expect(fetched.itemList.first?.order?.id == order.id)
        #expect(fetched.itemList.first?.storeID == storeID)
    }

    @Test func excluirPedidoRemoveItensMasPreservaCatalogoEstoqueEVendasLegadas() throws {
        let context = try TestDatabase.makeCleanContext()
        let (product, variant) = try makeProduct(in: context)
        let order = SalesOrder(storeID: product.storeID)
        context.insert(order)
        let item = try SalesOrderItem.snapshot(product: product, variant: variant, quantity: 1)
        context.insert(item)
        item.order = order
        context.insert(Sale(storeID: product.storeID))
        try context.save()
        context.delete(order)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<SalesOrder>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SalesOrderItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Product>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ProductVariant>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<StockMovement>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Sale>()) == 1)
        #expect(variant.quantity == 3)
    }

    @Test func excluirCatalogoNaoApagaRetratosDoPedido() throws {
        let context = try TestDatabase.makeCleanContext()
        let (product, variant) = try makeProduct(in: context)
        let order = SalesOrder(storeID: product.storeID, status: .completed)
        context.insert(order)
        let item = try SalesOrderItem.snapshot(product: product, variant: variant, quantity: 2)
        context.insert(item)
        item.order = order
        try context.save()
        try ProductService.delete(product, in: context)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<SalesOrder>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SalesOrderItem>()) == 1)
        #expect(order.total == 50 && item.productName == "Caneca" && item.variantName == "Verde")
    }

    @Test func valoresDesconhecidosNaoSaoConvertidosParaEstadosValidos() throws {
        let context = try TestDatabase.makeCleanContext()
        let order = SalesOrder()
        order.statusRawValue = "future-status"
        order.fulfillmentRawValue = "future-fulfillment"
        order.channelRawValue = "future-channel"
        context.insert(order)
        try context.save()
        let reader = ModelContext(TestDatabase.container)
        let fetched = try #require(reader.fetch(FetchDescriptor<SalesOrder>()).first)
        #expect(fetched.status == nil && fetched.fulfillment == nil && fetched.channel == nil)
        #expect(!fetched.canTransition(to: .shipped))
        #expect(fetched.statusRawValue == "future-status")
        #expect(!fetched.channelDisplayName.isEmpty)
    }

    @Test func canaisNaoDependemDePagamentoENomesCustomizadosSaoOpcionais() {
        let order = SalesOrder(channel: .other, customChannelName: "  Minha loja virtual  ")
        #expect(order.channelDisplayName == "Minha loja virtual")
        order.customChannelName = "  "
        #expect(order.channelDisplayName == SalesChannel.other.localizedName)
        order.channelRawValue = SalesChannel.shopee.rawValue
        #expect(order.channelDisplayName == "Shopee")
        #expect(!SalesChannel.allCases.map(\.rawValue).contains("pix"))
    }

    @Test func enumsTemRoundTripCodableETextosLocalizados() throws {
        for channel in SalesChannel.allCases {
            #expect(try JSONDecoder().decode(SalesChannel.self, from: JSONEncoder().encode(channel)) == channel)
            #expect(!channel.localizedName.isEmpty && !channel.localizedName.hasPrefix("order."))
        }
        for status in SalesOrderStatus.allCases {
            #expect(try JSONDecoder().decode(SalesOrderStatus.self, from: JSONEncoder().encode(status)) == status)
            #expect(!status.localizedName.isEmpty && !status.localizedName.hasPrefix("order."))
        }
        for fulfillment in OrderFulfillment.allCases {
            #expect(try JSONDecoder().decode(OrderFulfillment.self, from: JSONEncoder().encode(fulfillment)) == fulfillment)
            #expect(!fulfillment.localizedName.isEmpty && !fulfillment.localizedName.hasPrefix("order."))
        }
        for error in [SalesOrderItemError.invalidQuantity, .invalidPrices, .variantMismatch] {
            #expect(!error.localizedMessage.isEmpty && !error.localizedMessage.hasPrefix("order."))
        }
    }
}
