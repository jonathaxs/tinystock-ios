// ⌘
//  TinyStock/Views/HomeView/StockBoxView.swift
//
//  Propósito: Caixa sem tampa nas cores do ícone do app, em perspectiva isométrica: um número em cada
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
    static let size = CGSize(width: 200, height: 252)

    // MARK: - Cores (laranja do ícone, em degradê de cima para baixo)

    private static let leftFace = [Color(hex: 0xEF7645), Color(hex: 0xD2532B)]
    private static let rightFace = [Color(hex: 0xFF9B66), Color(hex: 0xF07440)]
    private static let innerLeft = [Color(hex: 0xC2602F), Color(hex: 0x8A3A18)]
    private static let innerRight = [Color(hex: 0xB5582A), Color(hex: 0x7E3414)]
    /// Cor de cada lado na legenda do balão.
    static var leftLegend: Color { leftFace[0] }
    static var rightLegend: Color { rightFace[0] }
    /// Borda cortada da caixa, mais clara, como papelão cortado.
    private static let cutEdge = Color(hex: 0xFFB48C)
    private static let backCutEdge = Color(hex: 0xE88A5C)

    static let tealPalette = BarPalette(
        left: Color(hex: 0x36A7A4), right: Color(hex: 0x51BEB9), top: Color(hex: 0x7DCBC7)
    )
    static let deepTealPalette = BarPalette(
        left: Color(hex: 0x116B6B), right: Color(hex: 0x198E8B), top: Color(hex: 0x4DA8A5)
    )
    /// Grafite no claro e creme no escuro, como a barra do meio do ícone.
    static func graphitePalette(for scheme: ColorScheme) -> BarPalette {
        scheme == .dark
            ? BarPalette(left: Color(hex: 0xE7DED1), right: Color(hex: 0xF7F4EF), top: Color(hex: 0xFDFBFA))
            : BarPalette(left: Color(hex: 0x292D3A), right: Color(hex: 0x424956), top: Color(hex: 0x666E7F))
    }

    // MARK: - Geometria

    /// Inclinação das arestas horizontais (perspectiva isométrica 2:1).
    private let slope: CGFloat = 0.5
    /// Metade da largura da caixa.
    private let halfWidth: CGFloat = 80
    /// Altura dos lados.
    private let faceHeight: CGFloat = 74
    /// Altura mínima (valor zero) e máxima das barras acima da borda.
    private let minBarRise: CGFloat = 30
    private let maxBarRise: CGFloat = 86
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
        // Margem embaixo para a sombra desfocada não ser cortada.
        let bottom = size.height - 16
        let w = halfWidth, k = slope, h = faceHeight

        // Cantos da caixa: frente, esquerda, direita e fundo; Bottom embaixo, Top na borda cortada.
        let frontBottom = CGPoint(x: cx, y: bottom)
        let leftBottom = CGPoint(x: cx - w, y: bottom - k * w)
        let rightBottom = CGPoint(x: cx + w, y: bottom - k * w)
        let backBottom = CGPoint(x: cx, y: bottom - 2 * k * w)
        let frontTop = CGPoint(x: cx, y: bottom - h)
        let leftTop = CGPoint(x: cx - w, y: bottom - k * w - h)
        let rightTop = CGPoint(x: cx + w, y: bottom - k * w - h)
        let backTop = CGPoint(x: cx, y: bottom - 2 * k * w - h)

        // Sombra no chão, para a caixa não flutuar.
        context.drawLayer { shadow in
            shadow.addFilter(.blur(radius: 6))
            shadow.fill(polygon([leftBottom, frontBottom, rightBottom, backBottom]).offsetBy(dx: 0, dy: 4),
                        with: .color(.black.opacity(0.18)))
        }

        // Abertura: paredes internas de trás, mais escuras para o fundo.
        let opening = polygon([leftTop, frontTop, rightTop, backTop])
        context.drawLayer { inner in
            inner.clip(to: opening)
            inner.fill(opening, with: gradient(Self.innerLeft, from: backTop, to: CGPoint(x: backTop.x, y: frontTop.y)))
            inner.fill(polygon([backTop, rightTop, rightTop + CGPoint(x: 0, y: h), backTop + CGPoint(x: 0, y: h)]),
                       with: gradient(Self.innerRight, from: backTop, to: CGPoint(x: backTop.x, y: frontTop.y)))
        }
        // Borda cortada das paredes de trás (fica atrás das barras).
        var backEdge = Path()
        backEdge.addLines([leftTop, backTop, rightTop])
        context.stroke(backEdge, with: .color(Self.backCutEdge),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

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
        context.fill(polygon([leftBottom, frontBottom, frontTop, leftTop]),
                     with: gradient(Self.leftFace, from: midpoint(leftTop, frontTop), to: midpoint(leftBottom, frontBottom)))
        context.fill(polygon([frontBottom, rightBottom, rightTop, frontTop]),
                     with: gradient(Self.rightFace, from: midpoint(frontTop, rightTop), to: midpoint(frontBottom, rightBottom)))

        // Borda cortada da frente.
        var frontEdge = Path()
        frontEdge.addLines([leftTop, frontTop, rightTop])
        context.stroke(frontEdge, with: .color(Self.cutEdge),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

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
        let top = point(p0, q0, height), base = point(p0, q0, 0)
        // Lados escurecem para baixo, como os lados da caixa.
        context.fill(polygon([point(p0, q0, 0), point(p0, q1, 0), point(p0, q1, height), point(p0, q0, height)]),
                     with: gradient([palette.left, palette.left.mix(with: .black, by: 0.25)], from: top, to: base))
        context.fill(polygon([point(p0, q0, 0), point(p1, q0, 0), point(p1, q0, height), point(p0, q0, height)]),
                     with: gradient([palette.right, palette.right.mix(with: .black, by: 0.25)], from: top, to: base))
        context.fill(polygon([point(p0, q0, height), point(p1, q0, height), point(p1, q1, height), point(p0, q1, height)]),
                     with: .color(palette.top))
        return point(p0 + barSide / 2, q0 + barSide / 2, height)
    }

    private func gradient(_ colors: [Color], from start: CGPoint, to end: CGPoint) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: colors), startPoint: start, endPoint: end)
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    /// Número grande e rótulo pequeno, encolhendo para caber na largura do lado.
    private func drawFaceText(value: Int, label: String, center: CGPoint, shear: CGFloat,
                              in context: inout GraphicsContext) {
        let number = context.resolve(
            Text(value, format: .number)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        )
        let caption = context.resolve(
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
        )
        let maxWidth = halfWidth - 14
        let numberSize = number.measure(in: CGSize(width: 1000, height: 100))
        let captionSize = caption.measure(in: CGSize(width: 1000, height: 100))
        let scale = min(1, maxWidth / max(numberSize.width, captionSize.width, 1))

        context.drawLayer { layer in
            layer.translateBy(x: center.x, y: center.y)
            layer.concatenate(CGAffineTransform(a: 1, b: shear, c: 0, d: 1, tx: 0, ty: 0))
            layer.scaleBy(x: scale, y: scale)
            layer.draw(number, at: CGPoint(x: 0, y: -6), anchor: .center)
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

private extension Color {
    /// Cor a partir do hexadecimal RRGGBB, como as amostras do ícone.
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
