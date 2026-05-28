import SwiftUI
import AppKit

// --- Application Entry Point ---
@main
struct PhotoSweepApp: App {
    @StateObject private var state = AppState()
    
    init() {
        // Set activation policy to regular so that it runs as a standard foreground application
        // with a Dock icon, menu bar, and full keyboard event focus.
        NSApplication.shared.setActivationPolicy(.regular)
        
        // Force the app to become active and bring its window to the front
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
        }
        .windowStyle(.hiddenTitleBar) // Custom unified titlebar layout
    }
}
