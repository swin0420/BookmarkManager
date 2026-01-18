import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var dbManager = DatabaseManager.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let themeColors = ThemeColors(colorScheme: colorScheme)

        ZStack {
            // Dynamic background
            themeColors.background
                .ignoresSafeArea()

            HSplitView {
                SidebarView()
                    .frame(minWidth: 220, maxWidth: 280)
                    .zIndex(1)

                MainContentView()
                    .frame(minWidth: 600)
                    .clipped()
            }
            .clipped()
        }
        .environment(\.themeColors, themeColors)
        .preferredColorScheme(appState.preferredColorScheme)
        .environmentObject(dbManager)
        .alert("Import Complete", isPresented: $appState.showImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            let newCount = appState.importedNewCount
            let updatedCount = appState.importedUpdatedCount
            if newCount > 0 && updatedCount > 0 {
                Text("Added \(newCount) new bookmarks, updated \(updatedCount) existing.")
            } else if newCount > 0 {
                Text("Added \(newCount) new bookmarks.")
            } else if updatedCount > 0 {
                Text("Updated \(updatedCount) existing bookmarks (no new bookmarks).")
            } else {
                Text("No bookmarks were imported.")
            }
        }
    }
}

struct MainContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.colorScheme) var colorScheme
    @State private var bookmarks: [Bookmark] = []
    @State private var isLoading = false

    private var themeColors: ThemeColors {
        ThemeColors(colorScheme: colorScheme)
    }

    var title: String {
        switch appState.selectedSection {
        case .allBookmarks:
            return "All Bookmarks"
        case .favorites:
            return "Favorites"
        case .folder(let id):
            return dbManager.folders.first { $0.id == id }?.name ?? "Folder"
        case .tag(let id):
            return dbManager.tags.first { $0.id == id }?.name ?? "Tag"
        case .smartCollection(let type):
            return type.rawValue
        }
    }

    var accentColor: Color {
        switch appState.selectedSection {
        case .allBookmarks:
            return .appAccent
        case .favorites:
            return .yellow
        case .folder(let id):
            return dbManager.folders.first { $0.id == id }?.color ?? .appAccent
        case .tag(let id):
            return dbManager.tags.first { $0.id == id }?.color ?? .appAccent
        case .smartCollection(let type):
            switch type {
            case .withMedia: return .pink
            case .textOnly: return .cyan
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with drag area
            VStack(spacing: 0) {
                // Drag area for window
                Color.clear
                    .frame(height: 38)

                // Title and controls
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(themeColors.primaryText)

                        HStack(spacing: 8) {
                            Text("\(bookmarks.count) bookmarks")
                                .font(.system(size: 13))
                                .foregroundColor(themeColors.tertiaryText)

                            if appState.isSelectionMode && !appState.selectedBookmarkIds.isEmpty {
                                Text("• \(appState.selectedBookmarkIds.count) selected")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(accentColor)
                            }
                        }
                    }

                    Spacer()

                    // Bulk actions when in selection mode
                    if appState.isSelectionMode && !appState.selectedBookmarkIds.isEmpty {
                        HStack(spacing: 8) {
                            // Move to folder menu
                            Menu {
                                Button("Remove from folder") {
                                    dbManager.moveBookmarksToFolder(Array(appState.selectedBookmarkIds), folderId: nil)
                                }
                                Divider()
                                ForEach(dbManager.folders) { folder in
                                    Button {
                                        dbManager.moveBookmarksToFolder(Array(appState.selectedBookmarkIds), folderId: folder.id)
                                    } label: {
                                        HStack {
                                            Circle().fill(folder.color).frame(width: 8, height: 8)
                                            Text(folder.name)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder")
                                    Text("Move")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(themeColors.secondaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(themeColors.hoverBackground))
                            }
                            .menuStyle(.borderlessButton)

                            // Add tag menu
                            Menu {
                                ForEach(dbManager.tags) { tag in
                                    Button {
                                        dbManager.addTagToBookmarks(Array(appState.selectedBookmarkIds), tagId: tag.id)
                                    } label: {
                                        HStack {
                                            Circle().fill(tag.color).frame(width: 8, height: 8)
                                            Text(tag.name)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "tag")
                                    Text("Tag")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(themeColors.secondaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(themeColors.hoverBackground))
                            }
                            .menuStyle(.borderlessButton)

                            // Delete
                            Button {
                                dbManager.deleteBookmarks(Array(appState.selectedBookmarkIds))
                                appState.selectedBookmarkIds.removeAll()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                    Text("Delete")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red.opacity(0.9))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Sort picker
                    Menu {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Button {
                                appState.sortOrder = order
                            } label: {
                                HStack {
                                    Text(order.rawValue)
                                    if appState.sortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(appState.sortOrder.rawValue)
                        }
                        .font(.system(size: 12))
                        .foregroundColor(themeColors.tertiaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(themeColors.hoverBackground))
                    }
                    .menuStyle(.borderlessButton)

                    // Selection mode toggle
                    Button {
                        appState.isSelectionMode.toggle()
                        if !appState.isSelectionMode {
                            appState.selectedBookmarkIds.removeAll()
                        }
                    } label: {
                        Image(systemName: appState.isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 16))
                            .foregroundColor(appState.isSelectionMode ? accentColor : themeColors.tertiaryText)
                            .frame(width: 32, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(appState.isSelectionMode ? accentColor.opacity(0.2) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Toggle selection mode")

                    // Theme picker
                    Menu {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Button {
                                appState.theme = theme
                            } label: {
                                HStack {
                                    Image(systemName: theme.icon)
                                    Text(theme.rawValue)
                                    if appState.theme == theme {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: appState.theme.icon)
                            .font(.system(size: 16))
                            .foregroundColor(themeColors.tertiaryText)
                            .frame(width: 32, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(themeColors.hoverBackground)
                            )
                    }
                    .menuStyle(.borderlessButton)
                    .help("Change theme")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // Search and filters
                FilterBarView(accentColor: accentColor)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
            .background(
                themeColors.sidebarBackground.opacity(0.5)
                    .background(.ultraThinMaterial)
            )

            // Content
            ScrollView {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if bookmarks.isEmpty {
                    EmptyStateView(accentColor: accentColor)
                } else {
                    BookmarkGridView(bookmarks: bookmarks, accentColor: accentColor)
                }
            }
            .clipped()
            .background(themeColors.background)
        }
        .onAppear {
            loadBookmarks()
        }
        .onChange(of: appState.selectedSection) { _, _ in
            loadBookmarks()
        }
        .onChange(of: appState.searchQuery) { _, _ in
            loadBookmarks()
        }
        .onChange(of: appState.selectedAuthor) { _, _ in
            loadBookmarks()
        }
        .onChange(of: appState.dateFrom) { _, _ in
            loadBookmarks()
        }
        .onChange(of: appState.dateTo) { _, _ in
            loadBookmarks()
        }
        .onChange(of: appState.sortOrder) { _, _ in
            loadBookmarks()
        }
        .onChange(of: appState.isSemanticSearchEnabled) { _, _ in
            loadBookmarks()
        }
        .onChange(of: dbManager.dataVersion) { _, _ in
            // Refresh bookmarks without full reload to avoid blinking
            refreshBookmarks()
        }
    }

    private func loadBookmarks() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            var results: [Bookmark] = []

            // Check if semantic search is enabled, we have a query, and we're in All Bookmarks
            let canUseSemanticSearch = appState.isSemanticSearchEnabled &&
                                        !appState.searchQuery.isEmpty &&
                                        appState.selectedSection == .allBookmarks

            if canUseSemanticSearch {
                // Use semantic search (unlimited)
                let searchResults = SemanticSearchService.shared.search(query: appState.searchQuery, limit: 10000)
                let bookmarkIds = searchResults.map { $0.bookmarkId }

                // Fetch bookmarks by IDs while preserving order
                let allBookmarks = dbManager.searchBookmarks(limit: 10000)
                let bookmarkMap = Dictionary(uniqueKeysWithValues: allBookmarks.map { ($0.id, $0) })

                for id in bookmarkIds {
                    if let bookmark = bookmarkMap[id] {
                        // Apply additional filters
                        var include = true

                        if let author = appState.selectedAuthor, !author.isEmpty {
                            include = include && bookmark.authorHandle == author
                        }

                        if let dateFrom = appState.dateFrom {
                            include = include && bookmark.postedAt >= dateFrom
                        }

                        if let dateTo = appState.dateTo {
                            include = include && bookmark.postedAt <= dateTo
                        }

                        if include {
                            results.append(bookmark)
                        }
                    }
                }
                // Semantic search: keep relevance order, don't sort
            } else {
                // Regular search
                switch appState.selectedSection {
                case .smartCollection(let type):
                    results = dbManager.getSmartCollectionBookmarks(
                        type,
                        author: appState.selectedAuthor,
                        query: appState.searchQuery.isEmpty ? nil : appState.searchQuery
                    )
                default:
                    var tagId: String?
                    var folderId: String?
                    var favoritesOnly = false

                    switch appState.selectedSection {
                    case .allBookmarks:
                        break
                    case .favorites:
                        favoritesOnly = true
                    case .folder(let id):
                        folderId = id
                    case .tag(let id):
                        tagId = id
                    default:
                        break
                    }

                    results = dbManager.searchBookmarks(
                        query: appState.searchQuery.isEmpty ? nil : appState.searchQuery,
                        author: appState.selectedAuthor,
                        tagId: tagId,
                        folderId: folderId,
                        favoritesOnly: favoritesOnly,
                        dateFrom: appState.dateFrom,
                        dateTo: appState.dateTo
                    )
                }

                // Apply sorting only for regular search (not semantic)
                results = sortBookmarks(results)
            }

            DispatchQueue.main.async {
                self.bookmarks = results
                self.isLoading = false
            }
        }
    }

    private func refreshBookmarks() {
        // Quick refresh without loading indicator to avoid blinking
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [Bookmark] = []

            switch appState.selectedSection {
            case .smartCollection(let type):
                results = dbManager.getSmartCollectionBookmarks(
                    type,
                    author: appState.selectedAuthor,
                    query: appState.searchQuery.isEmpty ? nil : appState.searchQuery
                )
            default:
                var tagId: String?
                var folderId: String?
                var favoritesOnly = false

                switch appState.selectedSection {
                case .allBookmarks:
                    break
                case .favorites:
                    favoritesOnly = true
                case .folder(let id):
                    folderId = id
                case .tag(let id):
                    tagId = id
                default:
                    break
                }

                results = dbManager.searchBookmarks(
                    query: appState.searchQuery.isEmpty ? nil : appState.searchQuery,
                    author: appState.selectedAuthor,
                    tagId: tagId,
                    folderId: folderId,
                    favoritesOnly: favoritesOnly,
                    dateFrom: appState.dateFrom,
                    dateTo: appState.dateTo
                )
            }

            results = sortBookmarks(results)

            DispatchQueue.main.async {
                withAnimation(.none) {
                    self.bookmarks = results
                }
            }
        }
    }

    private func sortBookmarks(_ bookmarks: [Bookmark]) -> [Bookmark] {
        switch appState.sortOrder {
        case .recentFirst:
            return bookmarks.sorted { $0.postedAt > $1.postedAt }
        case .oldestFirst:
            return bookmarks.sorted { $0.postedAt < $1.postedAt }
        case .authorAZ:
            return bookmarks.sorted { $0.authorHandle.lowercased() < $1.authorHandle.lowercased() }
        case .authorZA:
            return bookmarks.sorted { $0.authorHandle.lowercased() > $1.authorHandle.lowercased() }
        }
    }
}

struct EmptyStateView: View {
    @Environment(\.colorScheme) var colorScheme
    let accentColor: Color

    var body: some View {
        let themeColors = ThemeColors(colorScheme: colorScheme)

        VStack(spacing: 16) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 48))
                .foregroundColor(accentColor.opacity(0.5))

            Text("No bookmarks found")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(themeColors.secondaryText)

            Text("Try adjusting your search or filters")
                .font(.system(size: 14))
                .foregroundColor(themeColors.mutedText)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .frame(width: 1200, height: 800)
}
