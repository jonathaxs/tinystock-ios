// ⌘
//  TinyStock/Views/WelcomeView/WelcomeView.swift
//
//  Propósito: Apresentação mostrada só na primeira abertura: o que o app faz, o nome da loja (opcional)
//             e os lembretes. Dona do estado das etapas, dos botões do rodapé e da restauração de backup.
//             No layout largo (iPad, Duo aberto) o título da etapa e os botões vão para um painel à esquerda.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-11-07.
// ⌘

import SwiftData
import SwiftUI
import TinyStockCore
import UniformTypeIdentifiers

/// Chave de conclusão da apresentação.
enum WelcomeStorage {
    static let didCompleteKey = "app.didCompleteWelcome"

    /// Quem já tem dados (atualização do app ou banco restaurado) não vê a apresentação.
    static func markCompletedIfHasData(in context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didCompleteKey) else { return }
        let products = (try? context.fetchCount(FetchDescriptor<Product>())) ?? 0
        let orders = (try? context.fetchCount(FetchDescriptor<SalesOrder>())) ?? 0
        let stores = (try? context.fetchCount(FetchDescriptor<StoreProfile>())) ?? 0
        if products > 0 || orders > 0 || stores > 1 {
            defaults.set(true, forKey: didCompleteKey)
        }
    }
}

struct WelcomeView: View {

    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(StoreSession.self) private var storeSession
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(AppAccentColor.storageKey) private var accentColorRaw = AppAccentColor.defaultColor.rawValue
    @Query private var stores: [StoreProfile]

    @State private var currentStep: WelcomeStep = .start
    @State private var isGoingForward = true
    @State private var storeName = ""
    @State private var storeError: String?

    // Restaurar backup, no Início.
    @State private var backupCoordinator = DataBackupCoordinator()
    @State private var showRestoreOptions = false

    // Botões do rodapé: onde ficam e o espaço que as etapas Início e Tudo pronto reservam para eles.
    @State private var footerFrame: CGRect?
    @State private var slotFrames: [WelcomeStep: CGRect] = [:]
    @State private var buttonsHeight: CGFloat = 112
    // A primeira posição (Início, ao abrir) entra sem animação.
    @State private var didPlaceButtons = false

    private var accentColor: Color {
        (AppAccentColor(rawValue: accentColorRaw) ?? .defaultColor).color
    }

    private var currentStore: StoreProfile? {
        stores.first { $0.id == storeSession.selectedStoreID }
    }

