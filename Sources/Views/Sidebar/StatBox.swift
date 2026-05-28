import SwiftUI

struct StatBox: View {
    let title: String
    let count: String
    let size: String
    let icon: String
    let iconColor: Color
    let iconBg: Color
    var isFreed = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconBg)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.subheadline)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(count)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            if isFreed && count != "0" {
                Text(size)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.colorTrash)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.colorTrashGlow)
                    .cornerRadius(4)
            } else {
                Text(size)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}
