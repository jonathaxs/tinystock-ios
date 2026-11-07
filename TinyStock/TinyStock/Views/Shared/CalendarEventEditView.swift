// Proposito: Apresentar o editor nativo para o usuario revisar e salvar um evento.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-09.

import EventKit
import EventKitUI
import SwiftUI
import TinyStockCore

struct CalendarEventEditView: UIViewControllerRepresentable {
    let draft: OrderCalendarEventDraft
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.calendar = eventStore.defaultCalendarForNewEvents
        event.title = draft.title
        event.notes = draft.notes
        event.startDate = draft.startDate
        event.endDate = draft.endDate
        event.isAllDay = true
        event.availability = .free

        let controller = EKEventEditViewController()
        controller.eventStore = eventStore
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, EKEventEditViewDelegate {
        private let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func eventEditViewController(
            _ controller: EKEventEditViewController,
            didCompleteWith action: EKEventEditViewAction
        ) {
            onDismiss()
        }
    }
}
