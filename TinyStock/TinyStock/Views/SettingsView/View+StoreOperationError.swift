// Proposito: Padronizar a apresentacao de erros nas telas de gerenciamento de lojas.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-17.

import SwiftUI
import TinyStockCore

extension View {
    func storeOperationErrorAlert(message: Binding<String?>) -> some View {
        alert(
            String(localized: "stores.error.title", bundle: .tinyStockCore),
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            )
        ) {
            Button(String(localized: "common.ok", bundle: .tinyStockCore)) {
                message.wrappedValue = nil
            }
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
