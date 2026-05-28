import SwiftUI
import AppKit
import Combine

// --- File Size Formatter Helper ---
extension Int64 {
    func formattedSize() -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}

// --- Application Entry Point ---
@main
struct PhotoSweepApp: App {
    @StateObject private var state = AppState()
    
    init() {
        // Set activation policy to regular so that it runs as a standard foreground application
        // with a Dock icon, menu bar, and full keyboard event focus.
        NSApplication.shared.setActivationPolicy(.regular)
        
        // Force the app to become active and bring its window to the front
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 1080, minHeight: 720)
                .background(Color.bgBase)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar) // Custom unified titlebar layout
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

// --- Application State Engine ---
class AppState: ObservableObject {
    @Published var folderPath: String = ""
    @Published var images: [ImageFile] = []
    @Published var currentIndex: Int = -1
    @Published var activeImage: NSImage? = nil
    
    struct HistoryAction {
        let index: Int
        let actionType: ActionType
        let standardTrashedURL: URL?
        let rawTrashedURL: URL?
        
        enum ActionType {
            case kept
            case trashed
        }
    }
    
    @Published var historyStack: [HistoryAction] = []
    
    // Stats Metrics
    @Published var totalCount: Int = 0
    @Published var totalSize: Int64 = 0
    @Published var keptCount: Int = 0
    @Published var keptSize: Int64 = 0
    @Published var trashedCount: Int = 0
    @Published var trashedSize: Int64 = 0
    
    // Active HUD Feedback
    @Published var toastMessage: String? = nil
    @Published var toastIcon: String = "info"
    @Published var lastVisitedSubfolder: String? = nil
    
    struct ImageFile: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let path: String
        let url: URL
        let size: Int64
        let dateModified: Date
        var status: Status = .pending
        var rawURL: URL? = nil
        var rawSize: Int64 = 0
        
        enum Status {
            case pending, kept, trashed
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // --- File Explorer Variables ---
    @Published var explorerPath: URL = FileManager.default.homeDirectoryForCurrentUser
    @Published var explorerSubfolders: [URL] = []
    @Published var quickLocations: [QuickLocation] = []
    
    struct QuickLocation: Identifiable {
        let id = UUID()
        let name: String
        let url: URL
        let systemIcon: String
    }
    
    init() {
        setupKeyboardMonitor()
        setupQuickLocations()
        navigateTo(url: FileManager.default.homeDirectoryForCurrentUser)
        
        // Ensure the application activates and gains key focus immediately on startup
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let window = NSApplication.shared.windows.first(where: { $0.isVisible && !$0.title.isEmpty }) ?? NSApplication.shared.mainWindow ?? NSApplication.shared.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    func setupQuickLocations() {
        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures")
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        
        var locations = [
            QuickLocation(name: "Home", url: FileManager.default.homeDirectoryForCurrentUser, systemIcon: "house"),
            QuickLocation(name: "Pictures", url: picturesURL, systemIcon: "photo"),
            QuickLocation(name: "Desktop", url: desktopURL, systemIcon: "desktopcomputer"),
            QuickLocation(name: "Downloads", url: downloadsURL, systemIcon: "arrow.down.circle")
        ]
        
        // Dynamically find and append any connected removable volumes (like SD Cards, USB drives)
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey]
        if let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) {
            for volumeURL in volumes {
                if let resourceValues = try? volumeURL.resourceValues(forKeys: Set(keys)) {
                    let isRemovable = resourceValues.volumeIsRemovable ?? false
                    let name = resourceValues.volumeName ?? volumeURL.lastPathComponent
                    
                    if isRemovable {
                        locations.append(QuickLocation(
                            name: name,
                            url: volumeURL,
                            systemIcon: "sdcard" // Standard macOS high-fidelity SD Card SF Symbol!
                        ))
                    }
                }
            }
        }
        
        // Fallback Volumes shortcut if no removable volumes are mounted
        if !locations.contains(where: { $0.url.path.hasPrefix("/Volumes") }) {
            locations.append(QuickLocation(name: "Volumes", url: URL(fileURLWithPath: "/Volumes"), systemIcon: "externaldrive"))
        }
        
