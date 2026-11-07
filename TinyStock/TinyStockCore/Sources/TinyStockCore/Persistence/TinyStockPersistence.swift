// Proposito: Centralizar o schema, o arquivo local e o container privado do CloudKit.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-09.

import Foundation
import SwiftData

public enum TinyStockPersistence {
    public static let cloudContainerIdentifier = "iCloud.com.jonathaxs.TinyStock"
    public static let storeFilename = "TinyStock-v2.store"

    public static var schema: Schema {
        Schema([
            StoreProfile.self,
            Product.self,
            ProductVariant.self,
            StockMovement.self,
            SalesOrder.self,
            SalesOrderItem.self,
            Sale.self,
            SaleItem.self
        ])
    }

    public static var defaultStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: storeFilename)
    }

    /// Usa a base privada da Conta Apple. O arquivo SQLite continua no mesmo caminho
    /// usado antes da sincronizacao, permitindo que os dados locais sejam exportados.
    public static func cloudConfiguration(
        schema: Schema,
        url: URL = defaultStoreURL
    ) -> ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            url: url,
            cloudKitDatabase: .private(cloudContainerIdentifier)
        )
    }
}
