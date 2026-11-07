// Proposito: Calcular lembretes de producao e despacho por dia civil e estado atual.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-07.

import Foundation

public enum OrderReminderPlanner {
    /// Recebe todas as lojas e pedidos. A loja selecionada na interface nao restringe alertas.
    /// Nao agenda no passado nem repete atrasos antigos a cada abertura do aplicativo.
    @MainActor
    public static func reminders(
        orders: [SalesOrder], stores: [StoreProfile], settings: OrderReminderSettings,
        now: Date = Date(), calendar: Calendar = .current
    ) throws -> [OrderReminder] {
        guard settings.isEnabled else { return [] }
        guard settings.hasValidTime else { throw OrderReminderError.invalidTime }
        let activeStores = stores.filter { !$0.isArchived && $0.id != StoreScope.unassignedStoreID }
        var result: [OrderReminder] = []
        for order in orders {
            guard let store = activeStores.first(where: { $0.id == order.storeID }) else { continue }
            var deadlines: [(OrderReminder.Kind, Date)] = []
            switch order.status {
            case .awaitingProduction, .inProduction:
                if settings.productionEnabled, let date = order.productionDueAt { deadlines.append((.production, date)) }
                if settings.shippingEnabled, let date = order.shippingDueAt { deadlines.append((.shipping, date)) }
            case .readyToShip:
                if settings.shippingEnabled, let date = order.shippingDueAt { deadlines.append((.shipping, date)) }
            default:
                continue
            }

            var timings: [(OrderReminder.Timing, Int)] = []
            if settings.dayBeforeEnabled { timings.append((.dayBefore, -1)) }
            if settings.dueDayEnabled { timings.append((.dueDay, 0)) }
            if settings.overdueEnabled { timings.append((.overdue, 1)) }

            for (kind, deadline) in deadlines {
                guard deadline.timeIntervalSinceReferenceDate.isFinite else { continue }
                for (timing, offset) in timings {
                    guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: deadline)),
                          let fireDate = calendar.date(
                            bySettingHour: settings.hour, minute: settings.minute, second: 0, of: day,
                            matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward
                          ), calendar.isDate(fireDate, inSameDayAs: day), fireDate > now else { continue }
                    // O aviso identifica loja e produto sem incluir nome ou dados do comprador.
                    let product = order.itemList.first?.productName
                        ?? String(localized: "reminder.product.fallback", bundle: .tinyStockCore)
                    let body = String(format: String(localized: "reminder.body", bundle: .tinyStockCore), store.name, product)
                    result.append(OrderReminder(
                        storeID: store.id, orderID: order.id, kind: kind, timing: timing,
                        fireDate: fireDate, title: title(kind: kind, timing: timing),
                        body: body, soundEnabled: settings.soundEnabled
                    ))
                }
            }
        }
        return result.sorted {
            $0.fireDate == $1.fireDate ? $0.id < $1.id : $0.fireDate < $1.fireDate
        }
    }

    private static func title(kind: OrderReminder.Kind, timing: OrderReminder.Timing) -> String {
        switch (kind, timing) {
        case (.production, .dayBefore): String(localized: "reminder.production.tomorrow", bundle: .tinyStockCore)
        case (.production, .dueDay): String(localized: "reminder.production.today", bundle: .tinyStockCore)
        case (.production, .overdue): String(localized: "reminder.production.overdue", bundle: .tinyStockCore)
        case (.shipping, .dayBefore): String(localized: "reminder.shipping.tomorrow", bundle: .tinyStockCore)
        case (.shipping, .dueDay): String(localized: "reminder.shipping.today", bundle: .tinyStockCore)
        case (.shipping, .overdue): String(localized: "reminder.shipping.overdue", bundle: .tinyStockCore)
        }
    }
}
