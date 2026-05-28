import SwiftUI

struct SidebarPanel: View {
    @EnvironmentObject var state: AppState
    
    private var processedCount: Int {
        state.keptCount + state.trashedCount
    }
    
    private var progressRatio: Double {
        guard state.totalCount > 0 else { return 0.0 }
        return Double(processedCount) / Double(state.totalCount)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // File Explorer Navigation Panel (Always shown!)
                FileNavigatorView()
                
                // Photo Details (EXIF) Card — shown when a photo with EXIF is active
                if let exif = state.activeExif {
                    PhotoDetailsCard(exif: exif)
                }
                
                if state.totalCount > 0 {
                    // Progression Card
                    ProgressCard(processedCount: processedCount, totalCount: state.totalCount, progressRatio: progressRatio)
                    
                    // stats dashboard card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("DISK CLEAN STATS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .kerning(1.0)
                        
                        VStack(spacing: 12) {
                            // Total Count
                            StatBox(title: "Total Loaded", count: "\(state.totalCount)", size: state.totalSize.formattedSize(), icon: "photo.stack", iconColor: .white.opacity(0.6), iconBg: .white.opacity(0.05))
                            
                            // Kept Count
                            StatBox(title: "Kept Photos", count: "\(state.keptCount)", size: state.keptSize.formattedSize(), icon: "checkmark.seal.fill", iconColor: .colorKeep, iconBg: .colorKeepGlow)
                            
                            // Trashed Count (Freed space highlighted!)
                            StatBox(title: "Space Freed", count: "\(state.trashedCount)", size: state.trashedSize.formattedSize(), icon: "trash.fill", iconColor: .colorTrash, iconBg: .colorTrashGlow, isFreed: true)
                        }
                    }
                    .padding(18)
                    .background(Color.bgSurface)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    
                    // Keyboard Guide Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("KEYBOARD SHORTCUTS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .kerning(1.0)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            ShortcutRow(keys: ["←", "A"], desc: "Trash photo")
                            ShortcutRow(keys: ["→", "D", "Space"], desc: "Keep & Next")
                            ShortcutRow(keys: ["⌥ + O"], desc: "Reveal in Finder")
                        }
                    }
                    .padding(18)
                    .background(Color.bgSurface)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
                } // Closes `if state.totalCount > 0`
            } // Closes `VStack(spacing: 16)`
            .padding(16)
        } // Closes `ScrollView`
        .background(Color.bgBase.opacity(0.5))
    } // Closes `body`
} // Closes `SidebarPanel`
