// ⌘
//  TinyStockCore/Models/Product.swift
//
//  Propósito: Model SwiftData que representa um produto no estoque, com custo, preço e alerta de estoque baixo.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-07.
// ⌘

import Foundation
import SwiftData

// MARK: - Modelo SwiftData

/// Product representa um item do catálogo de uma loja.
/// Cada propriedade tem valor padrão para manter o model compatível com o CloudKit.
@Model
public final class Product {

    /// Identificador estável usado no backup JSON e no snapshot da venda.
    /// Não usa `.unique`, pois essa restrição é incompatível com o CloudKit.
    public var id: UUID = UUID()

    /// Loja dona do produto. O UUID simples permite consultas e exclusões por escopo.
    public var storeID: UUID = StoreScope.unassignedStoreID

    /// Nome do produto exibido nas listas.
    public var name: String = ""

    /// Campo legado preservado para restaurar backups do schema anterior.
    public var category: String = ""

    /// Estoque legado preservado para restaurar backups do schema anterior.
    public var quantity: Int = 0

    /// Alerta legado preservado para restaurar backups do schema anterior.
    public var minimumStock: Int = 0

    /// Custo unitário de produção ou compra. Decimal evita erro de ponto flutuante com dinheiro.
    public var costPrice: Decimal = 0

    /// Preço de venda unitário.
    public var salePrice: Decimal = 0

    /// Foto opcional armazenada fora do banco principal para reduzir o custo das consultas.
    @Attribute(.externalStorage) public var imageData: Data?

    /// Data de cadastro.
    public var createdAt: Date = Date()

    /// Data da última edição.
    public var updatedAt: Date = Date()

    // MARK: - Inicializador

    public init(
        id: UUID = UUID(),
        storeID: UUID = StoreScope.unassignedStoreID,
        name: String = "",
        category: String = "",
        quantity: Int = 0,
        minimumStock: Int = 0,
        costPrice: Decimal = 0,
        salePrice: Decimal = 0,
        imageData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.storeID = storeID
        self.name = name
        self.category = category
        self.quantity = quantity
        self.minimumStock = minimumStock
        self.costPrice = costPrice
        self.salePrice = salePrice
        self.imageData = imageData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Derivados (não persistidos)

    /// Indica se o estoque atingiu ou ficou abaixo do mínimo configurado.
    public var isLowStock: Bool {
        minimumStock > 0 && quantity <= minimumStock
    }

    /// Lucro unitário estimado (preço de venda menos custo).
    public var unitProfit: Decimal {
        salePrice - costPrice
    }

    /// Quanto o estoque parado ainda pode render, se tudo que existe hoje for vendido.
    public var potentialProfit: Decimal {
        unitProfit * Decimal(quantity)
    }

    // MARK: - Busca

    /// Verifica o texto digitado no nome e na categoria legada.
    ///
    /// `localizedStandardContains` ignora diferenças de maiúsculas e acentos.
    /// Texto vazio mantém todos os produtos no resultado.
    public func matches(searchText: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        return name.localizedStandardContains(query)
            || category.localizedStandardContains(query)
    }

    /// Busca no catálogo atual usando o nome do produto e suas variações.
    public func matches(searchText: String, variants: [ProductVariant]) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || name.localizedStandardContains(query) || variants.contains {
            $0.belongs(to: self) && !$0.isDefault && $0.name.localizedStandardContains(query)
        }
    }
}
