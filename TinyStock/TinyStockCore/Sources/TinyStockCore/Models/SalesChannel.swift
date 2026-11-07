// Proposito: Identificar onde o pedido foi vendido, separado da forma de pagamento.
// Created by Jonathas Motta (@jonathaxs) on 2026-08-31.

import Foundation

public enum SalesChannel: String, CaseIterable, Codable, Sendable {
    case direct
    case shopee
    case mercadoLivre
    case other

    public var localizedName: String {
        switch self {
        case .direct: String(localized: "order.channel.direct", bundle: .tinyStockCore)
        case .shopee: String(localized: "order.channel.shopee", bundle: .tinyStockCore)
        case .mercadoLivre: String(localized: "order.channel.mercadoLivre", bundle: .tinyStockCore)
        case .other: String(localized: "order.channel.other", bundle: .tinyStockCore)
        }
    }
}
