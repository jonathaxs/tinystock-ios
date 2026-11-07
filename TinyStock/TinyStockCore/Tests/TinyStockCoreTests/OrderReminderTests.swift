// Proposito: Validar prazos, sincronizacao e conteudo sem emitir notificacoes reais.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-07.

import Foundation
import Testing
import UserNotifications
@testable import TinyStockCore

@MainActor
struct OrderReminderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func date(_ day: Int, month: Int = 9, hour: Int = 8, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2028, month: month, day: day, hour: hour, minute: minute))!
    }

    private var enabled: OrderReminderSettings {
        var settings = OrderReminderSettings()
        settings.isEnabled = true
        return settings
    }

    private func order(store: StoreProfile, status: SalesOrderStatus = .awaitingProduction) -> SalesOrder {
        let order = SalesOrder(
            storeID: store.id, fulfillment: .production, status: status,
            buyerName: "Comprador privado", orderedAt: date(1),
            productionDueAt: date(10), shippingDueAt: date(12)
        )
        order.items = [SalesOrderItem(productName: "Produto", quantity: 2)]
        return order
    }

    private func plan(_ orders: [SalesOrder], stores: [StoreProfile], settings: OrderReminderSettings? = nil, now: Date? = nil) throws -> [OrderReminder] {
        try OrderReminderPlanner.reminders(orders: orders, stores: stores, settings: settings ?? enabled, now: now ?? date(7), calendar: calendar)
    }

    private func sync(_ service: OrderReminderService, _ orders: [SalesOrder], _ stores: [StoreProfile], settings: OrderReminderSettings? = nil) async throws -> OrderReminderSyncResult {
        try await service.synchronize(orders: orders, stores: stores, settings: settings ?? enabled, now: date(7), calendar: calendar)
    }

    @Test func producaoAgendaVesperaDiaEAtrasoParaAmbosOsPrazos() throws {
        let store = StoreProfile(name: "Loja")
        let reminders = try plan([order(store: store)], stores: [store])
        #expect(reminders.count == 6)
        #expect(reminders.map(\.fireDate) == [9, 10, 11, 11, 12, 13].map { date($0, hour: 9) })
        #expect(Set(reminders.map(\.id)).count == 6)
        #expect(reminders.filter { $0.kind == .production }.map(\.timing) == [.dayBefore, .dueDay, .overdue])
        #expect(reminders.allSatisfy { !$0.body.contains("Comprador privado") && $0.body.contains("Loja") && $0.body.contains("Produto") })
    }

    @Test func produzidoRetiraProducaoEDespachadoRetiraTudo() throws {
        let store = StoreProfile()
        let order = order(store: store)
        order.statusRawValue = SalesOrderStatus.inProduction.rawValue
        #expect(try plan([order], stores: [store]).count == 6)
        order.statusRawValue = SalesOrderStatus.readyToShip.rawValue
        #expect(try plan([order], stores: [store]).allSatisfy { $0.kind == .shipping })
        for state in [SalesOrderStatus.new, .shipped, .completed, .cancelled] {
            order.statusRawValue = state.rawValue
            #expect(try plan([order], stores: [store]).isEmpty)
        }
        order.statusRawValue = "future-state"
        #expect(try plan([order], stores: [store]).isEmpty)
    }

    @Test func lojasAtivasParticipamSemMisturarIDsOuIncluirArquivadas() throws {
        let first = StoreProfile(name: "Primeira")
        let second = StoreProfile(name: "Segunda")
        let archived = StoreProfile(isArchived: true)
        let missing = StoreProfile()
        let orders = [first, second, archived, missing].map { order(store: $0) }
        orders[1].id = orders[0].id
        let reminders = try plan(orders, stores: [first, second, archived])
        #expect(reminders.count == 12)
        #expect(Set(reminders.map(\.id)).count == 12)
        #expect(Set(reminders.map(\.storeID)) == Set([first.id, second.id]))
        #expect(reminders.filter { $0.storeID == second.id }.allSatisfy { $0.body.contains("Segunda") })
    }

    @Test func desativadoEPrazosAusentesNaoGeramNotificacoes() throws {
        let store = StoreProfile()
        let order = order(store: store)
        #expect(try plan([order], stores: [store], settings: OrderReminderSettings()).isEmpty)
        order.productionDueAt = nil
        order.shippingDueAt = nil
        #expect(try plan([order], stores: [store]).isEmpty)
    }

    @Test func preferenciasSelecionamEtapaMomentoESom() throws {
        let store = StoreProfile()
        var settings = enabled
        settings.productionEnabled = false
        settings.dayBeforeEnabled = false
        settings.overdueEnabled = false
        settings.soundEnabled = false
        settings.hour = 14
        settings.minute = 35
        let reminders = try plan([order(store: store)], stores: [store], settings: settings)
        #expect(reminders.count == 1)
        #expect(reminders.first?.kind == .shipping)
        #expect(reminders.first?.timing == .dueDay)
        #expect(reminders.first?.fireDate == date(12, hour: 14, minute: 35))
        #expect(reminders.first?.soundEnabled == false)
        let request = try SystemOrderReminderCenter.request(for: #require(reminders.first))
        #expect(request.content.sound == nil)
        settings.shippingEnabled = false
        #expect(try plan([order(store: store)], stores: [store], settings: settings).isEmpty)
        #expect(try JSONDecoder().decode(OrderReminderSettings.self, from: JSONEncoder().encode(settings)) == settings)
    }

    @Test func horariosInvalidosSaoRecusadosAntesDeAgendar() throws {
        for (hour, minute) in [(-1, 0), (24, 0), (9, -1), (9, 60)] {
            var settings = enabled
            settings.hour = hour
            settings.minute = minute
            #expect(throws: OrderReminderError.invalidTime) { try plan([], stores: [], settings: settings) }
        }
    }

    @Test func naoReenviaAvisosPassadosNemAtrasosAntigos() throws {
        let store = StoreProfile()
        let order = order(store: store, status: .readyToShip)
        let reminders = try plan([order], stores: [store], now: date(12, hour: 9))
        #expect(reminders.count == 1)
        #expect(reminders.first?.timing == .overdue)
        #expect(try plan([order], stores: [store], now: date(14)).isEmpty)
    }

    @Test func horarioDeVeraoMantemDiaLocalEAvancaHoraInexistente() throws {
        let store = StoreProfile()
        let order = order(store: store, status: .readyToShip)
        order.shippingDueAt = date(12, month: 3)
        var settings = enabled
        settings.hour = 2
        settings.minute = 30
        let reminders = try plan([order], stores: [store], settings: settings, now: date(10, month: 3))
        let due = try #require(reminders.first { $0.timing == .dueDay })
        #expect(calendar.component(.day, from: due.fireDate) == 12)
        #expect(calendar.component(.hour, from: due.fireDate) == 3)
        #expect(calendar.component(.day, from: reminders.first!.fireDate) == 11)
        #expect(calendar.component(.hour, from: reminders.first!.fireDate) == 2)
    }

    @Test func alteracaoDePrazoMantemIDMasAtualizaAssinatura() throws {
        let store = StoreProfile()
        let order = order(store: store)
        let before = try plan([order], stores: [store])
        order.productionDueAt = date(15)
        let after = try plan([order], stores: [store])
        #expect(Set(before.map(\.id)) == Set(after.map(\.id)))
        let old = try #require(before.first { $0.kind == .production && $0.timing == .dueDay })
        let new = try #require(after.first { $0.id == old.id })
        #expect(try old.signature() != new.signature())
    }

    @Test func sincronizacaoRepetidaNaoDuplicaEAtualizaSomTextoEPrazo() async throws {
        let store = StoreProfile(name: "Loja")
        let order = order(store: store)
        let center = TestReminderCenter()
        let service = OrderReminderService(center: center)
        _ = try await sync(service, [order], [store])
        #expect(center.added.count == 6)
        _ = try await sync(service, [order], [store])
        #expect(center.added.count == 6)
        var settings = enabled
        settings.soundEnabled = false
        store.name = "Novo nome"
        order.productionDueAt = date(15)
        _ = try await sync(service, [order], [store], settings: settings)
        #expect(center.added.count == 12)
        #expect(center.pending.count == 6)
        #expect(center.added.suffix(6).allSatisfy { !$0.soundEnabled && $0.body.contains("Novo nome") })
        #expect(center.permissionRequests == 0)
    }

    @Test func transicoesCancelamentoEExclusaoRemovemAlertasObsoletos() async throws {
        let store = StoreProfile()
        let order = order(store: store)
        let center = TestReminderCenter()
        let service = OrderReminderService(center: center)
        _ = try await sync(service, [order], [store])
        order.statusRawValue = SalesOrderStatus.readyToShip.rawValue
        _ = try await sync(service, [order], [store])
        #expect(center.pending.count == 3)
        #expect(center.pending.allSatisfy { $0.id.contains(".shipping.") })
        for status in [SalesOrderStatus.cancelled, .shipped, .completed] {
            order.statusRawValue = SalesOrderStatus.readyToShip.rawValue
            _ = try await sync(service, [order], [store])
            order.statusRawValue = status.rawValue
            _ = try await sync(service, [order], [store])
            #expect(center.pending.isEmpty)
        }
        order.statusRawValue = SalesOrderStatus.readyToShip.rawValue
        _ = try await sync(service, [order], [store])
        _ = try await sync(service, [], [store])
        #expect(center.pending.isEmpty)
    }

    @Test func arquivarLojaOuDesativarRemoveSomenteLembretesDePedidos() async throws {
        let store = StoreProfile()
        let order = order(store: store)
        let center = TestReminderCenter()
        center.pending = [.init(id: "another.feature", signature: nil)]
        let service = OrderReminderService(center: center)
        _ = try await sync(service, [order], [store])
        store.isArchived = true
        _ = try await sync(service, [order], [store])
        #expect(center.pending.map(\.id) == ["another.feature"])
        store.isArchived = false
        _ = try await sync(service, [order], [store])
        _ = try await sync(service, [order], [store], settings: .init())
        #expect(center.pending.map(\.id) == ["another.feature"])
    }

    @Test func permissaoNegadaOuDesconhecidaNaoAgendaNemSolicitaDialogo() async throws {
        let store = StoreProfile()
        for authorization in [OrderReminderAuthorization.denied, .notDetermined, .unknown] {
            let center = TestReminderCenter()
            let service = OrderReminderService(center: center)
            let order = order(store: store)
            _ = try await sync(service, [order], [store])
            center.status = authorization
            let result = try await sync(service, [order], [store])
            #expect(result.scheduledIDs.isEmpty)
            #expect(result.deferredIDs.count == 6)
            #expect(center.pending.isEmpty)
            #expect(center.permissionRequests == 0)
        }
    }

    @Test func autorizacaoExplicitaEProvisoriaSaoSuportadas() async throws {
        let store = StoreProfile()
        let center = TestReminderCenter()
        let service = OrderReminderService(center: center)
        #expect(try await service.requestAuthorization())
        #expect(center.permissionRequests == 1)
        center.status = .provisional
        let result = try await sync(service, [order(store: store)], [store])
        #expect(result.scheduledIDs.count == 6)
    }

    @Test func limitePriorizaProximosEDescontaNotificacoesDeOutrasFuncoes() async throws {
        let store = StoreProfile()
        let orders = (0..<15).map { _ in order(store: store) }
        let center = TestReminderCenter()
        center.pending = (0..<5).map { .init(id: "foreign.\($0)", signature: nil) }
        let result = try await sync(OrderReminderService(center: center), orders, [store])
        let expected = try plan(orders, stores: [store])
        #expect(result.scheduledIDs == Array(expected.prefix(55)).map(\.id))
        #expect(result.deferredIDs == expected.dropFirst(55).map(\.id))
        #expect(center.pending.count == 60)
    }

    @Test func falhaAoSubstituirRemovePrazoAntigoEPermiteNovaTentativa() async throws {
        let store = StoreProfile()
        let order = order(store: store)
        let center = TestReminderCenter()
        let service = OrderReminderService(center: center)
        _ = try await sync(service, [order], [store])
        let failedID = center.added.first!.id
        center.failedID = failedID
        order.productionDueAt = date(16)
        let result = try await sync(service, [order], [store])
        #expect(result.failedIDs == [failedID])
        #expect(!center.pending.contains { $0.id == failedID })
        center.failedID = nil
        let retry = try await sync(service, [order], [store])
        #expect(retry.failedIDs.isEmpty)
        #expect(center.pending.count == 6)
    }

    @Test func requisicaoDoSistemaPreservaDataConteudoSomERota() throws {
        let store = StoreProfile(name: "Loja")
        let reminder = try #require(plan([order(store: store)], stores: [store]).first)
        let request = try SystemOrderReminderCenter.request(for: reminder)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(!trigger.repeats)
        #expect(trigger.dateComponents.date == reminder.fireDate)
        #expect(request.identifier == reminder.id)
        #expect(request.content.title == reminder.title)
        #expect(request.content.body == reminder.body)
        #expect(request.content.sound != nil)
        #expect(request.content.userInfo["storeID"] as? String == store.id.uuidString)
        #expect(request.content.userInfo["orderID"] as? String == reminder.orderID.uuidString)
        #expect(request.content.userInfo["reminderSignature"] as? String == (try reminder.signature()))
    }

    @Test func cancelamentoDuranteAgendamentoPrevaleceSobrePlanoAnterior() async throws {
        let store = StoreProfile()
        let order = order(store: store)
        let center = TestReminderCenter()
        let service = OrderReminderService(center: center)
        var firstTask: Task<OrderReminderSyncResult, Error>?
        // Suspende a primeira inclusao para intercalar uma atualizacao do pedido.
        await withCheckedContinuation { entered in
            center.onPausedAdd = { entered.resume() }
            center.pauseNextAdd = true
            firstTask = Task { try await sync(service, [order], [store]) }
        }
        order.statusRawValue = SalesOrderStatus.cancelled.rawValue
        var secondTask: Task<OrderReminderSyncResult, Error>?
        await withCheckedContinuation { submitted in
            secondTask = Task {
                submitted.resume()
                return try await sync(service, [order], [store])
            }
        }
        center.addGate?.resume()
        center.addGate = nil
        let first = try await #require(firstTask).value
        let second = try await #require(secondTask).value
        #expect(first.scheduledIDs.count == 6)
        #expect(second.scheduledIDs.isEmpty)
        #expect(center.pending.isEmpty)
    }

    @Test func filaSemVagasPreservaOutrasFuncoesERefazPlanoQuandoHaEspaco() async throws {
        let store = StoreProfile()
        let order = order(store: store)
        let center = TestReminderCenter()
        center.pending = (0..<61).map { .init(id: "foreign.\($0)", signature: nil) }
        let service = OrderReminderService(center: center)
        let full = try await sync(service, [order], [store])
        #expect(full.scheduledIDs.isEmpty)
        #expect(full.deferredIDs.count == 6)
        #expect(center.pending.count == 61)
        center.pending = []
        let retry = try await sync(service, [order, order], [store])
        #expect(retry.scheduledIDs.count == 6)
        #expect(retry.deferredIDs.isEmpty)
        #expect(center.pending.count == 6)
    }

    @Test func horaRepetidaETrocaDeFusoMantemUmaUnicaOcorrenciaPorAviso() throws {
        let store = StoreProfile()
        let order = order(store: store, status: .readyToShip)
        order.shippingDueAt = date(5, month: 11)
        var settings = enabled
        settings.hour = 1
        settings.minute = 30
        let reminders = try plan([order], stores: [store], settings: settings, now: date(3, month: 11))
        let due = try #require(reminders.first { $0.timing == .dueDay })
        #expect(reminders.count == 3)
        #expect(calendar.timeZone.secondsFromGMT(for: due.fireDate) == -4 * 3600)
        let request = try SystemOrderReminderCenter.request(for: due)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.date == due.fireDate)
        var otherCalendar = calendar
        otherCalendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let changed = try OrderReminderPlanner.reminders(
            orders: [order], stores: [store], settings: settings, now: date(3, month: 11), calendar: otherCalendar
        )
        let changedDue = try #require(changed.first { $0.id == due.id })
        #expect(changedDue.fireDate != due.fireDate)
        #expect(try changedDue.signature() != due.signature())
    }
}

@MainActor
private final class TestReminderCenter: OrderReminderCenter {
    enum Failure: Error { case add }
    var status: OrderReminderAuthorization = .authorized
    var pending: [PendingOrderReminder] = []
    var added: [OrderReminder] = []
    var failedID: String?
    var permissionRequests = 0
    var pauseNextAdd = false
    var onPausedAdd: (() -> Void)?
    var addGate: CheckedContinuation<Void, Never>?

    func authorization() async -> OrderReminderAuthorization { status }
    func requestAuthorization() async throws -> Bool {
        permissionRequests += 1
        return true
    }
    func pendingRequests() async -> [PendingOrderReminder] { pending }
    func add(_ reminder: OrderReminder) async throws {
        if pauseNextAdd {
            pauseNextAdd = false
            await withCheckedContinuation { continuation in
                addGate = continuation
                onPausedAdd?()
                onPausedAdd = nil
            }
        }
        if reminder.id == failedID { throw Failure.add }
        pending.removeAll { $0.id == reminder.id }
        pending.append(.init(id: reminder.id, signature: try reminder.signature()))
        added.append(reminder)
    }
    func removePending(identifiers: [String]) async {
        pending.removeAll { identifiers.contains($0.id) }
    }
}
