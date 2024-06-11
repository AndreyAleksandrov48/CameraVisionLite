//
//  CameraVisionLiteApp.swift
//  CameraVisionLite
//
//  Created by Andrey Aleksandrov on 09/05/2024.
//

import SwiftUI
import SwiftData

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [DetectedObject.self]) 
        }
    }
}
