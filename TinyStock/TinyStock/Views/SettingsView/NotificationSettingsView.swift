// Proposito: Configurar lembretes e mostrar a permissao e a fila deste dispositivo.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-07.

import SwiftUI
import TinyStockCore

struct NotificationSettingsView: View {
    @Environment(OrderReminderCoordinator.self) private var coordinator
    @Environment(\.openURL) private var openURL
    @Environment(\.calendar) private var calendar

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "notifications.enabled", bundle: .tinyStockCore), isOn: Binding(
                    get: { coordinator.settings.isEnabled },
                    set: { enabled in Task { await coordinator.setEnabled(enabled) } }
                ))
                .disabled(coordinator.isRequestingPermission)
            } footer: {
                Text(String(localized: "notifications.scope", bundle: .tinyStockCore))
            }

            Section(String(localized: "notifications.permission", bundle: .tinyStockCore)) {
                LabeledContent(String(localized: "notifications.permission.status", bundle: .tinyStockCore)) {
                    Text(authorizationText).foregroundStyle(.secondary)
                }
                if coordinator.settings.isEnabled && coordinator.authorization == .notDetermined {
                    Button(String(localized: "notifications.permission.request", bundle: .tinyStockCore)) {
                        Task { await coordinator.setEnabled(true) }
                    }
                    .disabled(coordinator.isRequestingPermission)
                }
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                } label: {
                    Label(String(localized: "notifications.permission.settings", bundle: .tinyStockCore), systemImage: "arrow.up.forward.app")
                }
            }

            Section(String(localized: "notifications.stages", bundle: .tinyStockCore)) {
                Toggle(String(localized: "notifications.production", bundle: .tinyStockCore), isOn: preference(\.productionEnabled))
                Toggle(String(localized: "notifications.shipping", bundle: .tinyStockCore), isOn: preference(\.shippingEnabled))
            }
            .disabled(!coordinator.settings.isEnabled)

            Section {
                Toggle(String(localized: "notifications.dayBefore", bundle: .tinyStockCore), isOn: preference(\.dayBeforeEnabled))
                Toggle(String(localized: "notifications.dueDay", bundle: .tinyStockCore), isOn: preference(\.dueDayEnabled))
                Toggle(String(localized: "notifications.overdue", bundle: .tinyStockCore), isOn: preference(\.overdueEnabled))
                DatePicker(String(localized: "notifications.time", bundle: .tinyStockCore), selection: reminderTime, displayedComponents: .hourAndMinute)
            } header: {
                Text(String(localized: "notifications.when", bundle: .tinyStockCore))
            } footer: {
                Text(String(localized: "notifications.time.footer", bundle: .tinyStockCore))
            }
            .disabled(!coordinator.settings.isEnabled)

            Section {
                Toggle(String(localized: "notifications.sound", bundle: .tinyStockCore), isOn: preference(\.soundEnabled))
            }
            .disabled(!coordinator.settings.isEnabled)

            if coordinator.settings.isEnabled && coordinator.authorization.allowsScheduling {
                Section {
                    LabeledContent(String(localized: "notifications.scheduled", bundle: .tinyStockCore)) {
                        Text(coordinator.scheduledCount, format: .number)
                    }
                    if coordinator.deferredCount > 0 {
                        LabeledContent(String(localized: "notifications.deferred", bundle: .tinyStockCore)) {
                            Text(coordinator.deferredCount, format: .number)
                        }
                    }
                } footer: {
                    if coordinator.deferredCount > 0 {
                        Text(String(localized: "notifications.capacity.footer", bundle: .tinyStockCore))
                    }
                }
            }

            if let issue = coordinator.issue {
                Section {
                    Label(issue.localizedMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    Button(String(localized: "notifications.retry", bundle: .tinyStockCore)) {
                        Task {
                            if issue == .permission { await coordinator.setEnabled(coordinator.settings.isEnabled) }
                            else { await coordinator.refresh() }
                        }
                    }
                    .disabled(coordinator.isSynchronizing || coordinator.isRequestingPermission)
                }
            }
        }
        .navigationTitle(String(localized: "notifications.title", bundle: .tinyStockCore))
        .navigationBarTitleDisplayMode(.inline)
        .task { await coordinator.refresh() }
    }

    private func preference(_ keyPath: WritableKeyPath<OrderReminderSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { coordinator.settings[keyPath: keyPath] },
            set: { value in
                Task {
                    // Le a versao mais recente para nao sobrescrever outro controle alterado em seguida.
                    var settings = coordinator.settings
                    settings[keyPath: keyPath] = value
                    await coordinator.update(settings)
                }
            }
        )
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                calendar.date(from: DateComponents(
                    year: 2026, month: 1, day: 15,
                    hour: coordinator.settings.hour, minute: coordinator.settings.minute
                )) ?? Date()
            },
            set: { date in
                let components = calendar.dateComponents([.hour, .minute], from: date)
                Task {
                    var settings = coordinator.settings
                    settings.hour = components.hour ?? settings.hour
                    settings.minute = components.minute ?? settings.minute
                    await coordinator.update(settings)
                }
            }
        )
    }

    private var authorizationText: String {
        switch coordinator.authorization {
        case .notDetermined: String(localized: "notifications.authorization.notDetermined", bundle: .tinyStockCore)
        case .denied: String(localized: "notifications.authorization.denied", bundle: .tinyStockCore)
        case .authorized: String(localized: "notifications.authorization.authorized", bundle: .tinyStockCore)
        case .provisional: String(localized: "notifications.authorization.provisional", bundle: .tinyStockCore)
        case .unknown: String(localized: "notifications.authorization.unknown", bundle: .tinyStockCore)
        }
    }
}
