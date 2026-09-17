// Proposito: Representar o banco do TinyStock em um arquivo JSON versionado.
// Created by Jonathas Motta (@jonathaxs) on 2026-08-16.

import Foundation

public struct BackupPayload: Codable, Equatable, Sendable {
    public let version: Int
    public let exportedAt: Date
    public let products: [ProductSnapshot]
    public let sales: [SaleSnapshot]
    public let selectedStoreID: UUID?
    public let stores: [StoreSnapshot]
    public let variants: [ProductVariantSnapshot]
    public let stockMovements: [StockMovementSnapshot]
    public let orders: [SalesOrderSnapshot]

    public init(
        version: Int,
        exportedAt: Date,
        products: [ProductSnapshot],
        sales: [SaleSnapshot],
        selectedStoreID: UUID? = nil,
        stores: [StoreSnapshot] = [],
        variants: [ProductVariantSnapshot] = [],
        stockMovements: [StockMovementSnapshot] = [],
        orders: [SalesOrderSnapshot] = []
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.products = products
        self.sales = sales
        self.selectedStoreID = selectedStoreID
        self.stores = stores
        self.variants = variants
        self.stockMovements = stockMovements
        self.orders = orders
    }

    private enum CodingKeys: String, CodingKey {
        case version, exportedAt, products, sales, selectedStoreID, stores
        case variants, stockMovements, orders
    }

