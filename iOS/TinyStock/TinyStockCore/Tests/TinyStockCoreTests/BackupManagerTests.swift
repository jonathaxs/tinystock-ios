// Proposito: Garantir a integridade, compatibilidade e atomicidade do backup JSON.
// Created by Jonathas Motta (@jonathaxs) on 2026-08-16.

import Foundation
import SwiftData
import Testing
@testable import TinyStockCore

@Suite(.serialized)
@MainActor
struct BackupManagerTests {
    private let reference = Date(timeIntervalSince1970: 1_786_838_400.125)

    private enum SaveFailure: Error, Equatable {
        case simulated
    }

    private func makeContext() throws -> ModelContext {
        let context = try TestDatabase.makeCleanContext()
        context.autosaveEnabled = false
        return context
    }

    @Test func exportacaoV2PreservaDominioCompletoEIgnoraRascunho() throws {
        let context = try makeContext()
        let activeStore = StoreProfile(
            name: "Loja Principal", imageData: Data([0x01, 0x02]),
            sortOrder: 4,
            createdAt: reference, updatedAt: reference.addingTimeInterval(1)
        )
        let archivedStore = StoreProfile(
            name: "Loja arquivada", imageData: Data([0x03]), isArchived: true,
            archivedAt: reference.addingTimeInterval(2),
            sortOrder: 9,
            createdAt: reference.addingTimeInterval(2), updatedAt: reference.addingTimeInterval(3)
        )
        let product = Product(
            storeID: activeStore.id, name: "Produto Premium", category: "Legado",
            quantity: 4, minimumStock: 1, costPrice: Decimal(string: "80.25")!,
            salePrice: Decimal(string: "179.90")!, imageData: Data([0x04, 0x05]),
            createdAt: reference.addingTimeInterval(4), updatedAt: reference.addingTimeInterval(5)
        )
        let variant = ProductVariant(
            storeID: activeStore.id, productID: product.id,
            name: ProductVariant.internalDefaultName, isDefault: true, quantity: 3,
            createdAt: reference.addingTimeInterval(6), updatedAt: reference.addingTimeInterval(7)
        )
        let movement = StockMovement(
            storeID: activeStore.id, productID: product.id, variantID: variant.id,
            kind: .entry, quantityDelta: 3, balanceAfter: 3, note: "Lote inicial",
            referenceID: UUID(), createdAt: reference.addingTimeInterval(8)
        )
        movement.kindRawValue = "futureMovement"
        let order = SalesOrder(
            storeID: activeStore.id, channel: .other, customChannelName: "Feira",
            fulfillment: .production, status: .inProduction, buyerName: "Ana",
            externalReference: "PED-42", orderedAt: reference.addingTimeInterval(9),
            productionDueAt: reference.addingTimeInterval(10),
            shippingDueAt: reference.addingTimeInterval(11),
            cancellationReason: "", trackingCode: "BR123", note: "Embalar bem",
            channelFeePercentage: Decimal(string: "12.5")!,
            channelFeeAmount: Decimal(string: "22.49")!,
            createdAt: reference.addingTimeInterval(12), updatedAt: reference.addingTimeInterval(13)
        )
        order.channelRawValue = "futureChannel"
        order.fulfillmentRawValue = "futureFulfillment"
        order.statusRawValue = "futureStatus"
        order.productionStartedAt = reference.addingTimeInterval(14)
        order.producedAt = reference.addingTimeInterval(15)
        order.shippedAt = reference.addingTimeInterval(16)
        order.completedAt = reference.addingTimeInterval(17)
        order.cancelledAt = reference.addingTimeInterval(18)
        let item = SalesOrderItem(
            storeID: activeStore.id, productID: product.id, variantID: variant.id,
            productName: "Produto Premium", variantName: "Preta",
            unitPrice: Decimal(string: "179.90")!, unitCost: Decimal(string: "80.25")!,
            quantity: 2, position: 3
        )

        for model in [activeStore, archivedStore] { context.insert(model) }
        context.insert(product)
        context.insert(variant)
        context.insert(movement)
        context.insert(order)
        context.insert(item)
        item.order = order
        try context.save()

        context.insert(Product(storeID: activeStore.id, name: "Rascunho nao salvo"))
        let firstData = try BackupManager.export(
            from: context, selectedStoreID: activeStore.id, exportedAt: reference
        )
        let secondData = try BackupManager.export(
            from: context, selectedStoreID: activeStore.id, exportedAt: reference
        )
        let payload = try BackupManager.decode(firstData)

        #expect(firstData == secondData)
        #expect(payload.version == 2)
        #expect(payload.exportedAt == reference)
        #expect(payload.selectedStoreID == activeStore.id)
        #expect(payload.summary == BackupSummary(storeCount: 2, productCount: 1, variantCount: 1, orderCount: 1))
        #expect(payload.stores.first(where: { $0.id == activeStore.id })?.imageData == Data([0x01, 0x02]))
        #expect(payload.stores.first(where: { $0.id == activeStore.id })?.sortOrder == 4)
        #expect(payload.stores.first(where: { $0.id == archivedStore.id })?.isArchived == true)
        #expect(payload.stores.first(where: { $0.id == archivedStore.id })?.archivedAt == archivedStore.archivedAt)
        #expect(payload.products.map(\.name) == ["Produto Premium"])
        #expect(payload.products.first?.imageData == Data([0x04, 0x05]))
        #expect(payload.products.first?.costPrice == Decimal(string: "80.25"))
        #expect(payload.variants.first?.quantity == 3)
        #expect(payload.variants.first?.isDefault == true)
        #expect(payload.stockMovements.first?.kind == "futureMovement")
        #expect(payload.stockMovements.first?.referenceID == movement.referenceID)

        let orderSnapshot = try #require(payload.orders.first)
        let itemSnapshot = try #require(orderSnapshot.items.first)
        #expect(orderSnapshot.channel == "futureChannel")
        #expect(orderSnapshot.fulfillment == "futureFulfillment")
        #expect(orderSnapshot.status == "futureStatus")
        #expect(orderSnapshot.productionStartedAt == reference.addingTimeInterval(14))
        #expect(orderSnapshot.cancelledAt == reference.addingTimeInterval(18))
        #expect(orderSnapshot.channelFeeAmount == Decimal(string: "22.49"))
        #expect(itemSnapshot.variantID == variant.id)
        #expect(itemSnapshot.position == 3)
    }

