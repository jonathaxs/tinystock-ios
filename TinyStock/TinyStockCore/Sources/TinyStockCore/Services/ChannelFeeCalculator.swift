// ⌘
//  TinyStockCore/Services/ChannelFeeCalculator.swift
//
//  Propósito: Calcular a taxa cobrada pelo canal de venda com arredondamento monetário.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-19.
// ⌘

import Foundation

public enum ChannelFeeError: Error, Equatable, Sendable {
    case negativeRevenue
    case invalidPercentage
}

public enum ChannelFeeCalculator {

    /// Calcula a taxa sobre a receita e arredonda para centavos.
    public static func fee(on revenue: Decimal, percentage: Decimal) throws -> Decimal {
        guard revenue >= 0 else { throw ChannelFeeError.negativeRevenue }
        guard percentage >= 0, percentage <= 100 else {
            throw ChannelFeeError.invalidPercentage
        }

        var rawFee = revenue * percentage / 100
        var roundedFee = Decimal.zero
        NSDecimalRound(&roundedFee, &rawFee, 2, .plain)
        return roundedFee
    }
}
