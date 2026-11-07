// Proposito: Acompanhar o pedido operacional, seus prazos e retratos financeiros.
// Created by Jonathas Motta (@jonathaxs) on 2026-08-31.

import Foundation
import SwiftData

/// Modelo novo, independente de Sale. Defaults e relacoes opcionais preparam o schema para CloudKit.
@Model
public final class SalesOrder {
    public var id: UUID = UUID()
    public var storeID: UUID = StoreScope.unassignedStoreID
    public var channelRawValue: String = SalesChannel.direct.rawValue
    public var customChannelName: String = ""
    public var fulfillmentRawValue: String = OrderFulfillment.readyStock.rawValue
    public var statusRawValue: String = SalesOrderStatus.new.rawValue

    public var buyerName: String = ""
    public var externalReference: String = ""
    public var orderedAt: Date = Date()
    public var productionDueAt: Date?
    public var shippingDueAt: Date?

    /// Prazo planejado e data efetiva sao separados para medir o que foi realizado.
    public var productionStartedAt: Date?
    public var producedAt: Date?
    public var shippedAt: Date?
    public var completedAt: Date?
    public var cancelledAt: Date?
    public var cancellationReason: String = ""
    public var trackingCode: String = ""
    public var note: String = ""

    /// Valores do momento da venda, sem consultar taxas atuais do marketplace.
    public var channelFeePercentage: Decimal = 0
    public var channelFeeAmount: Decimal = 0
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \SalesOrderItem.order)
    public var items: [SalesOrderItem]?

    public init(
        id: UUID = UUID(),
        storeID: UUID = StoreScope.unassignedStoreID,
        channel: SalesChannel = .direct,
        customChannelName: String = "",
        fulfillment: OrderFulfillment = .readyStock,
        status: SalesOrderStatus? = nil,
        buyerName: String = "",
        externalReference: String = "",
        orderedAt: Date = Date(),
        productionDueAt: Date? = nil,
        shippingDueAt: Date? = nil,
        cancellationReason: String = "",
        trackingCode: String = "",
        note: String = "",
        channelFeePercentage: Decimal = 0,
        channelFeeAmount: Decimal = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.storeID = storeID
        channelRawValue = channel.rawValue
        self.customChannelName = customChannelName
        fulfillmentRawValue = fulfillment.rawValue
        statusRawValue = (status ?? fulfillment.initialStatus).rawValue
        self.buyerName = buyerName
        self.externalReference = externalReference
        self.orderedAt = orderedAt
        self.productionDueAt = productionDueAt
        self.shippingDueAt = shippingDueAt
        self.cancellationReason = cancellationReason
        self.trackingCode = trackingCode
        self.note = note
        self.channelFeePercentage = channelFeePercentage
        self.channelFeeAmount = channelFeeAmount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Valores desconhecidos permanecem no banco, mas nao liberam operacoes por um fallback silencioso.
    public var channel: SalesChannel? { SalesChannel(rawValue: channelRawValue) }
    public var fulfillment: OrderFulfillment? { OrderFulfillment(rawValue: fulfillmentRawValue) }
    public var status: SalesOrderStatus? { SalesOrderStatus(rawValue: statusRawValue) }

    public var channelDisplayName: String {
        guard let channel else { return String(localized: "order.channel.unknown", bundle: .tinyStockCore) }
        let name = customChannelName.trimmingCharacters(in: .whitespacesAndNewlines)
        return channel == .other && !name.isEmpty ? name : channel.localizedName
    }

    public var itemList: [SalesOrderItem] {
        (items ?? []).sorted {
            $0.position == $1.position ? $0.id.uuidString < $1.id.uuidString : $0.position < $1.position
        }
    }

    /// O total pode ultrapassar Int.max quando o pedido agrega varias linhas validas.
    public var totalQuantity: Decimal { itemList.reduce(Decimal.zero) { $0 + Decimal($1.quantity) } }
    public var total: Decimal { itemList.reduce(Decimal.zero) { $0 + $1.subtotal } }
    public var totalCost: Decimal { itemList.reduce(Decimal.zero) { $0 + $1.subtotalCost } }
    public var grossProfit: Decimal { total - totalCost }
    public var netProfit: Decimal { grossProfit - channelFeeAmount }

    /// Consulta pura. As alterações de estado, datas e estoque pertencem ao serviço de gerenciamento.
    public func canTransition(to next: SalesOrderStatus) -> Bool {
        guard let status, let fulfillment else { return false }
        return status.canTransition(to: next, fulfillment: fulfillment)
    }
}
