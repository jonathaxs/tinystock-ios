// Proposito: Selecionar um intervalo de dias completo para os relatorios.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-06.

import SwiftUI
import TinyStockCore

struct ReportCustomPeriodView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var end: Date
    let onApply: (Date, Date) -> Void

    init(initialStart: Date, initialEnd: Date, onApply: @escaping (Date, Date) -> Void) {
        _start = State(initialValue: initialStart)
        _end = State(initialValue: initialEnd)
        self.onApply = onApply
    }

    private var isValid: Bool {
        calendar.startOfDay(for: start) <= calendar.startOfDay(for: end)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        String(localized: "reports.custom.start", bundle: .tinyStockCore),
                        selection: $start,
                        displayedComponents: .date
                    )
                    DatePicker(
                        String(localized: "reports.custom.end", bundle: .tinyStockCore),
                        selection: $end,
                        displayedComponents: .date
                    )
                } footer: {
                    if !isValid {
                        Text(String(localized: "reports.custom.invalid", bundle: .tinyStockCore))
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(String(localized: "reports.custom.title", bundle: .tinyStockCore))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", bundle: .tinyStockCore)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.apply", bundle: .tinyStockCore)) {
                        onApply(start, end)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
