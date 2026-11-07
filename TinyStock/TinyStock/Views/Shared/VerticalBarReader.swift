// ⌘
//  TinyStock/Views/Shared/VerticalBarReader.swift
//
//  Propósito: Detectar quando o sistema põe as barras na coluna vertical ao lado da tela
//             (iPhone Duo dobrado, iOS 27.1+), para os botões irem para essa coluna.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-11-07.
// ⌘

import SwiftUI
import UIKit

extension EnvironmentValues {
    /// True quando o sistema usa a barra vertical (iPhone Duo dobrado, iOS 27.1+).
    @Entry var usesVerticalBar: Bool = false
}

/// Lê do UIKit se a cena usa a barra vertical e avisa quando muda (dobrar ou desdobrar o Duo).
/// Fora do Duo o `verticalBarEdge` é sempre `.unspecified`, então nada muda nos outros aparelhos.
struct VerticalBarReader: UIViewRepresentable {
    @Binding var isActive: Bool

    func makeUIView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onChange = { isActive = $0 }
        return view
    }

    func updateUIView(_ uiView: ReaderView, context: Context) {
        uiView.onChange = { isActive = $0 }
    }

    final class ReaderView: UIView {
        var onChange: ((Bool) -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            if #available(iOS 27.1, *) {
                registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) { (view: ReaderView, _) in
                    view.report()
                }
            }
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) não usado") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        private func report() {
            guard #available(iOS 27.1, *), window != nil else { return }
            let active = traitCollection.verticalBarEdge != .unspecified
            // Fora do ciclo de atualização da view, para não mexer em @State durante o render.
            DispatchQueue.main.async { [weak self] in self?.onChange?(active) }
        }
    }
}
