// Proposito: Receber alertas locais e conservar o destino ate a navegacao estar pronta.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-07.

import Observation
import UIKit
import UserNotifications
import TinyStockCore

@MainActor
@Observable
final class OrderReminderRouter {
    var request: OrderReminderRoute?
}

final class TinyStockAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let reminderRouter = OrderReminderRouter()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let route = OrderReminderRoute(
                identifier: response.notification.request.identifier,
                userInfo: response.notification.request.content.userInfo
              ) else { return }
        // Apenas o destino Sendable atravessa para o ator da interface.
        await MainActor.run { reminderRouter.request = route }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        guard notification.request.identifier.hasPrefix(OrderReminder.identifierPrefix) else { return [] }
        var options: UNNotificationPresentationOptions = [.banner, .list]
        if notification.request.content.sound != nil { options.insert(.sound) }
        return options
    }
}