    @Test func restauracaoV2SubstituiBancoERemontaRelacionamentos() throws {
        let payload = makeV2Payload()
        let context = try makeContext()
        let oldStore = StoreProfile(name: "Loja antiga")
        context.insert(oldStore)
        context.insert(Product(storeID: oldStore.id, name: "Produto antigo"))
        let legacySale = Sale(storeID: oldStore.id)
        context.insert(legacySale)
        context.insert(SaleItem(productName: "Item antigo", quantity: 1, sale: legacySale))
        try context.save()

        let result = try BackupManager.apply(payload, into: context)

        #expect(result.selectedStoreID == payload.selectedStoreID)
        #expect(result.migratedLegacyBackup == false)
        #expect(result.summary == payload.summary)
        #expect(try context.fetchCount(FetchDescriptor<StoreProfile>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<Product>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<ProductVariant>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<StockMovement>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<SalesOrder>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SalesOrderItem>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Sale>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SaleItem>()) == 0)

        let restoredOrder = try #require(context.fetch(FetchDescriptor<SalesOrder>()).first)
        let restoredItem = try #require(restoredOrder.itemList.first)
        #expect(restoredOrder.channelRawValue == "futureChannel")
        #expect(restoredOrder.fulfillmentRawValue == "futureFulfillment")
        #expect(restoredOrder.statusRawValue == "futureStatus")
        #expect(restoredItem.order?.id == restoredOrder.id)
        #expect(restoredItem.productName == "Caneca")
        #expect(restoredOrder.total == Decimal(string: "79.80"))
        #expect(try context.fetch(FetchDescriptor<StoreProfile>()).first {
            $0.id == payload.selectedStoreID
        }?.sortOrder == 2)
        let restoredTrash = try #require(context.fetch(FetchDescriptor<StoreProfile>()).first {
            $0.trashedAt != nil
        })
        #expect(restoredTrash.lifecycleState == .trashed)
        #expect(restoredTrash.wasArchivedBeforeTrash)
    }

    @Test func restauracaoV2PreservaIdentidadeDeRegistrosExistentes() throws {
        let payload = makeV2Payload()
        let context = try makeContext()
        let storeSnapshot = try #require(payload.stores.first)
        let productSnapshot = try #require(payload.products.first)
        let store = StoreProfile(id: storeSnapshot.id, name: "Nome anterior")
        let product = Product(
            id: productSnapshot.id,
            storeID: storeSnapshot.id,
            name: "Produto anterior"
        )
        context.insert(store)
        context.insert(product)
        try context.save()
        let storeModelID = store.persistentModelID
        let productModelID = product.persistentModelID

        try BackupManager.apply(payload, into: context)

        let restoredStore = try #require(context.fetch(FetchDescriptor<StoreProfile>()).first {
            $0.id == storeSnapshot.id
        })
        let restoredProduct = try #require(context.fetch(FetchDescriptor<Product>()).first {
            $0.id == productSnapshot.id
        })
        #expect(restoredStore.persistentModelID == storeModelID)
        #expect(restoredProduct.persistentModelID == productModelID)
        #expect(restoredStore.name == storeSnapshot.name)
        #expect(restoredProduct.name == productSnapshot.name)
    }

    @Test func falhaAoSalvarDesfazTodaRestauracaoV2() throws {
        let context = try makeContext()
        let oldStore = StoreProfile(name: "Loja preservada")
        let oldProduct = Product(storeID: oldStore.id, name: "Produto preservado")
        context.insert(oldStore)
        context.insert(oldProduct)
        try context.save()

        #expect(throws: SaveFailure.simulated) {
            try BackupManager.apply(
                makeV2Payload(), into: context, storeID: oldStore.id,
                saving: { _ in throw SaveFailure.simulated }
            )
        }

        let reader = ModelContext(TestDatabase.container)
        #expect(try reader.fetch(FetchDescriptor<StoreProfile>()).map(\.name) == ["Loja preservada"])
        #expect(try reader.fetch(FetchDescriptor<Product>()).map(\.name) == ["Produto preservado"])
        #expect(try reader.fetchCount(FetchDescriptor<SalesOrder>()) == 0)
    }

    @Test func v2RecusaIdentificadoresDuplicadosEAssociacoesOrfas() throws {
        let valid = makeV2Payload()
        let duplicateProduct = BackupPayload(
            version: valid.version, exportedAt: valid.exportedAt,
            products: valid.products + [valid.products[0]], sales: [],
            selectedStoreID: valid.selectedStoreID, stores: valid.stores,
            variants: valid.variants, stockMovements: valid.stockMovements, orders: valid.orders
        )
        let orphanVariant = BackupPayload.ProductVariantSnapshot(
            id: valid.variants[0].id, storeID: valid.variants[0].storeID,
            productID: UUID(), name: valid.variants[0].name, quantity: valid.variants[0].quantity,
            createdAt: valid.variants[0].createdAt, updatedAt: valid.variants[0].updatedAt
        )
        let orphanPayload = BackupPayload(
            version: valid.version, exportedAt: valid.exportedAt,
            products: valid.products, sales: [], selectedStoreID: valid.selectedStoreID,
            stores: valid.stores, variants: [orphanVariant] + Array(valid.variants.dropFirst()),
            stockMovements: valid.stockMovements, orders: valid.orders
        )

        #expect(throws: BackupError.invalidFile) {
            try BackupManager.decode(encodeForTest(duplicateProduct))
        }
        #expect(throws: BackupError.invalidFile) {
            try BackupManager.decode(encodeForTest(orphanPayload))
        }
    }

    @Test func v2RecusaLojaSelecionadaArquivada() throws {
        let valid = makeV2Payload()
        let archivedID = try #require(valid.stores.first(where: \.isArchived)?.id)
        let payload = BackupPayload(
            version: valid.version, exportedAt: valid.exportedAt,
            products: valid.products, sales: [], selectedStoreID: archivedID,
            stores: valid.stores, variants: valid.variants,
            stockMovements: valid.stockMovements, orders: valid.orders
        )

        #expect(throws: BackupError.invalidFile) {
            try BackupManager.decode(encodeForTest(payload))
        }
    }

    @Test func arquivoV1EhMigradoNaLojaSelecionadaSemAfetarOutraLoja() throws {
        let context = try makeContext()
        let targetStore = StoreProfile(name: "Loja de destino")
        let otherStore = StoreProfile(name: "Outra loja")
        context.insert(targetStore)
        context.insert(otherStore)
        context.insert(Product(storeID: targetStore.id, name: "Produto substituido"))
        context.insert(Product(storeID: otherStore.id, name: "Produto preservado"))
        context.insert(SalesOrder(storeID: targetStore.id))
        context.insert(SalesOrder(storeID: otherStore.id))
        try context.save()

        let productID = UUID()
        let saleID = UUID()
        let itemID = UUID()
        let json = legacyJSON(productID: productID, saleID: saleID, itemID: itemID)
        let payload = try BackupManager.decode(Data(json.utf8))
        let result = try BackupManager.apply(payload, into: context, storeID: targetStore.id)

        #expect(result.selectedStoreID == targetStore.id)
        #expect(result.migratedLegacyBackup)
        let products = try context.fetch(FetchDescriptor<Product>())
        #expect(products.filter { $0.storeID == targetStore.id }.map(\.name) == ["Produto legado"])
        #expect(products.filter { $0.storeID == otherStore.id }.map(\.name) == ["Produto preservado"])

        let variant = try #require(context.fetch(FetchDescriptor<ProductVariant>()).first {
            $0.storeID == targetStore.id
        })
        #expect(variant.id == productID)
        #expect(variant.productID == productID)
        #expect(variant.quantity == 4)
        #expect(try context.fetch(FetchDescriptor<StockMovement>()).first {
            $0.storeID == targetStore.id
        }?.balanceAfter == 4)

        let targetOrder = try #require(context.fetch(FetchDescriptor<SalesOrder>()).first {
            $0.storeID == targetStore.id
        })
        #expect(targetOrder.id == saleID)
        #expect(targetOrder.channel == .shopee)
        #expect(targetOrder.status == .completed)
        #expect(targetOrder.shippedAt == Date(timeIntervalSince1970: 1_786_838_400))
        #expect(targetOrder.itemList.first?.id == itemID)
        #expect(targetOrder.itemList.first?.order?.id == saleID)
        #expect(try context.fetch(FetchDescriptor<SalesOrder>()).filter { $0.storeID == otherStore.id }.count == 1)
        #expect(try context.fetchCount(FetchDescriptor<Sale>()) == 0)
    }

    @Test func arquivoV1SemTaxaContinuaCompativel() throws {
        let payload = try BackupManager.decode(Data(legacyJSON(
            productID: UUID(), saleID: UUID(), itemID: UUID()
        ).utf8))
        let sale = try #require(payload.sales.first)

        #expect(payload.isLegacy)
        #expect(sale.channelFeePercentage == 0)
        #expect(sale.channelFeeAmount == 0)
        #expect(payload.summary == BackupSummary(storeCount: 1, productCount: 1, variantCount: 1, orderCount: 1))
    }

    @Test func arquivoV2SemOrdemDeLojaContinuaCompativel() throws {
        let data = try encodeForTest(makeV2Payload())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var stores = try #require(object["stores"] as? [[String: Any]])
        for index in stores.indices {
            stores[index].removeValue(forKey: "sortOrder")
        }
        object["stores"] = stores

        let oldData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try BackupManager.decode(oldData)

        #expect(decoded.stores.allSatisfy { $0.sortOrder == 0 })
    }

    @Test func arquivoV2SemMarcadorDeVariacaoContinuaCompativel() throws {
        let data = try encodeForTest(makeV2Payload())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var variants = try #require(object["variants"] as? [[String: Any]])
        for index in variants.indices {
            variants[index].removeValue(forKey: "isDefault")
        }
        object["variants"] = variants

        let oldData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try BackupManager.decode(oldData)

        #expect(decoded.variants.allSatisfy { !$0.isDefault })
    }

    @Test func arquivoV2SemMetadadosDaLixeiraContinuaCompativel() throws {
        let data = try encodeForTest(makeV2Payload())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var stores = try #require(object["stores"] as? [[String: Any]])
        for index in stores.indices {
            stores[index].removeValue(forKey: "archivedAt")
            stores[index].removeValue(forKey: "trashedAt")
            stores[index].removeValue(forKey: "wasArchivedBeforeTrash")
        }
        object["stores"] = stores

        let oldData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try BackupManager.decode(oldData)

        #expect(decoded.stores.allSatisfy {
            $0.archivedAt == nil && $0.trashedAt == nil && !$0.wasArchivedBeforeTrash
        })
    }

    @Test func migracaoV1RecusaLojaAusenteOuArquivadaSemApagarDados() throws {
        let context = try makeContext()
        let archivedStore = StoreProfile(name: "Arquivada", isArchived: true)
        let product = Product(storeID: archivedStore.id, name: "Preservado")
        context.insert(archivedStore)
        context.insert(product)
        try context.save()
        let payload = try BackupManager.decode(Data(legacyJSON(
            productID: UUID(), saleID: UUID(), itemID: UUID()
        ).utf8))

        #expect(throws: BackupError.invalidFile) {
            try BackupManager.apply(payload, into: context, storeID: archivedStore.id)
        }
        #expect(try context.fetch(FetchDescriptor<Product>()).map(\.name) == ["Preservado"])
    }

    @Test func versaoDesconhecidaEJsonInvalidoSaoRecusados() {
        let unsupported = Data(
            "{\"version\":99,\"exportedAt\":1786838400,\"products\":[],\"sales\":[]}".utf8
        )
        let truncatedV1 = Data("{\"version\":1,\"exportedAt\":1786838400}".utf8)

        #expect(throws: BackupError.unsupportedVersion(99)) {
            try BackupManager.decode(unsupported)
        }
        #expect(throws: BackupError.invalidFile) {
            try BackupManager.decode(truncatedV1)
        }
        #expect(throws: BackupError.invalidFile) {
            try BackupManager.decode(Data("nao e json".utf8))
        }
    }

    @Test func nomeSugeridoEErrosLocalizadosPermanecemEstaveis() {
        #expect(BackupManager.suggestedFilename(relativeTo: reference) == "tinystock-backup-2026-08-16.json")
        #expect(BackupError.invalidFile.localizedDescription.isEmpty == false)
        #expect(BackupError.unsupportedVersion(3).localizedDescription.isEmpty == false)
    }

    private func makeV2Payload() -> BackupPayload {
        let activeStoreID = UUID()
        let archivedStoreID = UUID()
        let productID = UUID()
        let archivedProductID = UUID()
        let variantID = UUID()
        let archivedVariantID = UUID()
        let movementID = UUID()
        let reversedMovementID = UUID()
        let orderID = UUID()

        return BackupPayload(
            version: 2,
            exportedAt: reference,
            products: [
                .init(
                    id: productID, name: "Caneca", category: "", quantity: 0,
                    minimumStock: 0, costPrice: Decimal(string: "10.20")!,
                    salePrice: Decimal(string: "39.90")!, imageData: Data([0x01]),
                    createdAt: reference, updatedAt: reference, storeID: activeStoreID
                ),
                .init(
                    id: archivedProductID, name: "Produto arquivado", category: "", quantity: 0,
                    minimumStock: 0, costPrice: 5, salePrice: 12, imageData: nil,
                    createdAt: reference, updatedAt: reference, storeID: archivedStoreID
                )
            ],
            sales: [],
            selectedStoreID: activeStoreID,
            stores: [
                .init(
                    id: activeStoreID, name: "Loja ativa", imageData: Data([0x02]),
                    isArchived: false, sortOrder: 2,
                    createdAt: reference, updatedAt: reference
                ),
                .init(
                    id: archivedStoreID, name: "Loja arquivada", imageData: nil,
                    isArchived: true, archivedAt: reference,
                    trashedAt: reference.addingTimeInterval(1),
                    wasArchivedBeforeTrash: true, sortOrder: 7,
                    createdAt: reference, updatedAt: reference
                )
            ],
            variants: [
                .init(
                    id: variantID, storeID: activeStoreID, productID: productID,
                    name: "Branca", quantity: 7, createdAt: reference, updatedAt: reference
                ),
                .init(
                    id: archivedVariantID, storeID: archivedStoreID,
                    productID: archivedProductID, name: "Unica", quantity: 1,
                    createdAt: reference, updatedAt: reference
                )
            ],
            stockMovements: [
                .init(
                    id: movementID, storeID: activeStoreID, productID: productID,
                    variantID: variantID, kind: StockMovementKind.entry.rawValue,
                    quantityDelta: 7, balanceAfter: 7, note: "Entrada",
                    referenceID: nil, reversedMovementID: nil, reversedAt: reference,
                    createdAt: reference
                ),
                .init(
                    id: reversedMovementID, storeID: activeStoreID, productID: productID,
                    variantID: variantID, kind: "futureMovement",
                    quantityDelta: 1, balanceAfter: 7, note: "Futuro",
                    referenceID: orderID, reversedMovementID: movementID,
                    reversedAt: nil, createdAt: reference
                )
            ],
            orders: [
                .init(
                    id: orderID, storeID: activeStoreID, channel: "futureChannel",
                    customChannelName: "Canal futuro", fulfillment: "futureFulfillment",
                    status: "futureStatus", buyerName: "Joao", externalReference: "ABC",
                    orderedAt: reference, productionDueAt: reference,
                    shippingDueAt: reference, productionStartedAt: reference,
                    producedAt: reference, shippedAt: reference, completedAt: reference,
                    cancelledAt: nil, cancellationReason: "", trackingCode: "TRACK",
                    note: "Observacao", channelFeePercentage: 10,
                    channelFeeAmount: Decimal(string: "7.98")!,
                    createdAt: reference, updatedAt: reference,
                    items: [
                        .init(
                            id: UUID(), storeID: activeStoreID, productID: productID,
                            variantID: variantID, productName: "Caneca", variantName: "Branca",
                            unitPrice: Decimal(string: "39.90")!,
                            unitCost: Decimal(string: "10.20")!, quantity: 2, position: 0
                        )
                    ]
                )
            ]
        )
    }

    private func encodeForTest(_ payload: BackupPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(payload)
    }

    private func legacyJSON(productID: UUID, saleID: UUID, itemID: UUID) -> String {
        """
        {
          "version": 1,
          "exportedAt": "2026-08-16T00:00:00Z",
          "products": [
            {
              "id": "\(productID.uuidString)",
              "name": "Produto legado",
              "category": "Categoria antiga",
              "quantity": 4,
              "minimumStock": 1,
              "costPrice": 10,
              "salePrice": 25,
              "createdAt": "2026-08-16T00:00:00Z",
              "updatedAt": "2026-08-16T00:00:00Z"
            }
          ],
          "sales": [
            {
              "id": "\(saleID.uuidString)",
              "date": "2026-08-16T00:00:00Z",
              "paymentMethod": "shopee",
              "note": "Pedido antigo",
              "items": [
                {
                  "id": "\(itemID.uuidString)",
                  "productID": "\(productID.uuidString)",
                  "productName": "Produto legado",
                  "unitPrice": 25,
                  "unitCost": 10,
                  "quantity": 2
                }
              ]
            }
          ]
        }
        """
    }
}
