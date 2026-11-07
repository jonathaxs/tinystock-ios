// ⌘
//  TinyStockCoreTests/ChannelFeeCalculatorTests.swift
//
//  Propósito: Testar o cálculo percentual e o arredondamento da taxa de canal.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-19.
// ⌘

import Testing
import Foundation
@testable import TinyStockCore

struct ChannelFeeCalculatorTests {

    @Test func taxaPercentualUsaAReceitaDaVenda() throws {
        let fee = try ChannelFeeCalculator.fee(on: 100, percentage: 14)

        #expect(fee == 14)
    }

    @Test func taxaEhArredondadaParaCentavos() throws {
        let fee = try ChannelFeeCalculator.fee(on: 19.90, percentage: 14)

        #expect(fee == Decimal(string: "2.79"))
    }

    @Test func taxaZeroNaoDescontaNada() throws {
        #expect(try ChannelFeeCalculator.fee(on: 100, percentage: 0) == 0)
    }

    @Test func percentualForaDoIntervaloEhRecusado() {
        #expect(throws: ChannelFeeError.invalidPercentage) {
            try ChannelFeeCalculator.fee(on: 100, percentage: 101)
        }
        #expect(throws: ChannelFeeError.invalidPercentage) {
            try ChannelFeeCalculator.fee(on: 100, percentage: -1)
        }
    }

    @Test func receitaNegativaEhRecusada() {
        #expect(throws: ChannelFeeError.negativeRevenue) {
            try ChannelFeeCalculator.fee(on: -1, percentage: 10)
        }
    }
}
