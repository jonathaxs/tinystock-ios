// ⌘
//  TinyStockCore/Services/StoreProfileService.swift
//
//  Propósito: Centralizar criação, edição e arquivamento seguro das lojas.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-24.
// ⌘

import Foundation
import SwiftData

// MARK: - Erros

public enum StoreProfileError: Error, Equatable, Sendable {
    case emptyName
    case duplicateName
    case lastActiveStore
    case archivedStore
    case trashedStore
    case storeNotInTrash
}

public extension StoreProfileError {

    var localizedMessage: String {
        switch self {
        case .emptyName:
            String(localized: "store.error.emptyName", bundle: .tinyStockCore)
        case .duplicateName:
            String(localized: "store.error.duplicateName", bundle: .tinyStockCore)
        case .lastActiveStore:
            String(localized: "store.error.lastActiveStore", bundle: .tinyStockCore)
        case .archivedStore:
            String(localized: "store.error.archivedStore", bundle: .tinyStockCore)
        case .trashedStore:
            String(localized: "store.error.trashedStore", bundle: .tinyStockCore)
        case .storeNotInTrash:
            String(localized: "store.error.storeNotInTrash", bundle: .tinyStockCore)
        }
    }
}

// MARK: - Serviço

public enum StoreProfileService {

    /// Nome usado na primeira execução. O valor fica salvo e depois pode ser editado.
    public static var localizedDefaultName: String {
        String(localized: "store.default.name", bundle: .tinyStockCore)
    }

    /// Cria uma loja depois de normalizar e validar o nome.
    @discardableResult
    public static func create(
        name: String,
        imageData: Data? = nil,
        in context: ModelContext
    ) throws -> StoreProfile {
        let cleanName = sanitized(name)
        guard !cleanName.isEmpty else { throw StoreProfileError.emptyName }
        guard try !contains(name: cleanName, in: context) else {
            throw StoreProfileError.duplicateName
        }

        let existingStores = try context.fetch(FetchDescriptor<StoreProfile>())
        let store = StoreProfile(
            name: cleanName,
            imageData: imageData,
            sortOrder: nextSortOrder(after: existingStores)
        )
        context.insert(store)
        return store
    }

    /// Devolve uma loja ativa existente ou cria a loja inicial uma única vez.
    @discardableResult
    public static func ensureDefaultStore(
        name: String? = nil,
        in context: ModelContext
    ) throws -> StoreProfile {
        let descriptor = FetchDescriptor<StoreProfile>(
            predicate: #Predicate { !$0.isArchived && $0.trashedAt == nil },
            sortBy: [
                SortDescriptor(\StoreProfile.sortOrder),
                SortDescriptor(\StoreProfile.createdAt)
            ]
        )

        if let existing = try context.fetch(descriptor).first {
            return existing
        }

        // Um backup inconsistente pode chegar só com lojas arquivadas. Reativar a mais
        // antiga preserva os dados e evita criar outra loja com o mesmo nome.
        var archivedDescriptor = FetchDescriptor<StoreProfile>(
            predicate: #Predicate { $0.isArchived && $0.trashedAt == nil },
            sortBy: [SortDescriptor(\StoreProfile.archivedAt, order: .reverse),
                     SortDescriptor(\StoreProfile.updatedAt, order: .reverse)]
        )
        archivedDescriptor.fetchLimit = 1

        if let archived = try context.fetch(archivedDescriptor).first {
            archived.isArchived = false
            archived.archivedAt = nil
            archived.updatedAt = Date()
            return archived
        }

        var trashDescriptor = FetchDescriptor<StoreProfile>(
            predicate: #Predicate { $0.trashedAt != nil },
            sortBy: [SortDescriptor(\StoreProfile.trashedAt, order: .reverse)]
        )
        trashDescriptor.fetchLimit = 1
        if let trashed = try context.fetch(trashDescriptor).first {
            trashed.isArchived = false
            trashed.archivedAt = nil
            trashed.trashedAt = nil
            trashed.wasArchivedBeforeTrash = false
            trashed.updatedAt = Date()
            return trashed
        }

        let store = StoreProfile(
            id: StoreScope.primaryStoreID,
            name: name ?? localizedDefaultName
        )
        context.insert(store)
        return store
    }

