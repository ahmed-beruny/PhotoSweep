import SwiftUI

struct FileNavigatorView: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FILE EXPLORER")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .kerning(1.0)
            
            // 1. Quick Access Locations Grid
            HStack(spacing: 8) {
                ForEach(state.quickLocations) { loc in
                    QuickLocationButton(location: loc, activePath: state.explorerPath.path) {
                        state.navigateTo(url: loc.url)
                    }
                }
            }
            .padding(.bottom, 4)
            
            // 2. Active Folder Header & Go Up Button
            HStack {
                Text(state.explorerPath.lastPathComponent.isEmpty ? "/" : state.explorerPath.lastPathComponent)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: { state.navigateUp() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up")
                            .font(.caption2)
                        Text("Up")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(state.explorerPath.path == "/")
            }
            .padding(.horizontal, 4)
            
            // 3. Scrollable List of Sub-folders
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 2) {
                        if state.explorerSubfolders.isEmpty {
                            Text("No subfolders found")
                               .font(.caption)
                               .foregroundColor(.white.opacity(0.3))
                               .padding(.vertical, 16)
                        } else {
                            ForEach(state.explorerSubfolders, id: \.self) { subfolder in
                                let isActive = subfolder.path == state.folderPath
                                let isSelected = subfolder.path == state.lastVisitedSubfolder
                                
                                ExplorerFolderRow(url: subfolder, isActive: isActive, isSelected: isSelected) {
                                    state.navigateTo(url: subfolder)
                                }
                                .id(subfolder.path) // Assign unique ID for ScrollViewReader!
                            }
                        }
                    }
                }
                .frame(maxHeight: 180)
                .padding(6)
                .background(Color.black.opacity(0.15))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.04), lineWidth: 1))
                .onChange(of: state.lastVisitedSubfolder) { _, newSubfolder in
                    if let targetPath = newSubfolder {
                        withAnimation {
                            proxy.scrollTo(targetPath, anchor: .center)
                        }
                    }
                }
                .onChange(of: state.explorerSubfolders) { _, subfolders in
                    // Prioritize scrolling to the last visited subfolder if it exists in the new list
                    if let lastVisited = state.lastVisitedSubfolder, subfolders.contains(where: { $0.path == lastVisited }) {
                        withAnimation {
                            proxy.scrollTo(lastVisited, anchor: .center)
                        }
                    } else if subfolders.contains(where: { $0.path == state.folderPath }) {
                        // Otherwise, if the currently active loaded photo folder is in this list, auto-scroll to it!
                        withAnimation {
                            proxy.scrollTo(state.folderPath, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.bgSurface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}
