// ⌘
//  TinyStock/Navigation/AppRouter.swift
//
//  Propósito: Roteador único do app. Guarda o caminho do NavigationStack raiz, a sheet aberta por cima
//             da Início (Relatórios ou Calendário) e os pedidos de filtro e de pedido do Calendário, para
//             qualquer tela ou notificação abrir um destino sem conhecer a hierarquia.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-11-07.
// ⌘

import SwiftUI
import TinyStockCore

// MARK: - Rotas

/// Páginas empilhadas no stack raiz.
enum AppRoute: Hashable {
    case settings
}

/// Telas que abrem em sheet por cima da Início.
enum AppSheet: String, Identifiable {
    case reports
    case calendar

    var id: String { rawValue }
}

// MARK: - Roteador

/// Estado de navegação do app (MV: é um store, não um ViewModel). Injetado via `.environment`.
@Observable
final class AppRouter {

    var path: [AppRoute] = []

    /// Sheet aberta por cima da Início (nil = nenhuma).
    var sheet: AppSheet?

    /// Filtro que o Calendário aplica ao abrir. A tela consome e limpa o pedido.
    var calendarFilterRequest: CalendarOrderFilter?

    /// Pedido aberto a partir de uma notificação, mostrado dentro do Calendário.
    var reminderRoute: OrderReminderRoute?

    /// Ajustes sempre como página: fecha a sheet antes.
    func open(_ route: AppRoute) {
        sheet = nil
        guard path.last != route else { return }
        path.append(route)
    }

    func present(_ newSheet: AppSheet) {
        sheet = newSheet
    }

    /// Abre o Calendário já filtrado. Vindo dos Relatórios, troca uma sheet pela outra.
    func openCalendar(filter: CalendarOrderFilter) {
        calendarFilterRequest = filter
        sheet = .calendar
    }

    /// Volta para a Início e abre o pedido da notificação no Calendário.
    func openOrder(_ route: OrderReminderRoute) {
        path = []
        calendarFilterRequest = .all
        reminderRoute = route
        sheet = .calendar
    }
}