        self.quickLocations = locations
    }
    
    func navigateTo(url: URL) {
        let resolvedURL = url.resolvingSymlinksInPath()
        
        // If we navigate to a path that is not the parent/ancestor of our last visited subfolder, clear it
        if let lastVisited = lastVisitedSubfolder, !lastVisited.hasPrefix(resolvedURL.path) {
            lastVisitedSubfolder = nil
        }
        
        self.explorerPath = resolvedURL
        self.refreshExplorer()
    }
    
    func navigateUp() {
        let parent = explorerPath.deletingLastPathComponent()
        if parent.path != explorerPath.path {
            self.lastVisitedSubfolder = explorerPath.path // Track the subdirectory we are leaving!
            navigateTo(url: parent)
        }
    }
    
    func refreshExplorer() {
        self.setupQuickLocations() // Refresh connected volumes and SD cards dynamically!
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(at: explorerPath, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            var subdirs: [URL] = []
            for url in contents {
                if let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]), resourceValues.isDirectory == true {
                    subdirs.append(url)
                }
            }
            subdirs.sort { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }
            
            DispatchQueue.main.async {
                self.explorerSubfolders = subdirs
                // Automatically attempt to load standard images & RAW pairs from the current directory!
                self.loadFolder(url: self.explorerPath)
            }
        } catch {
            print("Failed to read explorer folder contents: \(error)")
            DispatchQueue.main.async {
                self.explorerSubfolders = []
            }
        }
    }
    
    // Installs a local AppKit event monitor for global window keyboard control
    private func setupKeyboardMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Handle Escape key globally for File Explorer navigation
            if event.keyCode == 53 { // Escape Key
                DispatchQueue.main.async {
                    self.navigateUp()
                }
                return nil
            }
            
            guard !self.folderPath.isEmpty && self.currentIndex != -1 else { return event }
            
            let isOptionPressed = event.modifierFlags.contains(.option)
            let isCommandPressed = event.modifierFlags.contains(.command)
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
            
            // Print key event to terminal for diagnostics
            print("PhotoSweep Keyboard Event - KeyCode: \(event.keyCode), Character: '\(chars)'")
            
            if event.keyCode == 126 || chars == "w" || (chars == "z" && isCommandPressed) { // Up Arrow, Key 'W', or Cmd + Z
                DispatchQueue.main.async {
                    withAnimation { self.undo() }
                }
                return nil
            } else if event.keyCode == 123 || chars == "a" { // Left Arrow or Key 'A'
                DispatchQueue.main.async {
                    withAnimation { self.trashActivePhoto() }
                }
                return nil
            } else if event.keyCode == 124 || chars == "d" || event.keyCode == 49 || chars == " " { // Right Arrow, Key 'D', or Space
                DispatchQueue.main.async {
                    withAnimation { self.keepActivePhoto() }
                }
                return nil
            } else if chars == "o" && isOptionPressed { // Option + O
                DispatchQueue.main.async {
                    self.revealActivePhoto()
                }
                return nil
            }
            return event
        }
    }
    
    // Prompts native directory selection via NSOpenPanel
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Folder containing Photos"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                self.loadFolder(url: url)
            }
        }
        
        // Force the application window to re-grab focus and active state after directory picker closes!
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first(where: { $0.isVisible && !$0.title.isEmpty }) ?? NSApplication.shared.mainWindow ?? NSApplication.shared.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    
    // Loads folder files asynchronously
    func loadFolder(url: URL) {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.nameKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        let allowedExtensions = ["jpg", "jpeg", "png", "webp", "gif", "heic", "heif", "tiff", "bmp", "svg"]
        let rawExtensions = ["arw"] // Sony Alpha Raw extension
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
                
                // 1. Separate standard image files and RAW files
                var standardURLs: [URL] = []
                var rawURLs: [URL] = []
                
                for fileURL in contents {
                    let resourceValues = try fileURL.resourceValues(forKeys: Set(keys))
                    let isDir = resourceValues.isDirectory ?? false
                    if isDir { continue }
                    
                    let ext = fileURL.pathExtension.lowercased()
                    if allowedExtensions.contains(ext) {
                        standardURLs.append(fileURL)
                    } else if rawExtensions.contains(ext) {
                        rawURLs.append(fileURL)
                    }
                }
                
                // 2. Map standard files and check for matching RAW file
                var loadedFiles: [ImageFile] = []
                var pairedRawURLs = Set<URL>()
                
                for fileURL in standardURLs {
                    let resourceValues = try fileURL.resourceValues(forKeys: Set(keys))
                    let name = resourceValues.name ?? fileURL.lastPathComponent
                    let size = Int64(resourceValues.fileSize ?? 0)
                    let date = resourceValues.contentModificationDate ?? Date()
                    
                    // Look for matching RAW file (.arw) in rawURLs
                    let baseName = fileURL.deletingPathExtension().lastPathComponent.lowercased()
                    var rawFile: URL? = nil
                    var rawSizeValue: Int64 = 0
                    
                    if let match = rawURLs.first(where: { $0.deletingPathExtension().lastPathComponent.lowercased() == baseName }) {
                        rawFile = match
                        pairedRawURLs.insert(match)
                        
                        // Read size of RAW file
                        if let rawStats = try? match.resourceValues(forKeys: [.fileSizeKey]) {
                            rawSizeValue = Int64(rawStats.fileSize ?? 0)
                        }
                    }
                    
                    loadedFiles.append(ImageFile(
                        name: name,
                        path: fileURL.path,
                        url: fileURL,
                        size: size,
                        dateModified: date,
                        status: .pending,
                        rawURL: rawFile,
                        rawSize: rawSizeValue
                    ))
                }
                
                // 3. For any RAW files that DO NOT have a matching JPEG/standard companion (shot RAW only), list them independently in the slider!
                for fileURL in rawURLs {
                    if !pairedRawURLs.contains(fileURL) {
                        let resourceValues = try fileURL.resourceValues(forKeys: Set(keys))
                        let name = resourceValues.name ?? fileURL.lastPathComponent
                        let size = Int64(resourceValues.fileSize ?? 0)
                        let date = resourceValues.contentModificationDate ?? Date()
                        
                        loadedFiles.append(ImageFile(
                            name: name,
                            path: fileURL.path,
                            url: fileURL,
                            size: size,
                            dateModified: date,
                            status: .pending,
                            rawURL: nil,
                            rawSize: 0
                        ))
                    }
                }
                
                // Sort by date modified (newest first)
                loadedFiles.sort { $0.dateModified > $1.dateModified }
                
                DispatchQueue.main.async {
                    self.folderPath = url.path
                    self.images = loadedFiles
                    self.totalCount = loadedFiles.count
                    
                    // Total size is standard size + raw size of paired files
                    self.totalSize = loadedFiles.reduce(0) { $0 + $1.size + $1.rawSize }
                    
                    self.keptCount = 0
                    self.keptSize = 0
                    self.trashedCount = 0
                    self.trashedSize = 0
                    
                    self.currentIndex = loadedFiles.isEmpty ? -1 : 0
                    self.loadActiveImage()
                    
                    // Show count including RAW pairings in toast
                    let rawCount = loadedFiles.filter { $0.rawURL != nil }.count
                    if rawCount > 0 {
                        self.showToast("Loaded \(loadedFiles.count) photos (with \(rawCount) RAW+JPEG pairs)!", icon: "photo.on.rectangle")
                    } else {
                        self.showToast("Successfully loaded \(loadedFiles.count) photos!", icon: "photo.on.rectangle")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showToast("Failed to read directory folder.", icon: "exclamationmark.triangle")
                }
            }
        }
    }
    
    // Loads current NSImage off the main thread to guarantee smooth transitions
    func loadActiveImage() {
        guard currentIndex >= 0 && currentIndex < images.count else {
            self.activeImage = nil
            return
        }
        
        let path = images[currentIndex].path
        DispatchQueue.global(qos: .userInteractive).async {
            if let image = NSImage(contentsOfFile: path) {
                DispatchQueue.main.async {
                    self.activeImage = image
                }
            }
        }
    }
    
    // Performs Keep Action
    func keepActivePhoto() {
        guard currentIndex >= 0 && currentIndex < images.count else { return }
        
        let currentStatus = images[currentIndex].status
        if currentStatus == .kept {
            // Already kept, just advance
            advanceIndex()
            return
        }
        
        // Push keep action to history stack before advancing
        historyStack.append(HistoryAction(
            index: currentIndex,
            actionType: .kept,
            standardTrashedURL: nil,
            rawTrashedURL: nil
        ))
        
        images[currentIndex].status = .kept
        keptCount += 1
        keptSize += images[currentIndex].size
        
        advanceIndex()
    }
    
    // Reverts the last decision (Keep or Delete) back to pending state
    func undo() {
        // Case 1: If the currently active photo is kept, revert it!
        if currentIndex >= 0 && currentIndex < images.count && images[currentIndex].status == .kept {
            let item = images[currentIndex]
            images[currentIndex].status = .pending
            keptCount = max(0, keptCount - 1)
            keptSize = max(0, keptSize - item.size)
            historyStack.removeAll { $0.index == currentIndex }
            
            loadActiveImage()
            showToast("Reverted photo back to queue", icon: "arrow.uturn.backward")
            return
        }
        
        // Case 2: Otherwise, pop the last action from the history stack
        guard let lastAction = historyStack.popLast() else {
            showToast("No decisions in history to revert", icon: "arrow.uturn.backward")
            return
        }
        
        let index = lastAction.index
        let item = images[index]
        
        if lastAction.actionType == .kept {
            if images[index].status == .kept {
                images[index].status = .pending
                keptCount = max(0, keptCount - 1)
                keptSize = max(0, keptSize - item.size)
                
                currentIndex = index
                loadActiveImage()
                showToast("Reverted last kept photo", icon: "arrow.uturn.backward")
            }
        } else if lastAction.actionType == .trashed {
            // Restore file back from standard Trash folder natively!
            var restoredStandard = false
            var restoredRaw = false
            
            if let trashedURL = lastAction.standardTrashedURL {
                do {
                    try FileManager.default.moveItem(at: trashedURL, to: item.url)
                    restoredStandard = true
                } catch {
                    print("Failed to restore standard file from Trash: \(error)")
                }
            }
            
            if let trashedRawURL = lastAction.rawTrashedURL, let originalRawURL = item.rawURL {
                do {
                    try FileManager.default.moveItem(at: trashedRawURL, to: originalRawURL)
                    restoredRaw = true
                } catch {
                    print("Failed to restore RAW pair file from Trash: \(error)")
                }
            }
            
            if restoredStandard {
                images[index].status = .pending
                trashedCount = max(0, trashedCount - 1)
                
                let spaceRestored = item.size + (restoredRaw ? item.rawSize : 0)
                trashedSize = max(0, trashedSize - spaceRestored)
                
                currentIndex = index
                loadActiveImage()
                
                if restoredRaw {
                    showToast("Restored JPG + RAW pair from Trash!", icon: "arrow.uturn.backward")
                } else {
                    showToast("Restored photo from Trash!", icon: "arrow.uturn.backward")
                }
            } else {
                showToast("Failed to restore photo from Trash Bin.", icon: "exclamationmark.triangle")
            }
        }
    }
    
    // Performs native macOS Trash recycling
    func trashActivePhoto() {
        guard currentIndex >= 0 && currentIndex < images.count else { return }
        let item = images[currentIndex]
        
        // If it was previously kept, we must subtract it from kept stats!
        let wasKept = item.status == .kept
        
        var trashedRawSuccess = false
        var trashedStandardSuccess = false
        
        var resultingRawURL: NSURL? = nil
        var resultingStandardURL: NSURL? = nil
        
        // 1. Recycle raw pair if exists
        if let rawURL = item.rawURL {
            do {
                try FileManager.default.trashItem(at: rawURL, resultingItemURL: &resultingRawURL)
                trashedRawSuccess = true
            } catch {
                print("Failed to recycle RAW pair file \(rawURL.path): \(error)")
            }
        }
        
        // 2. Recycle standard image
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: &resultingStandardURL)
            trashedStandardSuccess = true
        } catch {
            print("Failed to recycle standard file \(item.url.path): \(error)")
        }
        
        if trashedStandardSuccess {
            images[currentIndex].status = .trashed
            trashedCount += 1
            
            // Add size of BOTH standard and RAW file to the space cleared!
            let spaceFreed = item.size + (trashedRawSuccess ? item.rawSize : 0)
            trashedSize += spaceFreed
            
            if wasKept {
                keptCount = max(0, keptCount - 1)
                keptSize = max(0, keptSize - item.size)
            }
            
            // Clean up history stack for this index to maintain consistent undo order
            historyStack.removeAll { $0.index == currentIndex }
            
            // Push trash action to history stack!
            historyStack.append(HistoryAction(
                index: currentIndex,
                actionType: .trashed,
                standardTrashedURL: resultingStandardURL as URL?,
                rawTrashedURL: resultingRawURL as URL?
            ))
            
            advanceIndex()
            
            if trashedRawSuccess {
                showToast("Moved JPG + RAW pair to Trash", icon: "trash")
            } else {
                showToast("Moved photo to Trash Bin", icon: "trash")
            }
        } else {
            showToast("Failed to delete. Check lock permissions.", icon: "exclamationmark.shield")
        }
    }
    
    // Natively reveals file in macOS Finder
    func revealActivePhoto() {
        guard currentIndex >= 0 && currentIndex < images.count else { return }
        let url = images[currentIndex].url
        NSWorkspace.shared.activateFileViewerSelecting([url])
        showToast("Revealed file in macOS Finder", icon: "magnifyingglass")
    }
    
    // Moves to the next pending photo
    private func advanceIndex() {
        if let nextIndex = images.enumerated().first(where: { $0.offset > currentIndex && $0.element.status == .pending })?.offset {
            currentIndex = nextIndex
        } else if let prevIndex = images.enumerated().first(where: { $0.element.status == .pending })?.offset {
            currentIndex = prevIndex
        } else {
            currentIndex = -1 // All photos processed!
        }
        loadActiveImage()
    }
    
    // Jump directly to image from Filmstrip
    func selectIndex(_ index: Int) {
        guard index >= 0 && index < images.count else { return }
        guard images[index].status != .trashed else { return }
        
        currentIndex = index
        loadActiveImage()
    }
    
    // Show self-fading UI toast notifications
    func showToast(_ message: String, icon: String) {
        self.toastMessage = message
        self.toastIcon = icon
        
        // Auto-dismiss in 2 seconds
        Just(())
            .delay(for: .seconds(2.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                if self?.toastMessage == message {
                    self?.toastMessage = nil
                }
            }
            .store(in: &cancellables)
    }
    
    func reset() {
        self.folderPath = ""
        self.images = []
        self.currentIndex = -1
        self.activeImage = nil
        self.totalCount = 0
        self.totalSize = 0
        self.keptCount = 0
        self.keptSize = 0
        self.trashedCount = 0
        self.trashedSize = 0
    }
}

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
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = NSImage(contentsOfFile: path) {
                // Highly performant downscaling in AppKit
                let size = NSSize(width: 144, height: 96)
                let thumb = NSImage(size: size)
                thumb.lockFocus()
                image.draw(in: NSRect(origin: .zero, size: size),
                           from: NSRect(origin: .zero, size: image.size),
                           operation: .copy,
                           fraction: 1.0)
                thumb.unlockFocus()
                
                DispatchQueue.main.async {
                    self.thumbnail = thumb
                }
            }
        }
    }
}

