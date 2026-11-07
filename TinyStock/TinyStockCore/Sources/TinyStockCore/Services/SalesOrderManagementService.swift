// Proposito: Editar e cancelar pedidos sem separar seu estado dos efeitos no estoque.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-02.

import Foundation
import SwiftData

public struct SalesOrderDetails: Sendable {
    public let channel: SalesChannel
    public let customChannelName: String
    public let buyerName: String
    public let externalReference: String
    public let orderedAt: Date
    public let productionDueAt: Date?
    public let shippingDueAt: Date
    public let trackingCode: String
    public let note: String
    public let channelFeePercentage: Decimal

    public init(
        channel: SalesChannel,
        customChannelName: String = "",
        buyerName: String = "",
        externalReference: String = "",
        orderedAt: Date,
        productionDueAt: Date? = nil,
        shippingDueAt: Date,
        trackingCode: String = "",
        note: String = "",
        channelFeePercentage: Decimal = 0
    ) {
        self.channel = channel
        self.customChannelName = customChannelName
        self.buyerName = buyerName
        self.externalReference = externalReference
        self.orderedAt = orderedAt
        self.productionDueAt = productionDueAt
        self.shippingDueAt = shippingDueAt
        self.trackingCode = trackingCode
        self.note = note
        self.channelFeePercentage = channelFeePercentage
    }
}

public enum SalesOrderManagementError: Error, Equatable, Sendable {
    case orderUnavailable
    case editingNotAllowed
    case cancellationNotAllowed
    case invalidOrderData
    case stockHistoryMismatch
    case quantityOverflow
    case transitionNotAllowed
    case invalidTransitionDate

    public var localizedMessage: String {
        switch self {
        case .orderUnavailable: String(localized: "order.management.error.unavailable", bundle: .tinyStockCore)
        case .editingNotAllowed: String(localized: "order.management.error.editing", bundle: .tinyStockCore)
        case .cancellationNotAllowed: String(localized: "order.management.error.cancellation", bundle: .tinyStockCore)
        case .invalidOrderData: String(localized: "order.management.error.data", bundle: .tinyStockCore)
        case .stockHistoryMismatch: String(localized: "order.management.error.stockHistory", bundle: .tinyStockCore)
        case .quantityOverflow: String(localized: "order.management.error.quantityOverflow", bundle: .tinyStockCore)
        case .transitionNotAllowed: String(localized: "order.management.error.transition", bundle: .tinyStockCore)
        case .invalidTransitionDate: String(localized: "order.management.error.transitionDate", bundle: .tinyStockCore)
        }
    }
}

@MainActor
public extension SalesOrderService {
    /// Edita somente os dados administrativos. Itens e atendimento continuam retratos imutaveis.
    @discardableResult
    static func update(
        id: UUID,
        details: SalesOrderDetails,
        now: Date = Date(),
        calendar: Calendar = .current,
        in context: ModelContext
    ) throws -> SalesOrder {
        let order = try requiredOrder(id: id, in: context)
        guard let status = order.status, let fulfillment = order.fulfillment else {
            throw SalesOrderManagementError.invalidOrderData
        }
        guard !status.isTerminal, status != .shipped else {
            throw SalesOrderManagementError.editingNotAllowed
        }
        try validateDates(fulfillment: fulfillment, orderedAt: details.orderedAt,
                          productionDueAt: details.productionDueAt, shippingDueAt: details.shippingDueAt,
                          now: now, calendar: calendar)
        guard !details.channelFeePercentage.isNaN,
              details.channelFeePercentage >= 0, details.channelFeePercentage <= 100 else {
            throw SalesOrderError.invalidChannelFee
        }
        let fee: Decimal
        do {
            fee = try ChannelFeeCalculator.fee(on: order.total, percentage: details.channelFeePercentage)
        } catch {
            throw SalesOrderError.invalidMoney
        }
        guard !fee.isNaN, !(order.grossProfit - fee).isNaN else { throw SalesOrderError.invalidMoney }

        try context.save()
        let previous = OrderState(order)
        do {
            order.channelRawValue = details.channel.rawValue
            order.customChannelName = details.channel == .other ? clean(details.customChannelName) : ""
            order.buyerName = clean(details.buyerName)
            order.externalReference = clean(details.externalReference)
            order.orderedAt = details.orderedAt
            order.productionDueAt = fulfillment == .production ? details.productionDueAt : nil
            order.shippingDueAt = details.shippingDueAt
            order.trackingCode = clean(details.trackingCode)
            order.note = clean(details.note)
            order.channelFeePercentage = details.channelFeePercentage
            order.channelFeeAmount = fee
            order.updatedAt = now
            try context.save()
            return order
        } catch {
            previous.restore(order)
            context.rollback()
            throw error
        }
    }

