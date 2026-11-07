// Propósito: Expor as operações de exportação e restauração do backup JSON.
// Created by Jonathas Motta (@jonathaxs) on 2026-08-16.

import Foundation
import SwiftData

public enum BackupError: Error, Equatable, Sendable {
    case invalidFile
    case unsupportedVersion(Int)
}

extension BackupError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidFile:
            String(localized: "backup.error.invalidFile", bundle: .tinyStockCore)
        case .unsupportedVersion:
            String(localized: "backup.error.unsupportedVersion", bundle: .tinyStockCore)
        }
    }
}

public enum BackupManager {
    public static let currentVersion = 2

    // MARK: - Exportação

    @MainActor
    public static func export(
        from context: ModelContext,
        selectedStoreID: UUID,
        exportedAt: Date = Date()
    ) throws -> Data {
        // Um contexto próprio evita incluir rascunhos ainda não salvos pela interface.
        let snapshotContext = ModelContext(context.container)
        snapshotContext.autosaveEnabled = false
        let stores = try snapshotContext.fetch(FetchDescriptor<StoreProfile>())
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let products = try snapshotContext.fetch(FetchDescriptor<Product>())
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let variants = try snapshotContext.fetch(FetchDescriptor<ProductVariant>())
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let movements = try snapshotContext.fetch(FetchDescriptor<StockMovement>())
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let orders = try snapshotContext.fetch(FetchDescriptor<SalesOrder>())
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let activeStores = stores.filter(\.isActive)
        guard let selectedID = activeStores.first(where: { $0.id == selectedStoreID })?.id
            ?? activeStores.first?.id else {
            throw BackupError.invalidFile
        }

        let payload = BackupPayload(
            version: currentVersion,
            exportedAt: exportedAt,
            products: products.map(productSnapshot),
            sales: [],
            selectedStoreID: selectedID,
            stores: stores.map(storeSnapshot),
            variants: variants.map(variantSnapshot),
            stockMovements: movements.map(movementSnapshot),
            orders: orders.map(orderSnapshot)
        )
        guard isValidV2(payload) else { throw BackupError.invalidFile }
        return try encode(payload)
    }

    // MARK: - Decodificação

    @MainActor
    public static func decode(_ data: Data) throws -> BackupPayload {
        let payload: BackupPayload
        do {
            payload = try decoder().decode(BackupPayload.self, from: data)
        } catch {
            throw BackupError.invalidFile
        }

        switch payload.version {
        case 1:
            guard isValidV1(payload) else { throw BackupError.invalidFile }
        case currentVersion:
            guard isValidV2(payload) else { throw BackupError.invalidFile }
        default:
            throw BackupError.unsupportedVersion(payload.version)
        }
        return payload
    }

    // MARK: - Restauração

    @MainActor
    @discardableResult
    public static func apply(
        _ payload: BackupPayload,
        into context: ModelContext,
        storeID: UUID = StoreScope.unassignedStoreID
    ) throws -> BackupRestoreResult {
        try apply(payload, into: context, storeID: storeID, saving: { try $0.save() })
    }

    @MainActor
    static func apply(
        _ payload: BackupPayload,
        into context: ModelContext,
        storeID: UUID,
        saving: (ModelContext) throws -> Void
    ) throws -> BackupRestoreResult {
        switch payload.version {
        case 1 where isValidV1(payload):
            return try restoreV1(payload, into: context, storeID: storeID, saving: saving)
        case currentVersion where isValidV2(payload):
            return try restoreV2(payload, into: context, saving: saving)
        case 1, currentVersion:
            throw BackupError.invalidFile
        default:
            throw BackupError.unsupportedVersion(payload.version)
        }
    }

    public static func suggestedFilename(relativeTo date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return "tinystock-backup-\(formatter.string(from: date)).json"
    }
}
