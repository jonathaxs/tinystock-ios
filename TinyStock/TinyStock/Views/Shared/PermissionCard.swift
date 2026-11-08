// ⌘
//  TinyStock/Views/Shared/PermissionCard.swift
//
//  Propósito: Linha de permissão do sistema: ícone colorido, título, descrição e o botão Permitir
//             ou o estado atual (permitido ou negado).
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-11-07.
// ⌘

import SwiftUI
import TinyStockCore

/// Estado de um pedido de permissão.
enum PermissionCardState { case idle, allowed, denied }

struct PermissionCard: View {

    let icon: String
    let iconColor: Color
    let title: String
    let desc: String
    let state: PermissionCardState
    var accentColor: Color = .accentColor
    var isBusy: Bool = false
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            IconBadge(systemName: icon, color: iconColor, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)

            switch state {
            case .idle:
                Button(action: action) {
                    Text(String(localized: "welcome.ready.allow", bundle: .tinyStockCore))
                        .font(.subheadline.weight(.semibold))
                }
                .appProminentButton(accentColor, size: .regular)
                .disabled(isBusy)
            case .allowed:
                Label(String(localized: "welcome.ready.allowed", bundle: .tinyStockCore), systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
            case .denied:
                Text(String(localized: "welcome.ready.denied", bundle: .tinyStockCore))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .appCard()
    }
}
