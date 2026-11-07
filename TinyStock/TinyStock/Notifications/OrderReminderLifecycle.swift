// Proposito: Renovar lembretes apos persistencia e mudancas do ambiente do app.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-07.

import Combine
import CoreData
import SwiftData
import SwiftUI
import TinyStockCore

struct OrderReminderLifecycle: ViewModifier {
    @Environment(StoreSession.self) private var storeSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    let coordinator: OrderReminderCoordinator
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    func body(content: Content) -> some View {
        content
            .task { await coordinator.refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { reconcileRemoteChanges() }
            }
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in refresh() }
            .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
                reconcileRemoteChanges()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in refresh() }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in refresh() }
            .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in refresh() }
            .onReceive(timer) { _ in
                // Reabastece a fila limitada do sistema somente enquanto o app esta ativo.
                if scenePhase == .active { refresh() }
            }
    }

    private func refresh() {
        Task { await coordinator.refresh() }
    }

    private func reconcileRemoteChanges() {
        do {
            try storeSession.reconcileCloudChanges(in: modelContext)
            if modelContext.hasChanges { try modelContext.save() }
        } catch {
            // A proxima importacao ou ativacao do app tenta reconciliar novamente.
        }
        refresh()
    }
}
