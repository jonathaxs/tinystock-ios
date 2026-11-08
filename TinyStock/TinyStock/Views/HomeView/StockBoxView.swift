// ⌘
//  TinyStock/Views/HomeView/StockBoxView.swift
//
//  Propósito: Caixa aberta no desenho do ícone do app, em perspectiva isométrica: um número em cada
//             lado da caixa e três barras saindo do topo, com a altura proporcional ao valor.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-11-07.
// ⌘

import SwiftUI

/// Uma barra que sai do topo da caixa.
struct StockBoxBar: Equatable {
    let value: Int
    let palette: StockBoxView.BarPalette
}

struct StockBoxView: View, Animatable {

    /// Cores de uma barra: lado esquerdo (sombra), lado direito e topo (mais claro).
    struct BarPalette: Equatable {
        let left: Color
        let right: Color
        let top: Color
    }

    let leftValue: Int
    let leftLabel: String
    let rightValue: Int
    let rightLabel: String
    let bars: [StockBoxBar]
    /// 0 a 1: quanto as barras já cresceram (anima a entrada).
    var growth: CGFloat = 1

    var animatableData: CGFloat {
        get { growth }
        set { growth = newValue }
    }

    /// Tamanho do desenho; a caixa é uma ilustração com medidas fixas.
    static let size = CGSize(width: 260, height: 262)

    // MARK: - Cores do ícone

    private static let leftFace = Color(red: 0.894, green: 0.404, blue: 0.235)      // #E4673C
    private static let rightFace = Color(red: 0.980, green: 0.514, blue: 0.318)     // #FA8351
    private static let leftFlap = Color(red: 0.976, green: 0.510, blue: 0.318)      // #F98251
    private static let rightFlap = Color(red: 0.988, green: 0.604, blue: 0.420)     // #FC9A6B
    private static let backFlap = Color(red: 0.910, green: 0.439, blue: 0.247)      // #E8703F
    private static let innerLeft = Color(red: 0.718, green: 0.337, blue: 0.169)     // #B7562B
    private static let innerRight = Color(red: 0.682, green: 0.318, blue: 0.153)    // #AE5127

    static let tealPalette = BarPalette(
        left: Color(red: 0.212, green: 0.655, blue: 0.643),   // #36A7A4
        right: Color(red: 0.318, green: 0.745, blue: 0.725),  // #51BEB9
        top: Color(red: 0.490, green: 0.796, blue: 0.780)     // #7DCBC7
    )
    static let deepTealPalette = BarPalette(
        left: Color(red: 0.067, green: 0.420, blue: 0.420),   // #116B6B
        right: Color(red: 0.098, green: 0.557, blue: 0.545),  // #198E8B
        top: Color(red: 0.302, green: 0.659, blue: 0.647)     // #4DA8A5
    )
    /// Grafite no claro e creme no escuro, como a barra do meio do ícone.
    static func graphitePalette(for scheme: ColorScheme) -> BarPalette {
        scheme == .dark
            ? BarPalette(left: Color(red: 0.906, green: 0.871, blue: 0.820),   // #E7DED1
                         right: Color(red: 0.969, green: 0.957, blue: 0.937),  // #F7F4EF
                         top: Color(red: 0.992, green: 0.984, blue: 0.980))    // #FDFBFA
            : BarPalette(left: Color(red: 0.161, green: 0.176, blue: 0.227),   // #292D3A
                         right: Color(red: 0.259, green: 0.286, blue: 0.337),  // #424956
                         top: Color(red: 0.400, green: 0.431, blue: 0.498))    // #666E7F
    }

    // MARK: - Geometria

    /// Inclinação das arestas horizontais (perspectiva isométrica 2:1).
    private let slope: CGFloat = 0.5
    /// Metade da largura da caixa.
    private let halfWidth: CGFloat = 100
    /// Altura dos lados.
    private let faceHeight: CGFloat = 92
    /// Altura mínima e máxima das barras acima da borda.
    private let minBarRise: CGFloat = 12
    private let maxBarRise: CGFloat = 76
    /// Posição de cada barra no fundo da caixa (p para a direita, q para a esquerda) e o lado da base.
    private let barSlots: [(p: CGFloat, q: CGFloat)] = [(0.12, 0.58), (0.40, 0.40), (0.58, 0.12)]
    private let barSide: CGFloat = 0.2

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    // MARK: - Desenho

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let cx = size.width / 2
        let bottom = size.height - 6
        let w = halfWidth, k = slope, h = faceHeight

        // Cantos da caixa: frente, esquerda, direita e fundo; _b embaixo, _t na borda de cima.
        let frontBottom = CGPoint(x: cx, y: bottom)
        let leftBottom = CGPoint(x: cx - w, y: bottom - k * w)
        let rightBottom = CGPoint(x: cx + w, y: bottom - k * w)
        let frontTop = CGPoint(x: cx, y: bottom - h)
        let leftTop = CGPoint(x: cx - w, y: bottom - k * w - h)
        let rightTop = CGPoint(x: cx + w, y: bottom - k * w - h)
        let backTop = CGPoint(x: cx, y: bottom - 2 * k * w - h)

        // Abas de trás, em pé atrás da abertura.
        context.fill(polygon([leftTop, backTop, backTop + CGPoint(x: -14, y: -40), leftTop + CGPoint(x: -14, y: -40)]),
                     with: .color(Self.backFlap))
        context.fill(polygon([backTop, rightTop, rightTop + CGPoint(x: 14, y: -40), backTop + CGPoint(x: 14, y: -40)]),
                     with: .color(Self.backFlap))

