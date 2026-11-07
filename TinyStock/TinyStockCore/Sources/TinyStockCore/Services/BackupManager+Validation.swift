// Propósito: Validar a integridade e configurar a codificação dos backups JSON.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-12.

import Foundation

extension BackupManager {
    static func isValidV1(_ payload: BackupPayload) -> Bool {
        guard payload.version == 1,
              payload.stores.isEmpty,
              payload.variants.isEmpty,
              payload.stockMovements.isEmpty,
              payload.orders.isEmpty,
              payload.exportedAt.timeIntervalSinceReferenceDate.isFinite else {
            return false
        }
        let itemIDs = payload.sales.flatMap(\.items).map(\.id)
        return hasUniqueIDs(payload.products.map(\.id))
            && hasUniqueIDs(payload.sales.map(\.id))
            && hasUniqueIDs(itemIDs)
            && payload.products.allSatisfy {
                valid($0.createdAt, $0.updatedAt) && valid($0.costPrice, $0.salePrice)
            }
            && payload.sales.allSatisfy { sale in
                sale.date.timeIntervalSinceReferenceDate.isFinite
                    && valid(sale.channelFeePercentage, sale.channelFeeAmount)
                    && sale.items.allSatisfy {
                        $0.quantity > 0 && valid($0.unitPrice, $0.unitCost)
                    }
            }
    }

    static func isValidV2(_ payload: BackupPayload) -> Bool {
        guard payload.version == currentVersion,
              payload.sales.isEmpty,
              payload.exportedAt.timeIntervalSinceReferenceDate.isFinite,
              !payload.stores.isEmpty else {
            return false
        }

        let storeIDs = Set(payload.stores.map(\.id))
        let activeIDs = Set(payload.stores.filter {
            !$0.isArchived && $0.trashedAt == nil
        }.map(\.id))
        guard hasUniqueIDs(payload.stores.map(\.id)),
              !activeIDs.isEmpty,
              let selectedStoreID = payload.selectedStoreID,
              activeIDs.contains(selectedStoreID),
              !storeIDs.contains(StoreScope.unassignedStoreID),
              payload.stores.allSatisfy({
                  $0.sortOrder >= 0
                      && valid($0.createdAt, $0.updatedAt)
                      && $0.archivedAt?.timeIntervalSinceReferenceDate.isFinite != false
                      && $0.trashedAt?.timeIntervalSinceReferenceDate.isFinite != false
                      && ($0.trashedAt == nil || $0.isArchived)
                      && ($0.trashedAt != nil || !$0.wasArchivedBeforeTrash)
              }) else {
            return false
        }

        guard hasUniqueIDs(payload.products.map(\.id)) else { return false }
        let productsByID = Dictionary(uniqueKeysWithValues: payload.products.map { ($0.id, $0) })
        guard payload.products.allSatisfy({ snapshot in
            guard let storeID = snapshot.storeID else { return false }
            return storeIDs.contains(storeID)
                && valid(snapshot.createdAt, snapshot.updatedAt)
                && valid(snapshot.costPrice, snapshot.salePrice)
        }) else {
            return false
        }

        guard hasUniqueIDs(payload.variants.map(\.id)) else { return false }
        let variantsByID = Dictionary(uniqueKeysWithValues: payload.variants.map { ($0.id, $0) })
        guard payload.variants.allSatisfy({ snapshot in
            snapshot.quantity >= 0
                && productsByID[snapshot.productID]?.storeID == snapshot.storeID
                && valid(snapshot.createdAt, snapshot.updatedAt)
        }) else {
            return false
        }
        let variantsByProduct = Dictionary(grouping: payload.variants, by: \.productID)
        guard variantsByProduct.values.allSatisfy({ variants in
            let defaults = variants.filter(\.isDefault)
            return defaults.isEmpty || (defaults.count == 1 && variants.count == 1)
        }) else {
            return false
        }

        let movementIDs = Set(payload.stockMovements.map(\.id))
        guard movementIDs.count == payload.stockMovements.count,
              payload.stockMovements.allSatisfy({ snapshot in
                  productsByID[snapshot.productID]?.storeID == snapshot.storeID
                      && variantsByID[snapshot.variantID]?.productID == snapshot.productID
                      && variantsByID[snapshot.variantID]?.storeID == snapshot.storeID
                      && snapshot.createdAt.timeIntervalSinceReferenceDate.isFinite
                      && snapshot.reversedAt?.timeIntervalSinceReferenceDate.isFinite != false
                      && snapshot.reversedMovementID.map {
                          $0 != snapshot.id && movementIDs.contains($0)
                      } != false
              }) else {
            return false
        }

        let itemIDs = payload.orders.flatMap(\.items).map(\.id)
        return hasUniqueIDs(payload.orders.map(\.id))
            && hasUniqueIDs(itemIDs)
            && payload.orders.allSatisfy { order in
                storeIDs.contains(order.storeID)
                    && validOrderDates(order)
                    && valid(order.channelFeePercentage, order.channelFeeAmount)
                    && order.items.allSatisfy {
                        $0.storeID == order.storeID
                            && $0.quantity > 0
                            && valid($0.unitPrice, $0.unitCost)
                    }
            }
    }

    static func encode(_ payload: BackupPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.timeIntervalSince1970)
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let seconds = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: seconds)
            }

            let value = try container.decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: value) {
                return date
            }

            let standard = ISO8601DateFormatter()
            guard let date = standard.date(from: value) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date"
                )
            }
            return date
        }
        return decoder
    }

    private static func validOrderDates(_ order: BackupPayload.SalesOrderSnapshot) -> Bool {
        let dates = [order.orderedAt, order.createdAt, order.updatedAt]
        let optionalDates = [
            order.productionDueAt,
            order.shippingDueAt,
            order.productionStartedAt,
            order.producedAt,
            order.shippedAt,
            order.completedAt,
            order.cancelledAt
        ]
        return dates.allSatisfy { $0.timeIntervalSinceReferenceDate.isFinite }
            && optionalDates.allSatisfy {
                $0?.timeIntervalSinceReferenceDate.isFinite != false
            }
    }

    private static func valid(_ values: Decimal...) -> Bool {
        values.allSatisfy { !$0.isNaN }
    }

    private static func valid(_ dates: Date...) -> Bool {
        dates.allSatisfy { $0.timeIntervalSinceReferenceDate.isFinite }
    }

    private static func hasUniqueIDs(_ values: [UUID]) -> Bool {
        Set(values).count == values.count
    }
}
