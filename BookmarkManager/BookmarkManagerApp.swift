import SwiftUI

@main
struct BookmarkManagerApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var dbManager = DatabaseManager.shared

    init() {
        // Log app startup to app support directory (sandbox-safe)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("BookmarkManager")
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        let logPath = appFolder.appendingPathComponent("debug.log")

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] 🚀 App started\n"
        if let data = logMessage.data(using: .utf8) {
            try? data.write(to: logPath)
        }
        #if DEBUG
        print("Log path: \(logPath.path)")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(dbManager)
                .frame(minWidth: 1000, minHeight: 700)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("View") {
                Button("Toggle Sidebar") {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }

    private func logToFile(_ message: String) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let logPath = appSupport.appendingPathComponent("BookmarkManager/debug.log")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"

        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logPath)
            }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        logToFile("📥 [\(timestamp)] Received URL - length: \(url.absoluteString.count) chars")
        logToFile("   Scheme: \(url.scheme ?? "nil"), Host: \(url.host ?? "nil")")
        #if DEBUG
        print("📥 [\(timestamp)] Received URL - length: \(url.absoluteString.count) chars")
        print("   Scheme: \(url.scheme ?? "nil"), Host: \(url.host ?? "nil")")
        #endif

        guard url.scheme == "bookmarkmanager" else {
            #if DEBUG
            print("❌ Invalid scheme")
            #endif
            return
        }

        // Bring app to front
        NSApp.activate(ignoringOtherApps: true)

        if url.host == "open" {
            #if DEBUG
            print("✅ Open command received - app activated")
            #endif
            return
        }

        if url.host == "import" {
            logToFile("📦 Import command received")
            #if DEBUG
            print("📦 Import command received")
            #endif

            // Try URLComponents first, fall back to manual parsing for large URLs
            var dataParam: String?

            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let param = components.queryItems?.first(where: { $0.name == "data" })?.value {
                dataParam = param
                logToFile("   Parsed via URLComponents")
            } else {
                // Manual parsing for large URLs (URLComponents can fail on very long URLs)
                let urlString = url.absoluteString
                if let dataRange = urlString.range(of: "data=") {
                    dataParam = String(urlString[dataRange.upperBound...])
                    logToFile("   Parsed via manual extraction")
                }
            }

            if let dataParam = dataParam,
               let decodedData = dataParam.removingPercentEncoding,
               let jsonData = decodedData.data(using: .utf8) {

                logToFile("   Data param length: \(dataParam.count)")
                logToFile("   Decoded data length: \(decodedData.count)")
                #if DEBUG
                print("   Data param length: \(dataParam.count)")
                print("   Decoded data length: \(decodedData.count)")
                #endif

                do {
                    let bookmarks = try JSONDecoder().decode([ImportedBookmark].self, from: jsonData)
                    logToFile("   ✅ Parsed \(bookmarks.count) bookmarks")
                    #if DEBUG
                    print("   ✅ Parsed \(bookmarks.count) bookmarks")
                    #endif

                    let result = dbManager.importBookmarks(bookmarks)
                    logToFile("   ✅ Imported: \(result.newCount) new, \(result.updatedCount) updated")
                    #if DEBUG
                    print("   ✅ Imported: \(result.newCount) new, \(result.updatedCount) updated")
                    #endif

                    DispatchQueue.main.async {
                        self.appState.importedNewCount = result.newCount
                        self.appState.importedUpdatedCount = result.updatedCount
                        self.appState.showImportSuccess = true
                        self.logToFile("   ✅ Alert triggered")
                    }
                } catch {
                    logToFile("❌ Failed to decode bookmarks: \(error)")
                    #if DEBUG
                    print("❌ Failed to decode bookmarks: \(error)")
                    #endif
                }
            } else {
                // Check for file import - with path validation
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let fileParam = components.queryItems?.first(where: { $0.name == "file" })?.value {
                    // Validate file path to prevent path traversal attacks
                    let resolvedPath = (fileParam as NSString).standardizingPath
                    let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
                    let allowedPaths = [
                        homeDir + "/Downloads",
                        homeDir + "/Desktop",
                        homeDir + "/Documents"
                    ]

                    let isAllowed = allowedPaths.contains { resolvedPath.hasPrefix($0) }
                    guard isAllowed else {
                        logToFile("❌ File import blocked - path not in allowed locations: \(resolvedPath)")
                        #if DEBUG
                        print("❌ File import blocked - path not in allowed locations: \(resolvedPath)")
                        #endif
                        return
                    }

                    // Verify file exists and is a regular file
                    var isDirectory: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: resolvedPath, isDirectory: &isDirectory),
                          !isDirectory.boolValue else {
                        logToFile("❌ File not found or is directory: \(resolvedPath)")
                        return
                    }

                    logToFile("   File import: \(resolvedPath)")
                    #if DEBUG
                    print("   File import: \(resolvedPath)")
                    #endif
                    dbManager.importFromJSONFile(resolvedPath)
                } else {
                    logToFile("❌ Could not parse data from URL")
                    #if DEBUG
                    print("❌ Could not parse data from URL")
                    #endif
                }
            }
        }
    }
}

// Structure for imported bookmarks from Chrome extension
struct ImportedBookmark: Codable {
    let tweet_id: String
    let author_handle: String
    let author_name: String
    let author_avatar: String?
    let content: String
    let posted_at: String
    let bookmarked_at: String?
    let url: String
    let media_urls: [String]?
    let is_truncated: Bool?
}

// MARK: - App Theme
enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

class AppState: ObservableObject {
    @Published var selectedSection: SidebarSection = .allBookmarks
    @Published var selectedFolderId: String?
    @Published var selectedTagId: String?
    @Published var searchQuery: String = ""
    @Published var selectedAuthor: String?
    @Published var dateFrom: Date?
    @Published var dateTo: Date?
    @Published var showImportSuccess: Bool = false
    @Published var importedNewCount: Int = 0
    @Published var importedUpdatedCount: Int = 0

    // Bulk selection
    @Published var isSelectionMode: Bool = false
    @Published var selectedBookmarkIds: Set<String> = []

    // Sort options
    @Published var sortOrder: SortOrder = .recentFirst

    // Media preview
    @Published var expandedMediaBookmarkId: String?

    // AI Features
    @Published var isSemanticSearchEnabled: Bool = false
    @Published var showChatView: Bool = false

    // Theme (default to dark)
    @Published var theme: AppTheme = .dark {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    init() {
        // Load saved theme preference (defaults to dark if not set)
        if let savedTheme = UserDefaults.standard.string(forKey: "appTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            self.theme = theme
        }
    }
}

enum SortOrder: String, CaseIterable {
    case recentFirst = "Recent First"
    case oldestFirst = "Oldest First"
    case authorAZ = "Author A-Z"
    case authorZA = "Author Z-A"
}

enum SidebarSection: Hashable {
    case allBookmarks
    case favorites
    case folder(String)
    case tag(String)
    case smartCollection(SmartCollectionType)
}

enum SmartCollectionType: String, Hashable, CaseIterable {
    case withMedia = "With Media"
    case textOnly = "Text Only"
}
