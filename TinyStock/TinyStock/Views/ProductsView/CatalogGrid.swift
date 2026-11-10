// ⌘
//  TinyStock/Views/ProductsView/CatalogGrid.swift
//
//  Propósito: Catálogo em grade: fotos dos produtos (ou das variações) lado a lado. Tocar num produto
//             abre um balão com as ações dele; tocar numa variação abre a edição dela.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-11-09.
// ⌘

import SwiftUI
import TinyStockCore

/// Forma de mostrar o catálogo na Início, lembrada entre aberturas.
enum CatalogViewMode: String, CaseIterable {
    case list, grid

    static let storageKey = "products.catalogViewMode"

    /// Ícone do botão que troca o modo: mostra para onde vai (em lista, o de grade).
    var switchSymbolName: String { self == .list ? "square.grid.2x2" : "list.bullet" }

    var switchAccessibilityLabel: String {
        self == .list
            ? String(localized: "products.viewMode.showGrid", bundle: .tinyStockCore)
            : String(localized: "products.viewMode.showList", bundle: .tinyStockCore)
    }

    var next: CatalogViewMode { self == .list ? .grid : .list }
}

/// Colunas da grade: quantas couberem com no mínimo 100 pt cada.
private let catalogGridColumns = [GridItem(.adaptive(minimum: 100), spacing: 12, alignment: .top)]

// MARK: - Produtos

struct ProductCatalogGrid: View {
    let products: [Product]
    let variants: [ProductVariant]
    let onAction: (ProductActionsSheet.Action, Product) -> Void

    /// Produto com o balão aberto (nil = nenhum).
    @State private var openProductID: UUID?

    var body: some View {
        LazyVGrid(columns: catalogGridColumns, spacing: 16) {
            ForEach(products) { product in
                tile(product)
            }
        }
        .padding(.vertical, 4)
    }

    private func tile(_ product: Product) -> some View {
        let quantity = ProductVariantService.displayedQuantity(for: product, among: variants)
        let isOpen = Binding(
            get: { openProductID == product.id },
            set: { if !$0 { openProductID = nil } }
        )
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            openProductID = product.id
        } label: {
            CatalogGridTile(imageData: product.imageData, title: product.name,
                            detail: quantityText(quantity))
        }
        .buttonStyle(.plain)
        .adaptivePopover(isPresented: isOpen) {
            ProductActionsPopover(product: product, quantity: quantity) { action in
                openProductID = nil
                // Espera o balão fechar antes de abrir a folha escolhida.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onAction(action, product) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(product.name)
        .accessibilityValue(quantityText(quantity))
        .accessibilityHint(String(localized: "products.grid.hint", bundle: .tinyStockCore))
    }
}

// MARK: - Variações

struct VariantCatalogGrid: View {
    let variants: [ProductVariant]
    let onSelect: (ProductVariant) -> Void

    var body: some View {
        LazyVGrid(columns: catalogGridColumns, spacing: 16) {
            ForEach(variants) { variant in
                let title = variant.isDefault
                    ? String(localized: "products.variants.noVariation", bundle: .tinyStockCore)
                    : variant.name
                Button { onSelect(variant) } label: {
                    CatalogGridTile(imageData: variant.imageData, title: title,
                                    detail: quantityText(Decimal(variant.quantity)))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(title)
                .accessibilityValue(quantityText(Decimal(variant.quantity)))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Peças

private func quantityText(_ quantity: Decimal) -> String {
    String(format: String(localized: "products.catalog.quantity", bundle: .tinyStockCore), quantity.formatted())
}

/// Foto quadrada em card, nome e estoque embaixo.
private struct CatalogGridTile: View {
    let imageData: Data?
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 6) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    GeometryReader { proxy in
                        ProductImageView(imageData: imageData, side: proxy.size.width)
                    }
                }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .contentShape(Rectangle())
    }
}

/// Balão com as mesmas ações da folha de ações do produto, no estilo do Adicionar.
private struct ProductActionsPopover: View {
    let product: Product
    let quantity: Decimal
    let onPick: (ProductActionsSheet.Action) -> Void

    @AppStorage(AppAccentColor.storageKey) private var accentColorRaw = AppAccentColor.defaultColor.rawValue

    private var accentColor: Color {
        (AppAccentColor(rawValue: accentColorRaw) ?? .defaultColor).color
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text(product.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                Text(quantityText(quantity) + " · " + product.salePrice.currencyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 10)
                VStack(spacing: 0) {
                    row(.sale, "sale.new.title", "cart.badge.plus")
                    Divider().padding(.leading, 52)
                    row(.stockEntry, "stock.entry.new", "shippingbox.and.arrow.backward")
                    Divider().padding(.leading, 52)
                    row(.newVariant, "stock.entry.newVariant", "plus.square.on.square")
                    Divider().padding(.leading, 52)
                    row(.editVariant, "product.variant.edit.title", "square.and.pencil")
                    Divider().padding(.leading, 52)
                    row(.edit, "product.form.title.edit", "pencil")
                    Divider().padding(.leading, 52)
                    row(.details, "products.details", "info.circle")
                }
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: 300)
        .frame(maxHeight: 520)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(.systemGroupedBackground))
    }

    private func row(_ action: ProductActionsSheet.Action, _ titleKey: String, _ systemImage: String) -> some View {
        Button { onPick(action) } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(accentColor)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                Text(String(localized: String.LocalizationValue(titleKey), bundle: .tinyStockCore))
                    .foregroundStyle(Color.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
