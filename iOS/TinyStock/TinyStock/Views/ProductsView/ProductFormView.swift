// TinyStock/Views/ProductsView/ProductFormView.swift
//
// Proposito: Formulario de produto com foto e variacoes, sem gravacao antes de salvar.
//
// Created by Jonathas Motta (@jonathaxs) on 2026-08-08.

import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI
import TinyStockCore

/// Mantem os campos em memoria ate a confirmacao do cadastro ou da edicao.
struct ProductFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let editingProduct: Product?
    private let storeID: UUID

    @State private var name: String
    @State private var costPriceText: String
    @State private var salePriceText: String
    @State private var imageData: Data?
    @State private var initialVariationName = ""
    @State private var initialQuantityText = "0"
    @State private var variants: [ProductVariantInput] = []
    @State private var editingVariant: ProductVariantInput?
    @State private var didLoadVariants = false
    @State private var errorMessage: String?
    @State private var pickerItem: PhotosPickerItem?
    @State private var isPresentingPhotos = false
    @State private var isPresentingCamera = false
    @State private var isLoadingPhoto = false

    init(storeID: UUID, product: Product? = nil) {
        self.storeID = storeID
        editingProduct = product
        _name = State(initialValue: product?.name ?? "")
        _costPriceText = State(initialValue: CurrencyFormatter.editableText(from: product?.costPrice ?? 0))
        _salePriceText = State(initialValue: CurrencyFormatter.editableText(from: product?.salePrice ?? 0))
        _imageData = State(initialValue: product?.imageData)
    }

    private func price(from text: String) -> Decimal? {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : CurrencyFormatter.decimal(from: text)
    }

    private var initialQuantity: Int? {
        Int(initialQuantityText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var formVariants: [ProductVariantInput] {
        guard editingProduct == nil else { return variants }
        guard let initialQuantity else { return [] }
        return [ProductVariantInput(name: initialVariationName, initialQuantity: initialQuantity)]
    }

    private var canSave: Bool {
        guard let cost = price(from: costPriceText), let sale = price(from: salePriceText) else { return false }
        let hasValidInitialVariation = editingProduct != nil || (
            !initialVariationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && (initialQuantity ?? -1) >= 0
        )
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && cost >= 0 && sale >= 0 && hasValidInitialVariation && didLoadVariants && !isLoadingPhoto
    }

    private var title: String {
        editingProduct == nil
            ? String(localized: "product.form.title.new", bundle: .tinyStockCore)
            : String(localized: "product.form.title.edit", bundle: .tinyStockCore)
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                Section {
                    TextField(String(localized: "product.form.name", bundle: .tinyStockCore), text: $name)
                        .textInputAutocapitalization(.words)
                }
                pricesSection
                if editingProduct == nil {
                    initialVariationSection
                } else {
                    variantsSection
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", bundle: .tinyStockCore)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save", bundle: .tinyStockCore), action: save)
                        .disabled(!canSave)
                }
            }
            .alert(String(localized: "product.form.error.title", bundle: .tinyStockCore), isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button(String(localized: "common.ok", bundle: .tinyStockCore)) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task { loadVariants() }
        .sheet(item: $editingVariant) { input in
            ProductVariantFormView(input: input) { updated in
                if let index = variants.firstIndex(where: { $0.id == updated.id }) {
                    variants[index] = updated
                } else {
                    variants.append(updated)
                }
            }
        }
        .photosPicker(isPresented: $isPresentingPhotos, selection: $pickerItem, matching: .images)
        .task(id: pickerItem) {
            guard let pickerItem else { return }
            isLoadingPhoto = true
            defer { isLoadingPhoto = false }
            do {
                guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
                    throw ProductPhotoError.unreadable
                }
                try await preparePhoto(data)
            } catch {
                if !Task.isCancelled { showPhotoError() }
            }
        }
        .fullScreenCover(isPresented: $isPresentingCamera) {
            ProductCameraView { data in
                isPresentingCamera = false
                guard let data else { return }
                Task {
                    isLoadingPhoto = true
                    defer { isLoadingPhoto = false }
                    do { try await preparePhoto(data) } catch { showPhotoError() }
                }
            }
            .ignoresSafeArea()
        }
    }

    private var photoSection: some View {
        Section {
            Menu {
                Button(String(localized: "product.form.photo.choose", bundle: .tinyStockCore), systemImage: "photo") {
                    isPresentingPhotos = true
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button(String(localized: "product.form.photo.camera", bundle: .tinyStockCore), systemImage: "camera") {
                        Task { await openCamera() }
                    }
                }
                if imageData != nil {
                    Button(String(localized: "product.form.photo.remove", bundle: .tinyStockCore), systemImage: "trash", role: .destructive) {
                        pickerItem = nil
                        imageData = nil
                    }
                }
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    ProductImageView(imageData: imageData, side: 104)
                    Image(systemName: "camera.fill")
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.accentColor, in: Circle())
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))
                }
                .overlay { if isLoadingPhoto { ProgressView() } }
            }
            .buttonStyle(.plain)
            .disabled(isLoadingPhoto)
            .accessibilityLabel(String(localized: "product.form.photo.change", bundle: .tinyStockCore))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
    }

    private var pricesSection: some View {
        Section(String(localized: "product.form.section.prices", bundle: .tinyStockCore)) {
            priceField(String(localized: "product.form.salePrice", bundle: .tinyStockCore), text: $salePriceText)
            priceField(String(localized: "product.form.costPrice", bundle: .tinyStockCore), text: $costPriceText)
            if let sale = price(from: salePriceText), let cost = price(from: costPriceText) {
                LabeledContent(String(localized: "product.form.unitProfit", bundle: .tinyStockCore)) {
                    Text((sale - cost).currencyText)
                        .foregroundStyle(sale < cost ? Color.red : Color.primary)
                }
            }
        }
    }

    private func priceField(_ title: String, text: Binding<String>) -> some View {
        LabeledContent(title) {
            TextField(Decimal.zero.currencyText, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(title)
        }
    }

    private var variantsSection: some View {
        Section(String(localized: "product.form.variants", bundle: .tinyStockCore)) {
            ForEach(variants) { input in
                Button { editingVariant = input } label: {
                    LabeledContent(input.name) {
                        Text(input.initialQuantity, format: .number)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                }
                .accessibilityHint(String(localized: "product.form.variant.edit.hint", bundle: .tinyStockCore))
            }
        }
    }

    private var initialVariationSection: some View {
        Section(String(localized: "product.form.variant.title", bundle: .tinyStockCore)) {
            TextField(String(localized: "product.form.variant.name", bundle: .tinyStockCore), text: $initialVariationName)
                .textInputAutocapitalization(.words)
            LabeledContent(String(localized: "product.form.variant.initialStock", bundle: .tinyStockCore)) {
                TextField("0", text: $initialQuantityText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel(String(localized: "product.form.variant.initialStock", bundle: .tinyStockCore))
            }
        }
    }

    private func loadVariants() {
        guard !didLoadVariants else { return }
        do {
            if let editingProduct {
                variants = try ProductVariantService.variants(for: editingProduct, in: modelContext).map {
                    ProductVariantInput(id: $0.id, existingID: $0.id, name: $0.name, initialQuantity: $0.quantity)
                }
            }
            didLoadVariants = true
        } catch { errorMessage = error.localizedDescription }
    }

    private func preparePhoto(_ data: Data) async throws {
        let prepared = await Task.detached(priority: .userInitiated) {
            ProductImageProcessor.prepared(from: data)
        }.value
        // A troca de selecao cancela a tarefa anterior, que nao deve sobrescrever a foto nova.
        try Task.checkCancellation()
        guard let prepared else { throw ProductPhotoError.unreadable }
        imageData = prepared
    }

    private func showPhotoError() {
        errorMessage = String(localized: "product.form.photo.error", bundle: .tinyStockCore)
    }

    private func openCamera() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        if granted {
            isPresentingCamera = true
        } else {
            errorMessage = String(localized: "product.form.photo.permission", bundle: .tinyStockCore)
        }
    }

    private func save() {
        guard canSave, let cost = price(from: costPriceText), let sale = price(from: salePriceText) else { return }
        // Salva pendencias anteriores antes do lote para nao desfaze-las caso este cadastro falhe.
        do { try modelContext.save() } catch {
            errorMessage = error.localizedDescription
            return
        }
        do {
            try ProductFormService.apply(to: editingProduct, storeID: storeID, name: name,
                                         costPrice: cost, salePrice: sale, imageData: imageData,
                                         variants: formVariants, in: modelContext)
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            if let error = error as? ProductError {
                errorMessage = error.localizedMessage
            } else if let error = error as? ProductFormError {
                errorMessage = error.localizedMessage
            } else if let error = error as? ProductVariantError {
                errorMessage = error.localizedMessage
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private enum ProductPhotoError: Error { case unreadable }

#Preview {
    ProductFormView(storeID: UUID())
        .modelContainer(for: [Product.self, ProductVariant.self, StockMovement.self], inMemory: true)
}
