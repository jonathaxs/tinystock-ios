// ⌘
//  TinyStock/Views/HomeView/HomeAddButton.swift
//
//  Propósito: Botão "Adicionar" da Início, que abre um balão com nova venda, novo produto e nova
//             variação. Cada opção fecha o balão e só depois abre a tela escolhida.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-11-07.
// ⌘

import SwiftUI
import TinyStockCore

enum HomeAddAction {
    case sale, product, variant
}

struct HomeAddButton: View {

    /// Sem produtos, só dá para cadastrar um produto.
    let hasProducts: Bool
    let onPick: (HomeAddAction) -> Void

    @AppStorage(AppAccentColor.storageKey) private var accentColorRaw = AppAccentColor.defaultColor.rawValue
    @State private var showsOptions = false

    private var accentColor: Color {
        (AppAccentColor(rawValue: accentColorRaw) ?? .defaultColor).color
    }

    var body: some View {
        Button { showsOptions = true } label: {
            Label(String(localized: "home.add", bundle: .tinyStockCore), systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .appProminentButton(accentColor, size: .regular)
        .adaptivePopover(isPresented: $showsOptions) {
            HomeAddPopover(accentColor: accentColor, hasProducts: hasProducts) { action in
                showsOptions = false
                // Espera o balão terminar de fechar antes de abrir a sheet.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onPick(action) }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HomeAddPopover: View {

    let accentColor: Color
    let hasProducts: Bool
    let onPick: (HomeAddAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(String(localized: "home.add", bundle: .tinyStockCore))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity)
                .frame(height: 48)

            VStack(spacing: 0) {
                row("sale.new.title", systemImage: "cart.badge.plus", action: .sale, enabled: hasProducts)
                Divider().padding(.leading, 52)
                row("product.form.title.new", systemImage: "shippingbox", action: .product, enabled: true)
                Divider().padding(.leading, 52)
                row("stock.entry.newVariant", systemImage: "plus.square.on.square", action: .variant, enabled: hasProducts)
            }
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(.systemGroupedBackground))
    }

    private func row(_ titleKey: String, systemImage: String, action: HomeAddAction, enabled: Bool) -> some View {
        Button { onPick(action) } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(enabled ? accentColor : .secondary)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                Text(String(localized: String.LocalizationValue(titleKey), bundle: .tinyStockCore))
                    .font(.body)
                    .foregroundStyle(enabled ? Color.primary : .secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
