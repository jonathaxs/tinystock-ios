// Proposito: Representar preferencias e lembretes locais sem referencias ao SwiftData.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-07.

import Foundation

public struct OrderReminderSettings: Codable, Equatable, Sendable {
    public var isEnabled = false
    public var productionEnabled = true
    public var shippingEnabled = true
    public var dayBeforeEnabled = true
    public var dueDayEnabled = true
    public var overdueEnabled = true
    public var soundEnabled = true
    public var hour = 9
    public var minute = 0

    public init() {}

    public var hasValidTime: Bool { (0...23).contains(hour) && (0...59).contains(minute) }
}

public enum OrderReminderError: Error, Equatable, Sendable {
    case invalidTime
}

public struct OrderReminder: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable { case production, shipping }
    public enum Timing: String, Codable, Sendable { case dayBefore, dueDay, overdue }

    // O prefixo delimita somente os lembretes de pedidos, inclusive entre versoes do servico.
    public static let identifierPrefix = "tinystock.order-reminder."
    public let storeID: UUID
    public let orderID: UUID
    public let kind: Kind
    public let timing: Timing
    public let fireDate: Date
    public let title: String
    public let body: String
    public let soundEnabled: Bool

    public var id: String {
        Self.identifierPrefix + "\(storeID.uuidString).\(orderID.uuidString).\(kind.rawValue).\(timing.rawValue)"
    }

    /// Compara data, texto e som para evitar reagendamentos desnecessarios.
    public func signature() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self).base64EncodedString()
    }
}
