// Proposito: Excluir uma loja e todos os dados associados com validacao previa.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-11.

import Foundation
import SwiftData

public struct StoreDeletionSummary: Equatable, Sendable {
    public let productCount: Int
    public let variantCount: Int
    public let stockMovementCount: Int
    public let orderCount: Int

    public init(
        productCount: Int,
        variantCount: Int,
        stockMovementCount: Int,
        orderCount: Int
    ) {
        self.productCount = productCount
        self.variantCount = variantCount
        self.stockMovementCount = stockMovementCount
        self.orderCount = orderCount
    }
}

public extension StoreProfileService {

    static var trashRetentionDays: Int { 30 }

    /// Move para a lixeira sem remover os dados e guarda o estado anterior para restauracao.
    @MainActor
    static func moveToTrash(
        _ store: StoreProfile,
        date: Date = Date(),
        in context: ModelContext
    ) throws {
        guard !store.isTrashed else { return }
        if store.isActive {
            let storeID = store.id
            let remainingActiveCount = try context.fetchCount(
                FetchDescriptor<StoreProfile>(predicate: #Predicate {
                    !$0.isArchived && $0.trashedAt == nil && $0.id != storeID
                })
            )
            guard remainingActiveCount > 0 else { throw StoreProfileError.lastActiveStore }
        }

        store.wasArchivedBeforeTrash = store.isArchived
        store.isArchived = true
        store.trashedAt = date
        store.updatedAt = date
    }

    /// Restaura para ativa ou arquivada, conforme o estado anterior a lixeira.
    static func restoreFromTrash(
        _ store: StoreProfile,
        date: Date = Date()
    ) throws {
        guard store.isTrashed else { throw StoreProfileError.storeNotInTrash }

        let restoreAsArchived = store.wasArchivedBeforeTrash
        store.isArchived = restoreAsArchived
        store.archivedAt = restoreAsArchived ? (store.archivedAt ?? date) : nil
        store.trashedAt = nil
        store.wasArchivedBeforeTrash = false
        store.updatedAt = date
    }

    static func trashExpirationDate(
        for store: StoreProfile,
        calendar: Calendar = .current
    ) -> Date? {
        guard let trashedAt = store.trashedAt else { return nil }
        return calendar.date(byAdding: .day, value: trashRetentionDays, to: trashedAt)
    }

    /// Remove em lote somente lojas que completaram o prazo na lixeira.
    @MainActor
    @discardableResult
    static func purgeExpiredTrash(
        asOf date: Date = Date(),
        calendar: Calendar = .current,
        in context: ModelContext
    ) throws -> Int {
        let stores = try context.fetch(
            FetchDescriptor<StoreProfile>(predicate: #Predicate { $0.trashedAt != nil })
        )
        let expired = stores.filter {
            guard let expiration = trashExpirationDate(for: $0, calendar: calendar) else { return false }
            return expiration <= date
        }
        for store in expired {
            try deletePermanently(store, date: date, in: context)
        }
        return expired.count
    }

    /// Calcula o impacto antes de apresentar a confirmacao ao usuario.
    @MainActor
    static func deletionSummary(
        for store: StoreProfile,
        in context: ModelContext
    ) throws -> StoreDeletionSummary {
        try validateDeletion(of: store, in: context)
        let storeID = store.id

        let products = try context.fetchCount(
            FetchDescriptor<Product>(predicate: #Predicate { $0.storeID == storeID })
        )
        let variants = try context.fetchCount(
            FetchDescriptor<ProductVariant>(predicate: #Predicate { $0.storeID == storeID })
        )
        let movements = try context.fetchCount(
            FetchDescriptor<StockMovement>(predicate: #Predicate { $0.storeID == storeID })
        )
        let orders = try context.fetchCount(
            FetchDescriptor<SalesOrder>(predicate: #Predicate { $0.storeID == storeID })
        )
        let legacySales = try context.fetchCount(
            FetchDescriptor<Sale>(predicate: #Predicate { $0.storeID == storeID })
        )

        return StoreDeletionSummary(
            productCount: products,
            variantCount: variants,
            stockMovementCount: movements,
            orderCount: orders + legacySales
        )
    }

    /// Exclui o escopo completo. O chamador salva ou desfaz o contexto ao terminar.
    @MainActor
    @discardableResult
    static func deletePermanently(
        _ store: StoreProfile,
        date: Date = Date(),
        in context: ModelContext
    ) throws -> StoreProfile? {
        guard store.isTrashed else { throw StoreProfileError.storeNotInTrash }
        let stores = try context.fetch(FetchDescriptor<StoreProfile>())
        let remainingActiveStores = orderedForDisplay(
            stores.filter { $0.id != store.id && $0.isActive }
        )
        guard !remainingActiveStores.isEmpty else { throw StoreProfileError.lastActiveStore }

        let deletedStoreID = store.id
        try deleteData(storeID: deletedStoreID, in: context)
        context.delete(store)

        // A identidade inicial precisa continuar existindo para a reconciliacao entre dispositivos.
        if deletedStoreID == StoreScope.primaryStoreID,
           let replacement = remainingActiveStores.first {
            let previousID = replacement.id
            try remapStoreScope(from: previousID, to: StoreScope.primaryStoreID, in: context)
            replacement.id = StoreScope.primaryStoreID
            replacement.updatedAt = date
        }

        try setDisplayOrder(remainingActiveStores, date: date)
        return remainingActiveStores.first
    }

    @MainActor
    private static func validateDeletion(
        of store: StoreProfile,
        in context: ModelContext
    ) throws {
        guard store.isTrashed else { throw StoreProfileError.storeNotInTrash }
        let remainingActiveCount = try context.fetchCount(
            FetchDescriptor<StoreProfile>(predicate: #Predicate {
                !$0.isArchived && $0.trashedAt == nil
            })
        )
        guard remainingActiveCount > 0 else { throw StoreProfileError.lastActiveStore }
    }

    @MainActor
    private static func deleteData(storeID: UUID, in context: ModelContext) throws {
        let orderItems = try context.fetch(
            FetchDescriptor<SalesOrderItem>(predicate: #Predicate { $0.storeID == storeID })
        )
        let orders = try context.fetch(
            FetchDescriptor<SalesOrder>(predicate: #Predicate { $0.storeID == storeID })
        )
        let legacySales = try context.fetch(
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

        for item in orderItems { context.delete(item) }
        for order in orders { context.delete(order) }
        for sale in legacySales { context.delete(sale) }
        for movement in movements { context.delete(movement) }
        for variant in variants { context.delete(variant) }
        for product in products { context.delete(product) }
    }
}
