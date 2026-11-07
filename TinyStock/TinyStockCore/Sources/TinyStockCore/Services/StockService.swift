// ⌘
//  TinyStockCore/Services/StockService.swift
//
//  Propósito: Alterar o saldo das variações sempre por movimentações auditáveis.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-28.
// ⌘

import Foundation
import SwiftData

// MARK: - Erros

public enum StockError: Error, Equatable, Sendable {
    case invalidQuantity
    case negativeBalance
    case noChange
    case quantityOverflow
    case productMismatch
    case movementMismatch
    case alreadyReversed
    case reversalNotAllowed
    case orderManagedMovement
}

public extension StockError {

    var localizedMessage: String {
        switch self {
        case .invalidQuantity:
            String(localized: "stock.error.invalidQuantity", bundle: .tinyStockCore)
        case .negativeBalance:
            String(localized: "stock.error.negativeBalance", bundle: .tinyStockCore)
        case .noChange:
            String(localized: "stock.error.noChange", bundle: .tinyStockCore)
        case .quantityOverflow:
            String(localized: "stock.error.quantityOverflow", bundle: .tinyStockCore)
        case .productMismatch:
            String(localized: "stock.error.productMismatch", bundle: .tinyStockCore)
        case .movementMismatch:
            String(localized: "stock.error.movementMismatch", bundle: .tinyStockCore)
        case .alreadyReversed:
            String(localized: "stock.error.alreadyReversed", bundle: .tinyStockCore)
        case .reversalNotAllowed:
            String(localized: "stock.error.reversalNotAllowed", bundle: .tinyStockCore)
        case .orderManagedMovement:
            String(localized: "stock.error.orderManaged", bundle: .tinyStockCore)
        }
    }
}

// MARK: - Serviço

public enum StockService {

    /// Entrada pela tela do produto, em uma variacao existente ou em uma nova opcao.
    @discardableResult
    public static func registerEntry(
        quantity: Int,
        for product: Product,
        variantID: UUID?,
        newVariantName: String = "",
        note: String = "",
        in context: ModelContext
    ) throws -> StockMovement {
        guard quantity > 0 else { throw StockError.invalidQuantity }
        let variant: ProductVariant
        if let variantID {
            guard let existing = try ProductVariantService.variants(for: product, in: context)
                .first(where: { $0.id == variantID }) else {
                throw StockError.productMismatch
            }
            variant = existing
        } else {
            // A opcao nasce zerada: o recebimento e registrado como entrada, nao como saldo inicial.
            variant = try ProductVariantService.create(for: product, name: newVariantName, in: context)
        }
        return try registerEntry(quantity: quantity, to: variant, product: product, note: note, in: context)
    }

    /// Soma unidades recebidas ao saldo atual.
    @discardableResult
    public static func registerEntry(
        quantity: Int,
        to variant: ProductVariant,
        product: Product,
        note: String = "",
        referenceID: UUID? = nil,
        date: Date = Date(),
        in context: ModelContext
    ) throws -> StockMovement {
        guard quantity > 0 else { throw StockError.invalidQuantity }

        return try apply(
            delta: quantity,
            kind: .entry,
            to: variant,
            product: product,
            note: note,
            referenceID: referenceID,
            reversedMovementID: nil,
            date: date,
            in: context
        )
    }

    /// Define o saldo contado pelo comerciante e registra somente a diferença.
    @discardableResult
    public static func registerAdjustment(
        newQuantity: Int,
        to variant: ProductVariant,
        product: Product,
        note: String = "",
        date: Date = Date(),
        in context: ModelContext
    ) throws -> StockMovement {
        guard newQuantity >= 0 else { throw StockError.negativeBalance }
        guard newQuantity != variant.quantity else { throw StockError.noChange }

        let difference = newQuantity.subtractingReportingOverflow(variant.quantity)
        guard !difference.overflow else { throw StockError.quantityOverflow }

        return try apply(
            delta: difference.partialValue,
            kind: .adjustment,
            to: variant,
            product: product,
            note: note,
            referenceID: nil,
            reversedMovementID: nil,
            date: date,
            in: context
        )
    }

