// Proposito: Definir as transicoes operacionais sem executar efeitos no estoque.
// Created by Jonathas Motta (@jonathaxs) on 2026-08-31.

import Foundation

public enum SalesOrderStatus: String, CaseIterable, Codable, Sendable {
    case new
    case awaitingProduction
    case inProduction
    case readyToShip
    case shipped
    case completed
    case cancelled

    public var localizedName: String {
        switch self {
        case .new: String(localized: "order.status.new", bundle: .tinyStockCore)
        case .awaitingProduction: String(localized: "order.status.awaitingProduction", bundle: .tinyStockCore)
        case .inProduction: String(localized: "order.status.inProduction", bundle: .tinyStockCore)
        case .readyToShip: String(localized: "order.status.readyToShip", bundle: .tinyStockCore)
        case .shipped: String(localized: "order.status.shipped", bundle: .tinyStockCore)
        case .completed: String(localized: "order.status.completed", bundle: .tinyStockCore)
        case .cancelled: String(localized: "order.status.cancelled", bundle: .tinyStockCore)
        }
    }

    public var isTerminal: Bool { self == .completed || self == .cancelled }

    public func allowedNextStatuses(for fulfillment: OrderFulfillment) -> [SalesOrderStatus] {
        switch self {
        case .new:
            [fulfillment.initialStatus, .cancelled]
        case .awaitingProduction:
            // A acao rapida de marcar como produzido pode pular o inicio explicito da producao.
            fulfillment == .production ? [.inProduction, .readyToShip, .cancelled] : []
        case .inProduction:
            fulfillment == .production ? [.readyToShip, .cancelled] : []
        case .readyToShip:
            [.shipped, .cancelled]
        case .shipped:
            // Devolucao apos envio nao e cancelamento simples com reposicao automatica.
            [.completed]
        case .completed, .cancelled:
            []
        }
    }

    public func canTransition(to next: SalesOrderStatus, fulfillment: OrderFulfillment) -> Bool {
        allowedNextStatuses(for: fulfillment).contains(next)
    }
}