    private var trimmedStoreName: String {
        storeName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Body

    var body: some View {
        @Bindable var backupCoordinator = backupCoordinator

        GeometryReader { proxy in
            if HomeLayout.isWide(width: proxy.size.width, sizeClass: horizontalSizeClass) {
                HStack(spacing: 0) {
                    WelcomeContextPanel(currentStep: currentStep, accentColor: accentColor) {
                        buttonPair
                    }
                    .frame(width: proxy.size.width < HomeLayout.compactWideLimit
                           ? HomeLayout.compactHeroWidth : HomeLayout.heroWidth)
                    Divider()
                        .ignoresSafeArea()
                    stepContent(isWide: true)
                }
            } else {
                stepContent(isWide: false)
            }
        }
        .background { background }
            .onAppear(perform: prefillStoreName)
            .fileImporter(
                isPresented: $backupCoordinator.isImporting,
                allowedContentTypes: [.json],
                onCompletion: backupCoordinator.handleImportResult
            )
            .alert(
                String(localized: "settings.backup.import.confirm.title", bundle: .tinyStockCore),
                isPresented: $backupCoordinator.isConfirmingImport
            ) {
                Button(String(localized: "settings.backup.import.confirm.action", bundle: .tinyStockCore),
                       role: .destructive) {
                    backupCoordinator.restorePendingBackup(
                        into: modelContext, storeID: storeSession.selectedStoreID, storeSession: storeSession
                    )
                }
                Button(String(localized: "common.cancel", bundle: .tinyStockCore), role: .cancel) {
                    backupCoordinator.cancelPendingImport()
                }
            } message: {
                if let payload = backupCoordinator.pendingPayload {
                    Text(backupCoordinator.importConfirmationMessage(for: payload))
                }
            }
            .alert(
                String(localized: "settings.backup.icloud.restore.confirm.title", bundle: .tinyStockCore),
                isPresented: $backupCoordinator.isConfirmingICloudRestore
            ) {
                Button(String(localized: "settings.backup.icloud.restore", bundle: .tinyStockCore), role: .destructive) {
                    Task {
                        await backupCoordinator.restoreFromICloud(
                            into: modelContext, storeID: storeSession.selectedStoreID, storeSession: storeSession
                        )
                    }
                }
                Button(String(localized: "common.cancel", bundle: .tinyStockCore), role: .cancel) { }
            } message: {
                Text(String(localized: "settings.backup.icloud.restore.confirm.message", bundle: .tinyStockCore))
            }
            .alert(item: $backupCoordinator.presentedMessage) { message in
                Alert(title: Text(message.title), message: Text(message.message),
                      dismissButton: .default(Text(String(localized: "common.ok", bundle: .tinyStockCore))))
            }
            .alert(String(localized: "store.error.title", bundle: .tinyStockCore), isPresented: Binding(
                get: { storeError != nil }, set: { if !$0 { storeError = nil } }
            )) {
                Button(String(localized: "common.ok", bundle: .tinyStockCore)) { storeError = nil }
            } message: { Text(storeError ?? "") }
            // Backup restaurado: os dados já estão no app, então a apresentação termina.
            .onChange(of: backupCoordinator.completedRestores) { _, _ in
                backupCoordinator.presentedMessage = nil
                onComplete()
            }
            .overlay {
                if backupCoordinator.isRestoringFromICloud {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        ProgressView().controlSize(.large)
                    }
                }
            }
    }

