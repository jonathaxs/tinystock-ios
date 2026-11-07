// ⌘
//  TinyStockCore/Models/StoreProfile.swift
//
//  Propósito: Model SwiftData que representa uma loja e delimita seus dados no TinyStock.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-24.
// ⌘

import Foundation
import SwiftData

// MARK: - Escopo sem loja

/// Identificador reservado para objetos criados fora de uma loja, como fixtures antigas.
/// O app sempre informa uma loja real ao criar dados novos.
public enum StoreScope {
    public static let unassignedStoreID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    /// Identidade compartilhada pela loja criada na primeira execucao de cada dispositivo.
    /// O UUID fixo permite consolidar as copias quando o CloudKit importar os dados.
    public static let primaryStoreID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}

// MARK: - Loja

public enum StoreLifecycleState: String, Codable, Sendable {
    case active
    case archived
    case trashed
}

/// Uma loja independente dentro do TinyStock.
///
/// Produtos, pedidos e relatórios usam este identificador para manter o isolamento da loja.
/// Todas as propriedades possuem valor padrão para manter a compatibilidade com CloudKit.
@Model
public final class StoreProfile {

    /// Identificador estável usado nas relações, no backup e na seleção da loja atual.
    public var id: UUID = UUID()

    /// Nome escolhido pelo comerciante para identificar a loja.
    public var name: String = ""

    /// Logo ou foto opcional. O arquivo fica fora do banco principal.
    @Attribute(.externalStorage) public var imageData: Data?

    /// Lojas arquivadas preservam o histórico, mas não aparecem no uso cotidiano.
    public var isArchived: Bool = false

    /// Data usada para ordenar as lojas arquivadas da mais recente para a mais antiga.
    public var archivedAt: Date?

    /// Data de entrada na lixeira, usada para calcular a exclusao depois de 30 dias.
    public var trashedAt: Date?

    /// Permite restaurar uma loja da lixeira para o estado que possuia antes.
    public var wasArchivedBeforeTrash: Bool = false

    /// Posicao escolhida pelo usuario nas listas e no seletor rapido.
    public var sortOrder: Int = 0

    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        id: UUID = UUID(),
        name: String = "",
        imageData: Data? = nil,
        isArchived: Bool = false,
        archivedAt: Date? = nil,
        trashedAt: Date? = nil,
        wasArchivedBeforeTrash: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.imageData = imageData
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.trashedAt = trashedAt
        self.wasArchivedBeforeTrash = wasArchivedBeforeTrash
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    @Transient
    public var lifecycleState: StoreLifecycleState {
        if trashedAt != nil { return .trashed }
        return isArchived ? .archived : .active
    }

    public var isActive: Bool { lifecycleState == .active }
    public var isTrashed: Bool { lifecycleState == .trashed }
}
