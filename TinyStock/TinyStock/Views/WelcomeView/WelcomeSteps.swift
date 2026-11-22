// ⌘
//  TinyStock/Views/WelcomeView/WelcomeSteps.swift
//
//  Propósito: Conteúdo de cada etapa da apresentação: início, nome da loja (opcional), dicas do primeiro
//             produto e das variações, e tudo pronto, com o pedido de permissão dos lembretes.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-11-07.
// ⌘

import SwiftUI
import TinyStockCore

// MARK: - Início

/// Cabeçalho e, logo abaixo, o espaço onde sobem os botões Começar e Restaurar backup.
/// No layout largo fica só o cabeçalho: os botões estão no painel da esquerda.
struct WelcomeStartStep: View {
    let accentColor: Color
    var isWide = false

    var body: some View {
        WelcomeStepScroll {
            VStack(spacing: 28) {
                WelcomeStepHeader(step: .start, accentColor: accentColor)
                if !isWide {
                    WelcomeButtonsSlot(step: .start)
                }
            }
        }
    }
}

// MARK: - Primeiro produto

/// Dica do que o formulário pede, antes de abrir o de verdade.
struct WelcomeProductStep: View {
    let accentColor: Color
    var isWide = false

    var body: some View {
        WelcomeStepScroll {
            VStack(spacing: 20) {
                // No layout largo o cabeçalho fica no painel da esquerda.
                if !isWide {
                    WelcomeStepHeader(step: .product, accentColor: accentColor)
                }

                AppGroupedCard(dividerInset: 66) {
                    WelcomeTipRow(icon: "camera.fill", color: .orange, key: "welcome.product.photo")
                    WelcomeTipRow(icon: "tag.fill", color: .green, key: "welcome.product.price")
                    WelcomeTipRow(icon: "shippingbox.fill", color: .blue, key: "welcome.product.stock")
                }
            }
        }
    }
}

// MARK: - Variações

/// Com ou sem variações, com o exemplo dos tamanhos de uma camiseta.
struct WelcomeVariantsStep: View {
    let accentColor: Color
    var isWide = false

    var body: some View {
        WelcomeStepScroll {
            VStack(spacing: 20) {
                if !isWide {
                    WelcomeStepHeader(step: .variants, accentColor: accentColor)
                }

                AppGroupedCard(dividerInset: 66) {
                    WelcomeTipRow(icon: "square.on.square.fill", color: .purple, key: "welcome.variants.with") {
                        sizeChips
                    }
                    WelcomeTipRow(icon: "square.fill", color: .gray, key: "welcome.variants.without")
                }
            }
        }
    }

    private var sizes: [String] {
        String(localized: "welcome.variants.sizes", bundle: .tinyStockCore).components(separatedBy: ",")
    }

    /// P, M e G com a quantidade de cada um, só ilustrando.
    private var sizeChips: some View {
        HStack(spacing: 6) {
            ForEach(Array(zip(sizes, [3, 5, 2])), id: \.0) { size, quantity in
                Text("\(size) · \(quantity)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.15), in: Capsule())
            }
        }
        .padding(.top, 6)
        .accessibilityHidden(true)
    }
}

// MARK: - Sua loja

/// Nome da loja atual. Em branco mantém o nome padrão, e o botão do rodapé vira Pular.
struct WelcomeStoreStep: View {
    @Binding var storeName: String
    let accentColor: Color
    var isWide = false
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        WelcomeStepScroll {
            VStack(spacing: 20) {
                if !isWide {
                    WelcomeStepHeader(step: .store, accentColor: accentColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    AppSectionLabel(text: String(localized: "welcome.store.field", bundle: .tinyStockCore))
                    TextField(StoreProfileService.localizedDefaultName, text: $storeName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($isFocused)
                        .onSubmit(onSubmit)
                        .padding()
                        .appCard()
                        .accessibilityLabel(String(localized: "welcome.store.field", bundle: .tinyStockCore))
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Tudo pronto

/// Pedido opcional de notificações para os lembretes de produção e envio. Recusar não bloqueia nada.
struct WelcomeReadyStep: View {
    let accentColor: Color
    var isWide = false

    @Environment(OrderReminderCoordinator.self) private var reminders

    private var notificationState: PermissionCardState {
        switch reminders.authorization {
        case .authorized, .provisional: .allowed
        case .denied: .denied
        case .notDetermined, .unknown: .idle
        }
    }

    var body: some View {
        WelcomeStepScroll {
            VStack(spacing: 20) {
                if !isWide {
                    WelcomeStepHeader(step: .ready, accentColor: accentColor)
                }

                PermissionCard(
                    icon: "bell.badge.fill",
                    iconColor: .red,
                    title: String(localized: "welcome.ready.notifications.title", bundle: .tinyStockCore),
                    desc: String(localized: "welcome.ready.notifications.desc", bundle: .tinyStockCore),
                    state: notificationState,
                    accentColor: accentColor,
                    isBusy: reminders.isRequestingPermission
                ) {
                    Task { await reminders.setEnabled(true) }
                }

                if !isWide {
                    WelcomeButtonsSlot(step: .ready)
                        .padding(.top, 8)
                }
            }
        }
        .task { await reminders.refresh() }
    }
}

// MARK: - Restaurar backup

/// De onde restaurar o backup, escolhido no balão do Início.
enum WelcomeRestoreSource {
    case iCloud, file
}

struct WelcomeRestorePopover: View {

    let accentColor: Color
    let isICloudAvailable: Bool
    let onPick: (WelcomeRestoreSource) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(String(localized: "welcome.start.restore", bundle: .tinyStockCore))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity)
                .frame(height: 48)

            VStack(spacing: 0) {
                row("welcome.restore.icloud", systemImage: "icloud.and.arrow.down", source: .iCloud)
                    .disabled(!isICloudAvailable)
                    .opacity(isICloudAvailable ? 1 : 0.4)
                Divider().padding(.leading, 52)
                row("welcome.restore.file", systemImage: "doc.badge.arrow.up", source: .file)
            }
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(.systemGroupedBackground))
    }

    private func row(_ key: String, systemImage: String, source: WelcomeRestoreSource) -> some View {
        Button { onPick(source) } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(accentColor)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                Text(String(localized: String.LocalizationValue(key), bundle: .tinyStockCore))
                    .foregroundStyle(Color.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
