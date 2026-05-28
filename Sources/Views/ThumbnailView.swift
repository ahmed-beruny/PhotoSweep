import SwiftUI
import AppKit

// --- Asynchronous Thumbnail view for Filmstrip scrolling ---
struct ThumbnailView: View {
    let path: String
    @State private var thumbnail: NSImage? = nil
    
    var body: some View {
        Group {
            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.gray.opacity(0.08)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                    )
            }
        }
        .frame(width: 72, height: 48)
        .clipped()
        .cornerRadius(6)
        .onAppear {
            loadThumb()
        }
    }
    
    private func loadThumb() {
        guard thumbnail == nil else { return }
        
        let fileURL = URL(fileURLWithPath: path)
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 100% Thread-safe image thumbnail generation bypassing AppKit lockFocus() entirely
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 144
            ]
            if let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
               let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                let thumb = NSImage(cgImage: cgImage, size: NSSize(width: 72, height: 48))
                DispatchQueue.main.async {
                    self.thumbnail = thumb
                }
            }
        }
    }
}
