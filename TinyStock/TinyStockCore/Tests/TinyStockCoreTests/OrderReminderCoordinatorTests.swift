// Proposito: Validar preferencias e atualizacoes do app sem solicitar permissao ao sistema.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-07.

import Foundation
import SwiftData
import Testing
@testable import TinyStockCore

@MainActor
@Suite(.serialized)
struct OrderReminderCoordinatorTests {
    @Test func preferenciasPersistemTodosOsControlesSemAlterarOutrasChaves() throws {
        let fixture = ReminderFixture()
        defer { fixture.cleanUp() }
        fixture.defaults.set("mantido", forKey: "another.preference")
        #expect(try fixture.settingsStore.load() == OrderReminderSettings())
        var settings = fixture.enabledSettings
        settings.productionEnabled = false
        settings.shippingEnabled = false
        settings.dayBeforeEnabled = false
        settings.dueDayEnabled = false
        settings.overdueEnabled = false
        settings.soundEnabled = false
        settings.hour = 23
        settings.minute = 59
        try fixture.settingsStore.save(settings)
        #expect(try OrderReminderSettingsStore(defaults: fixture.defaults).load() == settings)
        #expect(fixture.defaults.string(forKey: "another.preference") == "mantido")
    }

    @Test func horarioInvalidoNaoSobrescrevePreferenciasValidas() throws {
        let fixture = ReminderFixture()
        defer { fixture.cleanUp() }
        try fixture.settingsStore.save(fixture.enabledSettings)
        var invalid = fixture.enabledSettings
        invalid.minute = 60
        #expect(throws: OrderReminderError.invalidTime) { try fixture.settingsStore.save(invalid) }
        #expect(try fixture.settingsStore.load() == fixture.enabledSettings)
        fixture.defaults.set(try JSONEncoder().encode(invalid), forKey: OrderReminderSettingsStore.key)
        #expect(throws: OrderReminderError.invalidTime) { try fixture.settingsStore.load() }
    }

    @Test func preferenciasCorrompidasExibemErroEPermitemReconfigurar() async {
        let fixture = ReminderFixture()
        defer { fixture.cleanUp() }
        fixture.defaults.set(Data("invalid".utf8), forKey: OrderReminderSettingsStore.key)
        let coordinator = fixture.makeCoordinator()
        #expect(coordinator.issue == .preferences)
        #expect(!coordinator.settings.isEnabled)
        await coordinator.refresh()
        #expect(coordinator.issue == .preferences)
        #expect(fixture.center.permissionRequests == 0)
        await coordinator.setEnabled(true)
        #expect(coordinator.issue == nil)
        #expect(coordinator.scheduledCount == 6)
    }

    @Test func abrirOuAtualizarNaoSolicitaPermissaoMasAtivarSolicitaUmaVez() async throws {
        let fixture = ReminderFixture()
        defer { fixture.cleanUp() }
        fixture.center.status = .notDetermined
        let coordinator = fixture.makeCoordinator()
        await coordinator.refresh()
        #expect(coordinator.authorization == .notDetermined)
        #expect(fixture.center.permissionRequests == 0)
        #expect(fixture.reads == 0)
        await coordinator.setEnabled(true)
        #expect(coordinator.authorization == .authorized)
        #expect(coordinator.scheduledCount == 6)
        #expect(fixture.center.permissionRequests == 1)
        await coordinator.setEnabled(true)
        await coordinator.refresh()
        #expect(fixture.center.permissionRequests == 1)
        #expect(try fixture.settingsStore.load().isEnabled)
    }

    @Test func permissaoNegadaMantemPreferenciaMasNaoAgendaNemRepeteDialogo() async throws {
        let fixture = ReminderFixture()
        defer { fixture.cleanUp() }
        fixture.center.status = .notDetermined
        fixture.center.grantsPermission = false
        let coordinator = fixture.makeCoordinator()
        await coordinator.setEnabled(true)
        #expect(coordinator.authorization == .denied)
        #expect(coordinator.settings.isEnabled)
        #expect(coordinator.scheduledCount == 0)
        await coordinator.setEnabled(true)
        #expect(fixture.center.permissionRequests == 1)
        #expect(try fixture.settingsStore.load().isEnabled)
        fixture.center.status = .authorized
        await coordinator.refresh()
        #expect(coordinator.scheduledCount == 6)
        fixture.center.status = .denied
        await coordinator.refresh()
        #expect(fixture.center.pending.isEmpty)
    }

