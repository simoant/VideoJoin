//
//  VideoJoinApp.swift
//  VideoJoin
//
//  Created by Anton Simonov on 23/3/24.
//

import SwiftUI
import SwiftData
import RevenueCat

@main
struct VideoJoinApp: App {
    init() {
            Purchases.logLevel = .debug
            Purchases.configure(withAPIKey: "appl_fWDAjoNENnPjyAkdPWVLVOKStsW", appUserID: nil)
        }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