    /// Prepara bancos criados antes do CloudKit, quando a primeira loja ainda tinha UUID aleatorio.
    /// Somente a loja mais antiga muda de identidade; todas as referencias de escopo acompanham.
    @discardableResult
    public static func prepareForCloudSync(
        preferredStoreID: UUID? = nil,
        in context: ModelContext
    ) throws -> StoreProfile {
        let stores = try context.fetch(
            FetchDescriptor<StoreProfile>(sortBy: [SortDescriptor(\StoreProfile.createdAt)])
        )

        if stores.isEmpty {
            return try ensureDefaultStore(in: context)
        }

        if !stores.contains(where: { $0.id == StoreScope.primaryStoreID }),
           let initialStore = stores.first {
            let previousID = initialStore.id
            try remapStoreScope(from: previousID, to: StoreScope.primaryStoreID, in: context)
            initialStore.id = StoreScope.primaryStoreID
        }

        return try reconcileCloudStores(preferredStoreID: preferredStoreID, in: context)
    }

    /// Consolida copias da loja inicial e devolve uma selecao ativa depois de uma importacao remota.
    @discardableResult
    public static func reconcileCloudStores(
        preferredStoreID: UUID? = nil,
        in context: ModelContext
    ) throws -> StoreProfile {
        var stores = try context.fetch(
            FetchDescriptor<StoreProfile>(sortBy: [SortDescriptor(\StoreProfile.createdAt)])
        )
        let primaryCopies = stores.filter { $0.id == StoreScope.primaryStoreID }

        if let canonical = primaryCopies.first {
            let newest = primaryCopies.max { $0.updatedAt < $1.updatedAt } ?? canonical
            canonical.name = newest.name
            canonical.imageData = newest.imageData
            canonical.isArchived = newest.isArchived
            canonical.archivedAt = newest.archivedAt
            canonical.trashedAt = newest.trashedAt
            canonical.wasArchivedBeforeTrash = newest.wasArchivedBeforeTrash
            canonical.sortOrder = newest.sortOrder
            canonical.updatedAt = newest.updatedAt

            for duplicate in primaryCopies.dropFirst() {
                context.delete(duplicate)
            }
        }

        stores = try context.fetch(
            FetchDescriptor<StoreProfile>(sortBy: [SortDescriptor(\StoreProfile.createdAt)])
        )
        stores = orderedForDisplay(stores)
        if stores.isEmpty {
            let created = try ensureDefaultStore(in: context)
            return created
        }

        if let preferredStoreID,
           let preferred = stores.first(where: { $0.id == preferredStoreID && $0.isActive }) {
            return preferred
        }
        if let active = stores.first(where: \.isActive) {
            return active
        }

        // Mantem o app utilizavel se uma importacao remota deixar todas as lojas inativas.
        let recovered = orderedArchivedForDisplay(stores).first
            ?? orderedTrashedForDisplay(stores).first
            ?? stores[0]
        recovered.isArchived = false
        recovered.archivedAt = nil
        recovered.trashedAt = nil
        recovered.wasArchivedBeforeTrash = false
        recovered.updatedAt = Date()
        return recovered
    }

    /// Atualiza os dados sem alterar a data original de criação.
    public static func update(
        _ store: StoreProfile,
        name: String,
        imageData: Data?,
        date: Date = Date(),
        in context: ModelContext
    ) throws {
        guard !store.isTrashed else { throw StoreProfileError.trashedStore }
        let cleanName = sanitized(name)
        guard !cleanName.isEmpty else { throw StoreProfileError.emptyName }
        guard try !contains(name: cleanName, excluding: store.id, in: context) else {
            throw StoreProfileError.duplicateName
        }

        store.name = cleanName
        store.imageData = imageData
        store.updatedAt = date
    }

    /// Arquiva sem apagar o histórico. A última loja ativa precisa permanecer disponível.
    public static func archive(
        _ store: StoreProfile,
        date: Date = Date(),
        in context: ModelContext
    ) throws {
        guard !store.isTrashed else { throw StoreProfileError.trashedStore }
        guard !store.isArchived else { return }

        let activeStores = try context.fetch(
            FetchDescriptor<StoreProfile>(predicate: #Predicate {
                !$0.isArchived && $0.trashedAt == nil
            })
        )
        guard activeStores.count > 1 else { throw StoreProfileError.lastActiveStore }

