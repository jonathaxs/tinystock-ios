// Proposito: Catalogo por loja, por produto ou por variacao, com acoes e modo de edicao.
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
    @State private var isPresentingAddSheet = false
    @State private var pendingAdd: AddAction?
    @State private var isPresentingModeSheet = false
    @State private var pendingDeletion: [Product] = []
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var isPresentingSale = false
    @State private var variantEdit: VariantEditRequest?
    @AppStorage("products.catalogMode") private var catalogMode: CatalogMode = .products

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
        NavigationStack {
            catalogContent
            .navigationTitle(String(localized: "tab.products", bundle: .tinyStockCore))
            .toolbar { productToolbar }
            .searchable(text: $searchText, prompt: Text(String(localized: "products.catalog.search", bundle: .tinyStockCore)))
            .sheet(isPresented: $isPresentingForm) { ProductFormView(storeID: storeID) }
            .sheet(isPresented: $isPresentingSale) { SalesOrderFormView(storeID: storeID) }
            .sheet(item: $variantEdit) { EditProductVariantView(product: $0.product, variantID: $0.variantID) }
            .sheet(item: $editingProduct) { ProductFormView(storeID: $0.storeID, product: $0) }
            .sheet(item: $stockProduct) { StockEntryView(product: $0) }
            .sheet(item: $salesProduct) { SalesOrderFormView(storeID: $0.storeID, product: $0) }
            .sheet(item: $variantRequest) { NewProductVariantView(storeID: storeID, productID: $0.productID) }
            .sheet(item: $detailProduct) { ProductDetailView(product: $0) }
            .sheet(item: $variantEditProduct) { EditProductVariantView(product: $0) }
            .sheet(isPresented: $isPresentingAddSheet, onDismiss: runPendingAdd) { addSheet }
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
        }
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
            isPresentingAddSheet = false
            isPresentingModeSheet = false
            pendingAdd = nil
            variantEdit = nil
            editMode = .inactive
            searchText = ""
        }
        .onChange(of: products.isEmpty) { _, empty in
            if empty { editMode = .inactive }
        }
        .onChange(of: catalogMode) { _, _ in editMode = .inactive }
    }

    private var catalogContent: some View {
        Group {
            if products.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "products.empty.title", bundle: .tinyStockCore), systemImage: "shippingbox")
                } description: {
                    Text(String(localized: "products.empty.message", bundle: .tinyStockCore))
                } actions: {
                    Button(String(localized: "products.add", bundle: .tinyStockCore)) { isPresentingForm = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            } else if filteredProducts.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if catalogMode == .variants {
                variantList
            } else {
                List {
                    modeSelector
                    ForEach(filteredProducts) { product in
                        productRow(product)
                            .deleteDisabled(!editMode.isEditing)
                    }
                    // O menos nativo so aparece em Editar; a confirmacao usa os objetos da lista filtrada.
                    .onDelete(perform: requestDeletion)
                    .onMove(perform: moveAction)
                }
                .environment(\.editMode, $editMode)
            }
        }
    }

    /// Abaixo do titulo, alterna entre produtos e variacoes agrupadas por produto.
    private var modeSelector: some View {
        TitleSelectorButton(title: catalogMode.title) { isPresentingModeSheet = true }
            .moveDisabled(true)
            .deleteDisabled(true)
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

    private var addSheet: some View {
        BottomActionSheet {
            SheetActionButton(title: String(localized: "product.form.title.new", bundle: .tinyStockCore),
                              systemImage: "shippingbox") { chooseAdd(.product) }
            SheetActionButton(title: String(localized: "stock.entry.newVariant", bundle: .tinyStockCore),
                              systemImage: "plus.square.on.square") { chooseAdd(.variant) }
                .disabled(products.isEmpty)
            SheetActionButton(title: String(localized: "sale.new.title", bundle: .tinyStockCore),
                              systemImage: "cart.badge.plus") { chooseAdd(.sale) }
                .disabled(products.isEmpty)
        }
    }

    private func chooseAdd(_ action: AddAction) {
        pendingAdd = action
        isPresentingAddSheet = false
    }

    /// Uma folha so abre depois que a anterior termina de fechar.
    private func runPendingAdd() {
        guard let action = pendingAdd else { return }
        pendingAdd = nil
        switch action {
        case .product: isPresentingForm = true
        case .variant: variantRequest = NewVariantRequest(productID: nil)
        case .sale: isPresentingSale = true
        }
    }

    private var variantList: some View {
        List {
            modeSelector
            ForEach(filteredProducts) { product in
                Section(product.name) {
                    ForEach(variants(of: product)) { variant in
                        Button { variantEdit = VariantEditRequest(product: product, variantID: variant.id) } label: {
                            LabeledContent(variant.isDefault
                                           ? String(localized: "products.variants.noVariation", bundle: .tinyStockCore)
                                           : variant.name) {
                                HStack(spacing: 6) {
                                    Text(variant.quantity, format: .number)
                                        .monospacedDigit()
                                        .foregroundStyle(.tint)
                                    chevron
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .foregroundStyle(.primary)
                    }
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

    @ToolbarContentBuilder
    private var productToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { StoreSwitcherView() }
        ToolbarItemGroup(placement: .topBarTrailing) {
            // O EditButton da barra alterava outro modo de edicao e nao alcancava a lista.
            if catalogMode == .products {
                Button(editMode.isEditing
                       ? String(localized: "common.done", bundle: .tinyStockCore)
                       : String(localized: "common.edit", bundle: .tinyStockCore)) {
                    withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                }
                .disabled(products.isEmpty)
            }
            Button { isPresentingAddSheet = true } label: {
                Label(String(localized: "products.add", bundle: .tinyStockCore), systemImage: "plus")
            }
        }
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
            Button { actionProduct = product } label: {
                rowLabel(product)
            }
            .buttonStyle(.plain)
            .accessibilityHint(String(localized: "products.actions.hint", bundle: .tinyStockCore))
        }
    }

    private func rowLabel(_ product: Product) -> some View {
        HStack(spacing: 8) {
            ProductRowView(product: product, quantity: quantity(of: product))
            if !editMode.isEditing { chevron }
        }
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

private enum AddAction {
    case product, variant, sale
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
    ProductsView(storeID: storeID)
        .environment(StoreSession(selectedStoreID: storeID))
        .modelContainer(for: [StoreProfile.self, Product.self, ProductVariant.self, StockMovement.self, SalesOrder.self, SalesOrderItem.self], inMemory: true)
}
