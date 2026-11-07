// ⌘
//  TinyStockCore/Models/StockMovement.swift
//
//  Propósito: Registrar cada alteração de estoque com seu saldo resultante.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-28.
// ⌘

import Foundation
import SwiftData

public enum StockMovementKind: String, CaseIterable, Codable, Sendable {
    case initialStock
    case entry
    case adjustment
    case reversal
    case orderWithdrawal
}

/// Registro auditável de uma mudança no saldo de uma variação.
/// O saldo fica materializado na variação para consultas rápidas, enquanto este
/// histórico explica como ele chegou ao valor atual.
@Model
public final class StockMovement {

    public var id: UUID = UUID()
    public var storeID: UUID = StoreScope.unassignedStoreID
    public var productID: UUID = UUID()
    public var variantID: UUID = UUID()
    public var kindRawValue: String = StockMovementKind.adjustment.rawValue

    /// Diferença aplicada ao saldo. Entrada é positiva e retirada é negativa.
    public var quantityDelta: Int = 0

    /// Saldo da variação imediatamente depois desta movimentação.
    public var balanceAfter: Int = 0

    public var note: String = ""

    /// Identificador do pedido ou de outra operação que originou a movimentação.
    public var referenceID: UUID?

    /// Preenchido somente na movimentação que desfaz outra.
    public var reversedMovementID: UUID?

    /// Marca quando esta movimentação original foi desfeita.
    public var reversedAt: Date?

    public var createdAt: Date = Date()

    @Transient
    public var kind: StockMovementKind {
        get { StockMovementKind(rawValue: kindRawValue) ?? .adjustment }
        set { kindRawValue = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        storeID: UUID = StoreScope.unassignedStoreID,
        productID: UUID = UUID(),
        variantID: UUID = UUID(),
        kind: StockMovementKind = .adjustment,
        quantityDelta: Int = 0,
        balanceAfter: Int = 0,
        note: String = "",
        referenceID: UUID? = nil,
        reversedMovementID: UUID? = nil,
        reversedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.storeID = storeID
        self.productID = productID
        self.variantID = variantID
        kindRawValue = kind.rawValue
        self.quantityDelta = quantityDelta
        self.balanceAfter = balanceAfter
        self.note = note
        self.referenceID = referenceID
        self.reversedMovementID = reversedMovementID
        self.reversedAt = reversedAt
        self.createdAt = createdAt
    }

    public func belongs(to variant: ProductVariant, product: Product) -> Bool {
        storeID == product.storeID
            && productID == product.id
            && variantID == variant.id
            && variant.belongs(to: product)
    }
}
