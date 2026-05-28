import SwiftUI

struct QuickLocationButton: View {
    let location: AppState.QuickLocation
    let activePath: String
    let action: () -> Void
    
    private var isActive: Bool {
        activePath == location.url.path
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: location.systemIcon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isActive ? .white : .white.opacity(0.6))
                .frame(width: 32, height: 32)
                .background(isActive ? Color.accentPrimary : Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(location.name)
    }
}
