// Proposito: Validar o pedido inteiro antes de registrar itens e baixa de estoque.
// Created by Jonathas Motta (@jonathaxs) on 2026-08-31.

import Foundation
import SwiftData

/// IDs permitem resolver os objetos no contexto de gravacao, sem transportar models entre contextos.
public struct SalesOrderLine: Sendable {
    public let productID: UUID
    public let variantID: UUID
    public let quantity: Int

    public init(productID: UUID, variantID: UUID, quantity: Int) {
        self.productID = productID
        self.variantID = variantID
        self.quantity = quantity
    }
}

public enum SalesOrderError: Error, Equatable, Sendable {
    case emptyOrder
    case storeUnavailable
    case productUnavailable
    case variantMismatch
    case invalidQuantity
    case quantityOverflow
    case insufficientStock(productName: String, variantName: String, available: Int, requested: Int)
    case invalidMoney
    case invalidChannelFee
    case invalidDates
    case futureOrderDate
    case shippingBeforeOrder
    case productionDateRequired
    case invalidProductionDate
    case duplicateOrder

    public var localizedMessage: String {
        switch self {
        case .emptyOrder: String(localized: "order.error.empty", bundle: .tinyStockCore)
        case .storeUnavailable: String(localized: "order.error.store", bundle: .tinyStockCore)
        case .productUnavailable: String(localized: "order.error.product", bundle: .tinyStockCore)
        case .variantMismatch: String(localized: "order.error.variant", bundle: .tinyStockCore)
        case .invalidQuantity: String(localized: "order.error.quantity", bundle: .tinyStockCore)
        case .quantityOverflow: String(localized: "order.error.quantityOverflow", bundle: .tinyStockCore)
        case let .insufficientStock(productName, variantName, available, requested):
            String(format: String(localized: "order.error.stock", bundle: .tinyStockCore),
                   requested.formatted(), productName, variantName, available.formatted())
        case .invalidMoney: String(localized: "order.error.money", bundle: .tinyStockCore)
        case .invalidChannelFee: String(localized: "order.error.fee", bundle: .tinyStockCore)
        case .invalidDates: String(localized: "order.error.dates", bundle: .tinyStockCore)
        case .futureOrderDate: String(localized: "order.error.futureDate", bundle: .tinyStockCore)
        case .shippingBeforeOrder: String(localized: "order.error.shippingDate", bundle: .tinyStockCore)
        case .productionDateRequired: String(localized: "order.error.productionRequired", bundle: .tinyStockCore)
        case .invalidProductionDate: String(localized: "order.error.productionDate", bundle: .tinyStockCore)
        case .duplicateOrder: String(localized: "order.error.duplicate", bundle: .tinyStockCore)
        }
    }
}

