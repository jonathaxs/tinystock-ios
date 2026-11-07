// ⌘
//  TinyStockCore/Models/SaleItem.swift
//
//  Propósito: Item de uma venda, guardando o retrato do produto no momento em que ela aconteceu.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-11.
// ⌘

import Foundation
import SwiftData

// MARK: - Item da venda

/// Uma linha da venda: qual produto, quantos e por quanto.
///
/// Não possui relação com `Product`. O item guarda uma cópia do nome, preço e custo
/// para preservar o histórico quando o catálogo for alterado ou excluído.
@Model
public final class SaleItem {

    public var id: UUID = UUID()

    /// Identificador do produto usado para agregar os rankings dos relatórios.
    /// Não é uma relação, então excluir o produto não apaga a venda.
    public var productID: UUID = UUID()

    /// Nome do produto como estava no dia da venda.
    public var productName: String = ""

    /// Preço unitário cobrado nessa venda.
    public var unitPrice: Decimal = 0

    /// Custo unitário na data da venda, usado para calcular o lucro do período.
    public var unitCost: Decimal = 0

    public var quantity: Int = 0

    /// Venda dona deste item. Opcional porque o CloudKit exige relação opcional.
    public var sale: Sale?

    // MARK: - Inicializador

    public init(
        id: UUID = UUID(),
        productID: UUID = UUID(),
        productName: String = "",
        unitPrice: Decimal = 0,
        unitCost: Decimal = 0,
        quantity: Int = 0,
        sale: Sale? = nil
    ) {
        self.id = id
        self.productID = productID
        self.productName = productName
        self.unitPrice = unitPrice
        self.unitCost = unitCost
        self.quantity = quantity
        self.sale = sale
    }

    /// Cria o item já copiando os dados atuais do produto.
    ///
    /// Uma função estática evita conflito com o `init(backingData:)` gerado por `@Model`.
    public static func from(product: Product, quantity: Int) -> SaleItem {
        SaleItem(
            productID: product.id,
            productName: product.name,
            unitPrice: product.salePrice,
            unitCost: product.costPrice,
            quantity: quantity
        )
    }

    // MARK: - Derivados (não persistidos)

    /// Quanto essa linha somou na venda.
    public var subtotal: Decimal {
        unitPrice * Decimal(quantity)
    }

    /// Custo total dos itens desta linha.
    public var subtotalCost: Decimal {
        unitCost * Decimal(quantity)
    }

    /// Lucro da linha.
    public var profit: Decimal {
        subtotal - subtotalCost
    }
}
