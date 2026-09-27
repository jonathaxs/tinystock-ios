// Proposito: Catalogo por loja com menu operacional e modo de edicao.
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
    @State private var pendingDeletion: [Product] = []
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?
    @State private var searchText = ""

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
            .sheet(item: $editingProduct) { ProductFormView(storeID: $0.storeID, product: $0) }
            .sheet(item: $stockProduct) { StockEntryView(product: $0) }
            .sheet(item: $salesProduct) { SalesOrderFormView(product: $0) }
            .sheet(item: $variantRequest) { NewProductVariantView(storeID: storeID, productID: $0.productID) }
            .sheet(item: $detailProduct) { ProductDetailView(product: $0) }
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
            pendingDeletion = []
            isConfirmingDelete = false
            isPresentingForm = false
            editMode = .inactive
            searchText = ""
        }
        .onChange(of: products.isEmpty) { _, empty in
            if empty { editMode = .inactive }
        }
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
            } else {
                List {
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

    @ToolbarContentBuilder
    private var productToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { StoreSwitcherView() }
        ToolbarItemGroup(placement: .topBarTrailing) {
            // O EditButton da barra alterava outro modo de edicao e nao alcancava a lista.
            Button(editMode.isEditing
                   ? String(localized: "common.done", bundle: .tinyStockCore)
                   : String(localized: "common.edit", bundle: .tinyStockCore)) {
                withAnimation { editMode = editMode.isEditing ? .inactive : .active }
            }
            .disabled(products.isEmpty)
            Menu {
                Button { isPresentingForm = true } label: {
                    Label(String(localized: "product.form.title.new", bundle: .tinyStockCore), systemImage: "shippingbox")
                }
                Button { variantRequest = NewVariantRequest(productID: nil) } label: {
                    Label(String(localized: "stock.entry.newVariant", bundle: .tinyStockCore), systemImage: "plus.square.on.square")
                }
                .disabled(products.isEmpty)
            } label: {
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
            Menu {
                Button { detailProduct = product } label: {
                    Label(String(localized: "products.details", bundle: .tinyStockCore), systemImage: "info.circle")
                }
                Button { salesProduct = product } label: {
                    Label(String(localized: "sale.new.title", bundle: .tinyStockCore), systemImage: "cart.badge.plus")
                }
                Button { stockProduct = product } label: {
                    Label(String(localized: "stock.entry.title", bundle: .tinyStockCore), systemImage: "shippingbox.and.arrow.backward")
                }
                Button { variantRequest = NewVariantRequest(productID: product.id) } label: {
                    Label(String(localized: "stock.entry.newVariant", bundle: .tinyStockCore), systemImage: "plus.square.on.square")
                }
                Button { editingProduct = product } label: {
                    Label(String(localized: "product.form.title.edit", bundle: .tinyStockCore), systemImage: "pencil")
                }
            } label: {
                rowLabel(product)
            }
            .buttonStyle(.plain)
            .accessibilityHint(String(localized: "products.actions.hint", bundle: .tinyStockCore))
        }
    }

    private func rowLabel(_ product: Product) -> some View {
        ProductRowView(product: product, quantity: ProductVariantService.displayedQuantity(for: product, among: variants))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
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
