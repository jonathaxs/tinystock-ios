// Proposito: Validar o destino de um lembrete antes de abrir loja e pedido.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-07.

import Foundation
import SwiftData

public struct OrderReminderRoute: Hashable, Identifiable, Sendable {
    public let id: UUID
    public let storeID: UUID
    public let orderID: UUID

    public init?(identifier: String, userInfo: [AnyHashable: Any]) {
        guard identifier.hasPrefix(OrderReminder.identifierPrefix) else { return nil }
        let parts = identifier.dropFirst(OrderReminder.identifierPrefix.count).split(separator: ".")
        guard parts.count == 4,
              let storeID = UUID(uuidString: String(parts[0])),
              let orderID = UUID(uuidString: String(parts[1])),
              OrderReminder.Kind(rawValue: String(parts[2])) != nil,
              OrderReminder.Timing(rawValue: String(parts[3])) != nil,
              userInfo["storeID"] as? String == storeID.uuidString,
              userInfo["orderID"] as? String == orderID.uuidString,
              userInfo["reminderKind"] as? String == String(parts[2]) else { return nil }
        id = UUID()
        self.storeID = storeID
        self.orderID = orderID
    }

    @MainActor
    public func resolve(in context: ModelContext) throws -> (store: StoreProfile, order: SalesOrder)? {
        let storeID = storeID
        let orderID = orderID
        guard let store = try context.fetch(FetchDescriptor<StoreProfile>(predicate: #Predicate {
            $0.id == storeID && !$0.isArchived
        })).first,
              let order = try context.fetch(FetchDescriptor<SalesOrder>(predicate: #Predicate {
                  $0.id == orderID && $0.storeID == storeID
              })).first else { return nil }
        return (store, order)
    }
}