@MainActor
public enum SalesOrderService {
    /// Confirma o lote em um save e restaura os saldos se a persistencia falhar.
    /// Nao ha await entre validacao e escrita; todos os objetos pertencem ao contexto informado.
    @discardableResult
    public static func register(
        id: UUID = UUID(),
        storeID: UUID,
        lines: [SalesOrderLine],
        fulfillment: OrderFulfillment,
        channel: SalesChannel = .direct,
        customChannelName: String = "",
        buyerName: String = "",
        externalReference: String = "",
        orderedAt: Date = Date(),
        productionDueAt: Date? = nil,
        shippingDueAt: Date,
        note: String = "",
        channelFeePercentage: Decimal = 0,
        now: Date = Date(),
        calendar: Calendar = .current,
        in context: ModelContext
    ) throws -> SalesOrder {
        guard !lines.isEmpty else { throw SalesOrderError.emptyOrder }
        let stores = try context.fetch(FetchDescriptor<StoreProfile>(predicate: #Predicate { $0.id == storeID }))
        guard storeID != StoreScope.unassignedStoreID, stores.count == 1, stores.first?.isArchived == false else {
            throw SalesOrderError.storeUnavailable
        }
        // A sheet deve reutilizar o ID do rascunho em tentativas repetidas para impedir dupla baixa.
        let existing = try context.fetch(FetchDescriptor<SalesOrder>(predicate: #Predicate { $0.id == id }))
        guard existing.isEmpty else { throw SalesOrderError.duplicateOrder }
        try validateDates(fulfillment: fulfillment, orderedAt: orderedAt, productionDueAt: productionDueAt,
                          shippingDueAt: shippingDueAt, now: now, calendar: calendar)
        guard !channelFeePercentage.isNaN, channelFeePercentage >= 0, channelFeePercentage <= 100 else {
            throw SalesOrderError.invalidChannelFee
        }

        let resolved = try resolve(lines, storeID: storeID, in: context)
        var snapshots: [SalesOrderItem] = []
        for (index, line) in resolved.enumerated() {
            if fulfillment == .readyStock && line.quantity > line.variant.quantity {
                throw SalesOrderError.insufficientStock(productName: line.product.name, variantName: line.variant.name,
                                                       available: line.variant.quantity, requested: line.quantity)
            }
            let item: SalesOrderItem
            do {
                item = try SalesOrderItem.snapshot(product: line.product, variant: line.variant,
                                                   quantity: line.quantity, position: index)
            } catch { throw SalesOrderError.invalidMoney }
            guard !item.subtotal.isNaN, !item.subtotalCost.isNaN else { throw SalesOrderError.invalidMoney }
            snapshots.append(item)
        }
        let revenue = snapshots.reduce(Decimal.zero) { $0 + $1.subtotal }
        let cost = snapshots.reduce(Decimal.zero) { $0 + $1.subtotalCost }
        guard !revenue.isNaN, !cost.isNaN, !(revenue - cost).isNaN else { throw SalesOrderError.invalidMoney }
        let fee = try ChannelFeeCalculator.fee(on: revenue, percentage: channelFeePercentage)
        guard !fee.isNaN, !(revenue - cost - fee).isNaN else { throw SalesOrderError.invalidMoney }

        // Todas as linhas e contas foram validadas. A gravacao tambem protege os objetos em memoria.
        return try persistRegistration(in: context, variants: fulfillment == .readyStock ? resolved.map(\.variant) : []) {
            let order = SalesOrder(id: id, storeID: storeID, channel: channel,
                               customChannelName: channel == .other ? clean(customChannelName) : "",
                               fulfillment: fulfillment, buyerName: clean(buyerName), externalReference: clean(externalReference),
                               orderedAt: orderedAt, productionDueAt: fulfillment == .production ? productionDueAt : nil,
                               shippingDueAt: shippingDueAt, note: clean(note), channelFeePercentage: channelFeePercentage,
                               channelFeeAmount: fee, createdAt: now, updatedAt: now)
            context.insert(order)
            for (line, item) in zip(resolved, snapshots) {
                context.insert(item)
                item.order = order
                if fulfillment == .readyStock {
                    try StockService.registerOrderWithdrawal(quantity: line.quantity, from: line.variant,
                                                            product: line.product, orderID: order.id, date: now, in: context)
                }
            }
            return order
        }
    }

    /// Fronteira interna de persistencia. A funcao de save permite testar falhas sem corromper um banco real.
    static func persistRegistration(
        in context: ModelContext,
        variants: [ProductVariant],
        applying: () throws -> SalesOrder,
        saving: (ModelContext) throws -> Void = { try $0.save() }
    ) throws -> SalesOrder {
        // Preserva trabalho anterior ao pedido. Somente o novo lote pertence ao rollback abaixo.
        try context.save()
        let previous = variants.map { (variant: $0, quantity: $0.quantity, updatedAt: $0.updatedAt) }
        do {
            let order = try applying()
            try saving(context)
            return order
        } catch {
            // O rollback sozinho pode manter o saldo alterado nos models ja carregados.
            // Restaura explicitamente os campos alterados antes de descartar as insercoes do lote.
            for state in previous {
                state.variant.quantity = state.quantity
                state.variant.updatedAt = state.updatedAt
            }
            context.rollback()
            throw error
        }
    }

    private struct ResolvedLine {
        let product: Product
        let variant: ProductVariant
        var quantity: Int
    }

    private static func resolve(_ lines: [SalesOrderLine], storeID: UUID, in context: ModelContext) throws -> [ResolvedLine] {
        let products = try context.fetch(FetchDescriptor<Product>(predicate: #Predicate { $0.storeID == storeID }))
        let variants = try context.fetch(FetchDescriptor<ProductVariant>(predicate: #Predicate { $0.storeID == storeID }))
        var result: [ResolvedLine] = []
        for line in lines {
            guard line.quantity > 0 else { throw SalesOrderError.invalidQuantity }
            let matchingProducts = products.filter { $0.id == line.productID }
            guard matchingProducts.count == 1, let product = matchingProducts.first else {
                throw SalesOrderError.productUnavailable
            }
            let matchingVariants = variants.filter { $0.id == line.variantID }
            guard matchingVariants.count == 1, let variant = matchingVariants.first, variant.belongs(to: product) else {
                throw SalesOrderError.variantMismatch
            }
            if let index = result.firstIndex(where: { $0.variant.id == variant.id }) {
                let sum = result[index].quantity.addingReportingOverflow(line.quantity)
                guard !sum.overflow else { throw SalesOrderError.quantityOverflow }
                result[index].quantity = sum.partialValue
            } else {
                result.append(ResolvedLine(product: product, variant: variant, quantity: line.quantity))
            }
        }
        return result
    }

    static func validateDates(
        fulfillment: OrderFulfillment, orderedAt: Date, productionDueAt: Date?,
        shippingDueAt: Date, now: Date, calendar: Calendar
    ) throws {
        let dates = [orderedAt, shippingDueAt, now] + (fulfillment == .production ? [productionDueAt].compactMap { $0 } : [])
        guard dates.allSatisfy({ $0.timeIntervalSinceReferenceDate.isFinite }) else { throw SalesOrderError.invalidDates }
        // A interface seleciona dias. Um despacho hoje as 00h nao precede uma venda hoje a tarde.
        guard calendar.compare(orderedAt, to: now, toGranularity: .day) != .orderedDescending else {
            throw SalesOrderError.futureOrderDate
        }
        guard calendar.compare(shippingDueAt, to: orderedAt, toGranularity: .day) != .orderedAscending else {
            throw SalesOrderError.shippingBeforeOrder
        }
        if fulfillment == .production {
            guard let productionDueAt else { throw SalesOrderError.productionDateRequired }
            guard calendar.compare(productionDueAt, to: orderedAt, toGranularity: .day) != .orderedAscending,
                  calendar.compare(productionDueAt, to: shippingDueAt, toGranularity: .day) != .orderedDescending else {
                throw SalesOrderError.invalidProductionDate
            }
        }
    }

    static func clean(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
}
