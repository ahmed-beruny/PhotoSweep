import SwiftUI
import AppKit

// --- Right Panel: Interactive Deck & Control Actions ---
struct WorkspacePanel: View {
    @EnvironmentObject var state: AppState
    @State private var dragOffset = CGSize.zero
    @State private var scale: CGFloat = 1.0
    @GestureState private var gestureScale: CGFloat = 1.0
    @State private var panOffset = CGSize.zero
    @State private var lastPanOffset = CGSize.zero
    
    private var activeItem: AppState.ImageFile? {
        guard state.currentIndex >= 0 && state.currentIndex < state.images.count else { return nil }
        return state.images[state.currentIndex]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let item = activeItem, let nsImage = state.activeImage {
                    ZStack {
                        // Drag Indicator HUD overlays
                        HStack {
                            Text("TRASH")
                                .font(.system(.title, design: .rounded))
                                .fontWeight(.black)
                                .foregroundColor(.colorTrash)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .border(Color.colorTrash, width: 4)
                                .cornerRadius(8)
                                .rotationEffect(.degrees(-15))
                                .opacity(Double(max(0, min(1, -dragOffset.width / 120.0))))
                                .padding(.leading, 32)
                            
                            Spacer()
                            
                            Text("KEEP")
                                .font(.system(.title, design: .rounded))
                                .fontWeight(.black)
                                .foregroundColor(.colorKeep)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .border(Color.colorKeep, width: 4)
                                .cornerRadius(8)
                                .rotationEffect(.degrees(15))
                                .opacity(Double(max(0, min(1, dragOffset.width / 120.0))))
                                .padding(.trailing, 32)
                        }
                        .zIndex(20)
                        
                        // Main Draggable Deck
                        VStack(spacing: 0) {
                            ZStack(alignment: .bottom) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .scaleEffect(scale * gestureScale)
                                    .offset(panOffset)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(8)
                                    .onTapGesture(count: 2) {
                                        withAnimation(.spring()) {
                                            if scale > 1.0 {
                                                scale = 1.0
                                                panOffset = .zero
                                                lastPanOffset = .zero
                                            } else {
                                                scale = 2.5
                                            }
                                        }
                                    }
                                
                                // Vibrant green badge overlay if already kept
                                if item.status == .kept {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.white)
                                        Text("KEPT PHOTO")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.colorKeep)
                                    .cornerRadius(20)
                                    .shadow(color: Color.colorKeepGlow, radius: 8)
                                    .padding(16)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                }
                                
                                // Glassmorphic Metadata Overlay
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 8) {
                                            Text(item.name)
                                                .font(.system(.body, design: .rounded))
                                                .fontWeight(.bold)
                                                .lineLimit(1)
                                            
                                            if item.rawURL != nil {
                                                Text("RAW+PAIR")
                                                    .font(.system(size: 8, weight: .black))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.accentPrimary)
                                                    .cornerRadius(4)
                                            }
                                        }
                                        
