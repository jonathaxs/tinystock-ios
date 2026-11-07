// ⌘
//  TinyStockCore/Services/ProductVariantService.swift
//
//  Propósito: Validar e consultar variações dentro do produto e da loja corretos.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-27.
// ⌘

import Foundation
import SwiftData

// MARK: - Erros

public enum ProductVariantError: Error, Equatable, Sendable {
    case emptyName
    case duplicateName
    case negativeQuantity
    case productMismatch
}

public extension ProductVariantError {

    var localizedMessage: String {
        switch self {
        case .emptyName:
            String(localized: "variant.error.emptyName", bundle: .tinyStockCore)
        case .duplicateName:
            String(localized: "variant.error.duplicateName", bundle: .tinyStockCore)
        case .negativeQuantity:
            String(localized: "variant.error.negativeQuantity", bundle: .tinyStockCore)
        case .productMismatch:
            String(localized: "variant.error.productMismatch", bundle: .tinyStockCore)
        }
    }
}

// MARK: - Serviço

public enum ProductVariantService {

    /// Cria uma variação já vinculada ao produto e à loja dele.
    @discardableResult
    public static func create(
        for product: Product,
        name: String,
        isDefault: Bool = false,
        initialQuantity: Int = 0,
        date: Date = Date(),
        in context: ModelContext
    ) throws -> ProductVariant {
        guard initialQuantity >= 0 else { throw ProductVariantError.negativeQuantity }
        let cleanName = isDefault
            ? ProductVariant.internalDefaultName
            : try validatedName(name, for: product, excluding: nil, in: context)

        if isDefault {
            let existing = try variants(for: product, in: context)
            guard existing.isEmpty else { throw ProductVariantError.productMismatch }
        }

        let variant = ProductVariant(
            storeID: product.storeID,
            productID: product.id,
            name: cleanName,
            isDefault: isDefault,
            quantity: 0,
            createdAt: date,
            updatedAt: date
        )
        context.insert(variant)

        if initialQuantity > 0 {
            try StockService.registerInitialStock(
                quantity: initialQuantity,
                to: variant,
                product: product,
                date: date,
                in: context
            )
        }

        return variant
    }

    /// Renomeia sem alterar o saldo, que será responsabilidade do serviço de estoque.
    public static func rename(
        _ variant: ProductVariant,
        to name: String,
        for product: Product,
        date: Date = Date(),
        in context: ModelContext
    ) throws {
        guard variant.belongs(to: product) else {
            throw ProductVariantError.productMismatch
        }

        variant.name = try validatedName(
            name,
            for: product,
            excluding: variant.id,
            in: context
        )
        variant.updatedAt = date
    }

    /// Consulta usando produto e loja para impedir vazamento entre perfis.
    public static func variants(
        for product: Product,
        in context: ModelContext
    ) throws -> [ProductVariant] {
        let productID = product.id
        let storeID = product.storeID
        let descriptor = FetchDescriptor<ProductVariant>(
            predicate: #Predicate {
                $0.productID == productID && $0.storeID == storeID
            },
            sortBy: [SortDescriptor(\ProductVariant.name)]
        )
        return try context.fetch(descriptor)
    }

    public static func totalQuantity(
        for product: Product,
        in context: ModelContext
    ) throws -> Int {
        try variants(for: product, in: context).reduce(0) { total, variant in
            let sum = total.addingReportingOverflow(variant.quantity)
            guard !sum.overflow else { throw StockError.quantityOverflow }
            return sum.partialValue
        }
    }

    /// Soma para exibicao sem limitar o total de varias variacoes ao tamanho de um Int.
    public static func displayedQuantity(for product: Product, among variants: [ProductVariant]) -> Decimal {
        variants.filter { $0.belongs(to: product) }.reduce(Decimal.zero) { $0 + Decimal($1.quantity) }
    }

    // MARK: - Validação

    /// Considera os nomes finais juntos, inclusive quando duas variacoes trocam de nome.
    static func validateEdits(_ inputs: [ProductVariantInput], existing: [ProductVariant]) throws {
        let existingIDs = Set(existing.map(\.id))
        let editedIDs = inputs.compactMap(\.existingID)
        guard Set(editedIDs).count == editedIDs.count,
              Set(editedIDs).isSubset(of: existingIDs) else {
            throw ProductVariantError.productMismatch
        }

        var names = Set(existing.filter { !editedIDs.contains($0.id) }.map { comparableName($0.name) })
        for input in inputs {
            let name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { throw ProductVariantError.emptyName }
            guard names.insert(comparableName(name)).inserted else { throw ProductVariantError.duplicateName }
            if input.existingID == nil, input.initialQuantity < 0 {
                throw ProductVariantError.negativeQuantity
            }
        }
    }

    static func applyEdits(
        _ inputs: [ProductVariantInput], existing: [ProductVariant],
        for product: Product, in context: ModelContext
    ) throws {
        // Primeiro renomeia todas as existentes. Seus saldos e historicos nao sao alterados.
        for input in inputs {
            if let variant = existing.first(where: { $0.id == input.existingID }) {
                let name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if variant.name != name || variant.isDefault {
                    variant.name = name
                    variant.isDefault = false
                    variant.updatedAt = Date()
                }
            }
        }
        for input in inputs where input.existingID == nil {
            try create(for: product, name: input.name, initialQuantity: input.initialQuantity, in: context)
        }
    }

    /// Preserva a identidade, o saldo e o historico ao ocultar a unica variacao do produto.
    static func applyDefault(
        existing: [ProductVariant],
        for product: Product,
        in context: ModelContext
    ) throws {
        guard existing.count <= 1 else { throw ProductFormError.cannotDisableMultipleVariations }
        if let variant = existing.first {
            guard variant.belongs(to: product) else { throw ProductVariantError.productMismatch }
            if !variant.isDefault || variant.name != ProductVariant.internalDefaultName {
                variant.name = ProductVariant.internalDefaultName
                variant.isDefault = true
                variant.updatedAt = Date()
            }
        } else {
            try create(for: product, name: "", isDefault: true, in: context)
        }
    }

    private static func validatedName(
        _ name: String,
        for product: Product,
        excluding variantID: UUID?,
        in context: ModelContext
    ) throws -> String {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw ProductVariantError.emptyName }

        let existing = try variants(for: product, in: context)
        let candidate = comparableName(cleanName)
        let isDuplicate = existing.contains {
            $0.id != variantID && comparableName($0.name) == candidate
        }
        guard !isDuplicate else { throw ProductVariantError.duplicateName }

        return cleanName
    }

    private static func comparableName(_ name: String) -> String {
        name.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "pt_BR")
        )
        .lowercased()
    }
}
