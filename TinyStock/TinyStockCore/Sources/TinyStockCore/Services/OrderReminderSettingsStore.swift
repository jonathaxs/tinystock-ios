// Proposito: Persistir as preferencias de notificacao deste dispositivo.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-07.

import Foundation

@MainActor
public final class OrderReminderSettingsStore {
    public static let key = "notifications.orderReminders.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() throws -> OrderReminderSettings {
        guard let data = defaults.data(forKey: Self.key) else { return .init() }
        let settings = try JSONDecoder().decode(OrderReminderSettings.self, from: data)
        guard settings.hasValidTime else { throw OrderReminderError.invalidTime }
        return settings
    }

    public func save(_ settings: OrderReminderSettings) throws {
        guard settings.hasValidTime else { throw OrderReminderError.invalidTime }
        defaults.set(try JSONEncoder().encode(settings), forKey: Self.key)
    }
}
