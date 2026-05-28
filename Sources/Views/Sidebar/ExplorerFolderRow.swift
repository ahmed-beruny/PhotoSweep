import SwiftUI

struct ExplorerFolderRow: View {
    let url: URL
    let isActive: Bool // Currently loaded photos folder
    let isSelected: Bool // Last visited subfolder when going Up
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isActive ? "folder.badge.gearshape.fill" : "folder.fill")
                    .foregroundColor(isActive ? .accentPrimary : (isSelected ? .accentPrimary.opacity(0.8) : .white.opacity(0.6)))
                    .font(.caption)
                
                Text(url.lastPathComponent)
                    .font(.system(size: 12, design: .rounded))
                    .fontWeight(isActive || isSelected ? .bold : .regular)
                    .foregroundColor(.white.opacity(isActive || isSelected || isHovered ? 1.0 : 0.7))
                    .lineLimit(1)
                
                Spacer()
                
                if isActive {
                    Text("ACTIVE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentPrimary)
                        .cornerRadius(4)
                } else if isSelected {
                    Image(systemName: "arrow.uturn.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.accentPrimary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.2))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                isActive ? Color.accentPrimary.opacity(0.12) :
                (isSelected ? Color.white.opacity(0.06) : (isHovered ? Color.white.opacity(0.04) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? Color.accentPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(6)
            .contentShape(Rectangle()) // Make entire row hit-testable
        }
        .buttonStyle(.plain)
        .onHover { hover in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hover
            }
        }
    }
}
