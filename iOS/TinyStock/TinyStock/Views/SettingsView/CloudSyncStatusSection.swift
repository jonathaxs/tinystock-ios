// Proposito: Exibir o estado da sincronizacao automatica na pagina de dados.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-09.

import CloudKit
import SwiftUI
import TinyStockCore

struct CloudSyncStatusSection: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var accountState: AccountState = .checking

    var body: some View {
        Section {
            LabeledContent {
                Label(accountState.localizedName, systemImage: accountState.symbolName)
                    .foregroundStyle(accountState.tint)
            } label: {
                Text(String(localized: "settings.sync.status", bundle: .tinyStockCore))
            }

            Button {
                Task { await refresh() }
            } label: {
                Label(
                    String(localized: "settings.sync.refresh", bundle: .tinyStockCore),
                    systemImage: "arrow.clockwise"
                )
            }
            .disabled(accountState == .checking)
        } header: {
            Text(String(localized: "settings.sync.title", bundle: .tinyStockCore))
        } footer: {
            Text(String(localized: "settings.sync.footer", bundle: .tinyStockCore))
        }
        .task { await refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh() } }
        }
    }

    @MainActor
    private func refresh() async {
        accountState = .checking
        do {
            let status = try await CKContainer(
                identifier: TinyStockPersistence.cloudContainerIdentifier
            ).accountStatus()
            accountState = AccountState(status)
        } catch {
            accountState = .unavailable
        }
    }
}

private enum AccountState: Equatable {
    case checking
    case available
    case noAccount
    case restricted
    case unavailable
    case unknown

    init(_ status: CKAccountStatus) {
        switch status {
        case .available: self = .available
        case .noAccount: self = .noAccount
        case .restricted: self = .restricted
        case .temporarilyUnavailable: self = .unavailable
        case .couldNotDetermine: self = .unknown
        @unknown default: self = .unknown
        }
    }

    var localizedName: String {
        switch self {
        case .checking:
            String(localized: "settings.sync.status.checking", bundle: .tinyStockCore)
        case .available:
            String(localized: "settings.sync.status.available", bundle: .tinyStockCore)
        case .noAccount:
            String(localized: "settings.sync.status.noAccount", bundle: .tinyStockCore)
        case .restricted:
            String(localized: "settings.sync.status.restricted", bundle: .tinyStockCore)
        case .unavailable:
            String(localized: "settings.sync.status.unavailable", bundle: .tinyStockCore)
        case .unknown:
            String(localized: "settings.sync.status.unknown", bundle: .tinyStockCore)
        }
    }

    var symbolName: String {
        switch self {
        case .checking: "clock"
        case .available: "checkmark.icloud"
        case .noAccount, .restricted, .unavailable: "exclamationmark.icloud"
        case .unknown: "questionmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .available: .green
        case .noAccount, .restricted, .unavailable: .orange
        case .checking, .unknown: .secondary
        }
    }
}
