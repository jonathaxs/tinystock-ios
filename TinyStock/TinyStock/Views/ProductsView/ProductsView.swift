// Proposito: Inicio com o catalogo por loja, por produto ou por variacao, em lista ou grade, com acoes e modo de
// edicao. No layout largo (iPad, Duo aberto) o topo da Inicio vira uma coluna ao lado do catalogo.
// Created by Jonathas Motta (@jonathaxs) on 2026-08-07.

import SwiftUI
import SwiftData
import TinyStockCore

struct ProductsView: View {
    @Environment(\.modelContext) private var modelContext
    private let storeID: UUID
    @Query private var products: [Product]
    @Query private var variants: [ProductVariant]
    @State private var editMode: EditMode = .inactive
    @State private var isPresentingForm = false
    @State private var editingProduct: Product?
    @State private var stockProduct: Product?
    @State private var salesProduct: Product?
    @State private var variantRequest: NewVariantRequest?
    @State private var detailProduct: Product?
    @State private var variantEditProduct: Product?
    @State private var actionProduct: Product?
    @State private var pendingAction: (ProductActionsSheet.Action, Product)?
    @State private var isPresentingModeSheet = false
    @State private var pendingDeletion: [Product] = []
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var isPresentingSale = false
    @State private var variantEdit: VariantEditRequest?
    @AppStorage("products.catalogMode") private var catalogMode: CatalogMode = .products
    @AppStorage(CatalogViewMode.storageKey) private var viewMode: CatalogViewMode = .list
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.usesVerticalBar) private var usesVerticalBar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Dobra do Duo que o layout mostra; segue a real com animacao (o sistema nao anima a dobra).
    @State private var displayedFold: HomeFold?
    /// Layout largo em uso; nele a busca fica no topo do catalogo (a barra do sistema esta escondida).
    @State private var isWideLayout = false

    init(storeID: UUID) {
        self.storeID = storeID
        _products = Query(filter: #Predicate<Product> { $0.storeID == storeID },
                          sort: [SortDescriptor(\Product.sortOrder), SortDescriptor(\Product.name)])
        _variants = Query(filter: #Predicate<ProductVariant> { $0.storeID == storeID })
    }

    private var filteredProducts: [Product] {
        products.filter { $0.matches(searchText: searchText, variants: variants) }
    }

    var body: some View {
        GeometryReader { proxy in
            let isWide = HomeLayout.isWide(width: proxy.size.width, sizeClass: horizontalSizeClass)
            // iPad deitado (sem a barra vertical do sistema): os botoes vao para a coluna de vidro a direita.
            let sideRail = isWide && !usesVerticalBar && proxy.size.width > proxy.size.height
            let fold = isWide ? HomeFold.active(in: proxy) : nil
            Group {
                if isWide {
                    HStack(spacing: 0) {
                        wideLayout(width: proxy.size.width, buttonsInRail: usesVerticalBar || sideRail,
                                   fold: displayedFold)
                        if sideRail {
                            HomeSideRail()
                                .padding(.trailing)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                } else {
                    catalogContent(showsHome: true)
                }
            }
            .onChange(of: isWide, initial: true) { _, wide in isWideLayout = wide }
            .onChange(of: fold, initial: true) { oldFold, newFold in
                guard oldFold != newFold else { displayedFold = newFold; return }
                withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.55, dampingFraction: 0.85)) {
                    displayedFold = newFold
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "tab.products", bundle: .tinyStockCore))
        .navigationBarTitleDisplayMode(.inline)
        // A Inicio desenha o proprio cabecalho (loja atual). Com a barra vertical (Duo dobrado) a barra fica
        // visivel para os botoes irem para a coluna do sistema.
        .toolbar(usesVerticalBar ? .automatic : .hidden, for: .navigationBar)
        .toolbar {
            if usesVerticalBar {
                // Um grupo so, para a coluna seguir esta ordem de cima para baixo.
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ForEach(HomeRailItem.allCases) { HomeRailButton(item: $0) }
                }
            }
        }
        .modifier(SystemSearch(isEnabled: !isWideLayout, text: $searchText))
        .sheet(isPresented: $isPresentingForm) { ProductFormView(storeID: storeID) }
        .sheet(isPresented: $isPresentingSale) { SalesOrderFormView(storeID: storeID) }
        .sheet(item: $variantEdit) { EditProductVariantView(product: $0.product, variantID: $0.variantID) }
        .sheet(item: $editingProduct) { ProductFormView(storeID: $0.storeID, product: $0) }
        .sheet(item: $stockProduct) { StockEntryView(product: $0) }
        .sheet(item: $salesProduct) { SalesOrderFormView(storeID: $0.storeID, product: $0) }
        .sheet(item: $variantRequest) { NewProductVariantView(storeID: storeID, productID: $0.productID) }
        .sheet(item: $detailProduct) { ProductDetailView(product: $0) }
        .sheet(item: $variantEditProduct) { EditProductVariantView(product: $0) }
        .sheet(isPresented: $isPresentingModeSheet) { modeSheet }
        .sheet(item: $actionProduct, onDismiss: runPendingAction) { product in
            ProductActionsSheet(product: product, quantity: quantity(of: product)) { action in
                pendingAction = (action, product)
                actionProduct = nil
            }
        }
        .alert(String(localized: "product.delete.confirm.title", bundle: .tinyStockCore), isPresented: $isConfirmingDelete) {
            Button(String(localized: "common.cancel", bundle: .tinyStockCore), role: .cancel) { pendingDeletion = [] }
            Button(String(localized: "common.delete", bundle: .tinyStockCore), role: .destructive, action: deleteProducts)
        } message: {
            Text(pendingDeletion.map(\.name).joined(separator: ", ") + "\n\n"
                 + String(localized: "products.delete.stock.message", bundle: .tinyStockCore))
        }
        .alert(String(localized: "products.error.title", bundle: .tinyStockCore), isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button(String(localized: "common.ok", bundle: .tinyStockCore)) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .onChange(of: storeID) { _, _ in
            // Nao carrega a selecao ou o modo de edicao de uma loja para outra.
            editingProduct = nil
            stockProduct = nil
            salesProduct = nil
            variantRequest = nil
            detailProduct = nil
            variantEditProduct = nil
            actionProduct = nil
            pendingAction = nil
            pendingDeletion = []
            isConfirmingDelete = false
            isPresentingForm = false
            isPresentingSale = false
            isPresentingModeSheet = false
            variantEdit = nil
            editMode = .inactive
            searchText = ""
        }
        .onChange(of: products.isEmpty) { _, empty in
            if empty { editMode = .inactive }
        }
        .onChange(of: catalogMode) { _, _ in editMode = .inactive }
        // Editar (apagar e reordenar) so existe na lista.
        .onChange(of: viewMode) { _, _ in editMode = .inactive }
    }

    // MARK: - Layout largo

    /// Topo da Inicio numa coluna ao lado do catalogo. Com o Duo meio aberto os dois se afastam da dobra: como
    /// livro o topo fica na metade esquerda; como mesa (ou aberto reto em pe) fica na metade de cima. E o mesmo
    /// par de views nos casos, entao abrir e fechar a dobra anima em vez de trocar de tela.
    private func wideLayout(width: CGFloat, buttonsInRail: Bool, fold: HomeFold?) -> some View {
        let compact = width < HomeLayout.compactWideLimit
        let layout: AnyLayout
        var heroWidth: CGFloat? = compact ? HomeLayout.compactHeroWidth : HomeLayout.heroWidth
        var heroHeight: CGFloat?
        var stacked = false
        switch fold {
        case .book(let band):
            layout = AnyLayout(HStackLayout(spacing: band.width))
            heroWidth = max(band.minX, 0)
        case .tabletop(let band):
            layout = AnyLayout(VStackLayout(spacing: band.height))
            heroWidth = nil
            heroHeight = max(band.minY, 0)
            stacked = true
        case .flatPortrait(let splitY):
            layout = AnyLayout(VStackLayout(spacing: 0))
            heroWidth = nil
            heroHeight = splitY
            stacked = true
        case nil:
            layout = AnyLayout(HStackLayout(spacing: 0))
        }
        return layout {
            wideHomeColumn(buttonsInRail: buttonsInRail, stacked: stacked)
                .frame(width: heroWidth, height: heroHeight)
                .frame(maxWidth: heroWidth == nil ? .infinity : nil)
            catalogContent(showsHome: false)
        }
    }

    /// Botoes (sem coluna), loja atual, caixa e Adicionar. Empilhado em cima do catalogo (Duo em pe), a caixa
    /// fica ao lado do resto para caber na metade da tela.
    private func wideHomeColumn(buttonsInRail: Bool, stacked: Bool) -> some View {
        let hero = HomeHeroView(storeID: storeID, products: products, variants: variants)
        let controls = VStack(spacing: 14) {
            if !buttonsInRail {
                HomePageButtons()
            }
            StoreSwitcherView()
            HomeAddButton(hasProducts: !products.isEmpty, onPick: handleAdd)
        }
        return GeometryReader { proxy in
            ScrollView {
                Group {
                    if stacked {
                        HStack(spacing: 16) {
                            hero.frame(maxWidth: 240)
                            controls.frame(maxWidth: 320)
                        }
                    } else {
                        VStack(spacing: 14) {
                            if !buttonsInRail {
                                HomePageButtons()
                                    .padding(.bottom, 6)
                            }
                            StoreSwitcherView()
                            hero
                            HomeAddButton(hasProducts: !products.isEmpty, onPick: handleAdd)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Catalogo

    private func catalogContent(showsHome: Bool) -> some View {
        List {
            // Durante a busca a lista mostra so os resultados.
            if showsHome && searchText.isEmpty {
                Section { homeRows }
            }
            // No layout largo a barra de navegacao fica escondida, e com ela a busca do sistema no iPad.
            if !showsHome && !products.isEmpty {
                Section {
                    CatalogSearchField(text: $searchText)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                        .moveDisabled(true)
                        .deleteDisabled(true)
                }
            }
            if products.isEmpty {
                Section { emptyCatalog }
            } else if filteredProducts.isEmpty {
                Section { ContentUnavailableView.search(text: searchText) }
            } else {
                Section { catalogHeader }
                if viewMode == .grid {
                    gridSections
                } else if catalogMode == .variants {
                    variantSections
                } else {
                    Section {
                        ForEach(filteredProducts) { product in
                            productRow(product)
                                .deleteDisabled(!editMode.isEditing)
                        }
                        // O menos nativo so aparece em Editar; a confirmacao usa os objetos da lista filtrada.
                        .onDelete(perform: requestDeletion)
                        .onMove(perform: moveAction)
                    }
                }
            }
        }
        .listSectionSpacing(.compact)
        .environment(\.editMode, $editMode)
    }

    /// Topo da Inicio: loja atual, caixa com o resumo, botoes redondos e Adicionar.
    private var homeRows: some View {
        Group {
            StoreSwitcherView()
                .frame(maxWidth: .infinity)
            HomeHeroView(storeID: storeID, products: products, variants: variants)
            // Com a barra vertical (Duo dobrado) os botoes vao para a coluna do sistema.
            if !usesVerticalBar {
                HomePageButtons()
            }
            HomeAddButton(hasProducts: !products.isEmpty, onPick: handleAdd)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
        .moveDisabled(true)
        .deleteDisabled(true)
    }

    private var emptyCatalog: some View {
        ContentUnavailableView {
            Label(String(localized: "products.empty.title", bundle: .tinyStockCore), systemImage: "shippingbox")
        } description: {
            Text(String(localized: "products.empty.message", bundle: .tinyStockCore))
        }
        .listRowBackground(Color.clear)
    }

    /// Acima do catalogo: troca entre produtos e variacoes e, nos produtos, o Editar.
    private var catalogHeader: some View {
        HStack(spacing: 12) {
            TitleSelectorButton(title: catalogMode.title) { isPresentingModeSheet = true }
            // O EditButton do sistema alterava outro modo de edicao e nao alcancava a lista.
            if catalogMode == .products && viewMode == .list {
                Button(editMode.isEditing
                       ? String(localized: "common.done", bundle: .tinyStockCore)
                       : String(localized: "common.edit", bundle: .tinyStockCore)) {
                    withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                }
                .buttonStyle(.borderless)
                .font(.body.weight(.semibold))
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))
        .listRowSeparator(.hidden)
        .moveDisabled(true)
        .deleteDisabled(true)
    }

    private func handleAdd(_ action: HomeAddAction) {
        switch action {
        case .product: isPresentingForm = true
        case .variant: variantRequest = NewVariantRequest(productID: nil)
        case .sale: isPresentingSale = true
        }
    }

    private var modeSheet: some View {
        BottomActionSheet {
            BottomActionSheetTitle(title: String(localized: "products.mode", bundle: .tinyStockCore))
            ForEach(CatalogMode.allCases, id: \.self) { mode in
                SheetActionButton(title: mode.title, systemImage: mode.systemImage,
                                  isSelected: mode == catalogMode) {
                    catalogMode = mode
                    isPresentingModeSheet = false
                }
            }
        }
    }

    /// Grade: fotos lado a lado. Produtos abrem o balao de acoes; variacoes abrem a edicao.
    @ViewBuilder
    private var gridSections: some View {
        if catalogMode == .variants {
            ForEach(filteredProducts) { product in
                Section(product.name) {
                    VariantCatalogGrid(variants: variants(of: product)) { variant in
                        variantEdit = VariantEditRequest(product: product, variantID: variant.id)
                    }
                    .gridRowStyle()
                }
            }
        } else {
            Section {
                ProductCatalogGrid(products: filteredProducts, variants: variants) { action, product in
                    pendingAction = (action, product)
                    runPendingAction()
                }
                .gridRowStyle()
            }
        }
    }

    private var variantSections: some View {
        ForEach(filteredProducts) { product in
            Section(product.name) {
                ForEach(variants(of: product)) { variant in
                    Button { variantEdit = VariantEditRequest(product: product, variantID: variant.id) } label: {
                        HStack(spacing: 12) {
                            ProductImageView(imageData: variant.imageData, side: 44)
                            Text(variant.isDefault
                                 ? String(localized: "products.variants.noVariation", bundle: .tinyStockCore)
                                 : variant.name)
                            Spacer(minLength: 8)
                            Text(variant.quantity, format: .number)
                                .monospacedDigit()
                                .foregroundStyle(.tint)
                            chevron
                        }
                        .contentShape(Rectangle())
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    private func variants(of product: Product) -> [ProductVariant] {
        variants.filter { $0.productID == product.id }.sorted { $0.name < $1.name }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func productRow(_ product: Product) -> some View {
        if editMode.isEditing {
            Button { editingProduct = product } label: {
                rowLabel(product)
            }
            .buttonStyle(.plain)
            .accessibilityHint(String(localized: "products.edit.hint", bundle: .tinyStockCore))
        } else {
            // Botoes separados deixam claro o que cada toque faz; a linha em si nao reage.
            HStack(spacing: 4) {
                ProductRowView(product: product, quantity: quantity(of: product))
                rowButton("info.circle", "products.details") { detailProduct = product }
                rowButton("gearshape", "products.actions") { actionProduct = product }
            }
        }
    }

    private func rowButton(_ systemImage: String, _ labelKey: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(String(localized: String.LocalizationValue(labelKey), bundle: .tinyStockCore))
    }

    private func rowLabel(_ product: Product) -> some View {
        ProductRowView(product: product, quantity: quantity(of: product))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }

    private func quantity(of product: Product) -> Decimal {
        ProductVariantService.displayedQuantity(for: product, among: variants)
    }

    /// Uma folha so abre depois que a anterior termina de fechar.
    private func runPendingAction() {
        guard let (action, product) = pendingAction else { return }
        pendingAction = nil
        switch action {
        case .details: detailProduct = product
        case .sale: salesProduct = product
        case .stockEntry: stockProduct = product
        case .newVariant: variantRequest = NewVariantRequest(productID: product.id)
        case .editVariant: variantEditProduct = product
        case .edit: editingProduct = product
        }
    }

    private func requestDeletion(at offsets: IndexSet) {
        pendingDeletion = offsets.compactMap { filteredProducts.indices.contains($0) ? filteredProducts[$0] : nil }
        isConfirmingDelete = !pendingDeletion.isEmpty
    }

    /// A ordem manual so vale para o catalogo completo, em modo de edicao e sem busca ativa.
    private var moveAction: ((IndexSet, Int) -> Void)? {
        guard editMode.isEditing, searchText.isEmpty else { return nil }
        return { source, destination in moveProducts(from: source, to: destination) }
    }

    private func moveProducts(from source: IndexSet, to destination: Int) {
        // Preserva pendencias anteriores caso a gravacao da nova ordem falhe.
        do { try modelContext.save() } catch {
            errorMessage = error.localizedDescription
            return
        }
        var ordered = products
        ordered.move(fromOffsets: source, toOffset: destination)
        ProductService.setDisplayOrder(ordered)
        do { try modelContext.save() } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func deleteProducts() {
        // Preserva pendencias anteriores caso a gravacao deste lote falhe.
        do { try modelContext.save() } catch {
            errorMessage = error.localizedDescription
            return
        }
        do {
            for product in pendingDeletion { try ProductService.delete(product, in: modelContext) }
            try modelContext.save()
            pendingDeletion = []
        } catch {
            modelContext.rollback()
            pendingDeletion = []
            errorMessage = (error as? ProductError)?.localizedMessage ?? error.localizedDescription
        }
    }
}

private extension View {
    /// A grade fica direto no fundo da tela, sem o card da linha da lista.
    func gridRowStyle() -> some View {
        listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowSeparator(.hidden)
            .moveDisabled(true)
            .deleteDisabled(true)
    }
}

// MARK: - Busca

/// Busca do sistema (na barra de baixo do iPhone); desligada no layout largo, que usa a `CatalogSearchField`.
private struct SystemSearch: ViewModifier {
    let isEnabled: Bool
    @Binding var text: String

    func body(content: Content) -> some View {
        if isEnabled {
            content.searchable(text: $text,
                               prompt: Text(String(localized: "products.catalog.search", bundle: .tinyStockCore)))
        } else {
            content
        }
    }
}

/// Campo de busca em capsula de vidro no topo do catalogo do layout largo.
private struct CatalogSearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(String(localized: "products.catalog.search", bundle: .tinyStockCore), text: $text)
                .focused($isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "common.clear", bundle: .tinyStockCore))
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(minHeight: 44)
        .appGlass(in: Capsule())
        .contentShape(Capsule())
        .onTapGesture { isFocused = true }
    }
}

// MARK: - Layout largo e dobra

/// Medidas do layout largo, as mesmas da Hoje do Nutshell. A apresentacao inicial usa as mesmas.
enum HomeLayout {
    static let compactWideLimit: CGFloat = 744
    static let compactHeroWidth: CGFloat = 320
    static let heroWidth: CGFloat = 360

    /// Largo a partir de 700 pt, ou ja a partir de 560 pt com largura regular (Duo aberto em pe, ~669 pt, fica
    /// igual ao iPad mini em vez do layout de iPhone esticado). Mesma regra dos Ajustes.
    static func isWide(width: CGFloat, sizeClass: UserInterfaceSizeClass?) -> Bool {
        width >= 700 || (sizeClass == .regular && width >= 560)
    }
}

/// Postura do iPhone Duo, com a faixa da dobra (margens incluidas) no espaco da Inicio.
private enum HomeFold: Equatable {
    /// Meio aberto com a dobra vertical: metades esquerda e direita.
    case book(CGRect)
    /// Meio aberto com a dobra horizontal: metade de cima em pe, de baixo apoiada.
    case tabletop(CGRect)
    /// Aberto reto em pe: mesmo arranjo da mesa, dividido no meio da tela (y).
    case flatPortrait(CGFloat)

    /// A faixa ativa (meio aberto) ou, aberto reto em pe, o meio da tela. A regiao inativa existe so no Duo.
    /// Nil fora do Duo e no Duo aberto reto deitado.
    static func active(in proxy: GeometryProxy) -> HomeFold? {
        guard #available(iOS 27.1, *) else { return nil }
        let regions = proxy.reservedRegions(kind: .division, options: [.includeInactive])
        if let band = regions.first(where: \.isActive)?.frame {
            return band.height > band.width ? .book(band) : .tabletop(band)
        }
        if !regions.isEmpty && proxy.size.height > proxy.size.width {
            return .flatPortrait(proxy.size.height / 2)
        }
        return nil
    }
}

/// Forma de exibir o catalogo, lembrada entre aberturas do aplicativo.
private enum CatalogMode: String, CaseIterable {
    case products, variants

    var title: String {
        switch self {
        case .products: String(localized: "products.mode.products", bundle: .tinyStockCore)
        case .variants: String(localized: "products.mode.variants", bundle: .tinyStockCore)
        }
    }

    var systemImage: String {
        switch self {
        case .products: "shippingbox"
        case .variants: "square.stack.3d.up"
        }
    }
}

private struct VariantEditRequest: Identifiable {
    let product: Product
    let variantID: UUID
    var id: UUID { variantID }
}

/// Pedido de nova variacao; sem produto, a tela deixa o usuario escolher no catalogo.
private struct NewVariantRequest: Identifiable {
    let id = UUID()
    let productID: UUID?
}

#Preview {
    let storeID = UUID()
    NavigationStack { ProductsView(storeID: storeID) }
        .environment(StoreSession(selectedStoreID: storeID))
        .environment(AppRouter())
        .modelContainer(for: [StoreProfile.self, Product.self, ProductVariant.self, StockMovement.self, SalesOrder.self, SalesOrderItem.self], inMemory: true)
}
