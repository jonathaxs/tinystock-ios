// Proposito: Concentrar selecao, captura e preparacao da foto de um produto.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-17.

import AVFoundation
import PhotosUI
import SwiftUI
import TinyStockCore

struct ProductPhotoEditor: View {
    @Binding var imageData: Data?
    @Binding var isProcessing: Bool
    @Binding var errorMessage: String?

    @State private var pickerItem: PhotosPickerItem?
    @State private var isPresentingPhotos = false
    @State private var isPresentingCamera = false

    var body: some View {
        Section {
            Menu {
                Button(
                    String(localized: "product.form.photo.choose", bundle: .tinyStockCore),
                    systemImage: "photo"
                ) {
                    isPresentingPhotos = true
                }

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button(
                        String(localized: "product.form.photo.camera", bundle: .tinyStockCore),
                        systemImage: "camera"
                    ) {
                        Task { await openCamera() }
                    }
                }

                if imageData != nil {
                    Button(
                        String(localized: "product.form.photo.remove", bundle: .tinyStockCore),
                        systemImage: "trash",
                        role: .destructive
                    ) {
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
                .overlay { if isProcessing { ProgressView() } }
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
            .accessibilityLabel(
                String(localized: "product.form.photo.change", bundle: .tinyStockCore)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
        .photosPicker(
            isPresented: $isPresentingPhotos,
            selection: $pickerItem,
            matching: .images
        )
        .task(id: pickerItem) {
            guard let pickerItem else { return }
            isProcessing = true
            defer { isProcessing = false }

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
                    isProcessing = true
                    defer { isProcessing = false }
                    do {
                        try await preparePhoto(data)
                    } catch {
                        showPhotoError()
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    private func preparePhoto(_ data: Data) async throws {
        let prepared = await Task.detached(priority: .userInitiated) {
            ProductImageProcessor.prepared(from: data)
        }.value

        // Uma selecao cancelada nao deve sobrescrever a foto escolhida depois dela.
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
            errorMessage = String(
                localized: "product.form.photo.permission",
                bundle: .tinyStockCore
            )
        }
    }
}

private enum ProductPhotoError: Error {
    case unreadable
}
