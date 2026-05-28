import SwiftUI

// --- Bottom Filmstrip queue timeline strip ---
struct FilmstripTimeline: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FILMSTRIP QUEUE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .kerning(1.0)
                .padding(.horizontal, 24)
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(state.images.enumerated()), id: \.element.id) { index, item in
                            let isActive = index == state.currentIndex
                            
                            VStack(spacing: 0) {
                                ThumbnailView(path: item.path)
                                    .overlay(
                                        Group {
                                            if item.status == .kept {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.colorKeep)
                                                    .font(.system(size: 14))
                                                    .shadow(radius: 2)
                                                    .padding(4)
                                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                            }
                                        }
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isActive ? Color.accentPrimary : Color.clear, lineWidth: 2)
                                    )
                                    .shadow(color: isActive ? Color.accentPrimary.opacity(0.3) : Color.clear, radius: 4)
                                    .opacity(
                                        item.status == .trashed ? 0.05 :
                                        (item.status == .kept ? 0.55 : (isActive ? 1.0 : 0.55))
                                    )
                            }
                            .id(index)
                            .scaleEffect(isActive ? 1.05 : 1.0)
                            .onTapGesture {
                                state.selectIndex(index)
                            }
                            .disabled(item.status == .trashed)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
                .frame(height: 64)
                .onChange(of: state.currentIndex) { _, newIndex in
                    if newIndex != -1 {
                        withAnimation {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .background(Color.bgBase.opacity(0.8))
    }
}
