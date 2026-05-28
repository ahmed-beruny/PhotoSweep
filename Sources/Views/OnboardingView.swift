import SwiftUI

// --- Onboarding Dashboard view ---
struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var isPulse = false
    
    var body: some View {
        ZStack {
            // Deep radial background glow
            RadialGradient(colors: [Color.accentPrimary.opacity(0.06), Color.clear],
                           center: .center, startRadius: 10, endRadius: 400)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("DESKTOP UTILITY")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .kerning(1.5)
                        .foregroundColor(.accentPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentPrimary.opacity(0.12))
                        .cornerRadius(20)
                    
                    Text("Sweep through your photos.")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                    Text("Clear disk space instantly.")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.accentPrimary)
                }
                .multilineTextAlignment(.center)
                
                Text("Select a folder on your Mac. Rapidly review each photo. Keep what is beautiful. Trash what is blurry. Direct integration with macOS system Trash. Supports HEIC, JPG, PNG, WEBP, and GIF.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                    .lineLimit(nil)
                
                Button(action: { state.selectFolder() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.badge.plus")
                            .font(.title2)
                        Text("Select Photo Folder")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .background(LinearGradient(colors: [.accentPrimary, Color(red: 0.3, green: 0.3, blue: 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .cornerRadius(50)
                    .shadow(color: Color.accentPrimary.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                
                // Shortcuts Cheatsheet
                HStack(spacing: 32) {
                    VStack(alignment: .center, spacing: 6) {
                        Text("←  or  A")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                        Text("Trash Photo")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    VStack(alignment: .center, spacing: 6) {
                        Text("→  or  D  or  Space")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                        Text("Keep & Advance")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    VStack(alignment: .center, spacing: 6) {
                        Text("Drag Card")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                        Text("Tinder swipe gestures")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.top, 40)
            }
            .padding(48)
            .background(Color.bgSurface)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.4), radius: 30, x: 0, y: 20)
            .frame(maxWidth: 680)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
