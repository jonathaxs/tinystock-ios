// ⌘
//  TinyStockCore/Bundle+TinyStockCore.swift
//
//  Propósito: Expõe o resource bundle do TinyStockCore aos app targets (iPhone, Watch),
//             para que `String(localized: "x", bundle: .tinyStockCore)` funcione fora do package.
//
//  Created by Jonathas Motta (@jonathaxs) on 2026-08-07.
// ⌘

import Foundation

public extension Bundle {
    /// Resource bundle do package TinyStockCore.
    /// Usar em call sites de `String(localized:bundle:)` fora do código do package,
    /// para localizar os recursos de `Localizable.strings`.
    ///
    /// No watchOS, retorna o sub-bundle `.lproj` do idioma escolhido no iPhone
    /// (sincronizado via WatchConnectivity em `app.preferredLanguage`), porque o
    /// watchOS não oferece idioma por app nem permite trocar o locale do processo em runtime.
    static var tinyStockCore: Bundle {
        #if os(watchOS)
        if let lang = UserDefaults.standard.string(forKey: "app.preferredLanguage"),
           let path = Bundle.module.path(forResource: lang, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            return langBundle
        }
        #endif
        return .module
    }
}
