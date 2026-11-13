// ⌘
//  TinyStock/Views/WelcomeView/WelcomeSteps.swift
//
//  Propósito: Conteúdo de cada etapa da apresentação: início, o que o app faz, nome da loja (opcional)
//             e tudo pronto, com o pedido de permissão dos lembretes.
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

// MARK: - O que dá para fazer

struct WelcomeAboutStep: View {
    let accentColor: Color
    var isWide = false

    var body: some View {
        WelcomeStepScroll {
            VStack(spacing: 20) {
                // No layout largo o cabeçalho fica no painel da esquerda.
                if !isWide {
                    WelcomeStepHeader(step: .about, accentColor: accentColor)
                }

                AppGroupedCard(dividerInset: 66) {
                    feature("shippingbox.fill", .orange, "welcome.about.products")
                    feature("calendar", .blue, "welcome.about.orders")
                    feature("chart.bar.fill", .green, "welcome.about.reports")
                    feature("storefront.fill", .purple, "welcome.about.stores")
                    feature("icloud.fill", .cyan, "welcome.about.icloud")
                }
            }
        }
    }

    private func feature(_ icon: String, _ color: Color, _ key: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            IconBadge(systemName: icon, color: color, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: String.LocalizationValue(key + ".title"), bundle: .tinyStockCore))
                    .font(.headline)
                Text(String(localized: String.LocalizationValue(key + ".desc"), bundle: .tinyStockCore))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
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
