import SwiftUI

// --- Custom Header Component ---
struct HeaderBar: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        HStack(spacing: 12) {
            // Spacer to avoid macOS hidden window traffic lights
            Spacer()
                .frame(width: 80)
            
            HStack(spacing: 6) {
                Text("✦")
                    .font(.title3)
                    .foregroundColor(.accentPrimary)
                Text("PhotoSweep")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            if !state.folderPath.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundColor(.accentPrimary)
                        .font(.subheadline)
                    
                    Text(state.folderPath)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 320)
                    
                    Button(action: { state.reset() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                            Text("Change Folder")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    .help("Select a different photo folder")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.08), lineWidth: 1))
                .cornerRadius(30)
            }
            
            Spacer()
        }
        .frame(height: 52)
        .padding(.horizontal, 16)
        .background(Color.bgBase.opacity(0.9))
    }
}