    /// Cancela antes do despacho e devolve a baixa de pronta entrega no mesmo save.
    @discardableResult
    static func cancel(
        id: UUID,
        reason: String = "",
        date: Date = Date(),
        in context: ModelContext
    ) throws -> SalesOrder {
        try cancel(id: id, reason: reason, date: date, in: context, saving: { try $0.save() })
    }

    /// Avanca o pedido por uma transicao permitida e registra a data efetiva correspondente.
    @discardableResult
    static func transition(
        id: UUID,
        to nextStatus: SalesOrderStatus,
        date: Date = Date(),
        in context: ModelContext
    ) throws -> SalesOrder {
        try transition(id: id, to: nextStatus, date: date, in: context, saving: { try $0.save() })
    }
}

@MainActor
extension SalesOrderService {
    static func transition(
        id: UUID,
        to nextStatus: SalesOrderStatus,
        date: Date,
        in context: ModelContext,
        saving: (ModelContext) throws -> Void
    ) throws -> SalesOrder {
        let order = try requiredOrder(id: id, in: context)
        guard nextStatus != .cancelled, order.canTransition(to: nextStatus) else {
            throw SalesOrderManagementError.transitionNotAllowed
        }
        guard date.timeIntervalSinceReferenceDate.isFinite, date >= order.orderedAt else {
            throw SalesOrderManagementError.invalidTransitionDate
        }
        if let previousDate = effectivePreviousDate(for: nextStatus, order: order), date < previousDate {
            throw SalesOrderManagementError.invalidTransitionDate
        }

        try context.save()
        let previous = OrderState(order)
        do {
            order.statusRawValue = nextStatus.rawValue
            switch nextStatus {
            case .inProduction:
                order.productionStartedAt = date
            case .readyToShip:
                if order.fulfillment == .production { order.producedAt = date }
            case .shipped:
                order.shippedAt = date
            case .completed:
                order.completedAt = date
            case .new, .awaitingProduction, .cancelled:
                break
            }
            order.updatedAt = date
            try saving(context)
            return order
        } catch {
            previous.restore(order)
            context.rollback()
            throw error
        }
    }

    static func cancel(
        id: UUID,
        reason: String,
        date: Date,
        in context: ModelContext,
        saving: (ModelContext) throws -> Void
    ) throws -> SalesOrder {
        let order = try requiredOrder(id: id, in: context)
        guard let status = order.status, let fulfillment = order.fulfillment else {
            throw SalesOrderManagementError.invalidOrderData
        }
        guard status.canTransition(to: .cancelled, fulfillment: fulfillment) else {
            throw SalesOrderManagementError.cancellationNotAllowed
        }
        guard date.timeIntervalSinceReferenceDate.isFinite else { throw SalesOrderError.invalidDates }
        let targets = fulfillment == .readyStock ? try cancellationTargets(for: order, in: context) : []

        // Nenhum dado anterior faz parte do rollback do cancelamento.
        try context.save()
        let previousOrder = OrderState(order)
        let previousTargets = targets.map(CancellationTargetState.init)
        do {
            for target in targets {
                try StockService.reverseOrderWithdrawal(
                    target.movement, orderID: order.id, variant: target.variant, product: target.product,
                    note: clean(reason), date: date, in: context
                )
            }
            order.statusRawValue = SalesOrderStatus.cancelled.rawValue
            order.cancelledAt = date
            order.cancellationReason = clean(reason)
            order.updatedAt = date
            try saving(context)
            return order
        } catch {
            previousOrder.restore(order)
            for state in previousTargets { state.restore() }
            context.rollback()
            throw error
        }
    }

    private struct CancellationTarget {
        let product: Product
        let variant: ProductVariant
        let movement: StockMovement
    }

    private struct CancellationTargetState {
        let variant: ProductVariant
        let quantity: Int
        let updatedAt: Date
        let movement: StockMovement
        let reversedAt: Date?

        init(_ target: CancellationTarget) {
            variant = target.variant
            quantity = target.variant.quantity
            updatedAt = target.variant.updatedAt
            movement = target.movement
            reversedAt = target.movement.reversedAt
        }

        func restore() {
            variant.quantity = quantity
            variant.updatedAt = updatedAt
            movement.reversedAt = reversedAt
        }
    }

