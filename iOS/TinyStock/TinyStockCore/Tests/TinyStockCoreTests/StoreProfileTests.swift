// ⌘
//  TinyStockCoreTests/StoreProfileTests.swift
//
//  Propósito: Testes do cadastro e arquivamento seguro das lojas.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-24.
// ⌘

import Foundation
import SwiftData
import Testing
@testable import TinyStockCore

/// Serializada e com banco compartilhado: ver [TestDatabase] para o porquê.
@Suite(.serialized)
@MainActor
struct StoreProfileTests {

    @Test func criacaoRemoveEspacosDoNome() throws {
        let context = try TestDatabase.makeCleanContext()

        let store = try StoreProfileService.create(name: "  Loja Principal  ", in: context)

        #expect(store.name == "Loja Principal")
        #expect(store.isArchived == false)
    }

    @Test func criacaoAtribuiOrdemSequencial() throws {
        let context = try TestDatabase.makeCleanContext()

        let first = try StoreProfileService.create(name: "Primeira", in: context)
        let second = try StoreProfileService.create(name: "Segunda", in: context)
        let third = try StoreProfileService.create(name: "Terceira", in: context)
        let positions: [Int] = [first.sortOrder, second.sortOrder, third.sortOrder]

        #expect(positions == [0, 1, 2])
    }

