// Proposito: Definir o atendimento do pedido e seu estado inicial.
// Created by Jonathas Motta (@jonathaxs) on 2026-08-31.

import Foundation

public enum OrderFulfillment: String, CaseIterable, Codable, Sendable {
    case readyStock
    case production

    public var localizedName: String {
        switch self {
        case .readyStock: String(localized: "order.fulfillment.readyStock", bundle: .tinyStockCore)
        case .production: String(localized: "order.fulfillment.production", bundle: .tinyStockCore)
        }
    }

    public var initialStatus: SalesOrderStatus {
        switch self {
        case .readyStock: .readyToShip
        case .production: .awaitingProduction
        }
    }
}
