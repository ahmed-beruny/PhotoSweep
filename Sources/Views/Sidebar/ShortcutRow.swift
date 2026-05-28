import SwiftUI

struct ShortcutRow: View {
    let keys: [String]
    let desc: String
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            Text(desc)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
    }
}
