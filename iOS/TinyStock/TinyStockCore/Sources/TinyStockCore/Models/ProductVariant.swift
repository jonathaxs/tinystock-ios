// ⌘
//  TinyStockCore/Models/ProductVariant.swift
//
//  Propósito: Representar uma opção vendável de produto com estoque próprio.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-27.
// ⌘

import Foundation
import SwiftData

/// Variação livre, como Azul, Tamanho M ou Edição especial.
/// Os identificadores explícitos mantêm produto e loja isolados sem relações obrigatórias,
/// preservando a compatibilidade com o CloudKit.
@Model
public final class ProductVariant {

    /// Nome persistido apenas para a variacao interna que representa produtos sem opcoes.
    public static let internalDefaultName = "__tinystock_default__"

    public var id: UUID = UUID()

    /// Loja herdada do produto para permitir consultas eficientes por escopo.
    public var storeID: UUID = StoreScope.unassignedStoreID

    /// Produto dono da variação.
    public var productID: UUID = UUID()

    /// Nome livre escolhido pelo comerciante.
    public var name: String = ""

    /// Distingue a variacao tecnica que nao deve aparecer na interface.
    public var isDefault: Bool = false

    /// Saldo atual, alterado exclusivamente pelos serviços de estoque e pedidos.
    public var quantity: Int = 0

    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        id: UUID = UUID(),
        storeID: UUID = StoreScope.unassignedStoreID,
        productID: UUID = UUID(),
        name: String = "",
        isDefault: Bool = false,
        quantity: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.storeID = storeID
        self.productID = productID
        self.name = name
        self.isDefault = isDefault
        self.quantity = quantity
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Confere os dois níveis do escopo para evitar associação cruzada.
    public func belongs(to product: Product) -> Bool {
        productID == product.id && storeID == product.storeID
    }
}