    private struct OrderState {
        let channelRawValue: String
        let customChannelName: String
        let buyerName: String
        let externalReference: String
        let orderedAt: Date
        let productionDueAt: Date?
        let shippingDueAt: Date?
        let productionStartedAt: Date?
        let producedAt: Date?
        let shippedAt: Date?
        let completedAt: Date?
        let note: String
        let trackingCode: String
        let channelFeePercentage: Decimal
        let channelFeeAmount: Decimal
        let statusRawValue: String
        let cancelledAt: Date?
        let cancellationReason: String
        let updatedAt: Date

        init(_ order: SalesOrder) {
            channelRawValue = order.channelRawValue
            customChannelName = order.customChannelName
            buyerName = order.buyerName
            externalReference = order.externalReference
            orderedAt = order.orderedAt
            productionDueAt = order.productionDueAt
            shippingDueAt = order.shippingDueAt
            productionStartedAt = order.productionStartedAt
            producedAt = order.producedAt
            shippedAt = order.shippedAt
            completedAt = order.completedAt
            note = order.note
            trackingCode = order.trackingCode
            channelFeePercentage = order.channelFeePercentage
            channelFeeAmount = order.channelFeeAmount
            statusRawValue = order.statusRawValue
            cancelledAt = order.cancelledAt
            cancellationReason = order.cancellationReason
            updatedAt = order.updatedAt
        }

        func restore(_ order: SalesOrder) {
            order.channelRawValue = channelRawValue
            order.customChannelName = customChannelName
            order.buyerName = buyerName
            order.externalReference = externalReference
            order.orderedAt = orderedAt
            order.productionDueAt = productionDueAt
            order.shippingDueAt = shippingDueAt
            order.productionStartedAt = productionStartedAt
            order.producedAt = producedAt
            order.shippedAt = shippedAt
            order.completedAt = completedAt
            order.note = note
            order.trackingCode = trackingCode
            order.channelFeePercentage = channelFeePercentage
            order.channelFeeAmount = channelFeeAmount
            order.statusRawValue = statusRawValue
            order.cancelledAt = cancelledAt
            order.cancellationReason = cancellationReason
            order.updatedAt = updatedAt
        }
    }

    private static func requiredOrder(id: UUID, in context: ModelContext) throws -> SalesOrder {
        let orders = try context.fetch(FetchDescriptor<SalesOrder>(predicate: #Predicate { $0.id == id }))
        guard orders.count == 1, let order = orders.first else {
            throw SalesOrderManagementError.orderUnavailable
        }
        return order
    }

    private static func effectivePreviousDate(for status: SalesOrderStatus, order: SalesOrder) -> Date? {
        switch status {
        case .readyToShip:
            order.productionStartedAt
        case .shipped:
            order.producedAt
        case .completed:
            order.shippedAt
        case .new, .awaitingProduction, .inProduction, .cancelled:
            nil
        }
    }

    private static func cancellationTargets(for order: SalesOrder, in context: ModelContext) throws -> [CancellationTarget] {
        let items = order.itemList
        guard !items.isEmpty else { throw SalesOrderManagementError.invalidOrderData }
        let storeID = order.storeID
        let products = try context.fetch(FetchDescriptor<Product>(predicate: #Predicate { $0.storeID == storeID }))
        let variants = try context.fetch(FetchDescriptor<ProductVariant>(predicate: #Predicate { $0.storeID == storeID }))
        let orderID = order.id
        let movements = try context.fetch(FetchDescriptor<StockMovement>(predicate: #Predicate { $0.referenceID == orderID }))
            .filter { $0.kind == .orderWithdrawal }
        guard movements.count == items.count else { throw SalesOrderManagementError.stockHistoryMismatch }

        var targets: [CancellationTarget] = []
        for item in items {
            let matchingProducts = products.filter { $0.id == item.productID }
            let matchingVariants = variants.filter { $0.id == item.variantID }
            let matchingMovements = movements.filter {
                $0.productID == item.productID && $0.variantID == item.variantID
            }
            guard matchingProducts.count == 1, let product = matchingProducts.first,
                  matchingVariants.count == 1, let variant = matchingVariants.first,
                  variant.belongs(to: product), matchingMovements.count == 1,
                  let movement = matchingMovements.first, movement.reversedAt == nil else {
                throw SalesOrderManagementError.stockHistoryMismatch
            }
            let expectedDelta = item.quantity.multipliedReportingOverflow(by: -1)
            guard !expectedDelta.overflow, movement.quantityDelta == expectedDelta.partialValue else {
                throw SalesOrderManagementError.stockHistoryMismatch
            }
            let resultingQuantity = variant.quantity.addingReportingOverflow(item.quantity)
            guard !resultingQuantity.overflow else { throw SalesOrderManagementError.quantityOverflow }
            targets.append(CancellationTarget(product: product, variant: variant, movement: movement))
        }
        return targets
    }
}
