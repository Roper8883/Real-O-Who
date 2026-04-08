//
//  Real_O_WhoApp.swift
//  Real O Who
//
//  Created by Aaron Roper on 31/3/2026.
//

import SwiftUI

@main
struct Real_O_WhoApp: App {
    @StateObject private var store = MarketplaceStore()
    @StateObject private var messaging = EncryptedMessagingService()

    var body: some Scene {
        WindowGroup {
            Group {
                if store.isAuthenticated {
                    ContentView()
                } else {
                    AuthenticationView()
                }
            }
                .environmentObject(store)
                .environmentObject(messaging)
        }
    }
}