        store.isArchived = true
        store.archivedAt = date
        store.updatedAt = date
    }

    /// Traz uma loja arquivada de volta sem alterar seus produtos ou histórico.
    public static func restore(
        _ store: StoreProfile,
        date: Date = Date()
    ) {
        guard store.isArchived, !store.isTrashed else { return }

        store.isArchived = false
        store.archivedAt = nil
        store.updatedAt = date
    }

    /// Ordena com desempate deterministico para bancos anteriores ao campo de posicao.
    public static func orderedForDisplay(_ stores: [StoreProfile]) -> [StoreProfile] {
        stores.sorted { left, right in
            if left.sortOrder != right.sortOrder {
                return left.sortOrder < right.sortOrder
            }
            if left.createdAt != right.createdAt {
                return left.createdAt < right.createdAt
            }
            return left.id.uuidString < right.id.uuidString
        }
    }

    /// Arquivadas e itens da lixeira usam a data da acao, sem depender da ordem manual.
    public static func orderedArchivedForDisplay(_ stores: [StoreProfile]) -> [StoreProfile] {
        stores.filter { $0.lifecycleState == .archived }.sorted {
            compareNewestFirst($0.archivedAt ?? $0.updatedAt, $1.archivedAt ?? $1.updatedAt,
                               leftID: $0.id, rightID: $1.id)
        }
    }

    public static func orderedTrashedForDisplay(_ stores: [StoreProfile]) -> [StoreProfile] {
        stores.filter(\.isTrashed).sorted {
            compareNewestFirst($0.trashedAt ?? $0.updatedAt, $1.trashedAt ?? $1.updatedAt,
                               leftID: $0.id, rightID: $1.id)
        }
    }

    /// Persiste a ordem completa recebida da interface sem alterar outros dados da loja.
    public static func setDisplayOrder(
        _ stores: [StoreProfile],
        date: Date = Date()
    ) throws {
        guard stores.allSatisfy(\.isActive) else {
            throw StoreProfileError.archivedStore
        }

        for (position, store) in stores.enumerated() where store.sortOrder != position {
            store.sortOrder = position
            store.updatedAt = date
        }
    }

    // MARK: - Apoio

    private static func sanitized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func nextSortOrder(after stores: [StoreProfile]) -> Int {
        guard let last = stores.map(\.sortOrder).max(), last < Int.max else {
            return stores.count
        }
        return last + 1
    }

    private static func compareNewestFirst(
        _ leftDate: Date,
        _ rightDate: Date,
        leftID: UUID,
        rightID: UUID
    ) -> Bool {
        if leftDate != rightDate { return leftDate > rightDate }
        return leftID.uuidString < rightID.uuidString
    }

    private static func contains(
        name: String,
        excluding storeID: UUID? = nil,
        in context: ModelContext
    ) throws -> Bool {
        let candidate = comparableName(name)

        return try context.fetch(FetchDescriptor<StoreProfile>()).contains {
            $0.id != storeID && comparableName($0.name) == candidate
        }
    }

    /// Evita duplicatas que diferem somente por maiúsculas ou acentos.
    private static func comparableName(_ name: String) -> String {
        sanitized(name)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "pt_BR")
            )
            .lowercased()
    }

    /// Os models usam UUIDs escalares para que a troca de identidade nao dependa de relacoes obrigatorias.
    static func remapStoreScope(
        from previousID: UUID,
        to newID: UUID,
        in context: ModelContext
    ) throws {
        for value in try context.fetch(FetchDescriptor<Product>()) where value.storeID == previousID {
            value.storeID = newID
        }
        for value in try context.fetch(FetchDescriptor<ProductVariant>()) where value.storeID == previousID {
            value.storeID = newID
        }
        for value in try context.fetch(FetchDescriptor<StockMovement>()) where value.storeID == previousID {
            value.storeID = newID
        }
        for value in try context.fetch(FetchDescriptor<SalesOrder>()) where value.storeID == previousID {
            value.storeID = newID
        }
        for value in try context.fetch(FetchDescriptor<SalesOrderItem>()) where value.storeID == previousID {
            value.storeID = newID
        }
        for value in try context.fetch(FetchDescriptor<Sale>()) where value.storeID == previousID {
            value.storeID = newID
        }
    }
}
