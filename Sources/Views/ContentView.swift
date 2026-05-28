import SwiftUI

// --- Main Layout View ---
struct ContentView: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HeaderBar()
            
            HStack(spacing: 0) {
                // Left Panel: File Navigator & Stats (Always visible!)
                SidebarPanel()
                    .frame(width: 280)
                
                Divider()
                    .background(Color.white.opacity(0.05))
                
                // Right Panel
                if state.images.isEmpty {
                    OnboardingView()
                } else {
                    VStack(spacing: 0) {
                        WorkspacePanel()
                        
                        Divider()
                            .background(Color.white.opacity(0.05))
                        
                        // Bottom Timeline Filmstrip
                        FilmstripTimeline()
                    }
                }
            }
        }
        .frame(minWidth: 1080, minHeight: 720)
        .background(Color.bgBase)
        .preferredColorScheme(.dark)
        .overlay(ToastOverlay())
    }
}
