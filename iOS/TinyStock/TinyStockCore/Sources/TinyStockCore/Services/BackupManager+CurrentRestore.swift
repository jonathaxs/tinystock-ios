// Propósito: Restaurar backups atuais preservando a identidade usada pelo CloudKit.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-12.

import Foundation
import SwiftData

extension BackupManager {
    @MainActor
    static func restoreV2(
        _ payload: BackupPayload,
        into context: ModelContext,
        saving: (ModelContext) throws -> Void
    ) throws -> BackupRestoreResult {
        guard let selectedID = payload.selectedStoreID else {
            throw BackupError.invalidFile
        }
        try context.save()

        do {
            try context.transaction {
                try mergeV2(payload, into: context)
                try saving(context)
            }
            return BackupRestoreResult(
                selectedStoreID: selectedID,
                migratedLegacyBackup: false,
                summary: payload.summary
            )
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Atualiza models com o mesmo UUID para preservar a identidade interna do CloudKit.
    @MainActor
    private static func mergeV2(_ payload: BackupPayload, into context: ModelContext) throws {
        var stores = indexed(
            try context.fetch(FetchDescriptor<StoreProfile>()),
            id: \StoreProfile.id,
            in: context
        )
        var products = indexed(
            try context.fetch(FetchDescriptor<Product>()),
            id: \Product.id,
            in: context
        )
        var variants = indexed(
            try context.fetch(FetchDescriptor<ProductVariant>()),
            id: \ProductVariant.id,
            in: context
        )
        var movements = indexed(
            try context.fetch(FetchDescriptor<StockMovement>()),
            id: \StockMovement.id,
            in: context
        )
        var orders = indexed(
            try context.fetch(FetchDescriptor<SalesOrder>()),
            id: \SalesOrder.id,
            in: context
        )
        var items = indexed(
            try context.fetch(FetchDescriptor<SalesOrderItem>()),
            id: \SalesOrderItem.id,
            in: context
        )

        let storeIDs = Set(payload.stores.map(\.id))
        let productIDs = Set(payload.products.map(\.id))
        let variantIDs = Set(payload.variants.map(\.id))
        let movementIDs = Set(payload.stockMovements.map(\.id))
        let orderIDs = Set(payload.orders.map(\.id))
        let itemIDs = Set(payload.orders.flatMap(\.items).map(\.id))

        for snapshot in payload.stores {
            let value = stores.removeValue(forKey: snapshot.id) ?? StoreProfile(id: snapshot.id)
            if value.modelContext == nil { context.insert(value) }
            apply(snapshot, to: value)
        }
        for snapshot in payload.products {
            guard let storeID = snapshot.storeID else { throw BackupError.invalidFile }
            let value = products.removeValue(forKey: snapshot.id) ?? Product(id: snapshot.id)
            if value.modelContext == nil { context.insert(value) }
            apply(snapshot, storeID: storeID, to: value)
        }
        for snapshot in payload.variants {
            let value = variants.removeValue(forKey: snapshot.id) ?? ProductVariant(id: snapshot.id)
            if value.modelContext == nil { context.insert(value) }
            apply(snapshot, to: value)
        }
        for snapshot in payload.stockMovements {
            let value = movements.removeValue(forKey: snapshot.id) ?? StockMovement(id: snapshot.id)
            if value.modelContext == nil { context.insert(value) }
            apply(snapshot, to: value)
        }

        var restoredOrders: [UUID: SalesOrder] = [:]
        for snapshot in payload.orders {
            let value = orders.removeValue(forKey: snapshot.id) ?? SalesOrder(id: snapshot.id)
            if value.modelContext == nil { context.insert(value) }
            apply(snapshot, to: value)
            restoredOrders[snapshot.id] = value
        }
        for orderSnapshot in payload.orders {
            guard let parent = restoredOrders[orderSnapshot.id] else {
                throw BackupError.invalidFile
            }
            var restoredItems: [SalesOrderItem] = []
            for snapshot in orderSnapshot.items {
                let value = items.removeValue(forKey: snapshot.id) ?? SalesOrderItem(id: snapshot.id)
                if value.modelContext == nil { context.insert(value) }
                apply(snapshot, to: value)
                value.order = parent
                restoredItems.append(value)
            }
            parent.items = restoredItems
        }

        // O formato v2 substitui o banco inteiro e remove apenas registros ausentes.
        for value in items.values where !itemIDs.contains(value.id) { context.delete(value) }
        for value in orders.values where !orderIDs.contains(value.id) { context.delete(value) }
        for value in movements.values where !movementIDs.contains(value.id) { context.delete(value) }
        for value in variants.values where !variantIDs.contains(value.id) { context.delete(value) }
        for value in products.values where !productIDs.contains(value.id) { context.delete(value) }
        for value in stores.values where !storeIDs.contains(value.id) { context.delete(value) }
        for value in try context.fetch(FetchDescriptor<SaleItem>()) { context.delete(value) }
        for value in try context.fetch(FetchDescriptor<Sale>()) { context.delete(value) }
    }

    @MainActor
    private static func indexed<Model: PersistentModel>(
        _ values: [Model],
        id: KeyPath<Model, UUID>,
        in context: ModelContext
    ) -> [UUID: Model] {
        var result: [UUID: Model] = [:]
        for value in values {
            let identifier = value[keyPath: id]
            if result[identifier] == nil {
                result[identifier] = value
            } else {
                // Duplicatas podem chegar por sincronização concorrente entre dispositivos.
                context.delete(value)
            }
        }
        return result
    }

    private static func apply(_ snapshot: BackupPayload.StoreSnapshot, to value: StoreProfile) {
        value.name = snapshot.name
        value.imageData = snapshot.imageData
        value.isArchived = snapshot.isArchived
        value.archivedAt = snapshot.archivedAt
        value.trashedAt = snapshot.trashedAt
        value.wasArchivedBeforeTrash = snapshot.wasArchivedBeforeTrash
        value.sortOrder = snapshot.sortOrder
        value.createdAt = snapshot.createdAt
        value.updatedAt = snapshot.updatedAt
    }

    private static func apply(
        _ snapshot: BackupPayload.ProductSnapshot,
        storeID: UUID,
        to value: Product
    ) {
        value.storeID = storeID
        value.name = snapshot.name
        value.category = snapshot.category
        value.quantity = snapshot.quantity
        value.minimumStock = snapshot.minimumStock
        value.costPrice = snapshot.costPrice
        value.salePrice = snapshot.salePrice
        value.imageData = snapshot.imageData
        value.createdAt = snapshot.createdAt
        value.updatedAt = snapshot.updatedAt
    }

    private static func apply(
        _ snapshot: BackupPayload.ProductVariantSnapshot,
        to value: ProductVariant
    ) {
        value.storeID = snapshot.storeID
        value.productID = snapshot.productID
        value.name = snapshot.name
        value.isDefault = snapshot.isDefault
        value.quantity = snapshot.quantity
        value.createdAt = snapshot.createdAt
        value.updatedAt = snapshot.updatedAt
    }

    private static func apply(
        _ snapshot: BackupPayload.StockMovementSnapshot,
        to value: StockMovement
    ) {
        value.storeID = snapshot.storeID
        value.productID = snapshot.productID
        value.variantID = snapshot.variantID
        value.kindRawValue = snapshot.kind
        value.quantityDelta = snapshot.quantityDelta
        value.balanceAfter = snapshot.balanceAfter
        value.note = snapshot.note
        value.referenceID = snapshot.referenceID
        value.reversedMovementID = snapshot.reversedMovementID
        value.reversedAt = snapshot.reversedAt
        value.createdAt = snapshot.createdAt
    }

    private static func apply(
        _ snapshot: BackupPayload.SalesOrderSnapshot,
        to value: SalesOrder
    ) {
        value.storeID = snapshot.storeID
        value.channelRawValue = snapshot.channel
        value.customChannelName = snapshot.customChannelName
        value.fulfillmentRawValue = snapshot.fulfillment
        value.statusRawValue = snapshot.status
        value.buyerName = snapshot.buyerName
        value.externalReference = snapshot.externalReference
        value.orderedAt = snapshot.orderedAt
        value.productionDueAt = snapshot.productionDueAt
        value.shippingDueAt = snapshot.shippingDueAt
        value.productionStartedAt = snapshot.productionStartedAt
        value.producedAt = snapshot.producedAt
        value.shippedAt = snapshot.shippedAt
        value.completedAt = snapshot.completedAt
        value.cancelledAt = snapshot.cancelledAt
        value.cancellationReason = snapshot.cancellationReason
        value.trackingCode = snapshot.trackingCode
        value.note = snapshot.note
        value.channelFeePercentage = snapshot.channelFeePercentage
        value.channelFeeAmount = snapshot.channelFeeAmount
        value.createdAt = snapshot.createdAt
        value.updatedAt = snapshot.updatedAt
    }

    private static func apply(
        _ snapshot: BackupPayload.SalesOrderItemSnapshot,
        to value: SalesOrderItem
    ) {
        value.storeID = snapshot.storeID
        value.productID = snapshot.productID
        value.variantID = snapshot.variantID
        value.productName = snapshot.productName
        value.variantName = snapshot.variantName
        value.unitPrice = snapshot.unitPrice
        value.unitCost = snapshot.unitCost
        value.quantity = snapshot.quantity
        value.position = snapshot.position
    }
}
