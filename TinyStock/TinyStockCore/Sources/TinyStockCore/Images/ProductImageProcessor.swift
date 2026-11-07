// ⌘
//  TinyStockCore/Images/ProductImageProcessor.swift
//
//  Propósito: Reduzir e recomprimir a foto escolhida antes de guardar no banco.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-10.
// ⌘

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - Processamento da foto do produto

/// Prepara a foto do produto para armazenamento.
///
/// Uma foto direto da câmera do iPhone passa de 4 MB. Guardar isso sem tratar deixaria
/// o banco enorme e a lista lenta, então aqui a imagem é reduzida e recomprimida em JPEG.
///
/// Usa ImageIO em vez de UIKit para compartilhar o mesmo código entre app e testes
/// pela linha de comando e num futuro alvo watchOS.
public enum ProductImageProcessor {

    /// Limite do maior lado da imagem armazenada, em pixels.
    public static let maxDimension = 1024

    /// Qualidade do JPEG. 0,8 é o ponto onde o olho não vê perda mas o arquivo cai bastante.
    public static let compressionQuality = 0.8

    /// Reduz a imagem ao limite informado e devolve os bytes em JPEG.
    /// Devolve nil quando os dados não são uma imagem que o sistema saiba ler.
    public static func prepared(from data: Data, maxDimension: Int = maxDimension) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Aplica a rotação do EXIF, senão foto tirada deitada aparece torta na lista.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]

        guard let resized = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ) else {
            return nil
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let destinationOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        CGImageDestinationAddImage(destination, resized, destinationOptions as CFDictionary)

        guard CGImageDestinationFinalize(destination) else { return nil }

        return output as Data
    }

    /// Largura e altura em pixels de uma imagem, sem precisar carregar ela inteira na memória.
    /// Lê as dimensões sem decodificar a imagem completa.
    public static func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else {
            return nil
        }

        return (width, height)
    }
}
