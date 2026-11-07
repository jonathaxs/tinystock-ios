// ⌘
//  TinyStockCore/Services/SaleCart.swift
//
//  Propósito: Carrinho da venda em montagem, com várias linhas e o estoque respeitado.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-12.
// ⌘

import Foundation

// MARK: - Carrinho

/// O que a tela vai juntando antes de fechar a venda.
///
/// Centraliza as regras do carrinho para manter a view restrita à apresentação:
/// somar o mesmo produto em vez de repetir, e nunca deixar passar do estoque.
/// O `SaleService` continua validando na hora de gravar, mas aqui a pessoa nem chega a errar.
///
/// Não é `Sendable` porque carrega models vinculados ao contexto do SwiftData.
public struct SaleCart {

    /// Linhas na ordem em que os produtos foram escolhidos, uma por produto.
    public private(set) var lines: [SaleLine]

    public init(lines: [SaleLine] = []) {
        self.lines = lines
    }

    // MARK: - Leitura

    public var isEmpty: Bool {
        lines.isEmpty
    }

    /// Quantas unidades a venda tem no total, somando todas as linhas.
    public var unitCount: Int {
        lines.reduce(0) { $0 + $1.quantity }
    }

    public var total: Decimal {
        lines.reduce(0) { $0 + $1.product.salePrice * Decimal($1.quantity) }
    }

    public var profit: Decimal {
        lines.reduce(0) { $0 + $1.product.unitProfit * Decimal($1.quantity) }
    }

    /// Taxa estimada para o resumo antes de a venda ser persistida.
    public func channelFee(percentage: Decimal) -> Decimal {
        (try? ChannelFeeCalculator.fee(on: total, percentage: percentage)) ?? 0
    }

    public func netProfit(channelFeePercentage: Decimal) -> Decimal {
        profit - channelFee(percentage: channelFeePercentage)
    }

    /// Quantas unidades desse produto já estão no carrinho.
    public func quantity(of product: Product) -> Int {
        lines.first { $0.product.id == product.id }?.quantity ?? 0
    }

    /// Quantidade que ainda pode ser adicionada sem ultrapassar o estoque.
    ///
    /// É o número que a tela mostra na hora de escolher: com 5 em estoque e 3 no carrinho,
    /// restam 2 unidades disponíveis.
    public func remainingStock(of product: Product) -> Int {
        max(0, product.quantity - quantity(of: product))
    }

    // MARK: - Escrita

    /// Coloca unidades no carrinho, somando na linha do produto se ela já existir.
    ///
    /// Nunca passa do estoque: pedir mais do que existe entra até o limite.
    /// Devolve `false` quando nenhuma unidade pôde ser adicionada.
    @discardableResult
    public mutating func add(_ product: Product, quantity: Int = 1) -> Bool {
        guard quantity > 0, remainingStock(of: product) > 0 else { return false }

        setQuantity(self.quantity(of: product) + quantity, for: product)
        return true
    }

    /// Fixa a quantidade de um produto. Zero tira o produto do carrinho,
    /// e acima do estoque para no estoque.
    public mutating func setQuantity(_ quantity: Int, for product: Product) {
        let limited = min(max(quantity, 0), product.quantity)

        guard let index = lines.firstIndex(where: { $0.product.id == product.id }) else {
            if limited > 0 {
                lines.append(SaleLine(product: product, quantity: limited))
            }
            return
        }

        if limited == 0 {
            lines.remove(at: index)
        } else {
            lines[index] = SaleLine(product: product, quantity: limited)
        }
    }

    public mutating func remove(_ product: Product) {
        lines.removeAll { $0.product.id == product.id }
    }

    /// Remove pelos índices fornecidos pelo `ForEach` da lista.
    ///
    /// A ordem inversa evita que uma remoção desloque os índices seguintes.
    /// Escrito na mão porque o `remove(atOffsets:)` pronto vem do SwiftUI, e o Core não importa UI.
    public mutating func remove(atOffsets offsets: IndexSet) {
        for index in offsets.sorted(by: >) where lines.indices.contains(index) {
            lines.remove(at: index)
        }
    }
}
