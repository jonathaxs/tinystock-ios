// ⌘
//  TinyStockCore/Services/SaleService.swift
//
//  Propósito: Registrar uma venda validando o estoque e dando baixa nos produtos.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-11.
// ⌘

import Foundation
import SwiftData

// MARK: - Erros da venda

/// Motivos pelos quais uma venda não pode ser registrada.
public enum SaleError: Error, Equatable, Sendable {

    /// Nenhum item foi escolhido.
    case emptySale

    /// Quantidade zero ou negativa em algum item.
    case invalidQuantity(productName: String)

    /// Estoque insuficiente com os valores necessários para explicar o bloqueio na interface.
    case insufficientStock(productName: String, available: Int, requested: Int)

    /// Percentual da taxa precisa ficar entre zero e cem.
    case invalidChannelFeePercentage

    /// Uma venda não pode misturar produtos de lojas diferentes.
    case mixedStores
}

public extension SaleError {

    /// Mensagem localizada para apresentação direta em alertas.
    var localizedMessage: String {
        switch self {
        case .emptySale:
            String(localized: "sale.error.emptySale", bundle: .tinyStockCore)

        case .invalidQuantity:
            String(localized: "sale.error.invalidQuantity", bundle: .tinyStockCore)

        case let .insufficientStock(productName, available, _):
            String(
                format: String(localized: "sale.error.insufficientStock", bundle: .tinyStockCore),
                available,
                productName
            )

        case .invalidChannelFeePercentage:
            String(localized: "sale.error.invalidChannelFeePercentage", bundle: .tinyStockCore)

        case .mixedStores:
            String(localized: "sale.error.mixedStores", bundle: .tinyStockCore)
        }
    }
}

// MARK: - Linha da venda em montagem

/// O que a tela monta antes de fechar a venda: um produto e quantas unidades.
///
/// Não é `Sendable` porque carrega um `@Model` vinculado ao contexto
/// do SwiftData e não pode atravessar threads.
public struct SaleLine {

    public let product: Product
    public let quantity: Int

    public init(product: Product, quantity: Int) {
        self.product = product
        self.quantity = quantity
    }
}

// MARK: - Registro da venda

/// Concentra a regra mais importante do app: vender dá baixa no estoque,
/// e limita a venda ao estoque disponível.
public enum SaleService {

    /// Valida as linhas, cria a venda e desconta o estoque dos produtos.
    ///
    /// Ou tudo funciona, ou nada é alterado: as validações acontecem todas antes
    /// de qualquer escrita, então uma venda recusada não deixa estoque pela metade.
    ///
    /// - Throws: `SaleError` quando a venda está vazia, tem quantidade inválida ou falta estoque.
    @discardableResult
    public static func register(
        lines: [SaleLine],
        paymentMethod: PaymentMethod,
        date: Date = Date(),
        note: String = "",
        channelFeePercentage: Decimal = 0,
        in context: ModelContext
    ) throws -> Sale {

        guard !lines.isEmpty else { throw SaleError.emptySale }

        // Valida as quantidades antes de calcular e alterar o estoque.
        for line in lines where line.quantity <= 0 {
            throw SaleError.invalidQuantity(productName: line.product.name)
        }

        // O mesmo produto pode ter sido adicionado duas vezes na tela. Somar antes de
        // validar evita liberar uma venda de 3 + 3 unidades quando só existem 5 em estoque.
        let mergedLines = merge(lines)
        let storeID = mergedLines[0].product.storeID

        guard mergedLines.allSatisfy({ $0.product.storeID == storeID }) else {
            throw SaleError.mixedStores
        }

        for line in mergedLines where line.quantity > line.product.quantity {
            throw SaleError.insufficientStock(
                productName: line.product.name,
                available: line.product.quantity,
                requested: line.quantity
            )
        }

        guard channelFeePercentage >= 0, channelFeePercentage <= 100 else {
            throw SaleError.invalidChannelFeePercentage
        }

        let revenue = mergedLines.reduce(Decimal.zero) {
            $0 + $1.product.salePrice * Decimal($1.quantity)
        }
        let channelFeeAmount: Decimal
        do {
            channelFeeAmount = try ChannelFeeCalculator.fee(
                on: revenue,
                percentage: channelFeePercentage
            )
        } catch {
            throw SaleError.invalidChannelFeePercentage
        }

        // As validações anteriores garantem que as alterações podem ser aplicadas juntas.
        let sale = Sale(
            storeID: storeID,
            date: date,
            paymentMethod: paymentMethod,
            note: note,
            channelFeePercentage: channelFeePercentage,
            channelFeeAmount: channelFeeAmount
        )
        context.insert(sale)

        let now = Date()

        for line in mergedLines {
            let item = SaleItem.from(product: line.product, quantity: line.quantity)
            item.sale = sale
            context.insert(item)

            // A baixa de estoque em si.
            line.product.quantity -= line.quantity
            line.product.updatedAt = now
        }

        return sale
    }

    /// Junta linhas repetidas do mesmo produto numa só, somando as quantidades.
    /// Mantém a ordem em que os produtos foram adicionados à venda.
    private static func merge(_ lines: [SaleLine]) -> [SaleLine] {
        var totals: [UUID: Int] = [:]
        var order: [UUID] = []
        var products: [UUID: Product] = [:]

        for line in lines {
            let id = line.product.id

            if totals[id] == nil {
                order.append(id)
                products[id] = line.product
            }

            totals[id, default: 0] += line.quantity
        }

        return order.compactMap { id in
            guard let product = products[id], let quantity = totals[id] else { return nil }
            return SaleLine(product: product, quantity: quantity)
        }
    }
}
