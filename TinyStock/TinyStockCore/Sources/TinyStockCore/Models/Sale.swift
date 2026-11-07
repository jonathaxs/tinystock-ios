// ⌘
//  TinyStockCore/Models/Sale.swift
//
//  Propósito: Model SwiftData de uma venda, com seus itens, forma de pagamento e totais.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-11.
// ⌘

import Foundation
import SwiftData

// MARK: - Venda

/// Uma venda fechada, com um ou mais itens.
/// Todas as propriedades possuem valor padrão para manter a compatibilidade com o CloudKit.
@Model
public final class Sale {

    public var id: UUID = UUID()

    /// Loja em que a venda foi registrada.
    public var storeID: UUID = StoreScope.unassignedStoreID

    /// Quando a venda aconteceu. É por essa data que o histórico agrupa e os relatórios filtram.
    public var date: Date = Date()

    /// Forma de pagamento guardada como texto.
    ///
    /// O texto persistido permite filtrar com `#Predicate`, que não oferece suporte confiável
    /// a enums. O acesso tipado permanece disponível em `paymentMethod`.
    public var paymentMethodRawValue: String = PaymentMethod.pix.rawValue

    /// Anotação livre, por exemplo o nome do cliente.
    public var note: String = ""

    /// Percentual cobrado pelo canal no momento em que a venda foi registrada.
    public var channelFeePercentage: Decimal = 0

    /// Valor efetivamente descontado. Fica persistido porque regras do canal podem mudar.
    public var channelFeeAmount: Decimal = 0

    /// Itens da venda. Apagar a venda apaga os itens junto.
    /// Opcional porque relações para muitos precisam ser opcionais no CloudKit.
    @Relationship(deleteRule: .cascade, inverse: \SaleItem.sale)
    public var items: [SaleItem]?

    // MARK: - Inicializador

    public init(
        id: UUID = UUID(),
        storeID: UUID = StoreScope.unassignedStoreID,
        date: Date = Date(),
        paymentMethod: PaymentMethod = .pix,
        note: String = "",
        channelFeePercentage: Decimal = 0,
        channelFeeAmount: Decimal = 0
    ) {
        self.id = id
        self.storeID = storeID
        self.date = date
        self.paymentMethodRawValue = paymentMethod.rawValue
        self.note = note
        self.channelFeePercentage = channelFeePercentage
        self.channelFeeAmount = channelFeeAmount
    }

    // MARK: - Forma de pagamento

    /// Acesso com tipo à forma de pagamento. Texto desconhecido cai no Pix,
    /// que é o padrão, em vez de quebrar a tela.
    ///
    /// Precisa de `@Transient`: por ter `set`, o SwiftData tentaria persistir essa
    /// propriedade como uma coluna adicional e impediria a inserção da venda.
    @Transient
    public var paymentMethod: PaymentMethod {
        get { PaymentMethod(rawValue: paymentMethodRawValue) ?? .pix }
        set { paymentMethodRawValue = newValue.rawValue }
    }

    // MARK: - Derivados (não persistidos)

    /// Itens numa lista comum, já que a propriedade persistida é opcional.
    ///
    /// Ordenado por nome porque relações para muitos do SwiftData não preservam ordem,
    /// então sem isso a mesma venda apareceria com os itens embaralhados a cada abertura.
    /// O custo da ordenação é reduzido porque cada venda possui poucos itens.
    public var itemList: [SaleItem] {
        (items ?? []).sorted {
            $0.productName.localizedStandardCompare($1.productName) == .orderedAscending
        }
    }

    /// Quantas unidades saíram no total, somando todos os itens.
    public var totalQuantity: Int {
        itemList.reduce(0) { $0 + $1.quantity }
    }

    /// Valor total cobrado do cliente.
    public var total: Decimal {
        itemList.reduce(0) { $0 + $1.subtotal }
    }

    /// Quanto custou o que foi vendido.
    public var totalCost: Decimal {
        itemList.reduce(0) { $0 + $1.subtotalCost }
    }

    /// Lucro antes de descontar a taxa do canal.
    public var grossProfit: Decimal {
        total - totalCost
    }

    /// Lucro que realmente sobra depois do custo e da taxa do canal.
    public var netProfit: Decimal {
        grossProfit - channelFeeAmount
    }

    /// Atalho mantido para relatórios e agrupamentos, agora com semântica de lucro líquido.
    public var profit: Decimal {
        netProfit
    }
}
