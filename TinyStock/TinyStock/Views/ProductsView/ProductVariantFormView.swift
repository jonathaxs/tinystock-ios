// TinyStock/Views/ProductsView/ProductVariantFormView.swift
//
// Proposito: Editar o rascunho de uma variacao e seu estoque.
//
// Created by Jonathas Motta (@jonathaxs) on 2026-08-30.

import SwiftUI
import TinyStockCore

/// Edita somente o rascunho. O formulario de produto confirma a gravacao do conjunto.
struct ProductVariantFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var input: ProductVariantInput
    let onSave: (ProductVariantInput) -> Void

    init(input: ProductVariantInput, onSave: @escaping (ProductVariantInput) -> Void) {
        _input = State(initialValue: input)
        self.onSave = onSave
    }

    private var canSave: Bool {
        !input.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && input.initialQuantity >= 0
    }

    private var stockTitle: String {
        String(localized: input.existingID == nil
               ? "product.form.variant.initialStock"
               : "product.form.variant.available", bundle: .tinyStockCore)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "product.variant.edit.name", bundle: .tinyStockCore)) {
                    TextField(String(localized: "product.form.variant.name", bundle: .tinyStockCore), text: $input.name)
                        .submitLabel(.done)
                }
                // Em uma variacao existente, o formulario do produto grava a diferenca como ajuste.
                Section(stockTitle) {
                    StockQuantityPicker(title: stockTitle, quantity: $input.initialQuantity,
                                        range: 0...max(100, input.initialQuantity), showsTitle: false)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(String(localized: "product.form.variant.title", bundle: .tinyStockCore))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", bundle: .tinyStockCore)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save", bundle: .tinyStockCore)) {
                        input.name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(input)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