    @Test func falhaDaPermissaoPodeSerTentadaNovamente() async {
        let fixture = ReminderFixture()
        defer { fixture.cleanUp() }
        fixture.center.status = .notDetermined
        fixture.center.failsPermission = true
        let coordinator = fixture.makeCoordinator()
        await coordinator.setEnabled(true)
        #expect(coordinator.issue == .permission)
        #expect(!coordinator.isRequestingPermission)
        fixture.center.failsPermission = false
        await coordinator.setEnabled(true)
        #expect(coordinator.issue == nil)
        #expect(coordinator.scheduledCount == 6)
    }

    @Test func leituraComFalhaPreservaFilaERecuperacaoReleDados() async {
        let fixture = ReminderFixture()
        defer { fixture.cleanUp() }
        let coordinator = fixture.makeCoordinator()
        await coordinator.setEnabled(true)
        let previousIDs = fixture.center.pending.map(\.id)
        fixture.failsRead = true
        await coordinator.refresh()
        #expect(coordinator.issue == .dataRead)
        #expect(fixture.center.pending.map(\.id) == previousIDs)
        fixture.failsRead = false
        fixture.order.statusRawValue = SalesOrderStatus.shipped.rawValue
        await coordinator.refresh()
        #expect(coordinator.issue == nil)
        #expect(coordinator.scheduledCount == 0)
        #expect(fixture.center.pending.isEmpty)
    }

    @Test func desativarLimpaFilaMesmoSeBancoNaoPuderSerLido() async {
        let fixture = ReminderFixture()
        defer { fixture.cleanUp() }
        let coordinator = fixture.makeCoordinator()
        await coordinator.setEnabled(true)
        fixture.failsRead = true
        fixture.center.pending.append(.init(id: "another.feature", signature: nil))
        await coordinator.setEnabled(false)
        #expect(coordinator.issue == nil)
        #expect(fixture.center.pending.map(\.id) == ["another.feature"])
    }

    @Test func novaLeituraDuranteAgendamentoPrevaleceSobrePlanoAntigo() async {
        let fixture = ReminderFixture()
        defer { fixture.cleanUp() }
        let coordinator = fixture.makeCoordinator()
        fixture.center.beforeNextAdd = {
            fixture.order.statusRawValue = SalesOrderStatus.cancelled.rawValue
            await coordinator.refresh()
        }
        await coordinator.setEnabled(true)
        #expect(fixture.reads == 2)
        #expect(fixture.center.pending.isEmpty)
        #expect(coordinator.scheduledCount == 0)
        #expect(!coordinator.isSynchronizing)
    }

    @Test func desativarDuranteAgendamentoNaoReativaAoTerminar() async throws {
        let fixture = ReminderFixture()
        defer { fixture.cleanUp() }
        let coordinator = fixture.makeCoordinator()
        fixture.center.beforeNextAdd = { await coordinator.setEnabled(false) }
        await coordinator.setEnabled(true)
        #expect(!coordinator.settings.isEnabled)
        #expect(try !fixture.settingsStore.load().isEnabled)
        #expect(fixture.center.pending.isEmpty)
    }

