// Proposito: Guardar o retrato do produto e da variacao no momento do pedido.
// Created by Jonathas Motta (@jonathaxs) on 2026-08-31.

import Foundation
import SwiftData

public enum SalesOrderItemError: Error, Equatable, Sendable {
    case invalidQuantity
    case variantMismatch
    case invalidPrices

    public var localizedMessage: String {
        switch self {
        case .invalidQuantity: String(localized: "order.item.error.quantity", bundle: .tinyStockCore)
        case .variantMismatch: String(localized: "order.item.error.variant", bundle: .tinyStockCore)
        case .invalidPrices: String(localized: "order.item.error.prices", bundle: .tinyStockCore)
        }
    }
}

@Model
public final class SalesOrderItem {
    public var id: UUID = UUID()
    public var storeID: UUID = StoreScope.unassignedStoreID
    public var productID: UUID = UUID()
    public var variantID: UUID = UUID()
    public var productName: String = ""
    public var variantName: String = ""
    public var unitPrice: Decimal = 0
    public var unitCost: Decimal = 0
    public var quantity: Int = 0

    /// Relacoes to-many nao preservam ordem; o indice mantem a sequencia escolhida.
    public var position: Int = 0
    public var order: SalesOrder?

    public init(
        id: UUID = UUID(),
        storeID: UUID = StoreScope.unassignedStoreID,
        productID: UUID = UUID(),
        variantID: UUID = UUID(),
        productName: String = "",
        variantName: String = "",
        unitPrice: Decimal = 0,
        unitCost: Decimal = 0,
        quantity: Int = 0,
        position: Int = 0
    ) {
        self.id = id
        self.storeID = storeID
        self.productID = productID
        self.variantID = variantID
        self.productName = productName
        self.variantName = variantName
        self.unitPrice = unitPrice
        self.unitCost = unitCost
        self.quantity = quantity
        self.position = position
    }

    /// Nao ha relacao com o catalogo: renomear ou excluir um produto nao muda o pedido.
    /// Criar o retrato nao reserva nem baixa estoque; essa operacao pertence ao servico de pedidos.
    public static func snapshot(
        product: Product,
        variant: ProductVariant,
        quantity: Int,
        position: Int = 0
    ) throws -> SalesOrderItem {
        guard variant.belongs(to: product) else { throw SalesOrderItemError.variantMismatch }
        guard quantity > 0 else { throw SalesOrderItemError.invalidQuantity }
        guard !product.salePrice.isNaN, !product.costPrice.isNaN,
              product.salePrice >= 0, product.costPrice >= 0 else { throw SalesOrderItemError.invalidPrices }
        return SalesOrderItem(
            storeID: product.storeID, productID: product.id, variantID: variant.id,
            productName: product.name, variantName: variant.isDefault ? "" : variant.name,
            unitPrice: product.salePrice, unitCost: product.costPrice,
            quantity: quantity, position: position
        )
    }

    public var subtotal: Decimal { unitPrice * Decimal(quantity) }
    public var subtotalCost: Decimal { unitCost * Decimal(quantity) }
    public var grossProfit: Decimal { subtotal - subtotalCost }
}