// --- Main Layout View ---
struct ContentView: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HeaderBar()
            
            HStack(spacing: 0) {
                // Left Panel: File Navigator & Stats (Always visible!)
                SidebarPanel()
                    .frame(width: 280)
                
                Divider()
                    .background(Color.white.opacity(0.05))
                
                // Right Panel
                if state.images.isEmpty {
                    OnboardingView()
                } else {
                    VStack(spacing: 0) {
                        WorkspacePanel()
                        
                        Divider()
                            .background(Color.white.opacity(0.05))
                        
                        // Bottom Timeline Filmstrip
                        FilmstripTimeline()
                    }
                }
            }
        }
        .overlay(ToastOverlay())
    }
}

// --- Custom Header Component ---
struct HeaderBar: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        HStack(spacing: 12) {
            // Spacer to avoid macOS hidden window traffic lights
            Spacer()
                .frame(width: 80)
            
            HStack(spacing: 6) {
                Text("✦")
                    .font(.title3)
                    .foregroundColor(.accentPrimary)
                Text("PhotoSweep")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            if !state.folderPath.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundColor(.accentPrimary)
                        .font(.subheadline)
                    
                    Text(state.folderPath)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 320)
                    
                    Button(action: { state.reset() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                            Text("Change Folder")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    .help("Select a different photo folder")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.08), lineWidth: 1))
                .cornerRadius(30)
            }
            
            Spacer()
        }
        .frame(height: 52)
        .padding(.horizontal, 16)
        .background(Color.bgBase.opacity(0.9))
    }
}

