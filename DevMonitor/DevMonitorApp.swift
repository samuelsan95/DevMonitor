//
//  DevMonitorApp.swift
//  DevMonitor
//
//  Created by Samuel Sánchez López on 12/3/26.
//

import SwiftUI


@main
struct DevMonitorApp: App {
    var body: some Scene {
        MenuBarExtra("DevMonitor", image: "MenuBarIcon") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}

