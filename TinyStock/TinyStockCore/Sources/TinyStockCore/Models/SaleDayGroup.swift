// ⌘
//  TinyStockCore/Models/SaleDayGroup.swift
//
//  Propósito: Agrupar as vendas por dia, com o título e os totais de cada dia.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-12.
// ⌘

import Foundation

// MARK: - Um dia do histórico

/// Vendas de um mesmo dia com os totais usados pela seção da lista.
///
/// Não é `Sendable` porque carrega models vinculados ao contexto do SwiftData.
public struct SaleDayGroup: Identifiable {

    /// Meia-noite do dia, no calendário de quem está usando o app.
    public let day: Date

    /// Vendas do dia, da mais recente para a mais antiga.
    public let sales: [Sale]

    public var id: Date { day }

    public init(day: Date, sales: [Sale]) {
        self.day = day
        self.sales = sales
    }

    // MARK: - Totais do dia

    /// Quanto entrou no dia.
    public var total: Decimal {
        sales.reduce(0) { $0 + $1.total }
    }

    /// Lucro líquido do dia, já descontando as taxas registradas nas vendas.
    public var profit: Decimal {
        sales.reduce(0) { $0 + $1.profit }
    }

    /// Quantas unidades saíram no dia, somando todos os itens de todas as vendas.
    public var totalQuantity: Int {
        sales.reduce(0) { $0 + $1.totalQuantity }
    }

    // MARK: - Título da seção

    /// Texto do cabeçalho: Hoje, Ontem, ou a data escrita por extenso.
    ///
    /// A referência é parâmetro porque "hoje" depende de quando se pergunta,
    /// e um teste precisa poder fixar esse ponto.
    public func title(
        relativeTo reference: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent
    ) -> String {

        if calendar.isDate(day, inSameDayAs: reference) {
            return String(localized: "sales.day.today", bundle: .tinyStockCore)
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: reference),
           calendar.isDate(day, inSameDayAs: yesterday) {
            return String(localized: "sales.day.yesterday", bundle: .tinyStockCore)
        }

        // Dentro do ano corrente o ano é ruído. De anos anteriores ele faz falta.
        let sameYear = calendar.component(.year, from: day) == calendar.component(.year, from: reference)
        let style = sameYear
            ? Date.FormatStyle.dateTime.day().month(.wide)
            : Date.FormatStyle.dateTime.day().month(.wide).year()

        return day.formatted(style.locale(locale))
    }
}

// MARK: - Agrupamento

public extension SaleDayGroup {

    /// Agrupa as vendas por dia, do mais recente para o mais antigo.
    ///
    /// Uma lista linear serve enquanto há três vendas. Com dezenas, é o corte por dia
    /// que responde a pergunta que a pessoa realmente faz: quanto eu vendi hoje.
    static func groups(from sales: [Sale], calendar: Calendar = .current) -> [SaleDayGroup] {
        Dictionary(grouping: sales) { calendar.startOfDay(for: $0.date) }
            .map { day, salesOfTheDay in
                SaleDayGroup(day: day, sales: salesOfTheDay.sorted { $0.date > $1.date })
            }
            .sorted { $0.day > $1.day }
    }
}
