// ⌘
//  TinyStockCoreTests/ProductImageProcessorTests.swift
//
//  Propósito: Testes do preparo da foto do produto, cobrindo redução de tamanho e entrada inválida.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-10.
// ⌘

import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import TinyStockCore

// MARK: - Apoio

/// Gera um PNG de teste do tamanho pedido, sem depender de arquivo no disco.
private func makeImageData(width: Int, height: Int) throws -> Data {
    let context = try #require(
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    )
    context.setFillColor(red: 0.9, green: 0.4, blue: 0.2, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let image = try #require(context.makeImage())
    let output = NSMutableData()
    let destination = try #require(
        CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)
    )
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))

    return output as Data
}

// MARK: - Redução

@Test func fotoGrandeCabeNoLadoMaximo() throws {
    // Tamanho parecido com o de uma foto de iPhone.
    let original = try makeImageData(width: 3024, height: 4032)
    let preparada = try #require(ProductImageProcessor.prepared(from: original))
    let tamanho = try #require(ProductImageProcessor.pixelSize(of: preparada))

    #expect(max(tamanho.width, tamanho.height) == ProductImageProcessor.maxDimension)
}

@Test func reducaoMantemAProporcaoDaFoto() throws {
    let original = try makeImageData(width: 2000, height: 1000)
    let preparada = try #require(ProductImageProcessor.prepared(from: original))
    let tamanho = try #require(ProductImageProcessor.pixelSize(of: preparada))

    #expect(tamanho.width == 1024)
    #expect(tamanho.height == 512)
}

@Test func fotoPequenaNaoEhEsticada() throws {
    // Imagens menores que o limite preservam suas dimensões.
    let original = try makeImageData(width: 300, height: 200)
    let preparada = try #require(ProductImageProcessor.prepared(from: original))
    let tamanho = try #require(ProductImageProcessor.pixelSize(of: preparada))

    #expect(tamanho.width == 300)
    #expect(tamanho.height == 200)
}

@Test func fotoPreparadaFicaMaisLeveQueAOriginal() throws {
    let original = try makeImageData(width: 3024, height: 4032)
    let preparada = try #require(ProductImageProcessor.prepared(from: original))

    #expect(preparada.count < original.count, "o objetivo do preparo é justamente aliviar o banco")
}

@Test func aceitaLadoMaximoPersonalizado() throws {
    let original = try makeImageData(width: 1200, height: 1200)
    let preparada = try #require(ProductImageProcessor.prepared(from: original, maxDimension: 200))
    let tamanho = try #require(ProductImageProcessor.pixelSize(of: preparada))

    #expect(tamanho.width == 200)
    #expect(tamanho.height == 200)
}

// MARK: - Entrada inválida

@Test func dadosQueNaoSaoImagemDevolvemNil() {
    let lixo = Data("isso aqui não é uma foto".utf8)
    #expect(ProductImageProcessor.prepared(from: lixo) == nil)
}

@Test func dadosVaziosDevolvemNil() {
    #expect(ProductImageProcessor.prepared(from: Data()) == nil)
}
