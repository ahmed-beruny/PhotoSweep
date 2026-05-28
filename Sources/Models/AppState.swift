import SwiftUI
import AppKit
import Combine

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
    
    // Loads current NSImage or video frame off the main thread to guarantee smooth transitions
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
