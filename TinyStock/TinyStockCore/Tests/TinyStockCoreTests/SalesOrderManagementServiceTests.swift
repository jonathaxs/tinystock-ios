// Proposito: Testar edicao e cancelamento de pedidos com consistencia de estoque.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-02.

import Foundation
import SwiftData
import Testing
@testable import TinyStockCore

@Suite(.serialized)
@MainActor
struct SalesOrderManagementServiceTests {
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
        let order: SalesOrder
    }

    private func fixture(
        fulfillment: OrderFulfillment = .readyStock,
        stock: Int = 5,
        sold: Int = 2
    ) throws -> Fixture {
        let context = try TestDatabase.makeCleanContext()
        let store = StoreProfile(name: "Loja")
        context.insert(store)
        let product = try ProductService.create(
            storeID: store.id, name: "Caneca", costPrice: 10, salePrice: 25, in: context
        )
        let variant = try ProductVariantService.create(
            for: product, name: "Verde", initialQuantity: stock, in: context
        )
        try context.save()
        let order = try SalesOrderService.register(
            storeID: store.id,
            lines: [SalesOrderLine(productID: product.id, variantID: variant.id, quantity: sold)],
            fulfillment: fulfillment,
            orderedAt: now,
            productionDueAt: fulfillment == .production ? now : nil,
            shippingDueAt: now.addingTimeInterval(86_400),
            now: now,
            calendar: calendar,
            in: context
        )
        return Fixture(context: context, store: store, product: product, variant: variant, order: order)
    }

    private func details(
        fulfillment: OrderFulfillment,
        fee: Decimal = 12.5,
        orderedAt: Date? = nil,
        productionDueAt: Date? = nil,
        shippingDueAt: Date? = nil
    ) -> SalesOrderDetails {
        SalesOrderDetails(
            channel: .other,
            customChannelName: "  Minha loja  ",
            buyerName: "  Maria  ",
            externalReference: "  PED-10  ",
            orderedAt: orderedAt ?? now,
            productionDueAt: fulfillment == .production ? (productionDueAt ?? now) : productionDueAt,
            shippingDueAt: shippingDueAt ?? now.addingTimeInterval(86_400),
            trackingCode: "  BR123  ",
            note: "  Entregar pela manha  ",
            channelFeePercentage: fee
        )
    }

    @Test func edicaoAtualizaDadosETaxaSemAlterarItemEstoqueOuEstado() throws {
        let f = try fixture()
        let previousItem = try #require(f.order.itemList.first)
        let previousMovementCount = try f.context.fetchCount(FetchDescriptor<StockMovement>())
        let changedAt = now.addingTimeInterval(3_600)

        let order = try SalesOrderService.update(
            id: f.order.id,
            details: details(fulfillment: .readyStock),
            now: changedAt,
            calendar: calendar,
            in: f.context
        )

        #expect(order.channel == .other && order.channelDisplayName == "Minha loja")
        #expect(order.buyerName == "Maria" && order.externalReference == "PED-10")
        #expect(order.note == "Entregar pela manha" && order.channelFeePercentage == Decimal(string: "12.5"))
        #expect(order.trackingCode == "BR123")
        #expect(order.channelFeeAmount == Decimal(string: "6.25") && order.netProfit == Decimal(string: "23.75"))
        #expect(order.productionDueAt == nil && order.updatedAt == changedAt)
        #expect(order.status == .readyToShip && order.itemList.first === previousItem)
        #expect(f.variant.quantity == 3)
        #expect(try f.context.fetchCount(FetchDescriptor<StockMovement>()) == previousMovementCount)
    }

    @Test func edicaoDeProducaoPreservaAtendimentoEAtualizaPrazos() throws {
        let f = try fixture(fulfillment: .production, stock: 0, sold: 4)
        let production = now.addingTimeInterval(86_400)
        let shipping = now.addingTimeInterval(2 * 86_400)
        let order = try SalesOrderService.update(
            id: f.order.id,
            details: details(fulfillment: .production, productionDueAt: production, shippingDueAt: shipping),
            now: now,
            calendar: calendar,
            in: f.context
        )
        #expect(order.fulfillment == .production && order.status == .awaitingProduction)
        #expect(order.productionDueAt == production && order.shippingDueAt == shipping)
        #expect(f.variant.quantity == 0)
    }

    @Test func edicaoRecusaTaxaEDatasInvalidasSemMudarPedido() throws {
        let f = try fixture()
        let originalBuyer = f.order.buyerName
        #expect(throws: SalesOrderError.invalidChannelFee) {
            try SalesOrderService.update(
                id: f.order.id, details: details(fulfillment: .readyStock, fee: 101),
                now: now, calendar: calendar, in: f.context
            )
        }
        #expect(throws: SalesOrderError.futureOrderDate) {
            try SalesOrderService.update(
                id: f.order.id,
                details: details(fulfillment: .readyStock, orderedAt: now.addingTimeInterval(86_400)),
                now: now, calendar: calendar, in: f.context
            )
        }
        #expect(f.order.buyerName == originalBuyer && f.order.channel == .direct)
        #expect(f.variant.quantity == 3 && !f.context.hasChanges)
    }

    @Test(arguments: [SalesOrderStatus.shipped, .completed, .cancelled])
    func pedidoEncerradoOuDespachadoNaoPodeSerEditado(status: SalesOrderStatus) throws {
        let f = try fixture()
        f.order.statusRawValue = status.rawValue
        try f.context.save()
        #expect(throws: SalesOrderManagementError.editingNotAllowed) {
            try SalesOrderService.update(
                id: f.order.id, details: details(fulfillment: .readyStock),
                now: now, calendar: calendar, in: f.context
            )
        }
        #expect(f.variant.quantity == 3 && !f.context.hasChanges)
    }

    @Test func dadosDesconhecidosEIDInexistenteNaoSaoAlterados() throws {
        let f = try fixture()
        f.order.statusRawValue = "future-status"
        try f.context.save()
        #expect(throws: SalesOrderManagementError.invalidOrderData) {
            try SalesOrderService.update(
                id: f.order.id, details: details(fulfillment: .readyStock),
                now: now, calendar: calendar, in: f.context
            )
        }
        #expect(throws: SalesOrderManagementError.orderUnavailable) {
            try SalesOrderService.cancel(id: UUID(), date: now, in: f.context)
        }
    }

    @Test func cancelamentoDeProntaEntregaDevolveEstoqueComReversaoAuditavel() throws {
        let f = try fixture()
        let original = try #require(try StockService.movements(for: f.variant, product: f.product, in: f.context)
            .first { $0.kind == .orderWithdrawal })
        let cancelledAt = now.addingTimeInterval(7_200)

        let order = try SalesOrderService.cancel(
            id: f.order.id, reason: "  Cliente desistiu  ", date: cancelledAt, in: f.context
        )

        #expect(order.status == .cancelled && order.cancelledAt == cancelledAt && order.updatedAt == cancelledAt)
        #expect(order.cancellationReason == "Cliente desistiu")
        #expect(f.variant.quantity == 5 && f.variant.updatedAt == cancelledAt)
        #expect(original.reversedAt == cancelledAt)
        let movements = try StockService.movements(for: f.variant, product: f.product, in: f.context)
        let reversal = try #require(movements.first { $0.reversedMovementID == original.id })
        #expect(reversal.kind == .reversal && reversal.quantityDelta == 2 && reversal.balanceAfter == 5)
        #expect(reversal.referenceID == order.id && reversal.note == "Cliente desistiu")
        #expect(order.total == 50 && order.itemList.first?.quantity == 2)
    }

    @Test func cancelamentoDeProducaoNaoCriaMovimentoDeEstoque() throws {
        let f = try fixture(fulfillment: .production, stock: 0, sold: 8)
        let order = try SalesOrderService.cancel(id: f.order.id, reason: "Sem material", date: now, in: f.context)
        #expect(order.status == .cancelled && order.cancellationReason == "Sem material" && f.variant.quantity == 0)
        #expect(try f.context.fetchCount(FetchDescriptor<StockMovement>()) == 0)
    }

    @Test func dataDeCancelamentoInvalidaNaoAlteraPedido() throws {
        let f = try fixture()
        #expect(throws: SalesOrderError.invalidDates) {
            try SalesOrderService.cancel(
                id: f.order.id, date: Date(timeIntervalSince1970: .infinity), in: f.context
            )
        }
        #expect(f.order.status == .readyToShip && f.order.cancelledAt == nil)
        #expect(f.variant.quantity == 3 && !f.context.hasChanges)
    }

    @Test(arguments: [SalesOrderStatus.shipped, .completed, .cancelled])
    func pedidoDespachadoOuTerminalNaoPodeSerCancelado(status: SalesOrderStatus) throws {
        let f = try fixture()
        f.order.statusRawValue = status.rawValue
        try f.context.save()
        #expect(throws: SalesOrderManagementError.cancellationNotAllowed) {
            try SalesOrderService.cancel(id: f.order.id, date: now, in: f.context)
        }
        #expect(f.variant.quantity == 3)
        #expect(try f.context.fetchCount(FetchDescriptor<StockMovement>()) == 2)
    }

    @Test func segundoCancelamentoNaoDevolveEstoqueNovamente() throws {
        let f = try fixture()
        _ = try SalesOrderService.cancel(id: f.order.id, date: now, in: f.context)
        #expect(throws: SalesOrderManagementError.cancellationNotAllowed) {
            try SalesOrderService.cancel(id: f.order.id, date: now, in: f.context)
        }
        #expect(f.variant.quantity == 5)
        #expect(try f.context.fetchCount(FetchDescriptor<StockMovement>()) == 3)
    }

    @Test func historicoInconsistenteBloqueiaCancelamentoAntesDeQualquerMudanca() throws {
        let f = try fixture()
        let withdrawal = try #require(try StockService.movements(for: f.variant, product: f.product, in: f.context)
            .first { $0.kind == .orderWithdrawal })
        withdrawal.quantityDelta = -1
        try f.context.save()

        #expect(throws: SalesOrderManagementError.stockHistoryMismatch) {
            try SalesOrderService.cancel(id: f.order.id, date: now, in: f.context)
        }
        #expect(f.order.status == .readyToShip && f.order.cancelledAt == nil && f.order.cancellationReason.isEmpty)
        #expect(f.variant.quantity == 3 && withdrawal.reversedAt == nil)
        #expect(try f.context.fetchCount(FetchDescriptor<StockMovement>()) == 2)
    }

    @Test func cancelamentoComDoisItensDevolveCadaVariacaoUmaVez() throws {
        let f = try fixture(fulfillment: .production, stock: 5, sold: 1)
        let other = try ProductVariantService.create(for: f.product, name: "Branca", initialQuantity: 4, in: f.context)
        try f.context.save()
        // Substitui o pedido de producao por um pedido de pronta entrega com duas linhas.
        f.context.delete(f.order)
        try f.context.save()
        let order = try SalesOrderService.register(
            storeID: f.store.id,
            lines: [
                SalesOrderLine(productID: f.product.id, variantID: f.variant.id, quantity: 2),
                SalesOrderLine(productID: f.product.id, variantID: other.id, quantity: 3)
            ],
            fulfillment: .readyStock, orderedAt: now, shippingDueAt: now,
            now: now, calendar: calendar, in: f.context
        )
        #expect(f.variant.quantity == 3 && other.quantity == 1)
        _ = try SalesOrderService.cancel(id: order.id, date: now, in: f.context)
        #expect(f.variant.quantity == 5 && other.quantity == 4)
        #expect(try f.context.fetch(FetchDescriptor<StockMovement>()).filter { $0.reversedMovementID != nil }.count == 2)
    }

    @Test func falhaNoSaveRestauraPedidoMovimentoESaldoEmMemoriaENoBanco() throws {
        let f = try fixture()
        let previousUpdatedAt = f.variant.updatedAt
        let withdrawal = try #require(try StockService.movements(for: f.variant, product: f.product, in: f.context)
            .first { $0.kind == .orderWithdrawal })
        enum SaveFailure: Error { case simulated }

        #expect(throws: SaveFailure.simulated) {
            try SalesOrderService.cancel(
                id: f.order.id, reason: "Teste", date: now.addingTimeInterval(1), in: f.context,
                saving: { _ in throw SaveFailure.simulated }
            )
        }

        #expect(f.order.status == .readyToShip && f.order.cancelledAt == nil)
        #expect(f.variant.quantity == 3 && f.variant.updatedAt == previousUpdatedAt)
        #expect(withdrawal.reversedAt == nil && !f.context.hasChanges)
        #expect(try f.context.fetchCount(FetchDescriptor<StockMovement>()) == 2)
        let reader = ModelContext(TestDatabase.container)
        #expect(try reader.fetch(FetchDescriptor<ProductVariant>()).first?.quantity == 3)
        #expect(try reader.fetch(FetchDescriptor<SalesOrder>()).first?.status == .readyToShip)
    }

    @Test func prontaEntregaAvancaParaDespachadoEConcluidoSemMudarEstoque() throws {
        let f = try fixture()
        let shippedAt = now.addingTimeInterval(3_600)
        let completedAt = shippedAt.addingTimeInterval(3_600)

        _ = try SalesOrderService.transition(id: f.order.id, to: .shipped, date: shippedAt, in: f.context)
        #expect(f.order.status == .shipped && f.order.shippedAt == shippedAt)
        #expect(f.order.completedAt == nil && f.variant.quantity == 3)

        _ = try SalesOrderService.transition(id: f.order.id, to: .completed, date: completedAt, in: f.context)
        #expect(f.order.status == .completed && f.order.completedAt == completedAt)
        #expect(f.variant.quantity == 3)
        #expect(try f.context.fetchCount(FetchDescriptor<StockMovement>()) == 2)
    }

    @Test func producaoRegistraTodasAsDatasEfetivasEmOrdem() throws {
        let f = try fixture(fulfillment: .production, stock: 0, sold: 3)
        let startedAt = now.addingTimeInterval(1_000)
        let producedAt = startedAt.addingTimeInterval(1_000)
        let shippedAt = producedAt.addingTimeInterval(1_000)
        let completedAt = shippedAt.addingTimeInterval(1_000)

        _ = try SalesOrderService.transition(id: f.order.id, to: .inProduction, date: startedAt, in: f.context)
        _ = try SalesOrderService.transition(id: f.order.id, to: .readyToShip, date: producedAt, in: f.context)
        _ = try SalesOrderService.transition(id: f.order.id, to: .shipped, date: shippedAt, in: f.context)
        _ = try SalesOrderService.transition(id: f.order.id, to: .completed, date: completedAt, in: f.context)

        #expect(f.order.productionStartedAt == startedAt && f.order.producedAt == producedAt)
        #expect(f.order.shippedAt == shippedAt && f.order.completedAt == completedAt)
        #expect(f.order.status == .completed && f.variant.quantity == 0)
    }

    @Test func acaoProduzidoPodePularInicioDaProducao() throws {
        let f = try fixture(fulfillment: .production, stock: 0, sold: 1)
        let producedAt = now.addingTimeInterval(1_000)
        _ = try SalesOrderService.transition(id: f.order.id, to: .readyToShip, date: producedAt, in: f.context)
        #expect(f.order.status == .readyToShip && f.order.productionStartedAt == nil)
        #expect(f.order.producedAt == producedAt)
    }

    @Test func transicoesInvalidasEDatasForaDeOrdemNaoAlteramPedido() throws {
        let f = try fixture(fulfillment: .production, stock: 0, sold: 1)
        #expect(throws: SalesOrderManagementError.transitionNotAllowed) {
            try SalesOrderService.transition(id: f.order.id, to: .shipped, date: now, in: f.context)
        }
        #expect(throws: SalesOrderManagementError.transitionNotAllowed) {
            try SalesOrderService.transition(id: f.order.id, to: .cancelled, date: now, in: f.context)
        }
        #expect(throws: SalesOrderManagementError.invalidTransitionDate) {
            try SalesOrderService.transition(
                id: f.order.id, to: .readyToShip, date: now.addingTimeInterval(-1), in: f.context
            )
        }
        #expect(f.order.status == .awaitingProduction && f.order.producedAt == nil)
        #expect(!f.context.hasChanges)
    }

    @Test func dataEfetivaNaoPodeAntecederAOperacaoAnterior() throws {
        let f = try fixture(fulfillment: .production, stock: 0, sold: 1)
        let startedAt = now.addingTimeInterval(2_000)
        _ = try SalesOrderService.transition(id: f.order.id, to: .inProduction, date: startedAt, in: f.context)
        #expect(throws: SalesOrderManagementError.invalidTransitionDate) {
            try SalesOrderService.transition(id: f.order.id, to: .readyToShip, date: startedAt.addingTimeInterval(-1), in: f.context)
        }
        #expect(f.order.status == .inProduction && f.order.producedAt == nil)
    }

    @Test func falhaNoSaveDaTransicaoRestauraEstadoEDatas() throws {
        let f = try fixture()
        let previousUpdatedAt = f.order.updatedAt
        enum SaveFailure: Error { case simulated }
        #expect(throws: SaveFailure.simulated) {
            try SalesOrderService.transition(
                id: f.order.id, to: .shipped, date: now.addingTimeInterval(1), in: f.context,
                saving: { _ in throw SaveFailure.simulated }
            )
        }
        #expect(f.order.status == .readyToShip && f.order.shippedAt == nil)
        #expect(f.order.updatedAt == previousUpdatedAt && !f.context.hasChanges)
        let reader = ModelContext(TestDatabase.container)
        #expect(try reader.fetch(FetchDescriptor<SalesOrder>()).first?.status == .readyToShip)
    }

    @Test func errosDeGerenciamentoPossuemMensagensLocalizadas() {
        let errors: [SalesOrderManagementError] = [
            .orderUnavailable, .editingNotAllowed, .cancellationNotAllowed,
            .invalidOrderData, .stockHistoryMismatch, .quantityOverflow,
            .transitionNotAllowed, .invalidTransitionDate
        ]
        for error in errors {
            #expect(!error.localizedMessage.isEmpty && !error.localizedMessage.hasPrefix("order."))
        }
    }
}