    /// Desfaz o efeito de uma movimentação sem apagar o histórico original.
    @discardableResult
    public static func reverse(
        _ movement: StockMovement,
        for variant: ProductVariant,
        product: Product,
        note: String = "",
        date: Date = Date(),
        in context: ModelContext
    ) throws -> StockMovement {
        guard movement.kind != .reversal else { throw StockError.reversalNotAllowed }
        guard movement.kind != .orderWithdrawal else { throw StockError.orderManagedMovement }
        guard movement.reversedAt == nil else { throw StockError.alreadyReversed }
        guard movement.belongs(to: variant, product: product) else {
            throw StockError.movementMismatch
        }

        let oppositeDelta = movement.quantityDelta.multipliedReportingOverflow(by: -1)
        guard !oppositeDelta.overflow else { throw StockError.quantityOverflow }

        let reversal = try apply(
            delta: oppositeDelta.partialValue,
            kind: .reversal,
            to: variant,
            product: product,
            note: note,
            referenceID: movement.referenceID,
            reversedMovementID: movement.id,
            date: date,
            in: context
        )
        movement.reversedAt = date
        return reversal
    }

    /// Histórico mais recente primeiro, sempre limitado ao escopo completo.
    public static func movements(
        for variant: ProductVariant,
        product: Product,
        in context: ModelContext
    ) throws -> [StockMovement] {
        guard variant.belongs(to: product) else { throw StockError.productMismatch }

        let storeID = product.storeID
        let productID = product.id
        let variantID = variant.id
        let descriptor = FetchDescriptor<StockMovement>(
            predicate: #Predicate {
                $0.storeID == storeID
                    && $0.productID == productID
                    && $0.variantID == variantID
            },
            sortBy: [SortDescriptor(\StockMovement.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: - Uso interno

    /// Somente o servico de pedidos pode registrar a baixa vinculada ao atendimento.
    @discardableResult
    static func registerOrderWithdrawal(
        quantity: Int, from variant: ProductVariant, product: Product,
        orderID: UUID, date: Date, in context: ModelContext
    ) throws -> StockMovement {
        guard quantity > 0 else { throw StockError.invalidQuantity }
        return try apply(delta: -quantity, kind: .orderWithdrawal, to: variant, product: product,
                         note: "", referenceID: orderID, reversedMovementID: nil, date: date, in: context)
    }

    /// Somente o cancelamento coordenado pode devolver uma baixa de pedido ao estoque.
    @discardableResult
    static func reverseOrderWithdrawal(
        _ movement: StockMovement,
        orderID: UUID,
        variant: ProductVariant,
        product: Product,
        note: String,
        date: Date,
        in context: ModelContext
    ) throws -> StockMovement {
        guard movement.kind == .orderWithdrawal, movement.referenceID == orderID else {
            throw StockError.orderManagedMovement
        }
        guard movement.reversedAt == nil else { throw StockError.alreadyReversed }
        guard movement.belongs(to: variant, product: product) else { throw StockError.movementMismatch }

        let oppositeDelta = movement.quantityDelta.multipliedReportingOverflow(by: -1)
        guard !oppositeDelta.overflow else { throw StockError.quantityOverflow }
        let reversal = try apply(
            delta: oppositeDelta.partialValue,
            kind: .reversal,
            to: variant,
            product: product,
            note: note,
            referenceID: orderID,
            reversedMovementID: movement.id,
            date: date,
            in: context
        )
        movement.reversedAt = date
        return reversal
    }

    /// Registra o saldo informado junto com a criação de uma variação.
    @discardableResult
    static func registerInitialStock(
        quantity: Int,
        to variant: ProductVariant,
        product: Product,
        date: Date,
        in context: ModelContext
    ) throws -> StockMovement {
        guard quantity > 0 else { throw StockError.invalidQuantity }

        return try apply(
            delta: quantity,
            kind: .initialStock,
            to: variant,
            product: product,
            note: "",
            referenceID: nil,
            reversedMovementID: nil,
            date: date,
            in: context
        )
    }

    @discardableResult
    private static func apply(
        delta: Int,
        kind: StockMovementKind,
        to variant: ProductVariant,
        product: Product,
        note: String,
        referenceID: UUID?,
        reversedMovementID: UUID?,
        date: Date,
        in context: ModelContext
    ) throws -> StockMovement {
        guard variant.belongs(to: product) else { throw StockError.productMismatch }
        guard delta != 0 else { throw StockError.noChange }

        let result = variant.quantity.addingReportingOverflow(delta)
        guard !result.overflow else { throw StockError.quantityOverflow }
        guard result.partialValue >= 0 else { throw StockError.negativeBalance }

        let movement = StockMovement(
            storeID: product.storeID,
            productID: product.id,
            variantID: variant.id,
            kind: kind,
            quantityDelta: delta,
            balanceAfter: result.partialValue,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            referenceID: referenceID,
            reversedMovementID: reversedMovementID,
            createdAt: date
        )
        variant.quantity = result.partialValue
        variant.updatedAt = date
        context.insert(movement)
        return movement
    }
}
