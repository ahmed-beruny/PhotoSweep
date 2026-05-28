import SwiftUI

// --- UI Toast HUD Overlay ---
struct ToastOverlay: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        VStack {
            if let msg = state.toastMessage {
                HStack(spacing: 10) {
                    Image(systemName: state.toastIcon)
                        .foregroundColor(.accentPrimary)
                        .font(.body)
                    
                    Text(msg)
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.bgElevated)
                .cornerRadius(30)
                .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.08), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
                .padding(.top, 64) // Placed at top center just under the folder path bar
                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                       removal: .opacity))
            }
            
            Spacer()
        }
        .animation(.spring(), value: state.toastMessage)
    }
}
