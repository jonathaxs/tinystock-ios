// Proposito: Reconciliar o plano completo de lembretes com as notificacoes pendentes.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-07.

import Foundation

public enum OrderReminderAuthorization: Sendable {
    case notDetermined, denied, authorized, provisional, unknown
    public var allowsScheduling: Bool { self == .authorized || self == .provisional }
}

public struct PendingOrderReminder: Sendable {
    public let id: String
    public let signature: String?

    public init(id: String, signature: String?) {
        self.id = id
        self.signature = signature
    }
}

/// Permite testar o agendamento sem solicitar permissao nem emitir alertas reais.
@MainActor
public protocol OrderReminderCenter {
    func authorization() async -> OrderReminderAuthorization
    func requestAuthorization() async throws -> Bool
    func pendingRequests() async -> [PendingOrderReminder]
    func add(_ reminder: OrderReminder) async throws
    func removePending(identifiers: [String]) async
}

public struct OrderReminderSyncResult: Sendable {
    public let authorization: OrderReminderAuthorization
    public let scheduledIDs: [String]
    public let deferredIDs: [String]
    public let failedIDs: [String]
}

@MainActor
public final class OrderReminderService {
    private let center: any OrderReminderCenter
    private var lastTask: Task<OrderReminderSyncResult, Never>?

    public init(center: any OrderReminderCenter) { self.center = center }

    public func authorization() async -> OrderReminderAuthorization { await center.authorization() }

    /// Solicitar permissao somente na acao explicita de ativar notificacoes.
    public func requestAuthorization() async throws -> Bool { try await center.requestAuthorization() }

    /// Deve receber um retrato completo de todas as lojas, apos salvar os dados com sucesso.
    /// O teto de 60 e uma politica conservadora do app; a fila prioriza os prazos proximos.
    /// Renovar o plano ao abrir o app, editar pedidos ou mudar preferencias/fuso/idioma.
    public func synchronize(
        orders: [SalesOrder], stores: [StoreProfile], settings: OrderReminderSettings,
        now: Date = Date(), calendar: Calendar = .current
    ) async throws -> OrderReminderSyncResult {
        // Os models sao lidos antes do primeiro await para nao misturar estados de duas edicoes.
        let plan = try OrderReminderPlanner.reminders(orders: orders, stores: stores, settings: settings, now: now, calendar: calendar)
        let previous = lastTask
        let center = center
        let task = Task { @MainActor in
            // Serializa inclusive chamadas sobrepostas durante os awaits do sistema.
            _ = await previous?.value
            return await Self.reconcile(plan, center: center)
        }
        lastTask = task
        return await task.value
    }

    private static func reconcile(_ plan: [OrderReminder], center: any OrderReminderCenter) async -> OrderReminderSyncResult {
        let authorization = await center.authorization()
        let pending = await center.pendingRequests()
        let owned = pending.filter { $0.id.hasPrefix(OrderReminder.identifierPrefix) }
        let foreignCount = pending.count - owned.count
        let capacity = max(0, 60 - foreignCount)
        // IDs repetidos nao consomem duas vagas nem geram duas chamadas ao sistema.
        var seen: Set<String> = []
        let unique = plan.filter { seen.insert($0.id).inserted }
        let desired = authorization.allowsScheduling ? Array(unique.prefix(capacity)) : []
        let desiredIDs = Set(desired.map(\.id))
        let obsolete = owned.filter { !desiredIDs.contains($0.id) }.map(\.id)
        if !obsolete.isEmpty { await center.removePending(identifiers: obsolete) }

        var scheduledIDs: [String] = []
        var failedIDs: [String] = []
        for reminder in desired {
            do {
                let signature = try reminder.signature()
                if !owned.contains(where: { $0.id == reminder.id && $0.signature == signature }) {
                    try await center.add(reminder)
                }
                scheduledIDs.append(reminder.id)
            } catch {
                // Se a substituicao falhar, um prazo antigo nao deve continuar avisando.
                await center.removePending(identifiers: [reminder.id])
                failedIDs.append(reminder.id)
            }
        }
        return OrderReminderSyncResult(
            authorization: authorization, scheduledIDs: scheduledIDs,
            deferredIDs: authorization.allowsScheduling ? unique.dropFirst(capacity).map(\.id) : unique.map(\.id),
            failedIDs: failedIDs
        )
    }
}
