// ⌘
//  TinyStock/Views/Shared/AdaptivePopover.swift
//
//  Propósito: Balão preso a uma view que abre para baixo e só abre para cima quando falta espaço
//             embaixo. No iPhone continua balão, sem virar sheet.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-11-07.
// ⌘

import SwiftUI
import UIKit

extension View {

    /// Balão preso à view: abre para baixo (seta no topo) e, quando falta espaço embaixo e sobra em
    /// cima (ex.: última linha de uma lista rolada até o fim), abre para cima.
    func adaptivePopover<Content: View>(isPresented: Binding<Bool>,
                                        @ViewBuilder content: @escaping () -> Content) -> some View {
        modifier(AdaptivePopoverModifier(isPresented: isPresented, popoverContent: content))
    }
}

/// Espaço mínimo embaixo para o balão abrir para baixo sem ficar espremido.
private let popoverComfortableHeight: CGFloat = 360

/// Abre para cima só quando embaixo tem pouco espaço e em cima tem mais.
private func popoverOpensUp(frame: CGRect, in window: UIWindow) -> Bool {
    let insets = window.safeAreaInsets
    let below = window.bounds.height - insets.bottom - frame.maxY
    let above = frame.minY - insets.top
    return below < popoverComfortableHeight && above > below
}

private struct AdaptivePopoverModifier<PopoverContent: View>: ViewModifier {

    @Binding var isPresented: Bool
    let popoverContent: () -> PopoverContent

    @State private var opensUp = false

    func body(content: Content) -> some View {
        content
            // Acompanha a posição na tela (rolagem incluída) e decide o lado antes de abrir.
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                guard let window = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }
                let up = popoverOpensUp(frame: frame, in: window)
                if up != opensUp { opensUp = up }
            }
            .popover(isPresented: $isPresented,
                     attachmentAnchor: .point(opensUp ? .top : .bottom),
                     arrowEdge: opensUp ? .bottom : .top) {
                popoverContent()
                    .presentationCompactAdaptation(.popover)
            }
    }
}
