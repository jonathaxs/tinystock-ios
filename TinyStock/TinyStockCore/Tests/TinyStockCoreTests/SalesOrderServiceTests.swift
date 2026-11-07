// Proposito: Testar registro integral do pedido, protecao do estoque e validacoes de entrada.
// Created by Jonathas Motta (@jonathaxs) on 2026-08-31.

import Foundation
import SwiftData
import Testing
@testable import TinyStockCore

@Suite(.serialized)
@MainActor
struct SalesOrderServiceTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private struct Fixture {
        let context: ModelContext
        let store: StoreProfile
        let product: Product
        let variant: ProductVariant
        func line(_ quantity: Int) -> SalesOrderLine {
            SalesOrderLine(productID: product.id, variantID: variant.id, quantity: quantity)
        }
    }

    private func fixture(quantity: Int = 5) throws -> Fixture {
        let context = try TestDatabase.makeCleanContext()
        let store = StoreProfile(name: "Loja de teste")
        context.insert(store)
        let product = try ProductService.create(storeID: store.id, name: "Caneca", costPrice: 10, salePrice: 25, in: context)
        let variant = try ProductVariantService.create(for: product, name: "Verde", initialQuantity: quantity, in: context)
        product.quantity = 99
        try context.save()
        return Fixture(context: context, store: store, product: product, variant: variant)
    }

    private func register(_ f: Fixture, lines: [SalesOrderLine]? = nil,
                          fulfillment: OrderFulfillment = .readyStock,
                          fee: Decimal = 0, id: UUID = UUID()) throws -> SalesOrder {
        try SalesOrderService.register(id: id, storeID: f.store.id, lines: lines ?? [f.line(2)],
                                       fulfillment: fulfillment, orderedAt: now,
                                       productionDueAt: fulfillment == .production ? now : nil,
                                       shippingDueAt: now.addingTimeInterval(86_400), channelFeePercentage: fee,
                                       now: now, calendar: calendar, in: f.context)
    }

    private func expectNoOrder(_ f: Fixture, quantity: Int = 5) throws {
        #expect(try f.context.fetchCount(FetchDescriptor<SalesOrder>()) == 0)
        #expect(try f.context.fetchCount(FetchDescriptor<SalesOrderItem>()) == 0)
        #expect(f.variant.quantity == quantity)
        #expect(f.product.quantity == 99)
    }

    @Test func prontaEntregaGravaPedidoItensETaxaComBaixaAuditavel() throws {
        let f = try fixture()
        let order = try SalesOrderService.register(storeID: f.store.id, lines: [f.line(2)], fulfillment: .readyStock,
                                                  channel: .other, customChannelName: " Minha plataforma ",
                                                  buyerName: " Comprador ", externalReference: " REF-01 ", orderedAt: now,
                                                  shippingDueAt: now, note: " Observacao ", channelFeePercentage: 10,
                                                  now: now, calendar: calendar, in: f.context)
        try f.context.save()
        #expect(order.status == .readyToShip && order.total == 50 && order.totalCost == 20)
        #expect(order.channelFeeAmount == 5 && order.netProfit == 25)
        #expect(order.channelDisplayName == "Minha plataforma" && order.buyerName == "Comprador")
        #expect(order.externalReference == "REF-01" && order.note == "Observacao")
        #expect(order.createdAt == now && order.updatedAt == now)
        #expect(f.variant.quantity == 3 && f.product.quantity == 99)
        let entry = try #require(StockService.movements(for: f.variant, product: f.product, in: f.context)
            .first { $0.kind == .orderWithdrawal })
        #expect(entry.referenceID == order.id && entry.quantityDelta == -2 && entry.balanceAfter == 3)
        #expect(entry.createdAt == now && f.variant.updatedAt == now)
        let reader = ModelContext(TestDatabase.container)
        let persisted = try #require(reader.fetch(FetchDescriptor<SalesOrder>()).first)
        #expect(persisted.itemList.count == 1 && persisted.itemList.first?.variantID == f.variant.id)
        #expect(persisted.itemList.first?.storeID == f.store.id && persisted.total == 50)
    }

    @Test func produzirNaoBaixaNemReservaEstoqueMesmoSemUnidades() throws {
        let f = try fixture(quantity: 0)
        let order = try register(f, lines: [f.line(20)], fulfillment: .production)
        #expect(order.status == .awaitingProduction && order.totalQuantity == 20)
        #expect(order.productionDueAt == now && order.itemList.count == 1)
        #expect(f.variant.quantity == 0)
        #expect(try f.context.fetchCount(FetchDescriptor<StockMovement>()) == 0)
    }

    @Test func linhasRepetidasSaoSomadasAntesDaBaixa() throws {
        let f = try fixture()
        let order = try register(f, lines: [f.line(2), f.line(3)])
        #expect(order.itemList.count == 1 && order.itemList.first?.quantity == 5)
        #expect(f.variant.quantity == 0)
        #expect(try f.context.fetchCount(FetchDescriptor<StockMovement>()) == 2)
    }

    @Test func somaRepetidaAcimaDoEstoqueNaoAlteraNada() throws {
        let f = try fixture()
        #expect(throws: SalesOrderError.insufficientStock(productName: "Caneca", variantName: "Verde", available: 5, requested: 6)) {
            try register(f, lines: [f.line(3), f.line(3)])
        }
        try expectNoOrder(f)
        #expect(!f.context.hasChanges)
    }

    @Test func falhaNoUltimoItemNaoBaixaOPrimeiro() throws {
        let f = try fixture()
        let other = try ProductVariantService.create(for: f.product, name: "Branca", initialQuantity: 1, in: f.context)
        try f.context.save()
        let last = SalesOrderLine(productID: f.product.id, variantID: other.id, quantity: 2)
        #expect(throws: SalesOrderError.insufficientStock(productName: "Caneca", variantName: "Branca", available: 1, requested: 2)) {
            try register(f, lines: [f.line(1), last])
        }
        try expectNoOrder(f)
        #expect(other.quantity == 1 && !f.context.hasChanges)
    }

    @Test func variasVariacoesPreservamSequenciaERecebemBaixasSeparadas() throws {
        let f = try fixture()
        let other = try ProductService.create(storeID: f.store.id, name: "Suporte", costPrice: 5, salePrice: 15, in: f.context)
        let otherVariant = try ProductVariantService.create(for: other, name: "Unico", initialQuantity: 4, in: f.context)
        let line = SalesOrderLine(productID: other.id, variantID: otherVariant.id, quantity: 2)
        let order = try register(f, lines: [line, f.line(1), line])
        #expect(order.itemList.map(\.productName) == ["Suporte", "Caneca"])
        #expect(order.itemList.map(\.quantity) == [4, 1])
        #expect(order.total == 85 && order.totalCost == 30)
        #expect(otherVariant.quantity == 0 && f.variant.quantity == 4)
    }

    @Test func pedidoVazioELojaArquivadaSaoRecusados() throws {
        let f = try fixture()
        #expect(throws: SalesOrderError.emptyOrder) { try register(f, lines: []) }
        f.store.isArchived = true
        try f.context.save()
        #expect(throws: SalesOrderError.storeUnavailable) { try register(f) }
        try expectNoOrder(f)
        #expect(!f.context.hasChanges)
    }

    @Test func lojaInexistenteOuSemEscopoNaoPodeReceberPedido() throws {
        let f = try fixture()
        for storeID in [UUID(), StoreScope.unassignedStoreID] {
            #expect(throws: SalesOrderError.storeUnavailable) {
                try SalesOrderService.register(storeID: storeID, lines: [f.line(1)], fulfillment: .readyStock,
                                               orderedAt: now, shippingDueAt: now, now: now, in: f.context)
            }
        }
        try expectNoOrder(f)
    }

    @Test func produtoOuVariacaoDeOutroEscopoSaoRecusados() throws {
        let f = try fixture()
        let other = try ProductService.create(storeID: UUID(), name: "Outra loja", in: f.context)
        let variant = try ProductVariantService.create(for: other, name: "Outra", in: f.context)
        try f.context.save()
        #expect(throws: SalesOrderError.productUnavailable) {
            try register(f, lines: [.init(productID: other.id, variantID: variant.id, quantity: 1)])
        }
        #expect(throws: SalesOrderError.variantMismatch) {
            try register(f, lines: [.init(productID: f.product.id, variantID: variant.id, quantity: 1)])
        }
        #expect(throws: SalesOrderError.variantMismatch) {
            try register(f, lines: [.init(productID: f.product.id, variantID: UUID(), quantity: 1)])
        }
        try expectNoOrder(f)
        #expect(!f.context.hasChanges)
    }

    @Test func idsAmbiguosNoCatalogoNaoSaoEscolhidosArbitrariamente() throws {
        let f = try fixture()
        f.context.insert(ProductVariant(id: f.variant.id, storeID: f.store.id, productID: UUID(), name: "Duplicada"))
        try f.context.save()
        #expect(throws: SalesOrderError.variantMismatch) { try register(f) }
        try expectNoOrder(f)
    }

    @Test(arguments: [0, -1])
    func quantidadeInvalidaNaoCriaPedido(quantity: Int) throws {
        let f = try fixture()
        #expect(throws: SalesOrderError.invalidQuantity) { try register(f, lines: [f.line(quantity)]) }
        try expectNoOrder(f)
    }

    @Test func somaDeQuantidadesComOverflowEhRecusadaTambemNaProducao() throws {
        let f = try fixture()
        #expect(throws: SalesOrderError.quantityOverflow) {
            try register(f, lines: [f.line(Int.max), f.line(1)], fulfillment: .production)
        }
        try expectNoOrder(f)
    }

    @Test func valoresMonetariosInvalidosNaoGeramBaixa() throws {
        let f = try fixture()
        for value in [Decimal(-1), Decimal.nan, Decimal.greatestFiniteMagnitude] {
            f.product.salePrice = value
            #expect(throws: SalesOrderError.invalidMoney) { try register(f) }
            try expectNoOrder(f)
        }
        f.product.salePrice = 25
        f.product.costPrice = .nan
        #expect(throws: SalesOrderError.invalidMoney) { try register(f) }
        try expectNoOrder(f)
    }

    @Test func taxaInvalidaNaoGravaEArredondamentoValidoUsaCentavos() throws {
        let f = try fixture()
        for rate in [Decimal(-1), Decimal(101), Decimal.nan] {
            #expect(throws: SalesOrderError.invalidChannelFee) { try register(f, fee: rate) }
        }
        try expectNoOrder(f)
        f.product.salePrice = Decimal(string: "2.35")!
        let order = try register(f, lines: [f.line(3)], fee: 10)
        #expect(order.total == Decimal(string: "7.05") && order.channelFeeAmount == Decimal(string: "0.71"))
    }

    @Test func datasInvalidasSaoRecusadasAntesDaGravacao() throws {
        let f = try fixture()
        let tomorrow = now.addingTimeInterval(86_400)
        #expect(throws: SalesOrderError.futureOrderDate) {
            try SalesOrderService.register(storeID: f.store.id, lines: [f.line(1)], fulfillment: .readyStock,
                                           orderedAt: tomorrow, shippingDueAt: tomorrow, now: now, calendar: calendar, in: f.context)
        }
        #expect(throws: SalesOrderError.shippingBeforeOrder) {
            try SalesOrderService.register(storeID: f.store.id, lines: [f.line(1)], fulfillment: .readyStock,
                                           orderedAt: now, shippingDueAt: now.addingTimeInterval(-86_400), now: now, calendar: calendar, in: f.context)
        }
        #expect(throws: SalesOrderError.invalidDates) {
            try SalesOrderService.register(storeID: f.store.id, lines: [f.line(1)], fulfillment: .readyStock,
                                           orderedAt: now, shippingDueAt: Date(timeIntervalSince1970: .infinity), now: now, in: f.context)
        }
        try expectNoOrder(f)
        #expect(!f.context.hasChanges)
    }

    @Test func producaoExigeDataEntreVendaEDespacho() throws {
        let f = try fixture()
        #expect(throws: SalesOrderError.productionDateRequired) {
            try SalesOrderService.register(storeID: f.store.id, lines: [f.line(1)], fulfillment: .production,
                                           orderedAt: now, shippingDueAt: now, now: now, in: f.context)
        }
        for date in [now.addingTimeInterval(-86_400), now.addingTimeInterval(86_400)] {
            #expect(throws: SalesOrderError.invalidProductionDate) {
                try SalesOrderService.register(storeID: f.store.id, lines: [f.line(1)], fulfillment: .production,
                                               orderedAt: now, productionDueAt: date, shippingDueAt: now,
                                               now: now, calendar: calendar, in: f.context)
            }
        }
        try expectNoOrder(f)
    }

    @Test func selecaoPorDiaAceitaHorariosDiferentesETrocaDeAtendimentoLimpaProducao() throws {
        let f = try fixture()
        let start = calendar.startOfDay(for: now)
        let afternoon = start.addingTimeInterval(15 * 3_600)
        let order = try SalesOrderService.register(storeID: f.store.id, lines: [f.line(1)], fulfillment: .readyStock,
                                                  orderedAt: afternoon, productionDueAt: Date(timeIntervalSince1970: .nan),
                                                  shippingDueAt: start, now: afternoon, calendar: calendar, in: f.context)
        #expect(order.productionDueAt == nil && order.shippingDueAt == start)
    }

    @Test func comparacaoDosDiasRespeitaOFusoInformado() throws {
        let f = try fixture()
        let utcMidnight = calendar.startOfDay(for: now)
        var local = calendar
        local.timeZone = TimeZone(secondsFromGMT: -3 * 3_600)!
        let sale = utcMidnight.addingTimeInterval(1_800)
        let shipping = utcMidnight.addingTimeInterval(-3_600)
        let order = try SalesOrderService.register(storeID: f.store.id, lines: [f.line(1)], fulfillment: .readyStock,
                                                  orderedAt: sale, shippingDueAt: shipping, now: sale, calendar: local, in: f.context)
        #expect(order.status == .readyToShip)
    }

    @Test func registroRetroativoMantemPrazosMasMovimentaNaDataDeRegistro() throws {
        let f = try fixture()
        let past = now.addingTimeInterval(-3 * 86_400)
        let order = try SalesOrderService.register(storeID: f.store.id, lines: [f.line(1)], fulfillment: .readyStock,
                                                  orderedAt: past, shippingDueAt: past, now: now, calendar: calendar, in: f.context)
        #expect(order.orderedAt == past && order.shippingDueAt == past && order.createdAt == now)
        let withdrawal = try #require(StockService.movements(for: f.variant, product: f.product, in: f.context)
            .first { $0.kind == .orderWithdrawal })
        #expect(withdrawal.createdAt == now)
    }

    @Test func mesmoRascunhoNaoPodeBaixarEstoqueDuasVezes() throws {
        let f = try fixture()
        let id = UUID()
        _ = try register(f, id: id)
        #expect(throws: SalesOrderError.duplicateOrder) { try register(f, id: id) }
        try f.context.save()
        #expect(throws: SalesOrderError.duplicateOrder) { try register(f, id: id) }
        #expect(f.variant.quantity == 3)
        #expect(try f.context.fetchCount(FetchDescriptor<SalesOrder>()) == 1)
        #expect(try f.context.fetchCount(FetchDescriptor<StockMovement>()) == 2)
    }

    @Test func falhaNoSaveDesfazPedidoItensEBaixaSemApagarDadosAnteriores() throws {
        let f = try fixture()
        f.context.insert(Sale(storeID: f.store.id))
        try f.context.save()
        let previousDate = f.variant.updatedAt
        enum SaveFailure: Error { case simulated }
        #expect(throws: SaveFailure.simulated) {
            try SalesOrderService.persistRegistration(in: f.context, variants: [f.variant], applying: {
                let order = SalesOrder(storeID: f.store.id)
                f.context.insert(order)
                let item = try SalesOrderItem.snapshot(product: f.product, variant: f.variant, quantity: 2)
                f.context.insert(item)
                item.order = order
                try StockService.registerOrderWithdrawal(quantity: 2, from: f.variant, product: f.product,
                                                        orderID: order.id, date: now, in: f.context)
                return order
            }, saving: { _ in throw SaveFailure.simulated })
        }
        try expectNoOrder(f)
        #expect(f.variant.updatedAt == previousDate)
        #expect(!f.context.hasChanges)
        #expect(try f.context.fetchCount(FetchDescriptor<StockMovement>()) == 1)
        #expect(try f.context.fetchCount(FetchDescriptor<Sale>()) == 1)
        let reader = ModelContext(TestDatabase.container)
        #expect(try reader.fetch(FetchDescriptor<ProductVariant>()).first?.quantity == 5)
        #expect(try reader.fetchCount(FetchDescriptor<SalesOrder>()) == 0)
    }

    @Test func baixaDoPedidoNaoPodeSerEstornadaIsoladamente() throws {
        let f = try fixture()
        let order = try register(f)
        let withdrawal = try #require(StockService.movements(for: f.variant, product: f.product, in: f.context)
            .first { $0.kind == .orderWithdrawal })
        #expect(throws: StockError.orderManagedMovement) {
            try StockService.reverse(withdrawal, for: f.variant, product: f.product, in: f.context)
        }
        #expect(f.variant.quantity == 3 && order.status == .readyToShip && withdrawal.reversedAt == nil)
    }

    @Test(arguments: SalesOrderStatus.allCases)
    func exclusaoDoProdutoDependeDoEncerramentoDosPedidos(status: SalesOrderStatus) throws {
        let f = try fixture()
        let order = try register(f)
        order.statusRawValue = status.rawValue
        try f.context.save()
        if status.isTerminal {
            try ProductService.delete(f.product, in: f.context)
            try f.context.save()
            #expect(order.itemList.first?.productName == "Caneca")
        } else {
            #expect(throws: ProductError.activeOrders) { try ProductService.delete(f.product, in: f.context) }
            #expect(f.variant.quantity == 3 && !f.context.hasChanges)
        }
        #expect(try f.context.fetchCount(FetchDescriptor<SalesOrder>()) == 1)
    }

    @Test func pedidoDeOutraLojaNaoBloqueiaProdutoMasEstadoDesconhecidoBloqueia() throws {
        let f = try fixture()
        let order = try register(f)
        order.statusRawValue = "future-status"
        try f.context.save()
        #expect(throws: ProductError.activeOrders) { try ProductService.delete(f.product, in: f.context) }
        order.storeID = UUID()
        try f.context.save()
        try ProductService.delete(f.product, in: f.context)
        #expect(order.itemList.count == 1)
    }

    @Test func mensagensDeErroEstaoLocalizadas() {
        let errors: [SalesOrderError] = [.emptyOrder, .storeUnavailable, .productUnavailable, .variantMismatch,
            .invalidQuantity, .quantityOverflow, .invalidMoney, .invalidChannelFee, .invalidDates, .futureOrderDate,
            .shippingBeforeOrder, .productionDateRequired, .invalidProductionDate, .duplicateOrder,
            .insufficientStock(productName: "Caneca", variantName: "Verde", available: 1, requested: 2)]
        for error in errors {
            #expect(!error.localizedMessage.isEmpty && !error.localizedMessage.hasPrefix("order."))
        }
        #expect(errors.last?.localizedMessage.contains("Caneca") == true)
        #expect(errors.last?.localizedMessage.contains("Verde") == true)
    }
}
