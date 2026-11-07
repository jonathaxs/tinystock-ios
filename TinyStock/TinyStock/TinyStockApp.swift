// ⌘
//  TinyStock/TinyStockApp.swift
//
//  Propósito: Ponto de entrada do app; configura o container do SwiftData e mostra a navegação principal.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-07.
// ⌘

import SwiftUI
import SwiftData
import TinyStockCore

@main
struct TinyStockApp: App {
    @UIApplicationDelegateAdaptor(TinyStockAppDelegate.self) private var appDelegate

    // Sinaliza falha ao abrir o banco (disco cheio, arquivo corrompido, etc.).
    // Quando true, o app mostra uma tela de erro em vez de travar.
    private let containerInitFailed: Bool
    private let sharedModelContainer: ModelContainer
    private let storeSession: StoreSession
    private let reminderCoordinator: OrderReminderCoordinator

    init() {
        let schema = TinyStockPersistence.schema
        let config = TinyStockPersistence.cloudConfiguration(schema: schema)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let session = try StoreSession.bootstrapForCloudSync(in: context)
            try context.save()

            sharedModelContainer = container
            storeSession = session
            containerInitFailed = false
        } catch {
            // Usa um container em memória para permitir a apresentação da tela de erro.
            // Nesse estado os dados não são salvos, mas o app não trava.
            let container = try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
            )
            let context = ModelContext(container)

            sharedModelContainer = container
            storeSession = try! StoreSession.bootstrap(in: context)
            containerInitFailed = true
        }
        let container = sharedModelContainer
        reminderCoordinator = OrderReminderCoordinator(
            service: OrderReminderService(center: SystemOrderReminderCenter()),
            loadSnapshot: { try OrderReminderSnapshot(container: container) }
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if containerInitFailed {
                    DataStoreErrorView()
                } else {
                    MainView()
                        .modifier(OrderReminderLifecycle(coordinator: reminderCoordinator))
                }
            }
            .environment(storeSession)
            .environment(reminderCoordinator)
            .environment(appDelegate.reminderRouter)
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Tela de erro do banco de dados

// Exibida no caso raro em que o container do SwiftData não pode ser criado.
private struct DataStoreErrorView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            Text(String(localized: "app.error.dataStore.title", bundle: .tinyStockCore))
                .font(.title2.bold())

            Text(String(localized: "app.error.dataStore.message", bundle: .tinyStockCore))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}