    @Test func mudarHoraSomEEtapasSubstituiFilaSemDuplicar() async {
        let fixture = ReminderFixture()
        defer { fixture.cleanUp() }
        let coordinator = fixture.makeCoordinator()
        await coordinator.setEnabled(true)
        var settings = coordinator.settings
        settings.productionEnabled = false
        settings.soundEnabled = false
        settings.hour = 17
        settings.minute = 20
        await coordinator.update(settings)
        #expect(coordinator.scheduledCount == 3)
        #expect(fixture.center.added.suffix(3).allSatisfy {
            $0.kind == .shipping && !$0.soundEnabled
                && fixture.calendar.component(.hour, from: $0.fireDate) == 17
                && fixture.calendar.component(.minute, from: $0.fireDate) == 20
        })
        settings.hour = 24
        await coordinator.update(settings)
        #expect(coordinator.issue == .preferences)
        #expect(coordinator.settings.hour == 17)
        #expect(fixture.center.pending.count == 3)
    }

    @Test func falhaDoSistemaExibeErroERetryRecupera() async {
        let fixture = ReminderFixture()
        defer { fixture.cleanUp() }
        fixture.center.failsAdd = true
        let coordinator = fixture.makeCoordinator()
        await coordinator.setEnabled(true)
        #expect(coordinator.issue == .scheduling)
        #expect(coordinator.failedCount == 6)
        fixture.center.failsAdd = false
        await coordinator.refresh()
        #expect(coordinator.issue == nil)
        #expect(coordinator.failedCount == 0)
        #expect(coordinator.scheduledCount == 6)
    }

    @Test func filaLotadaInformaPendenciasEReabasteceNoRefresh() async {
        let fixture = ReminderFixture()
        defer { fixture.cleanUp() }
        fixture.center.pending = (0..<60).map { .init(id: "foreign.\($0)", signature: nil) }
        let coordinator = fixture.makeCoordinator()
        await coordinator.setEnabled(true)
        #expect(coordinator.scheduledCount == 0)
        #expect(coordinator.deferredCount == 6)
        fixture.center.pending = []
        await coordinator.refresh()
        #expect(coordinator.scheduledCount == 6)
        #expect(coordinator.deferredCount == 0)
    }

    @Test func retratoUsaSomenteDadosSalvosEAtualizaItensELoja() throws {
        let context = try TestDatabase.makeCleanContext()
        context.autosaveEnabled = false
        let store = StoreProfile(name: "Salva")
        let order = SalesOrder(storeID: store.id)
        order.items = [SalesOrderItem(productName: "Produto salvo", quantity: 1)]
        context.insert(store)
        context.insert(order)
        try context.save()
        store.name = "Rascunho"
        order.items?.first?.productName = "Produto novo"
        let before = try OrderReminderSnapshot(container: context.container)
        #expect(before.stores.first?.name == "Salva")
        #expect(before.orders.first?.itemList.first?.productName == "Produto salvo")
        try context.save()
        let after = try OrderReminderSnapshot(container: context.container)
        #expect(after.stores.first?.name == "Rascunho")
        #expect(after.orders.first?.itemList.first?.productName == "Produto novo")
    }

    @Test func todoErroPossuiMensagemLocalizada() {
        for issue in [OrderReminderIssue.preferences, .permission, .dataRead, .scheduling] {
            #expect(!issue.localizedMessage.isEmpty)
            #expect(!issue.localizedMessage.hasPrefix("notifications."))
        }
    }
}

@MainActor
private final class ReminderFixture {
    let suite = "OrderReminderTests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let settingsStore: OrderReminderSettingsStore
    let center = CoordinatorTestCenter()
    let store = StoreProfile(name: "Loja")
    let order: SalesOrder
    let calendar: Calendar
    let now: Date
    var reads = 0
    var failsRead = false

    var enabledSettings: OrderReminderSettings {
        var settings = OrderReminderSettings()
        settings.isEnabled = true
        return settings
    }

    init() {
        defaults = UserDefaults(suiteName: suite)!
        settingsStore = OrderReminderSettingsStore(defaults: defaults)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        now = calendar.date(from: DateComponents(year: 2028, month: 9, day: 7, hour: 8))!
        order = SalesOrder(
            storeID: store.id, fulfillment: .production, status: .awaitingProduction,
            productionDueAt: calendar.date(from: DateComponents(year: 2028, month: 9, day: 10)),
            shippingDueAt: calendar.date(from: DateComponents(year: 2028, month: 9, day: 12))
        )
        order.items = [SalesOrderItem(productName: "Produto", quantity: 1)]
    }

    func makeCoordinator() -> OrderReminderCoordinator {
        OrderReminderCoordinator(
            service: OrderReminderService(center: center), settingsStore: settingsStore,
            now: { self.now }, calendar: { self.calendar }, loadSnapshot: {
                self.reads += 1
                if self.failsRead { throw CoordinatorTestCenter.Failure.simulated }
                return OrderReminderSnapshot(orders: [self.order], stores: [self.store])
            }
        )
    }

    func cleanUp() { defaults.removePersistentDomain(forName: suite) }
}

@MainActor
private final class CoordinatorTestCenter: OrderReminderCenter {
    enum Failure: Error { case simulated }
    var status: OrderReminderAuthorization = .authorized
    var grantsPermission = true
    var failsPermission = false
    var failsAdd = false
    var permissionRequests = 0
    var pending: [PendingOrderReminder] = []
    var added: [OrderReminder] = []
    var beforeNextAdd: (() async -> Void)?

    func authorization() async -> OrderReminderAuthorization { status }
    func requestAuthorization() async throws -> Bool {
        permissionRequests += 1
        if failsPermission { throw Failure.simulated }
        status = grantsPermission ? .authorized : .denied
        return grantsPermission
    }
    func pendingRequests() async -> [PendingOrderReminder] { pending }
    func add(_ reminder: OrderReminder) async throws {
        if let action = beforeNextAdd {
            beforeNextAdd = nil
            await action()
        }
        if failsAdd { throw Failure.simulated }
        pending.removeAll { $0.id == reminder.id }
        pending.append(.init(id: reminder.id, signature: try reminder.signature()))
        added.append(reminder)
    }
    func removePending(identifiers: [String]) async {
        pending.removeAll { identifiers.contains($0.id) }
    }
}