    @Test func reordenacaoPersistePosicoesConsecutivas() throws {
        let context = try TestDatabase.makeCleanContext()
        let first = try StoreProfileService.create(name: "Primeira", in: context)
        let second = try StoreProfileService.create(name: "Segunda", in: context)
        let third = try StoreProfileService.create(name: "Terceira", in: context)
        let reorderedAt = Date(timeIntervalSince1970: 1_800_000_000)

        try StoreProfileService.setDisplayOrder(
            [third, first, second],
            date: reorderedAt
        )

        #expect(third.sortOrder == 0)
        #expect(first.sortOrder == 1)
        #expect(second.sortOrder == 2)
        #expect(StoreProfileService.orderedForDisplay([first, second, third]).map(\.id) == [
            third.id, first.id, second.id
        ])
        #expect([first, second, third].allSatisfy { $0.updatedAt == reorderedAt })
    }

    @Test func nomeVazioEhRecusado() throws {
        let context = try TestDatabase.makeCleanContext()

        #expect(throws: StoreProfileError.emptyName) {
            try StoreProfileService.create(name: "   \n", in: context)
        }
    }

    @Test func nomeDuplicadoIgnoraMaiusculasEAcentos() throws {
        let context = try TestDatabase.makeCleanContext()
        try StoreProfileService.create(name: "Loja Secundária", in: context)

        #expect(throws: StoreProfileError.duplicateName) {
            try StoreProfileService.create(name: "LOJA SECUNDARIA", in: context)
        }
    }

    @Test func lojaPadraoEhCriadaUmaUnicaVez() throws {
        let context = try TestDatabase.makeCleanContext()

        let first = try StoreProfileService.ensureDefaultStore(
            name: "Minha loja",
            in: context
        )
        let second = try StoreProfileService.ensureDefaultStore(
            name: "Outra loja",
            in: context
        )
        let stores = try context.fetch(FetchDescriptor<StoreProfile>())

        #expect(stores.count == 1)
        #expect(first.id == second.id)
        #expect(first.id == StoreScope.primaryStoreID)
        #expect(second.name == "Minha loja")
    }

    @Test func preparacaoDoCloudKitRemapeiaLojaInicialETodoOEscopo() throws {
        let context = try TestDatabase.makeCleanContext()
        let oldID = UUID()
        let product = Product(storeID: oldID, name: "Caneca")
        let variant = ProductVariant(storeID: oldID, productID: product.id, name: "Branca")
        let movement = StockMovement(storeID: oldID, productID: product.id, variantID: variant.id)
        let order = SalesOrder(storeID: oldID)
        let orderItem = SalesOrderItem(
            storeID: oldID, productID: product.id, variantID: variant.id,
            productName: product.name, variantName: variant.name
        )
        let legacySale = Sale(storeID: oldID)
        let store = StoreProfile(id: oldID, name: "Loja antiga")
        context.insert(store)
        context.insert(product)
        context.insert(variant)
        context.insert(movement)
        context.insert(order)
        context.insert(orderItem)
        context.insert(legacySale)
        orderItem.order = order

        let selected = try StoreProfileService.prepareForCloudSync(
            preferredStoreID: oldID,
            in: context
        )

        #expect(selected.id == StoreScope.primaryStoreID)
        #expect(store.id == StoreScope.primaryStoreID)
        #expect(product.storeID == StoreScope.primaryStoreID)
        #expect(variant.storeID == StoreScope.primaryStoreID)
        #expect(movement.storeID == StoreScope.primaryStoreID)
        #expect(order.storeID == StoreScope.primaryStoreID)
        #expect(orderItem.storeID == StoreScope.primaryStoreID)
        #expect(legacySale.storeID == StoreScope.primaryStoreID)
    }

    @Test func reconciliacaoDoCloudKitConsolidaCopiasDaLojaInicial() throws {
        let context = try TestDatabase.makeCleanContext()
        let older = StoreProfile(
            id: StoreScope.primaryStoreID,
            name: "Minha loja",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let newer = StoreProfile(
            id: StoreScope.primaryStoreID,
            name: "Loja Principal",
            createdAt: Date(timeIntervalSince1970: 200),
            updatedAt: Date(timeIntervalSince1970: 300)
        )
        context.insert(older)
        context.insert(newer)

        let selected = try StoreProfileService.reconcileCloudStores(in: context)
        try context.save()

        let stores = try context.fetch(FetchDescriptor<StoreProfile>())
        #expect(stores.count == 1)
        #expect(selected.id == StoreScope.primaryStoreID)
        #expect(selected.name == "Loja Principal")
        #expect(selected.createdAt == Date(timeIntervalSince1970: 100))
    }

    @Test func reconciliacaoDoCloudKitPreservaCicloDeVidaMaisRecente() throws {
        let context = try TestDatabase.makeCleanContext()
        let trashedAt = Date(timeIntervalSince1970: 300)
        let canonical = StoreProfile(
            id: StoreScope.primaryStoreID, name: "Antiga",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let remote = StoreProfile(
            id: StoreScope.primaryStoreID, name: "Remota", isArchived: true,
            archivedAt: Date(timeIntervalSince1970: 200), trashedAt: trashedAt,
            wasArchivedBeforeTrash: true,
            createdAt: Date(timeIntervalSince1970: 200), updatedAt: trashedAt
        )
        let active = StoreProfile(name: "Ativa")
        context.insert(canonical)
        context.insert(remote)
        context.insert(active)

        let selected = try StoreProfileService.reconcileCloudStores(
            preferredStoreID: active.id, in: context
        )
        try context.save()

        let stores = try context.fetch(FetchDescriptor<StoreProfile>())
        let primary = try #require(stores.first { $0.id == StoreScope.primaryStoreID })
        #expect(stores.count == 2)
        #expect(selected.id == active.id)
        #expect(primary.name == "Remota")
        #expect(primary.lifecycleState == .trashed)
        #expect(primary.trashedAt == trashedAt)
        #expect(primary.wasArchivedBeforeTrash)
    }

    @Test func edicaoPreservaDataDeCriacao() throws {
        let context = try TestDatabase.makeCleanContext()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let store = StoreProfile(name: "Loja 1", createdAt: createdAt, updatedAt: createdAt)
        context.insert(store)

        try StoreProfileService.update(
            store,
            name: "  Loja principal ",
            imageData: nil,
            date: updatedAt,
            in: context
        )

        #expect(store.name == "Loja principal")
        #expect(store.createdAt == createdAt)
        #expect(store.updatedAt == updatedAt)
    }

    @Test func lojaPadraoReativaLojaArquivadaEmBancoInconsistente() throws {
        let context = try TestDatabase.makeCleanContext()
        let archived = StoreProfile(name: "Loja Principal", isArchived: true)
        context.insert(archived)

        let recovered = try StoreProfileService.ensureDefaultStore(in: context)
        let stores = try context.fetch(FetchDescriptor<StoreProfile>())

        #expect(stores.count == 1)
        #expect(recovered.id == archived.id)
        #expect(recovered.isArchived == false)
    }

    @Test func ultimaLojaAtivaNaoPodeSerArquivada() throws {
        let context = try TestDatabase.makeCleanContext()
        let store = try StoreProfileService.create(name: "Minha loja", in: context)

        #expect(throws: StoreProfileError.lastActiveStore) {
            try StoreProfileService.archive(store, in: context)
        }
        #expect(store.isArchived == false)
    }

    @Test func lojaPodeSerArquivadaQuandoExisteOutraAtiva() throws {
        let context = try TestDatabase.makeCleanContext()
        let first = try StoreProfileService.create(name: "Loja Principal", in: context)
        try StoreProfileService.create(name: "Loja Secundária", in: context)
        let archivedAt = Date(timeIntervalSince1970: 1_800_000_000)

        try StoreProfileService.archive(first, date: archivedAt, in: context)

        #expect(first.isArchived == true)
        #expect(first.archivedAt == archivedAt)
        #expect(first.lifecycleState == .archived)
        #expect(first.updatedAt == archivedAt)
    }

    @Test func lojaArquivadaPodeSerRestaurada() throws {
        let restoredAt = Date(timeIntervalSince1970: 1_800_000_000)
        let store = StoreProfile(name: "Loja Principal", isArchived: true)

        StoreProfileService.restore(store, date: restoredAt)

        #expect(store.isArchived == false)
        #expect(store.archivedAt == nil)
        #expect(store.lifecycleState == .active)
        #expect(store.updatedAt == restoredAt)
    }

    @Test func lixeiraRestauraOEstadoAnteriorSemAlterarDados() throws {
        let context = try TestDatabase.makeCleanContext()
        let active = try StoreProfileService.create(name: "Ativa", in: context)
        let target = try StoreProfileService.create(name: "Temporaria", in: context)
        let archivedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let trashedAt = archivedAt.addingTimeInterval(100)
        let restoredAt = trashedAt.addingTimeInterval(100)
        try StoreProfileService.archive(target, date: archivedAt, in: context)

        try StoreProfileService.moveToTrash(target, date: trashedAt, in: context)
        #expect(target.lifecycleState == .trashed)
        #expect(target.wasArchivedBeforeTrash)
        #expect(target.archivedAt == archivedAt)

        try StoreProfileService.restoreFromTrash(target, date: restoredAt)
        #expect(target.lifecycleState == .archived)
        #expect(target.archivedAt == archivedAt)
        #expect(target.trashedAt == nil)
        #expect(!target.wasArchivedBeforeTrash)
        #expect(active.lifecycleState == .active)
    }

    @Test func lojaAtivaVoltaAtivaDepoisDaLixeira() throws {
        let context = try TestDatabase.makeCleanContext()
        let target = try StoreProfileService.create(name: "Temporaria", in: context)
        try StoreProfileService.create(name: "Mantida", in: context)

        try StoreProfileService.moveToTrash(target, in: context)
        try StoreProfileService.restoreFromTrash(target)

        #expect(target.lifecycleState == .active)
        #expect(target.archivedAt == nil)
        #expect(target.trashedAt == nil)
    }

    @Test func arquivadasELixeiraUsamOrdemMaisRecentePrimeiro() throws {
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        let firstArchived = StoreProfile(name: "A", isArchived: true, archivedAt: older)
        let secondArchived = StoreProfile(name: "B", isArchived: true, archivedAt: newer)
        let firstTrashed = StoreProfile(name: "C", isArchived: true, trashedAt: older)
        let secondTrashed = StoreProfile(name: "D", isArchived: true, trashedAt: newer)

        #expect(StoreProfileService.orderedArchivedForDisplay([
            firstArchived, secondArchived, firstTrashed, secondTrashed
        ]).map(\.id) == [secondArchived.id, firstArchived.id])
        #expect(StoreProfileService.orderedTrashedForDisplay([
            firstArchived, secondArchived, firstTrashed, secondTrashed
        ]).map(\.id) == [secondTrashed.id, firstTrashed.id])
    }

    @Test func exclusaoPermanenteRemoveEscopoCompletoEPreservaOutraLoja() throws {
        let context = try TestDatabase.makeCleanContext()
        let target = try StoreProfileService.create(name: "Loja temporaria", in: context)
        let remaining = try StoreProfileService.create(name: "Loja mantida", in: context)
        let keptProduct = Product(storeID: remaining.id, name: "Produto mantido")
        let product = Product(storeID: target.id, name: "Produto")
        let variant = ProductVariant(
            storeID: target.id,
            productID: product.id,
            name: "Padrao",
            quantity: 2
        )
        let movement = StockMovement(
            storeID: target.id,
            productID: product.id,
            variantID: variant.id,
            kind: .initialStock,
            quantityDelta: 2,
            balanceAfter: 2
        )
        let order = SalesOrder(storeID: target.id)
        let orderItem = SalesOrderItem(
            storeID: target.id,
            productID: product.id,
            variantID: variant.id,
            productName: product.name,
            variantName: variant.name,
            quantity: 1
        )
        let legacySale = Sale(storeID: target.id)
        let legacyItem = SaleItem(productID: product.id, productName: product.name, quantity: 1)

        context.insert(keptProduct)
        context.insert(product)
        context.insert(variant)
        context.insert(movement)
        context.insert(order)
        context.insert(orderItem)
        context.insert(legacySale)
        context.insert(legacyItem)
        orderItem.order = order
        legacyItem.sale = legacySale
        try context.save()

        try StoreProfileService.moveToTrash(target, in: context)

        let summary = try StoreProfileService.deletionSummary(for: target, in: context)
        #expect(summary == StoreDeletionSummary(
            productCount: 1,
            variantCount: 1,
            stockMovementCount: 1,
            orderCount: 2
        ))

        let targetID = target.id
        let replacement = try StoreProfileService.deletePermanently(target, in: context)
        try context.save()

        #expect(replacement?.id == remaining.id)
        #expect(try context.fetchCount(FetchDescriptor<StoreProfile>()) == 1)
        #expect(try context.fetchCount(
            FetchDescriptor<Product>(predicate: #Predicate { $0.storeID == targetID })
        ) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Product>()) == 1)
        #expect(try context.fetchCount(
            FetchDescriptor<ProductVariant>(predicate: #Predicate { $0.storeID == targetID })
        ) == 0)
        #expect(try context.fetchCount(
            FetchDescriptor<StockMovement>(predicate: #Predicate { $0.storeID == targetID })
        ) == 0)
        #expect(try context.fetchCount(
            FetchDescriptor<SalesOrder>(predicate: #Predicate { $0.storeID == targetID })
        ) == 0)
        #expect(try context.fetchCount(
            FetchDescriptor<SalesOrderItem>(predicate: #Predicate { $0.storeID == targetID })
        ) == 0)
        #expect(try context.fetchCount(
            FetchDescriptor<Sale>(predicate: #Predicate { $0.storeID == targetID })
        ) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SaleItem>()) == 0)
    }

    @Test func ultimaLojaAtivaNaoPodeIrParaLixeira() throws {
        let context = try TestDatabase.makeCleanContext()
        let store = try StoreProfileService.create(name: "Loja principal", in: context)

        #expect(throws: StoreProfileError.lastActiveStore) {
            try StoreProfileService.moveToTrash(store, in: context)
        }
        #expect(throws: StoreProfileError.storeNotInTrash) {
            try StoreProfileService.deletePermanently(store, in: context)
        }
        #expect(try context.fetchCount(FetchDescriptor<StoreProfile>()) == 1)
    }

    @Test func lojaArquivadaPodeSerExcluidaComApenasUmaLojaAtiva() throws {
        let context = try TestDatabase.makeCleanContext()
        let active = StoreProfile(name: "Ativa")
        let archived = StoreProfile(name: "Arquivada", isArchived: true)
        context.insert(active)
        context.insert(archived)

        try StoreProfileService.moveToTrash(archived, in: context)
        _ = try StoreProfileService.deletePermanently(archived, in: context)
        try context.save()

        let stores = try context.fetch(FetchDescriptor<StoreProfile>())
        #expect(stores.map(\.id) == [active.id])
    }

    @Test func exclusaoDaLojaInicialTransfereIdentidadeParaSubstituta() throws {
        let context = try TestDatabase.makeCleanContext()
        let initial = StoreProfile(id: StoreScope.primaryStoreID, name: "Inicial", sortOrder: 0)
        let replacement = StoreProfile(name: "Substituta", sortOrder: 1)
        let product = Product(storeID: replacement.id, name: "Produto mantido")
        context.insert(initial)
        context.insert(replacement)
        context.insert(product)

        try StoreProfileService.moveToTrash(initial, in: context)
        let selected = try StoreProfileService.deletePermanently(initial, in: context)
        try context.save()

        #expect(selected?.id == StoreScope.primaryStoreID)
        #expect(replacement.id == StoreScope.primaryStoreID)
        #expect(replacement.sortOrder == 0)
        #expect(product.storeID == StoreScope.primaryStoreID)
    }

    @Test func lixeiraExpiraSomenteDepoisDeTrintaDiasCompletos() throws {
        let context = try TestDatabase.makeCleanContext()
        let trashedAt = Date(timeIntervalSince1970: 1_800_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let target = try StoreProfileService.create(name: "Temporaria", in: context)
        try StoreProfileService.create(name: "Mantida", in: context)
        try StoreProfileService.moveToTrash(target, date: trashedAt, in: context)
        let expiration = try #require(
            StoreProfileService.trashExpirationDate(for: target, calendar: calendar)
        )

        let beforeExpiration = expiration.addingTimeInterval(-1)
        #expect(try StoreProfileService.purgeExpiredTrash(
            asOf: beforeExpiration, calendar: calendar, in: context
        ) == 0)
        #expect(try context.fetchCount(FetchDescriptor<StoreProfile>()) == 2)

        #expect(try StoreProfileService.purgeExpiredTrash(
            asOf: expiration, calendar: calendar, in: context
        ) == 1)
        #expect(try context.fetchCount(FetchDescriptor<StoreProfile>()) == 1)
    }

    @Test func lojaNaLixeiraNaoPodeSerEditadaOuSelecionada() throws {
        let context = try TestDatabase.makeCleanContext()
        let target = try StoreProfileService.create(name: "Temporaria", in: context)
        let active = try StoreProfileService.create(name: "Ativa", in: context)
        try StoreProfileService.moveToTrash(target, in: context)

        #expect(throws: StoreProfileError.trashedStore) {
            try StoreProfileService.update(target, name: "Outro nome", imageData: nil, in: context)
        }
        let session = StoreSession(selectedStoreID: active.id, defaults: makeDefaults())
        #expect(throws: StoreProfileError.archivedStore) {
            try session.select(target)
        }
    }

    @Test func todoErroTemMensagemLocalizada() {
        let errors: [StoreProfileError] = [
            .emptyName,
            .duplicateName,
            .lastActiveStore,
            .archivedStore,
            .trashedStore,
            .storeNotInTrash
        ]

        #expect(errors.allSatisfy { !$0.localizedMessage.isEmpty })
    }

    // MARK: - Seleção atual

    @Test func sessaoCriaLojaPadraoEPersisteASelecao() throws {
        let context = try TestDatabase.makeCleanContext()
        let defaults = makeDefaults()

        let session = try StoreSession.bootstrap(in: context, defaults: defaults)
        let stores = try context.fetch(FetchDescriptor<StoreProfile>())

        #expect(stores.count == 1)
        #expect(stores.first?.id == session.selectedStoreID)
        #expect(defaults.string(forKey: StoreSession.selectedStoreKey) == session.selectedStoreID.uuidString)
    }

    @Test func sessaoRemoveLixeiraVencidaAoIniciar() throws {
        let context = try TestDatabase.makeCleanContext()
        let defaults = makeDefaults()
        let active = try StoreProfileService.create(name: "Ativa", in: context)
        let target = try StoreProfileService.create(name: "Temporaria", in: context)
        let expiredDate = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        try StoreProfileService.moveToTrash(target, date: expiredDate, in: context)

        let session = try StoreSession.bootstrap(in: context, defaults: defaults)

        #expect(session.selectedStoreID == active.id)
        #expect(try context.fetchCount(FetchDescriptor<StoreProfile>()) == 1)
    }

    @Test func selecaoInvalidaVoltaParaLojaAtiva() throws {
        let context = try TestDatabase.makeCleanContext()
        let defaults = makeDefaults()
        defaults.set(UUID().uuidString, forKey: StoreSession.selectedStoreKey)
        let store = try StoreProfileService.create(name: "Loja Principal", in: context)

        let session = try StoreSession.bootstrap(in: context, defaults: defaults)

        #expect(session.selectedStoreID == store.id)
    }

    @Test func sessaoRecusaSelecionarLojaArquivada() throws {
        let context = try TestDatabase.makeCleanContext()
        let defaults = makeDefaults()
        let active = try StoreProfileService.create(name: "Loja Principal", in: context)
        let archived = StoreProfile(name: "Loja antiga", isArchived: true)
        context.insert(archived)
        let session = StoreSession(selectedStoreID: active.id, defaults: defaults)

        #expect(throws: StoreProfileError.archivedStore) {
            try session.select(archived)
        }
        #expect(session.selectedStoreID == active.id)
    }

    @Test func sessaoTrocaSelecaoArquivadaAposImportacaoRemota() throws {
        let context = try TestDatabase.makeCleanContext()
        let defaults = makeDefaults()
        let archived = StoreProfile(name: "Arquivada", isArchived: true)
        let active = StoreProfile(name: "Ativa")
        context.insert(archived)
        context.insert(active)
        let session = StoreSession(selectedStoreID: archived.id, defaults: defaults)

        try session.reconcileCloudChanges(in: context)

        #expect(session.selectedStoreID == active.id)
        #expect(defaults.string(forKey: StoreSession.selectedStoreKey) == active.id.uuidString)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "TinyStockCoreTests.StoreSession"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
