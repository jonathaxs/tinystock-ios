// Propósito: Converter models persistidos em retratos serializáveis do backup.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-12.

extension BackupManager {
    static func storeSnapshot(_ value: StoreProfile) -> BackupPayload.StoreSnapshot {
        .init(
            id: value.id,
            name: value.name,
            imageData: value.imageData,
            isArchived: value.isArchived,
            sortOrder: value.sortOrder,
            createdAt: value.createdAt,
            updatedAt: value.updatedAt
        )
    }

    static func productSnapshot(_ value: Product) -> BackupPayload.ProductSnapshot {
        .init(
            id: value.id,
            name: value.name,
            category: value.category,
            quantity: value.quantity,
            minimumStock: value.minimumStock,
            costPrice: value.costPrice,
            salePrice: value.salePrice,
            imageData: value.imageData,
            createdAt: value.createdAt,
            updatedAt: value.updatedAt,
            storeID: value.storeID
        )
    }

    static func variantSnapshot(
        _ value: ProductVariant
    ) -> BackupPayload.ProductVariantSnapshot {
        .init(
            id: value.id,
            storeID: value.storeID,
            productID: value.productID,
            name: value.name,
            isDefault: value.isDefault,
            quantity: value.quantity,
            createdAt: value.createdAt,
            updatedAt: value.updatedAt
        )
    }

    static func movementSnapshot(
        _ value: StockMovement
    ) -> BackupPayload.StockMovementSnapshot {
        .init(
            id: value.id,
            storeID: value.storeID,
            productID: value.productID,
            variantID: value.variantID,
            kind: value.kindRawValue,
            quantityDelta: value.quantityDelta,
            balanceAfter: value.balanceAfter,
            note: value.note,
            referenceID: value.referenceID,
            reversedMovementID: value.reversedMovementID,
            reversedAt: value.reversedAt,
            createdAt: value.createdAt
        )
    }

    static func orderSnapshot(_ value: SalesOrder) -> BackupPayload.SalesOrderSnapshot {
        .init(
            id: value.id,
            storeID: value.storeID,
            channel: value.channelRawValue,
            customChannelName: value.customChannelName,
            fulfillment: value.fulfillmentRawValue,
            status: value.statusRawValue,
            buyerName: value.buyerName,
            externalReference: value.externalReference,
            orderedAt: value.orderedAt,
            productionDueAt: value.productionDueAt,
            shippingDueAt: value.shippingDueAt,
            productionStartedAt: value.productionStartedAt,
            producedAt: value.producedAt,
            shippedAt: value.shippedAt,
            completedAt: value.completedAt,
            cancelledAt: value.cancelledAt,
            cancellationReason: value.cancellationReason,
            trackingCode: value.trackingCode,
            note: value.note,
            channelFeePercentage: value.channelFeePercentage,
            channelFeeAmount: value.channelFeeAmount,
            createdAt: value.createdAt,
            updatedAt: value.updatedAt,
            items: value.itemList.map {
                .init(
                    id: $0.id,
                    storeID: $0.storeID,
                    productID: $0.productID,
                    variantID: $0.variantID,
                    productName: $0.productName,
                    variantName: $0.variantName,
                    unitPrice: $0.unitPrice,
                    unitCost: $0.unitCost,
                    quantity: $0.quantity,
                    position: $0.position
                )
            }
        )
    }
}
