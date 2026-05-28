import SwiftUI
import AppKit

// --- File Size Formatter Helper ---
extension Int64 {
    func formattedSize() -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}

// --- Colors Design System ---
extension Color {
    static let bgBase = Color(NSColor(calibratedWhite: 0.04, alpha: 1.0))
    static let bgSurface = Color(NSColor(calibratedWhite: 0.08, alpha: 0.75))
    static let bgElevated = Color(NSColor(calibratedWhite: 0.12, alpha: 0.85))
    static let accentPrimary = Color(red: 0.38, green: 0.40, blue: 0.95)
    static let colorKeep = Color(red: 0.06, green: 0.72, blue: 0.40)
    static let colorKeepGlow = Color(red: 0.06, green: 0.72, blue: 0.40, opacity: 0.15)
    static let colorTrash = Color(red: 0.95, green: 0.25, blue: 0.35)
    static let colorTrashGlow = Color(red: 0.95, green: 0.25, blue: 0.35, opacity: 0.15)
}
