// Propósito: Migrar backups do schema anterior para o domínio atual de pedidos.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-12.

import Foundation
import SwiftData

extension BackupManager {
    @MainActor
    static func restoreV1(
        _ payload: BackupPayload,
        into context: ModelContext,
        storeID: UUID,
        saving: (ModelContext) throws -> Void
    ) throws -> BackupRestoreResult {
        let store = try context.fetch(FetchDescriptor<StoreProfile>(predicate: #Predicate {
            $0.id == storeID && !$0.isArchived
        })).first
        guard store != nil else { throw BackupError.invalidFile }
        try context.save()

        do {
            try context.transaction {
                try deleteStoreData(storeID: storeID, in: context)
                for snapshot in payload.products {
                    context.insert(product(from: snapshot, storeID: storeID))
                    let quantity = max(0, snapshot.quantity)
                    let variant = ProductVariant(
                        id: snapshot.id,
                        storeID: storeID,
                        productID: snapshot.id,
                        name: String(
                            localized: "backup.legacy.variant.default",
                            bundle: .tinyStockCore
                        ),
                        quantity: quantity,
                        createdAt: snapshot.createdAt,
                        updatedAt: snapshot.updatedAt
                    )
                    context.insert(variant)
                    if quantity > 0 {
                        context.insert(
                            StockMovement(
                                storeID: storeID,
                                productID: snapshot.id,
                                variantID: variant.id,
                                kind: .initialStock,
                                quantityDelta: quantity,
                                balanceAfter: quantity,
                                createdAt: snapshot.createdAt
                            )
                        )
                    }
                }
                for snapshot in payload.sales {
                    context.insert(migratedOrder(from: snapshot, storeID: storeID))
                }
                try saving(context)
            }
            return BackupRestoreResult(
                selectedStoreID: storeID,
                migratedLegacyBackup: true,
                summary: payload.summary
            )
        } catch {
            context.rollback()
            throw error
        }
    }

    @MainActor
    private static func deleteStoreData(storeID: UUID, in context: ModelContext) throws {
        let orders = try context.fetch(
            FetchDescriptor<SalesOrder>(predicate: #Predicate { $0.storeID == storeID })
        )
        let sales = try context.fetch(
            FetchDescriptor<Sale>(predicate: #Predicate { $0.storeID == storeID })
        )
        let movements = try context.fetch(
            FetchDescriptor<StockMovement>(predicate: #Predicate { $0.storeID == storeID })
        )
        let variants = try context.fetch(
            FetchDescriptor<ProductVariant>(predicate: #Predicate { $0.storeID == storeID })
        )
        let products = try context.fetch(
            FetchDescriptor<Product>(predicate: #Predicate { $0.storeID == storeID })
        )

        for order in orders { context.delete(order) }
        for sale in sales { context.delete(sale) }
        for movement in movements { context.delete(movement) }
        for variant in variants { context.delete(variant) }
        for product in products { context.delete(product) }
    }

    private static func product(
        from snapshot: BackupPayload.ProductSnapshot,
        storeID: UUID
    ) -> Product {
        Product(
            id: snapshot.id,
            storeID: storeID,
            name: snapshot.name,
            category: snapshot.category,
            quantity: snapshot.quantity,
            minimumStock: snapshot.minimumStock,
            costPrice: snapshot.costPrice,
            salePrice: snapshot.salePrice,
            imageData: snapshot.imageData,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt
        )
    }

    private static func migratedOrder(
        from snapshot: BackupPayload.SaleSnapshot,
        storeID: UUID
    ) -> SalesOrder {
        let channel: SalesChannel = snapshot.paymentMethod == PaymentMethod.shopee.rawValue
            ? .shopee
            : .direct
        let order = SalesOrder(
            id: snapshot.id,
            storeID: storeID,
            channel: channel,
            fulfillment: .readyStock,
            status: .completed,
            orderedAt: snapshot.date,
            shippingDueAt: snapshot.date,
            note: snapshot.note,
            channelFeePercentage: snapshot.channelFeePercentage,
            channelFeeAmount: snapshot.channelFeeAmount,
            createdAt: snapshot.date,
            updatedAt: snapshot.date
        )
        order.shippedAt = snapshot.date
        order.completedAt = snapshot.date
        order.items = snapshot.items.enumerated().map { position, item in
            let restored = SalesOrderItem(
                id: item.id,
                storeID: storeID,
                productID: item.productID,
                variantID: item.productID,
                productName: item.productName,
                variantName: String(
                    localized: "backup.legacy.variant.default",
                    bundle: .tinyStockCore
                ),
                unitPrice: item.unitPrice,
                unitCost: item.unitCost,
                quantity: item.quantity,
                position: position
            )
            restored.order = order
            return restored
        }
        return order
    }
}
