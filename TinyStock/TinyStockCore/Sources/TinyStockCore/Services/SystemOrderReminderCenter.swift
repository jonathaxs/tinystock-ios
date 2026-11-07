// Proposito: Adaptar o servico de lembretes ao UserNotifications da Apple.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-07.

import Foundation
import UserNotifications

@MainActor
public final class SystemOrderReminderCenter: OrderReminderCenter {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) { self.center = center }

    public func authorization() async -> OrderReminderAuthorization {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional: return .provisional
        #if os(iOS)
        case .ephemeral: return .authorized
        #endif
        @unknown default: return .unknown
        }
    }

    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    public func pendingRequests() async -> [PendingOrderReminder] {
        await center.pendingNotificationRequests().map {
            PendingOrderReminder(id: $0.identifier, signature: $0.content.userInfo["reminderSignature"] as? String)
        }
    }

    public func add(_ reminder: OrderReminder) async throws {
        try await center.add(Self.request(for: reminder))
    }

    public func removePending(identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        // A consulta seguinte acompanha a fila do centro antes de adicionar substitutos.
        _ = await center.pendingNotificationRequests()
    }

    /// Construcao pura tambem usada pelos testes, sem acessar o centro real do sistema.
    static func request(for reminder: OrderReminder) throws -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = reminder.soundEnabled ? .default : nil
        content.threadIdentifier = "tinystock.store.\(reminder.storeID.uuidString)"
        content.userInfo = [
            "storeID": reminder.storeID.uuidString,
            "orderID": reminder.orderID.uuidString,
            "reminderKind": reminder.kind.rawValue,
            "reminderSignature": try reminder.signature()
        ]
        // A data civil ja foi resolvida pelo planejador no fuso local. UTC preserva esse
        // instante, inclusive quando a hora se repete no fim do horario de verao.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
    }
}
