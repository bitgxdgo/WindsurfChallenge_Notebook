//
//  WindsurfChallengeApp.swift
//  WindsurfChallenge
//
//  Created by Zhuanz1密码0000 on 2024/12/12.
//

import SwiftUI
import CoreData

@main
struct WindsurfChallengeApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