    /// Campos do dominio novo nao existem nos arquivos v1.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        // As duas colecoes existem desde a v1; a ausencia indica arquivo truncado.
        products = try container.decode([ProductSnapshot].self, forKey: .products)
        sales = try container.decode([SaleSnapshot].self, forKey: .sales)
        selectedStoreID = try container.decodeIfPresent(UUID.self, forKey: .selectedStoreID)
        stores = try container.decodeIfPresent([StoreSnapshot].self, forKey: .stores) ?? []
        variants = try container.decodeIfPresent([ProductVariantSnapshot].self, forKey: .variants) ?? []
        stockMovements = try container.decodeIfPresent([StockMovementSnapshot].self, forKey: .stockMovements) ?? []
        orders = try container.decodeIfPresent([SalesOrderSnapshot].self, forKey: .orders) ?? []
    }

    public var isLegacy: Bool { version == 1 }

    public var summary: BackupSummary {
        if isLegacy {
            return BackupSummary(storeCount: 1, productCount: products.count,
                                 variantCount: products.count, orderCount: sales.count)
        }
        return BackupSummary(storeCount: stores.count, productCount: products.count,
                             variantCount: variants.count, orderCount: orders.count)
    }

    public struct StoreSnapshot: Codable, Equatable, Sendable {
        public let id: UUID
        public let name: String
        public let imageData: Data?
        public let isArchived: Bool
        public let archivedAt: Date?
        public let trashedAt: Date?
        public let wasArchivedBeforeTrash: Bool
        public let sortOrder: Int
        public let createdAt: Date
        public let updatedAt: Date

        public init(id: UUID, name: String, imageData: Data?, isArchived: Bool,
                    archivedAt: Date? = nil, trashedAt: Date? = nil,
                    wasArchivedBeforeTrash: Bool = false,
                    sortOrder: Int = 0, createdAt: Date, updatedAt: Date) {
            self.id = id
            self.name = name
            self.imageData = imageData
            self.isArchived = isArchived
            self.archivedAt = archivedAt
            self.trashedAt = trashedAt
            self.wasArchivedBeforeTrash = wasArchivedBeforeTrash
            self.sortOrder = sortOrder
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        private enum CodingKeys: String, CodingKey {
            case id, name, imageData, isArchived, archivedAt, trashedAt
            case wasArchivedBeforeTrash, sortOrder, createdAt, updatedAt
        }

        /// Backups v2 anteriores a ordenacao continuam validos com a ordem inicial.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
            isArchived = try container.decode(Bool.self, forKey: .isArchived)
            archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
            trashedAt = try container.decodeIfPresent(Date.self, forKey: .trashedAt)
            wasArchivedBeforeTrash = try container.decodeIfPresent(
                Bool.self, forKey: .wasArchivedBeforeTrash
            ) ?? false
            sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
            createdAt = try container.decode(Date.self, forKey: .createdAt)
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        }
    }

    public struct ProductSnapshot: Codable, Equatable, Sendable {
        public let id: UUID
        public let name: String
        public let category: String
        public let quantity: Int
        public let minimumStock: Int
        public let costPrice: Decimal
        public let salePrice: Decimal
        public let imageData: Data?
        public let createdAt: Date
        public let updatedAt: Date
        public let storeID: UUID?

        public init(
            id: UUID, name: String, category: String, quantity: Int, minimumStock: Int,
            costPrice: Decimal, salePrice: Decimal, imageData: Data?,
            createdAt: Date, updatedAt: Date, storeID: UUID? = nil
        ) {
            self.id = id
            self.name = name
            self.category = category
            self.quantity = quantity
            self.minimumStock = minimumStock
            self.costPrice = costPrice
            self.salePrice = salePrice
            self.imageData = imageData
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.storeID = storeID
        }
    }

    public struct ProductVariantSnapshot: Codable, Equatable, Sendable {
        public let id: UUID
        public let storeID: UUID
        public let productID: UUID
        public let name: String
        public let isDefault: Bool
        public let quantity: Int
        public let createdAt: Date
        public let updatedAt: Date

        public init(id: UUID, storeID: UUID, productID: UUID, name: String, isDefault: Bool = false,
                    quantity: Int, createdAt: Date, updatedAt: Date) {
            self.id = id
            self.storeID = storeID
            self.productID = productID
            self.name = name
            self.isDefault = isDefault
            self.quantity = quantity
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        private enum CodingKeys: String, CodingKey {
            case id, storeID, productID, name, isDefault, quantity, createdAt, updatedAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            storeID = try container.decode(UUID.self, forKey: .storeID)
            productID = try container.decode(UUID.self, forKey: .productID)
            name = try container.decode(String.self, forKey: .name)
            isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
            quantity = try container.decode(Int.self, forKey: .quantity)
            createdAt = try container.decode(Date.self, forKey: .createdAt)
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        }
    }

    public struct StockMovementSnapshot: Codable, Equatable, Sendable {
        public let id: UUID
        public let storeID: UUID
        public let productID: UUID
        public let variantID: UUID
        public let kind: String
        public let quantityDelta: Int
        public let balanceAfter: Int
        public let note: String
        public let referenceID: UUID?
        public let reversedMovementID: UUID?
        public let reversedAt: Date?
        public let createdAt: Date

        public init(
            id: UUID, storeID: UUID, productID: UUID, variantID: UUID, kind: String,
            quantityDelta: Int, balanceAfter: Int, note: String, referenceID: UUID?,
            reversedMovementID: UUID?, reversedAt: Date?, createdAt: Date
        ) {
            self.id = id
            self.storeID = storeID
            self.productID = productID
            self.variantID = variantID
            self.kind = kind
            self.quantityDelta = quantityDelta
            self.balanceAfter = balanceAfter
            self.note = note
            self.referenceID = referenceID
            self.reversedMovementID = reversedMovementID
            self.reversedAt = reversedAt
            self.createdAt = createdAt
        }
    }

    public struct SalesOrderSnapshot: Codable, Equatable, Sendable {
        public let id: UUID
        public let storeID: UUID
        public let channel: String
        public let customChannelName: String
        public let fulfillment: String
        public let status: String
        public let buyerName: String
        public let externalReference: String
        public let orderedAt: Date
        public let productionDueAt: Date?
        public let shippingDueAt: Date?
        public let productionStartedAt: Date?
        public let producedAt: Date?
        public let shippedAt: Date?
        public let completedAt: Date?
        public let cancelledAt: Date?
        public let cancellationReason: String
        public let trackingCode: String
        public let note: String
        public let channelFeePercentage: Decimal
        public let channelFeeAmount: Decimal
        public let createdAt: Date
        public let updatedAt: Date
        public let items: [SalesOrderItemSnapshot]

        public init(
            id: UUID, storeID: UUID, channel: String, customChannelName: String,
            fulfillment: String, status: String, buyerName: String,
            externalReference: String, orderedAt: Date, productionDueAt: Date?,
            shippingDueAt: Date?, productionStartedAt: Date?, producedAt: Date?,
            shippedAt: Date?, completedAt: Date?, cancelledAt: Date?,
            cancellationReason: String, trackingCode: String, note: String,
            channelFeePercentage: Decimal, channelFeeAmount: Decimal,
            createdAt: Date, updatedAt: Date, items: [SalesOrderItemSnapshot]
        ) {
            self.id = id
            self.storeID = storeID
            self.channel = channel
            self.customChannelName = customChannelName
            self.fulfillment = fulfillment
            self.status = status
            self.buyerName = buyerName
            self.externalReference = externalReference
            self.orderedAt = orderedAt
            self.productionDueAt = productionDueAt
            self.shippingDueAt = shippingDueAt
            self.productionStartedAt = productionStartedAt
            self.producedAt = producedAt
            self.shippedAt = shippedAt
            self.completedAt = completedAt
            self.cancelledAt = cancelledAt
            self.cancellationReason = cancellationReason
            self.trackingCode = trackingCode
            self.note = note
            self.channelFeePercentage = channelFeePercentage
            self.channelFeeAmount = channelFeeAmount
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.items = items
        }
    }

    public struct SalesOrderItemSnapshot: Codable, Equatable, Sendable {
        public let id: UUID
        public let storeID: UUID
        public let productID: UUID
        public let variantID: UUID
        public let productName: String
        public let variantName: String
        public let unitPrice: Decimal
        public let unitCost: Decimal
        public let quantity: Int
        public let position: Int

        public init(id: UUID, storeID: UUID, productID: UUID, variantID: UUID,
                    productName: String, variantName: String, unitPrice: Decimal,
                    unitCost: Decimal, quantity: Int, position: Int) {
            self.id = id
            self.storeID = storeID
            self.productID = productID
            self.variantID = variantID
            self.productName = productName
            self.variantName = variantName
            self.unitPrice = unitPrice
            self.unitCost = unitCost
            self.quantity = quantity
            self.position = position
        }
    }

    // Formato preservado exclusivamente para importar backups v1.
    public struct SaleSnapshot: Codable, Equatable, Sendable {
        public let id: UUID
        public let date: Date
        public let paymentMethod: String
        public let note: String
        public let channelFeePercentage: Decimal
        public let channelFeeAmount: Decimal
        public let items: [SaleItemSnapshot]

        public init(id: UUID, date: Date, paymentMethod: String, note: String,
                    channelFeePercentage: Decimal = 0, channelFeeAmount: Decimal = 0,
                    items: [SaleItemSnapshot]) {
            self.id = id
            self.date = date
            self.paymentMethod = paymentMethod
            self.note = note
            self.channelFeePercentage = channelFeePercentage
            self.channelFeeAmount = channelFeeAmount
            self.items = items
        }

        private enum CodingKeys: String, CodingKey {
            case id, date, paymentMethod, note, channelFeePercentage, channelFeeAmount, items
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            date = try container.decode(Date.self, forKey: .date)
            paymentMethod = try container.decode(String.self, forKey: .paymentMethod)
            note = try container.decode(String.self, forKey: .note)
            channelFeePercentage = try container.decodeIfPresent(Decimal.self, forKey: .channelFeePercentage) ?? 0
            channelFeeAmount = try container.decodeIfPresent(Decimal.self, forKey: .channelFeeAmount) ?? 0
            items = try container.decode([SaleItemSnapshot].self, forKey: .items)
        }
    }

    public struct SaleItemSnapshot: Codable, Equatable, Sendable {
        public let id: UUID
        public let productID: UUID
        public let productName: String
        public let unitPrice: Decimal
        public let unitCost: Decimal
        public let quantity: Int

        public init(id: UUID, productID: UUID, productName: String,
                    unitPrice: Decimal, unitCost: Decimal, quantity: Int) {
            self.id = id
            self.productID = productID
            self.productName = productName
            self.unitPrice = unitPrice
            self.unitCost = unitCost
            self.quantity = quantity
        }
    }
}

public struct BackupSummary: Equatable, Sendable {
    public let storeCount: Int
    public let productCount: Int
    public let variantCount: Int
    public let orderCount: Int
}

public struct BackupRestoreResult: Equatable, Sendable {
    public let selectedStoreID: UUID
    public let migratedLegacyBackup: Bool
    public let summary: BackupSummary
}
