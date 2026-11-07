// Proposito: Coordenar preferencias, permissao e atualizacao dos lembretes do app.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-07.

import Foundation
import Observation
import SwiftData

@MainActor
public struct OrderReminderSnapshot {
    public let orders: [SalesOrder]
    public let stores: [StoreProfile]
    private let context: ModelContext?

    public init(orders: [SalesOrder], stores: [StoreProfile]) {
        self.orders = orders
        self.stores = stores
        context = nil
    }

    public init(container: ModelContainer) throws {
        // Um contexto novo le somente dados persistidos e permanece vivo durante o planejamento.
        let context = ModelContext(container)
        context.autosaveEnabled = false
        stores = try context.fetch(FetchDescriptor<StoreProfile>())
        orders = try context.fetch(FetchDescriptor<SalesOrder>())
        self.context = context
    }
}

public enum OrderReminderIssue: Sendable {
    case preferences, permission, dataRead, scheduling

    public var localizedMessage: String {
        switch self {
        case .preferences: String(localized: "notifications.error.preferences", bundle: .tinyStockCore)
        case .permission: String(localized: "notifications.error.permission", bundle: .tinyStockCore)
        case .dataRead: String(localized: "notifications.error.data", bundle: .tinyStockCore)
        case .scheduling: String(localized: "notifications.error.scheduling", bundle: .tinyStockCore)
        }
    }
}

@MainActor
@Observable
public final class OrderReminderCoordinator {
    public private(set) var settings: OrderReminderSettings
    public private(set) var authorization: OrderReminderAuthorization = .unknown
    public private(set) var issue: OrderReminderIssue?
    public private(set) var scheduledCount = 0
    public private(set) var deferredCount = 0
    public private(set) var failedCount = 0
    public private(set) var isSynchronizing = false
    public private(set) var isRequestingPermission = false

    @ObservationIgnored private let service: OrderReminderService
    @ObservationIgnored private let settingsStore: OrderReminderSettingsStore
    @ObservationIgnored private let loadSnapshot: () throws -> OrderReminderSnapshot
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: () -> Calendar
    @ObservationIgnored private var refreshRequested = false

    public init(
        service: OrderReminderService, settingsStore: OrderReminderSettingsStore = .init(),
        now: @escaping () -> Date = Date.init, calendar: @escaping () -> Calendar = { .current },
        loadSnapshot: @escaping () throws -> OrderReminderSnapshot
    ) {
        self.service = service
        self.settingsStore = settingsStore
        self.loadSnapshot = loadSnapshot
        self.now = now
        self.calendar = calendar
        do { settings = try settingsStore.load() }
        catch {
            settings = .init()
            issue = .preferences
        }
    }

    public func setEnabled(_ enabled: Bool) async {
        var updated = settings
        updated.isEnabled = enabled
        guard persist(updated) else { return }
        if enabled && !isRequestingPermission {
            isRequestingPermission = true
            authorization = await service.authorization()
            if authorization == .notDetermined {
                do { _ = try await service.requestAuthorization() }
                catch { issue = .permission }
            }
            isRequestingPermission = false
        }
        await refresh()
    }

    public func update(_ settings: OrderReminderSettings) async {
        guard persist(settings) else { return }
        await refresh()
    }

    /// Atualizacoes durante um await provocam uma nova leitura ao terminar, sem perder o ultimo save.
    public func refresh() async {
        refreshRequested = true
        guard !isSynchronizing else { return }
        isSynchronizing = true
        defer { isSynchronizing = false }

        repeat {
            refreshRequested = false
            let snapshot: OrderReminderSnapshot
            do {
                snapshot = settings.isEnabled ? try loadSnapshot() : .init(orders: [], stores: [])
            } catch {
                issue = .dataRead
                authorization = await service.authorization()
                continue
            }

            do {
                let result = try await service.synchronize(
                    orders: snapshot.orders, stores: snapshot.stores, settings: settings,
                    now: now(), calendar: calendar()
                )
                authorization = result.authorization
                scheduledCount = result.scheduledIDs.count
                deferredCount = result.deferredIDs.count
                failedCount = result.failedIDs.count
                if failedCount > 0 { issue = .scheduling }
                else if issue == .dataRead || issue == .scheduling { issue = nil }
            } catch { issue = .scheduling }
        } while refreshRequested
    }

    private func persist(_ settings: OrderReminderSettings) -> Bool {
        do {
            try settingsStore.save(settings)
            self.settings = settings
            issue = nil
            return true
        } catch {
            issue = .preferences
            return false
        }
    }
}