        // Abertura: paredes internas de trás, recortadas pelo losango da borda.
        let opening = polygon([leftTop, frontTop, rightTop, backTop])
        context.drawLayer { inner in
            inner.clip(to: opening)
            inner.fill(opening, with: .color(Self.innerLeft))
            inner.fill(polygon([backTop, rightTop, rightTop + CGPoint(x: 0, y: h), backTop + CGPoint(x: 0, y: h)]),
                       with: .color(Self.innerRight))
        }

        // Barras, de trás para a frente.
        let maxValue = max(bars.map(\.value).max() ?? 0, 1)
        let order = barSlots.indices.sorted { barSlots[$0].p + barSlots[$0].q > barSlots[$1].p + barSlots[$1].q }
        var labelSpots: [(Int, CGPoint)] = []
        for index in order where index < bars.count {
            let bar = bars[index]
            let rise = minBarRise + (maxBarRise - minBarRise) * CGFloat(bar.value) / CGFloat(maxValue)
            let height = (h + rise) * growth
            let topCenter = drawBar(slot: barSlots[index], height: height, palette: bar.palette,
                                    origin: frontBottom, in: &context)
            labelSpots.append((index, topCenter))
        }

        // Lados da frente, por cima das barras.
        context.fill(polygon([leftBottom, frontBottom, frontTop, leftTop]), with: .color(Self.leftFace))
        context.fill(polygon([frontBottom, rightBottom, rightTop, frontTop]), with: .color(Self.rightFace))

        // Abas da frente, abertas para fora.
        context.fill(polygon([leftTop, frontTop, frontTop + CGPoint(x: -34, y: 6), leftTop + CGPoint(x: -34, y: 6)]),
                     with: .color(Self.leftFlap))
        context.fill(polygon([frontTop, rightTop, rightTop + CGPoint(x: 34, y: 6), frontTop + CGPoint(x: 34, y: 6)]),
                     with: .color(Self.rightFlap))

        // Números pintados nos lados, inclinados junto com cada lado.
        let leftCenter = CGPoint(x: cx - w / 2, y: bottom - k * w / 2 - h / 2)
        let rightCenter = CGPoint(x: cx + w / 2, y: bottom - k * w / 2 - h / 2)
        drawFaceText(value: leftValue, label: leftLabel, center: leftCenter, shear: k, in: &context)
        drawFaceText(value: rightValue, label: rightLabel, center: rightCenter, shear: -k, in: &context)

        // Valor em cima de cada barra.
        guard growth > 0.6 else { return }
        for (index, spot) in labelSpots {
            let text = context.resolve(
                Text(bars[index].value, format: .number)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            )
            // Acima do vértice de trás do topo, para não encostar na barra.
            context.draw(text, at: CGPoint(x: spot.x, y: spot.y - barSide * slope * halfWidth - 4), anchor: .bottom)
        }
    }

    /// Desenha um prisma de base quadrada no fundo da caixa e devolve o centro do topo.
    private func drawBar(slot: (p: CGFloat, q: CGFloat), height: CGFloat, palette: BarPalette,
                         origin: CGPoint, in context: inout GraphicsContext) -> CGPoint {
        func point(_ p: CGFloat, _ q: CGFloat, _ z: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + (p - q) * halfWidth,
                    y: origin.y - (p + q) * slope * halfWidth - z)
        }
        let p0 = slot.p, q0 = slot.q, p1 = slot.p + barSide, q1 = slot.q + barSide
        // Lado esquerdo (p fixo), lado direito (q fixo) e topo.
        context.fill(polygon([point(p0, q0, 0), point(p0, q1, 0), point(p0, q1, height), point(p0, q0, height)]),
                     with: .color(palette.left))
        context.fill(polygon([point(p0, q0, 0), point(p1, q0, 0), point(p1, q0, height), point(p0, q0, height)]),
                     with: .color(palette.right))
        context.fill(polygon([point(p0, q0, height), point(p1, q0, height), point(p1, q1, height), point(p0, q1, height)]),
                     with: .color(palette.top))
        return point(p0 + barSide / 2, q0 + barSide / 2, height)
    }

    /// Número grande e rótulo pequeno, encolhendo para caber na largura do lado.
    private func drawFaceText(value: Int, label: String, center: CGPoint, shear: CGFloat,
                              in context: inout GraphicsContext) {
        let number = context.resolve(
            Text(value, format: .number)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        )
        let caption = context.resolve(
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
        )
        let maxWidth = halfWidth - 18
        let numberSize = number.measure(in: CGSize(width: 1000, height: 100))
        let captionSize = caption.measure(in: CGSize(width: 1000, height: 100))
        let scale = min(1, maxWidth / max(numberSize.width, captionSize.width, 1))

        context.drawLayer { layer in
            layer.translateBy(x: center.x, y: center.y)
            layer.concatenate(CGAffineTransform(a: 1, b: shear, c: 0, d: 1, tx: 0, ty: 0))
            layer.scaleBy(x: scale, y: scale)
            layer.draw(number, at: CGPoint(x: 0, y: -8), anchor: .center)
            layer.draw(caption, at: CGPoint(x: 0, y: numberSize.height / 2 + 2), anchor: .center)
        }
    }

    private func polygon(_ points: [CGPoint]) -> Path {
        Path { path in
            path.addLines(points)
            path.closeSubpath()
        }
    }
}

private extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
}