// --- Onboarding Dashboard view ---
struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var isPulse = false
    
    var body: some View {
        ZStack {
            // Deep radial background glow
            RadialGradient(colors: [Color.accentPrimary.opacity(0.06), Color.clear],
                           center: .center, startRadius: 10, endRadius: 400)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("DESKTOP UTILITY")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .kerning(1.5)
                        .foregroundColor(.accentPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentPrimary.opacity(0.12))
                        .cornerRadius(20)
                    
                    Text("Sweep through your photos.")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                    Text("Clear disk space instantly.")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.accentPrimary)
                }
                .multilineTextAlignment(.center)
                
                Text("Select a folder on your Mac. Rapidly review each photo. Keep what is beautiful. Trash what is blurry. Direct integration with macOS system Trash. Supports HEIC, JPG, PNG, WEBP, and GIF.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                    .lineLimit(nil)
                
                Button(action: { state.selectFolder() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.badge.plus")
                            .font(.title2)
                        Text("Select Photo Folder")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .background(LinearGradient(colors: [.accentPrimary, Color(red: 0.3, green: 0.3, blue: 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .cornerRadius(50)
                    .shadow(color: Color.accentPrimary.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                
                // Shortcuts Cheatsheet
                HStack(spacing: 32) {
                    VStack(alignment: .center, spacing: 6) {
                        Text("←  or  A")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                        Text("Trash Photo")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    VStack(alignment: .center, spacing: 6) {
                        Text("→  or  D  or  Space")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                        Text("Keep & Advance")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    VStack(alignment: .center, spacing: 6) {
                        Text("Drag Card")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                        Text("Tinder swipe gestures")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.top, 40)
            }
            .padding(48)
            .background(Color.bgSurface)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.4), radius: 30, x: 0, y: 20)
            .frame(maxWidth: 680)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// --- Left Panel: Statistics & Progression UI ---
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
        }
        .buttonStyle(.plain)
        .onHover { hover in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hover
            }
        }
    }
}

struct QuickLocationButton: View {
    let location: AppState.QuickLocation
    let activePath: String
    let action: () -> Void
    
    private var isActive: Bool {
        activePath == location.url.path
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: location.systemIcon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isActive ? .white : .white.opacity(0.6))
                .frame(width: 32, height: 32)
                .background(isActive ? Color.accentPrimary : Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(location.name)
    }
}

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

// --- UI Toast HUD Overlay ---
struct ToastOverlay: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        VStack {
            if let msg = state.toastMessage {
                HStack(spacing: 10) {
                    Image(systemName: state.toastIcon)
                        .foregroundColor(.accentPrimary)
                        .font(.body)
                    
                    Text(msg)
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.bgElevated)
                .cornerRadius(30)
                .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.08), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
                .padding(.top, 64) // Placed at top center just under the folder path bar
                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                       removal: .opacity))
            }
            
            Spacer()
        }
        .animation(.spring(), value: state.toastMessage)
    }
}
