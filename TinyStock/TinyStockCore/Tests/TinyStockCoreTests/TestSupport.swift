// ⌘
//  TinyStockCoreTests/TestSupport.swift
//
//  Propósito: Banco em memória compartilhado pelos testes que precisam de SwiftData.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-11.
// ⌘

import Foundation
import SwiftData
@testable import TinyStockCore

// MARK: - Banco de teste

/// Um único `ModelContainer` para todos os testes do processo.
///
/// Criar um container por teste derruba o SwiftData: a partir do quarto ou quinto,
/// o processo morre com SIGTRAP sem mensagem. Como o container é em memória, o custo
/// de compartilhar é zero, desde que cada teste comece com o banco limpo.
@MainActor
enum TestDatabase {

    static let container: ModelContainer = {
        do {
            return try ModelContainer(
                for: TinyStockPersistence.schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("não foi possível abrir o banco de teste: \(error)")
        }
    }()

    /// Limpa o contexto compartilhado antes de cada teste.
    /// Só funciona com as suítes marcadas `.serialized`, senão um teste limpa o do outro.
    static func makeCleanContext() throws -> ModelContext {
        let context = ModelContext(container)

        try context.delete(model: SalesOrderItem.self)
        try context.delete(model: SalesOrder.self)
        try context.delete(model: SaleItem.self)
        try context.delete(model: Sale.self)
        try context.delete(model: StockMovement.self)
        try context.delete(model: ProductVariant.self)
        try context.delete(model: Product.self)
        try context.delete(model: StoreProfile.self)
        try context.save()

        return context
    }
}