                                        HStack(spacing: 8) {
                                            Text("\(Int(nsImage.size.width)) x \(Int(nsImage.size.height)) px")
                                            Text("•")
                                            Text(item.dateModified.formatted(date: .abbreviated, time: .shortened))
                                        }
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.6))
                                    }
                                    
                                    Spacer()
                                    
                                    Text(item.size.formattedSize())
                                        .font(.system(.caption, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(.accentPrimary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.accentPrimary.opacity(0.12))
                                        .cornerRadius(20)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(LinearGradient(colors: [Color.black.opacity(0.85), Color.black.opacity(0.4), Color.clear], startPoint: .bottom, endPoint: .top))
                            }
                        }
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(
                                    dragOffset.width > 80 ? Color.colorKeep :
                                    (dragOffset.width < -80 ? Color.colorTrash : Color.white.opacity(0.08)),
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: dragOffset.width > 80 ? Color.colorKeepGlow :
                            (dragOffset.width < -80 ? Color.colorTrashGlow : Color.black.opacity(0.4)),
                            radius: 20
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(
                            HStack(spacing: 6) {
                                Button(action: {
                                    withAnimation(.spring()) {
                                        scale = max(1.0, scale - 0.5)
                                        if scale == 1.0 {
                                            panOffset = .zero
                                            lastPanOffset = .zero
                                        }
                                    }
                                }) {
                                    Image(systemName: "minus.magnifyingglass")
                                        .font(.body)
                                        .foregroundColor(.white.opacity(0.85))
                                        .padding(6)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                                
                                Button(action: {
                                    withAnimation(.spring()) {
                                        scale = 1.0
                                        panOffset = .zero
                                        lastPanOffset = .zero
                                    }
                                }) {
                                    Text(String(format: "%.1fx", scale))
                                        .font(.system(.caption, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.06))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                                
                                Button(action: {
                                    withAnimation(.spring()) {
                                        scale = min(5.0, scale + 0.5)
                                    }
                                }) {
                                    Image(systemName: "plus.magnifyingglass")
                                        .font(.body)
                                        .foregroundColor(.white.opacity(0.85))
                                        .padding(6)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                            }
                            .padding(8)
                            .background(Color.bgSurface.opacity(0.65))
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                            .padding(16)
                            .opacity(scale > 1.0 || dragOffset == .zero ? 1.0 : 0.0), // Fade HUD out during swipe
                            alignment: .topTrailing
                        )
                        .offset(dragOffset)
                        .rotationEffect(.degrees(Double(dragOffset.width) * 0.04))
                        .simultaneousGesture(
                            MagnificationGesture()
                                .updating($gestureScale) { currentState, gestureState, _ in
                                    gestureState = currentState
                                }
                                .onEnded { value in
                                    withAnimation(.spring()) {
                                        scale = min(max(scale * value, 1.0), 5.0)
                                        if scale == 1.0 {
                                            panOffset = .zero
                                            lastPanOffset = .zero
                                        }
                                    }
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1.0 {
                                        panOffset = CGSize(
                                            width: lastPanOffset.width + value.translation.width,
                                            height: lastPanOffset.height + value.translation.height
                                        )
                                    } else {
                                        dragOffset = value.translation
                                    }
                                }
                                .onEnded { value in
                                    if scale > 1.0 {
                                        withAnimation(.spring()) {
                                            // Clamp panning bounds based on resolution and scale factor
                                            let limitX = (nsImage.size.width * scale) * 0.18
                                            let limitY = (nsImage.size.height * scale) * 0.18
                                            panOffset.width = min(max(panOffset.width, -limitX), limitX)
                                            panOffset.height = min(max(panOffset.height, -limitY), limitY)
                                            lastPanOffset = panOffset
                                        }
                                    } else {
                                        let threshold: CGFloat = 140
                                        if value.translation.width > threshold {
                                            // Swipe Keep
                                            withAnimation(.spring()) {
                                                dragOffset = CGSize(width: 900, height: value.translation.height)
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                                state.keepActivePhoto()
                                                dragOffset = .zero
                                            }
                                        } else if value.translation.width < -threshold {
                                            // Swipe Trash
                                            withAnimation(.spring()) {
                                                dragOffset = CGSize(width: -900, height: value.translation.height)
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                                state.trashActivePhoto()
                                                dragOffset = .zero
                                            }
                                        } else {
                                            // Bounce back
                                            withAnimation(.spring()) {
                                                dragOffset = .zero
                                            }
                                        }
                                    }
                                }
                        )
                    }
                } else {
                    // Empty/Complete Screen
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.colorKeep)
                            .shadow(color: Color.colorKeepGlow, radius: 10)
                        
                        Text("Cleanup Finished!")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                        
                        Text("You have swept through all photos. Kept photos remain safe on your Mac, and trashed photos were moved to the native Trash Bin.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 400)
                        
                        Button(action: { state.selectFolder() }) {
                            HStack {
                                Image(systemName: "folder")
                                Text("Select Another Folder")
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.accentPrimary)
                            .cornerRadius(30)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(32)
            
            // Bottom Action Controls
            if activeItem != nil {
                HStack(spacing: 24) {
                    // Trash Button
                    Button(action: {
                        withAnimation { state.trashActivePhoto() }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                            Text("TRASH PHOTO")
                                .fontWeight(.bold)
                            Text("A / ←")
                                .font(.system(size: 10, design: .monospaced))
                                .opacity(0.5)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(LinearGradient(colors: [.colorTrash, Color(red: 0.8, green: 0.15, blue: 0.25)], startPoint: .top, endPoint: .bottom))
                        .cornerRadius(40)
                        .shadow(color: Color.colorTrashGlow, radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("a", modifiers: [])
                    
                    // Invisible helper for Left Arrow
                    Button("") {
                        withAnimation { state.trashActivePhoto() }
                    }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    
                    // Go Back / Undo Button
                    let canUndo = !state.historyStack.isEmpty || (activeItem?.status == .kept)
                    Button(action: {
                        withAnimation { state.undo() }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("UNDO DECISION")
                                .fontWeight(.bold)
                            Text("Cmd + Z / W")
                                .font(.system(size: 10, design: .monospaced))
                                .opacity(0.5)
                        }
                        .foregroundColor(.white.opacity(canUndo ? 1.0 : 0.4))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(canUndo ? Color.white.opacity(0.08) : Color.white.opacity(0.02))
                        .overlay(RoundedRectangle(cornerRadius: 40).stroke(Color.white.opacity(canUndo ? 0.12 : 0.04), lineWidth: 1))
                        .cornerRadius(40)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canUndo)
                    .help(activeItem?.status == .kept ? "Go Back / Revert this Kept Photo" : "Go Back / Revert last Kept Photo")
                    
                    // Invisible helper for Up Arrow (Undo)
                    Button("") {
                        withAnimation { state.undo() }
                    }
                    .keyboardShortcut(.upArrow, modifiers: [])
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    
                    // Reveal Finder Button
                    Button(action: { state.revealActivePhoto() }) {
                        Image(systemName: "safari")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(14)
                            .background(Color.white.opacity(0.06))
                            .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in macOS Finder")
                    
                    // Keep Button
                    Button(action: {
                        withAnimation { state.keepActivePhoto() }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                            Text("KEEP PHOTO")
                                .fontWeight(.bold)
                            Text("D / →")
                                .font(.system(size: 10, design: .monospaced))
                                .opacity(0.5)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(LinearGradient(colors: [.colorKeep, Color(red: 0.04, green: 0.6, blue: 0.32)], startPoint: .top, endPoint: .bottom))
                        .cornerRadius(40)
                        .shadow(color: Color.colorKeepGlow, radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("d", modifiers: [])
                    
                    // Invisible helpers for Right Arrow & Space
                    Button("") {
                        withAnimation { state.keepActivePhoto() }
                    }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    
                    Button("") {
                        withAnimation { state.keepActivePhoto() }
                    }
                    .keyboardShortcut(.space, modifiers: [])
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    
                    // Invisible zoom shortcuts helpers
                    Group {
                        Button("") {
                            withAnimation(.spring()) {
                                scale = min(5.0, scale + 0.5)
                            }
                        }
                        .keyboardShortcut("=", modifiers: [.command])
                        .frame(width: 0, height: 0)
                        .opacity(0)
                        
                        Button("") {
                            withAnimation(.spring()) {
                                scale = max(1.0, scale - 0.5)
                                if scale == 1.0 {
                                    panOffset = .zero
                                    lastPanOffset = .zero
                                }
                            }
                        }
                        .keyboardShortcut("-", modifiers: [.command])
                        .frame(width: 0, height: 0)
                        .opacity(0)
                        
                        Button("") {
                            withAnimation(.spring()) {
                                scale = 1.0
                                panOffset = .zero
                                lastPanOffset = .zero
                            }
                        }
                        .keyboardShortcut("0", modifiers: [.command])
                        .frame(width: 0, height: 0)
                        .opacity(0)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .onChange(of: state.currentIndex) { _, _ in
            withAnimation(.spring()) {
                scale = 1.0
                panOffset = .zero
                lastPanOffset = .zero
            }
        }
    }
}