    // Fundo agrupado com um brilho suave da cor de destaque no topo.
    private var background: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
            LinearGradient(colors: [accentColor.opacity(0.22), accentColor.opacity(0)],
                           startPoint: .top, endPoint: .center)
        }
        .ignoresSafeArea()
    }

    // MARK: - Etapas

    private func stepContent(isWide: Bool) -> some View {
        VStack(spacing: 0) {
            WelcomeProgressBar(currentStep: currentStep, activeColor: accentColor)
                .frame(minHeight: 44)
                .padding(.horizontal, AppStyle.horizontalPadding)
                .padding(.top, 12)

            Group {
                switch currentStep {
                case .start: WelcomeStartStep(accentColor: accentColor, isWide: isWide)
                case .about: WelcomeAboutStep(accentColor: accentColor, isWide: isWide)
                case .store: WelcomeStoreStep(storeName: $storeName, accentColor: accentColor, isWide: isWide,
                                              onSubmit: advance)
                case .ready: WelcomeReadyStep(accentColor: accentColor, isWide: isWide)
                }
            }
            .frame(maxHeight: .infinity)
            // Esmaece o conteúdo nas bordas, em vez de cortar seco no topo e acima dos botões.
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 16)
                    Color.black
                    LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 28)
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: isGoingForward ? .trailing : .leading),
                removal: .move(edge: isGoingForward ? .leading : .trailing)
            ))
            .animation(.easeInOut(duration: 0.3), value: currentStep)
            .environment(\.welcomeButtonsHeight, buttonsHeight)
            .environment(\.welcomeButtonsSlotReporter, WelcomeButtonsSlotReporter(report: reportSlot))

            // No layout largo os botões ficam no painel da esquerda.
            if !isWide {
                footerButtons
            }
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        // Os botões ficam fixos na base com o teclado aberto; o ScrollView de cada etapa se ajusta.
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Botões do rodapé

    /// Um só par de botões para todas as etapas. No Início ficam logo abaixo do "Olá!", mais estreitos
    /// (Começar e Restaurar backup); ao avançar descem para o rodapé e viram Continuar e Voltar.
    /// No Tudo pronto sobem para logo abaixo da permissão.
    private var footerButtons: some View {
        buttonPair
        .frame(maxWidth: currentStep == .start ? 260 : .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { buttonsHeight = $0 }
        .offset(y: buttonsOffset)
        // Até saber onde fica o espaço do Início, os botões não aparecem (evita o pulo ao abrir).
        .opacity(didPlaceButtons ? 1 : 0)
        .padding(.horizontal, AppStyle.horizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 16)
        // Medido fora do offset: é a posição de repouso no rodapé.
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { footerFrame = $0 }
    }

    /// Continuar e Voltar (Começar e Restaurar backup no Início), no rodapé ou no painel do layout largo.
    private var buttonPair: some View {
        VStack(spacing: 10) {
            WelcomeContinueButton(label: continueLabel, color: accentColor, action: advance)

            Button {
                if currentStep == .start { showRestoreOptions = true } else { goBack() }
            } label: {
                Text(currentStep == .start
                     ? String(localized: "welcome.start.restore", bundle: .tinyStockCore)
                     : String(localized: "welcome.button.back", bundle: .tinyStockCore))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .appSecondaryButton(accentColor)
            .adaptivePopover(isPresented: $showRestoreOptions) {
                WelcomeRestorePopover(accentColor: accentColor,
                                      isICloudAvailable: backupCoordinator.isICloudAvailable) { source in
                    showRestoreOptions = false
                    // Espera o balão fechar antes do seletor de arquivo ou da confirmação.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        switch source {
                        case .iCloud: backupCoordinator.isConfirmingICloudRestore = true
                        case .file: backupCoordinator.isImporting = true
                        }
                    }
                }
            }
        }
    }

    private var continueLabel: String {
        switch currentStep {
        case .start: String(localized: "welcome.button.start", bundle: .tinyStockCore)
        case .store where trimmedStoreName.isEmpty: String(localized: "welcome.button.skip", bundle: .tinyStockCore)
        case .ready: String(localized: "welcome.button.finish", bundle: .tinyStockCore)
        default: String(localized: "welcome.button.continue", bundle: .tinyStockCore)
        }
    }

    /// Quanto os botões sobem do rodapé até o espaço reservado pela etapa (0 = no rodapé).
    private var buttonsOffset: CGFloat {
        guard let footerFrame, let slot = slotFrames[currentStep] else { return 0 }
        // O VStack dos botões começa 8 pt abaixo do topo do rodapé (padding de cima).
        return slot.minY - (footerFrame.minY + 8)
    }

    /// Só vale a posição da etapa atual, para a etapa que sai deslizando não puxar os botões junto.
    private func reportSlot(_ step: WelcomeStep, _ frame: CGRect) {
        guard step == currentStep else { return }
        if didPlaceButtons {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { slotFrames[step] = frame }
        } else {
            slotFrames[step] = frame
            DispatchQueue.main.async { didPlaceButtons = true }
        }
    }

    // MARK: - Navegação

    private func advance() {
        if currentStep == .store, !saveStoreName() { return }
        guard let next = WelcomeStep(rawValue: currentStep.rawValue + 1) else {
            onComplete()
            return
        }
        isGoingForward = true
        withAnimation(.easeInOut(duration: 0.3)) { currentStep = next }
    }

    private func goBack() {
        guard let previous = WelcomeStep(rawValue: currentStep.rawValue - 1) else { return }
        isGoingForward = false
        withAnimation(.easeInOut(duration: 0.3)) { currentStep = previous }
    }

    // MARK: - Loja

    /// Um nome já trocado (ex.: vindo do iCloud) aparece no campo; o padrão fica só como dica.
    private func prefillStoreName() {
        guard let name = currentStore?.name, name != StoreProfileService.localizedDefaultName else { return }
        storeName = name
    }

    /// Em branco mantém o nome atual. Devolve false quando o nome não pôde ser salvo.
    private func saveStoreName() -> Bool {
        guard let store = currentStore, !trimmedStoreName.isEmpty, trimmedStoreName != store.name else { return true }
        do {
            try StoreProfileService.update(store, name: trimmedStoreName, imageData: store.imageData, in: modelContext)
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            storeError = (error as? StoreProfileError)?.localizedMessage ?? error.localizedDescription
            return false
        }
    }
}
