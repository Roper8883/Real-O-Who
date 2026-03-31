//
//  Real_A_WhoApp.swift
//  Real A Who
//
//  Created by Aaron Roper on 31/3/2026.
//

import SwiftUI

@main
struct Real_A_WhoApp: App {
    @StateObject private var store = JournalStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
