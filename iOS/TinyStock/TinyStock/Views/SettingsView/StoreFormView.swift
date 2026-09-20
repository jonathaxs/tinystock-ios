// ⌘
//  TinyStock/Views/SettingsView/StoreFormView.swift
//
//  Propósito: Cadastrar ou editar o nome e a imagem de uma loja.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-25.
// ⌘

import PhotosUI
import SwiftData
import SwiftUI
import TinyStockCore

struct StoreFormView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreSession.self) private var storeSession

    private let editingStore: StoreProfile?

    @State private var name: String
    @State private var imageData: Data?
    @State private var pickerItem: PhotosPickerItem?
    @State private var isLoadingImage = false
    @State private var errorMessage: String?

    init(store: StoreProfile? = nil) {
        editingStore = store
        _name = State(initialValue: store?.name ?? "")
        _imageData = State(initialValue: store?.imageData)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoadingImage
    }

    private var title: String {
        editingStore == nil
            ? String(localized: "store.form.title.new", bundle: .tinyStockCore)
            : String(localized: "store.form.title.edit", bundle: .tinyStockCore)
    }

    var body: some View {
        NavigationStack {
            Form {
                imageSection

                Section(String(localized: "store.form.section.identification", bundle: .tinyStockCore)) {
                    TextField(
                        String(localized: "store.form.name", bundle: .tinyStockCore),
                        text: $name
                    )
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", bundle: .tinyStockCore)) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save", bundle: .tinyStockCore), action: save)
                        .disabled(!canSave)
                }
            }
            .alert(
                String(localized: "store.error.title", bundle: .tinyStockCore),
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button(String(localized: "common.ok", bundle: .tinyStockCore)) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var imageSection: some View {
        Section {
            VStack(spacing: 12) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        StoreImageView(imageData: imageData, side: 104)

                        Image(systemName: "camera.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.tint, in: Circle())
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    String(localized: "store.form.photo.choose", bundle: .tinyStockCore)
                )

                if isLoadingImage {
                    ProgressView()
                } else if imageData != nil {
                    Button(
                        String(localized: "store.form.photo.remove", bundle: .tinyStockCore),
                        role: .destructive
                    ) {
                        imageData = nil
                        pickerItem = nil
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .onChange(of: pickerItem) { _, item in
            Task { await loadImage(from: item) }
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }

        isLoadingImage = true
        defer { isLoadingImage = false }

        guard let rawData = try? await item.loadTransferable(type: Data.self) else { return }
        let prepared = await Task.detached(priority: .userInitiated) {
            ProductImageProcessor.prepared(from: rawData)
        }.value

        guard let prepared else { return }
        imageData = prepared
    }

    private func save() {
        do {
            var createdStore: StoreProfile?

            if let editingStore {
                try StoreProfileService.update(
                    editingStore,
                    name: name,
                    imageData: imageData,
                    in: modelContext
                )
            } else {
                let store = try StoreProfileService.create(
                    name: name,
                    imageData: imageData,
                    in: modelContext
                )
                createdStore = store
            }

            try modelContext.save()

            if let createdStore {
                try storeSession.select(createdStore)
            }

            dismiss()
        } catch let error as StoreProfileError {
            modelContext.rollback()
            errorMessage = error.localizedMessage
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
