import SwiftUI

struct ProgressCard: View {
    let processedCount: Int
    let totalCount: Int
    let progressRatio: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SWEEPING PROGRESS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .kerning(1.0)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(processedCount)")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                Text("/")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.3))
                Text("\(totalCount)")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                Text("\(Int(progressRatio * 100))%")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.accentPrimary)
            }
            
            // Simple progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(LinearGradient(colors: [.accentPrimary, Color(red: 0.6, green: 0.6, blue: 0.95)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(progressRatio))
                }
            }
            .frame(height: 6)
        }
        .padding(18)
        .background(Color.bgSurface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}
