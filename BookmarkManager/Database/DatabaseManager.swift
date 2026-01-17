import Foundation
import SQLite3

class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    @Published var bookmarks: [Bookmark] = []
    @Published var tags: [Tag] = []
    @Published var folders: [Folder] = []
    @Published var authors: [String] = []
    @Published var stats: BookmarkStats = BookmarkStats(total: 0, favorites: 0, authors: 0, unprocessed: 0)
    @Published var dataVersion: Int = 0  // Increments on any data change to trigger UI refresh

    private init() {
        openDatabase()
        initializeSchema()
        loadData()
    }

    private func getDBPath() -> String {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("BookmarkManager")

        if !fileManager.fileExists(atPath: appFolder.path) {
            try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }

        return appFolder.appendingPathComponent("bookmarks.db").path
    }

    private func openDatabase() {
        let dbPath = getDBPath()

        // Check if we should copy from the old location
        let oldPath = FileManager.default.currentDirectoryPath + "/data/bookmarks.db"
        if FileManager.default.fileExists(atPath: oldPath) && !FileManager.default.fileExists(atPath: dbPath) {
            try? FileManager.default.copyItem(atPath: oldPath, toPath: dbPath)
        }

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Error opening database: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    private func initializeSchema() {
        let createTables = """
        CREATE TABLE IF NOT EXISTS folders (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            color TEXT DEFAULT '#6b7280',
            icon TEXT DEFAULT 'folder',
            sort_order INTEGER DEFAULT 0,
            created_at TEXT DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS tags (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            color TEXT DEFAULT '#6b7280',
            is_quick_tag INTEGER DEFAULT 0,
            sort_order INTEGER DEFAULT 0,
            created_at TEXT DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS bookmarks (
            id TEXT PRIMARY KEY,
            tweet_id TEXT UNIQUE NOT NULL,
            author_handle TEXT NOT NULL,
            author_name TEXT NOT NULL,
            author_avatar TEXT,
            content TEXT NOT NULL,
            posted_at TEXT NOT NULL,
            bookmarked_at TEXT NOT NULL,
            url TEXT NOT NULL,
            media_urls TEXT DEFAULT '[]',
            summary TEXT,
            categories TEXT DEFAULT '[]',
            is_favorite INTEGER DEFAULT 0,
            folder_id TEXT REFERENCES folders(id) ON DELETE SET NULL,
            created_at TEXT DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS bookmark_tags (
            bookmark_id TEXT NOT NULL REFERENCES bookmarks(id) ON DELETE CASCADE,
            tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
            PRIMARY KEY (bookmark_id, tag_id)
        );

        CREATE INDEX IF NOT EXISTS idx_bookmarks_author ON bookmarks(author_handle);
        CREATE INDEX IF NOT EXISTS idx_bookmarks_favorite ON bookmarks(is_favorite);
        CREATE INDEX IF NOT EXISTS idx_bookmarks_folder ON bookmarks(folder_id);

        CREATE TABLE IF NOT EXISTS bookmark_embeddings (
            bookmark_id TEXT PRIMARY KEY REFERENCES bookmarks(id) ON DELETE CASCADE,
            embedding BLOB NOT NULL,
            embedding_model TEXT NOT NULL,
            created_at TEXT DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS chat_messages (
            id TEXT PRIMARY KEY,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            context_bookmark_ids TEXT,
            created_at TEXT DEFAULT (datetime('now'))
        );

        CREATE INDEX IF NOT EXISTS idx_chat_messages_created ON chat_messages(created_at);
        """

        executeSQL(createTables)

        // Migration: add sort_order to tags if it doesn't exist
        executeSQL("ALTER TABLE tags ADD COLUMN sort_order INTEGER DEFAULT 0")

        initializeDefaultTags()
    }

    private func initializeDefaultTags() {
        let count = queryScalar("SELECT COUNT(*) FROM tags") ?? 0
        if count == 0 {
            let defaultTags = [
                ("hentai", "#ec4899"),
                ("vibecoding", "#8b5cf6"),
                ("crypto", "#f59e0b"),
                ("tech", "#3b82f6"),
                ("anime", "#ef4444"),
                ("visual-novel", "#10b981"),
                ("misc", "#6b7280")
            ]

            for (name, color) in defaultTags {
                executeSQL("INSERT INTO tags (id, name, color, is_quick_tag) VALUES ('\(UUID().uuidString)', '\(name)', '\(color)', 1)")
            }
        }
    }

    func loadData() {
        loadTags()
        loadFolders()
        loadAuthors()
        loadStats()
    }

    // MARK: - Bookmarks

    func searchBookmarks(
        query: String? = nil,
        author: String? = nil,
        tagId: String? = nil,
        folderId: String? = nil,
        favoritesOnly: Bool = false,
        dateFrom: Date? = nil,
        dateTo: Date? = nil,
        limit: Int = 10000,
        offset: Int = 0
    ) -> [Bookmark] {
        var conditions: [String] = []
        var params: [String] = []

        if let query = query, !query.isEmpty {
            conditions.append("(content LIKE ? OR author_handle LIKE ? OR author_name LIKE ?)")
            let likeQuery = "%\(query)%"
            params.append(contentsOf: [likeQuery, likeQuery, likeQuery])
        }

        if let author = author, !author.isEmpty {
            conditions.append("author_handle = ?")
            params.append(author)
        }

        if let tagId = tagId {
            conditions.append("id IN (SELECT bookmark_id FROM bookmark_tags WHERE tag_id = ?)")
            params.append(tagId)
        }

        if let folderId = folderId {
            conditions.append("folder_id = ?")
            params.append(folderId)
        }

        if favoritesOnly {
            conditions.append("is_favorite = 1")
        }

        if let dateFrom = dateFrom {
            conditions.append("posted_at >= ?")
            params.append(dateFormatter.string(from: dateFrom))
        }

        if let dateTo = dateTo {
            conditions.append("posted_at <= ?")
            params.append(dateFormatter.string(from: dateTo))
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
        let sql = "SELECT * FROM bookmarks \(whereClause) ORDER BY bookmarked_at DESC LIMIT \(limit) OFFSET \(offset)"

        return queryBookmarks(sql, params: params)
    }

    private func queryBookmarks(_ sql: String, params: [String] = []) -> [Bookmark] {
        var statement: OpaquePointer?
        var bookmarks: [Bookmark] = []

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            for (index, param) in params.enumerated() {
                sqlite3_bind_text(statement, Int32(index + 1), param, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }

            while sqlite3_step(statement) == SQLITE_ROW {
                if let bookmark = parseBookmarkRow(statement) {
                    bookmarks.append(bookmark)
                }
            }
        }
        sqlite3_finalize(statement)

        // Load tags for each bookmark
        return bookmarks.map { bookmark in
            var b = bookmark
            b.tags = getTagsForBookmark(bookmark.id)
            return b
        }
    }

    private func parseBookmarkRow(_ statement: OpaquePointer?) -> Bookmark? {
        guard let statement = statement else { return nil }

        let id = String(cString: sqlite3_column_text(statement, 0))
        let tweetId = String(cString: sqlite3_column_text(statement, 1))
        let authorHandle = String(cString: sqlite3_column_text(statement, 2))
        let authorName = String(cString: sqlite3_column_text(statement, 3))
        let authorAvatar = sqlite3_column_text(statement, 4).map { String(cString: $0) }
        let content = String(cString: sqlite3_column_text(statement, 5))
        let postedAtStr = String(cString: sqlite3_column_text(statement, 6))
        let bookmarkedAtStr = String(cString: sqlite3_column_text(statement, 7))
        let url = String(cString: sqlite3_column_text(statement, 8))
        let mediaUrlsJson = String(cString: sqlite3_column_text(statement, 9))
        let summary = sqlite3_column_text(statement, 10).map { String(cString: $0) }
        let categoriesJson = String(cString: sqlite3_column_text(statement, 11))
        let isFavorite = sqlite3_column_int(statement, 12) == 1
        let folderId = sqlite3_column_text(statement, 13).map { String(cString: $0) }
        let createdAtStr = String(cString: sqlite3_column_text(statement, 14))

        let mediaUrls = (try? JSONDecoder().decode([String].self, from: mediaUrlsJson.data(using: .utf8) ?? Data())) ?? []
        let categories = (try? JSONDecoder().decode([String].self, from: categoriesJson.data(using: .utf8) ?? Data())) ?? []

        return Bookmark(
            id: id,
            tweetId: tweetId,
            authorHandle: authorHandle,
            authorName: authorName,
            authorAvatar: authorAvatar,
            content: content,
            postedAt: parseDate(postedAtStr) ?? Date(),
            bookmarkedAt: parseDate(bookmarkedAtStr) ?? Date(),
            url: url,
            mediaUrls: mediaUrls,
            summary: summary,
            categories: categories,
            isFavorite: isFavorite,
            folderId: folderId,
            tags: [],
            createdAt: parseDate(createdAtStr) ?? Date()
        )
    }

    private func parseDate(_ string: String) -> Date? {
        dateFormatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    func toggleFavorite(_ bookmarkId: String) {
        executeSQL("UPDATE bookmarks SET is_favorite = NOT is_favorite WHERE id = '\(bookmarkId)'")
        loadStats()
        notifyDataChanged()
    }

    private func notifyDataChanged() {
        DispatchQueue.main.async {
            self.dataVersion += 1
        }
    }

    func setFolder(_ bookmarkId: String, folderId: String?) {
        if let folderId = folderId {
            executeSQL("UPDATE bookmarks SET folder_id = '\(folderId)' WHERE id = '\(bookmarkId)'")
        } else {
            executeSQL("UPDATE bookmarks SET folder_id = NULL WHERE id = '\(bookmarkId)'")
        }
        notifyDataChanged()
    }

    func deleteBookmark(_ bookmarkId: String) {
        executeSQL("DELETE FROM bookmarks WHERE id = '\(bookmarkId)'")
        loadStats()
        notifyDataChanged()
    }

    func updateSummary(_ bookmarkId: String, summary: String) {
        let escaped = summary.replacingOccurrences(of: "'", with: "''")
        executeSQL("UPDATE bookmarks SET summary = '\(escaped)' WHERE id = '\(bookmarkId)'")
        notifyDataChanged()
    }

    func getBookmarksWithoutSummary(limit: Int = 1000) -> [Bookmark] {
        let sql = "SELECT * FROM bookmarks WHERE summary IS NULL OR summary = '' LIMIT \(limit)"
        return queryBookmarks(sql)
    }

    // MARK: - Tags

    func loadTags() {
        var statement: OpaquePointer?
        var loadedTags: [Tag] = []

        let sql = "SELECT id, name, color, is_quick_tag, COALESCE(sort_order, 0), created_at FROM tags ORDER BY sort_order ASC, name ASC"

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let name = String(cString: sqlite3_column_text(statement, 1))
                let color = String(cString: sqlite3_column_text(statement, 2))
                let isQuickTag = sqlite3_column_int(statement, 3) == 1
                let sortOrder = Int(sqlite3_column_int(statement, 4))
                let createdAtStr = String(cString: sqlite3_column_text(statement, 5))

                let tag = Tag(
                    id: id,
                    name: name,
                    colorHex: color,
                    isQuickTag: isQuickTag,
                    sortOrder: sortOrder,
                    createdAt: parseDate(createdAtStr) ?? Date()
                )
                loadedTags.append(tag)
            }
        }
        sqlite3_finalize(statement)

        DispatchQueue.main.async {
            self.tags = loadedTags
        }
    }

    func getTagsForBookmark(_ bookmarkId: String) -> [Tag] {
        var statement: OpaquePointer?
        var tagList: [Tag] = []

        let sql = """
        SELECT t.id, t.name, t.color, t.is_quick_tag, t.created_at
        FROM tags t
        JOIN bookmark_tags bt ON t.id = bt.tag_id
        WHERE bt.bookmark_id = ?
        """

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, bookmarkId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let name = String(cString: sqlite3_column_text(statement, 1))
                let color = String(cString: sqlite3_column_text(statement, 2))
                let isQuickTag = sqlite3_column_int(statement, 3) == 1
                let createdAtStr = String(cString: sqlite3_column_text(statement, 4))

                let tag = Tag(
                    id: id,
                    name: name,
                    colorHex: color,
                    isQuickTag: isQuickTag,
                    createdAt: parseDate(createdAtStr) ?? Date()
                )
                tagList.append(tag)
            }
        }
        sqlite3_finalize(statement)

        return tagList
    }

    func addTagToBookmark(_ bookmarkId: String, tagId: String) {
        executeSQL("INSERT OR IGNORE INTO bookmark_tags (bookmark_id, tag_id) VALUES ('\(bookmarkId)', '\(tagId)')")
        notifyDataChanged()
    }

    func removeTagFromBookmark(_ bookmarkId: String, tagId: String) {
        executeSQL("DELETE FROM bookmark_tags WHERE bookmark_id = '\(bookmarkId)' AND tag_id = '\(tagId)'")
        notifyDataChanged()
    }

    func createTag(name: String, color: String, isQuickTag: Bool = false) {
        let id = UUID().uuidString
        executeSQL("INSERT INTO tags (id, name, color, is_quick_tag) VALUES ('\(id)', '\(name)', '\(color)', \(isQuickTag ? 1 : 0))")
        loadTags()
    }

    func deleteTag(_ tagId: String) {
        executeSQL("DELETE FROM tags WHERE id = '\(tagId)'")
        loadTags()
    }

    func renameTag(_ tagId: String, newName: String) {
        let escaped = newName.replacingOccurrences(of: "'", with: "''")
        executeSQL("UPDATE tags SET name = '\(escaped)' WHERE id = '\(tagId)'")
        loadTags()
    }

    // MARK: - Folders

    func loadFolders() {
        var statement: OpaquePointer?
        var loadedFolders: [Folder] = []

        let sql = "SELECT id, name, color, icon, sort_order, created_at FROM folders ORDER BY sort_order ASC, name ASC"

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let name = String(cString: sqlite3_column_text(statement, 1))
                let color = String(cString: sqlite3_column_text(statement, 2))
                let icon = String(cString: sqlite3_column_text(statement, 3))
                let sortOrder = Int(sqlite3_column_int(statement, 4))
                let createdAtStr = String(cString: sqlite3_column_text(statement, 5))

                let folder = Folder(
                    id: id,
                    name: name,
                    colorHex: color,
                    icon: icon,
                    sortOrder: sortOrder,
                    createdAt: parseDate(createdAtStr) ?? Date()
                )
                loadedFolders.append(folder)
            }
        }
        sqlite3_finalize(statement)

        DispatchQueue.main.async {
            self.folders = loadedFolders
        }
    }

    func createFolder(name: String, color: String = "#6b7280") {
        let id = UUID().uuidString
        executeSQL("INSERT INTO folders (id, name, color) VALUES ('\(id)', '\(name)', '\(color)')")
        loadFolders()
    }

    func deleteFolder(_ folderId: String) {
        executeSQL("DELETE FROM folders WHERE id = '\(folderId)'")
        loadFolders()
    }

    func renameFolder(_ folderId: String, newName: String) {
        let escaped = newName.replacingOccurrences(of: "'", with: "''")
        executeSQL("UPDATE folders SET name = '\(escaped)' WHERE id = '\(folderId)'")
        loadFolders()
    }

    func reorderFolders(_ folderIds: [String]) {
        for (index, id) in folderIds.enumerated() {
            executeSQL("UPDATE folders SET sort_order = \(index) WHERE id = '\(id)'")
        }
        loadFolders()
    }

    func reorderTags(_ tagIds: [String]) {
        for (index, id) in tagIds.enumerated() {
            executeSQL("UPDATE tags SET sort_order = \(index) WHERE id = '\(id)'")
        }
        loadTags()
    }

    // MARK: - Authors

    func loadAuthors() {
        var statement: OpaquePointer?
        var authorList: [String] = []

        let sql = "SELECT author_handle FROM bookmarks GROUP BY author_handle ORDER BY COUNT(*) DESC"

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let author = String(cString: sqlite3_column_text(statement, 0))
                authorList.append(author)
            }
        }
        sqlite3_finalize(statement)

        DispatchQueue.main.async {
            self.authors = authorList
        }
    }

    // MARK: - Stats

    func loadStats() {
        let total = queryScalar("SELECT COUNT(*) FROM bookmarks") ?? 0
        let favorites = queryScalar("SELECT COUNT(*) FROM bookmarks WHERE is_favorite = 1") ?? 0
        let authors = queryScalar("SELECT COUNT(DISTINCT author_handle) FROM bookmarks") ?? 0
        let unprocessed = queryScalar("SELECT COUNT(*) FROM bookmarks WHERE summary IS NULL OR summary = ''") ?? 0

        DispatchQueue.main.async {
            self.stats = BookmarkStats(total: total, favorites: favorites, authors: authors, unprocessed: unprocessed)
        }
    }

    // MARK: - Smart Collections

    func getSmartCollectionBookmarks(_ type: SmartCollectionType, author: String? = nil, query: String? = nil) -> [Bookmark] {
        var conditions: [String] = []

        // Smart collection condition
        switch type {
        case .withMedia:
            conditions.append("media_urls LIKE '%http%'")
        case .textOnly:
            conditions.append("(media_urls NOT LIKE '%http%' OR media_urls IS NULL OR media_urls = '' OR media_urls = '[]')")
        }

        // Author filter
        if let author = author, !author.isEmpty {
            conditions.append("author_handle = '\(author.replacingOccurrences(of: "'", with: "''"))'")
        }

        // Search query filter
        if let query = query, !query.isEmpty {
            let escaped = query.replacingOccurrences(of: "'", with: "''")
            conditions.append("(content LIKE '%\(escaped)%' OR author_handle LIKE '%\(escaped)%' OR author_name LIKE '%\(escaped)%')")
        }

        let whereClause = conditions.joined(separator: " AND ")
        let sql = "SELECT * FROM bookmarks WHERE \(whereClause) ORDER BY bookmarked_at DESC"

        print("🔍 Smart Collection SQL: \(sql)")
        let results = queryBookmarks(sql)
        print("🔍 Found \(results.count) bookmarks")
        return results
    }

    // MARK: - Bulk Operations

    func moveBookmarksToFolder(_ bookmarkIds: [String], folderId: String?) {
        for id in bookmarkIds {
            setFolder(id, folderId: folderId)
        }
    }

    func deleteBookmarks(_ bookmarkIds: [String]) {
        for id in bookmarkIds {
            executeSQL("DELETE FROM bookmarks WHERE id = '\(id)'")
        }
        loadStats()
    }

    func deleteAllBookmarks() {
        executeSQL("DELETE FROM bookmark_tags")
        executeSQL("DELETE FROM bookmarks")
        loadData()
        DispatchQueue.main.async {
            self.dataVersion += 1
        }
    }

    func addTagToBookmarks(_ bookmarkIds: [String], tagId: String) {
        for id in bookmarkIds {
            addTagToBookmark(id, tagId: tagId)
        }
    }

    // MARK: - Remove Duplicates

    func removeDuplicates() -> Int {
        // Find duplicate tweet_ids and keep only the one with most data (has tags/folder/favorite)
        let sql = """
        DELETE FROM bookmarks WHERE id NOT IN (
            SELECT MIN(id) FROM bookmarks GROUP BY tweet_id
        )
        """
        executeSQL(sql)

        let countSql = "SELECT changes()"
        var statement: OpaquePointer?
        var removed = 0
        if sqlite3_prepare_v2(db, countSql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                removed = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)

        if removed > 0 {
            loadData()
            notifyDataChanged()
        }

        print("Removed \(removed) duplicate bookmarks")
        return removed
    }

    // MARK: - Import

    func importFromPath(_ path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }

        var sourceDb: OpaquePointer?
        if sqlite3_open(path, &sourceDb) == SQLITE_OK {
            // Copy all data from source to destination
            let tables = ["bookmarks", "tags", "folders", "bookmark_tags"]
            for table in tables {
                copyTable(from: sourceDb, to: db, tableName: table)
            }
            sqlite3_close(sourceDb)
        }

        loadData()
    }

    struct ImportResult {
        let newCount: Int
        let updatedCount: Int
        var total: Int { newCount + updatedCount }
    }

    func importBookmarks(_ bookmarks: [ImportedBookmark]) -> ImportResult {
        var newCount = 0
        var updatedCount = 0
        let now = ISO8601DateFormatter().string(from: Date())

        print("📦 Starting import of \(bookmarks.count) bookmarks...")

        for bookmark in bookmarks {
            let mediaUrlsJson = (try? JSONEncoder().encode(bookmark.media_urls ?? [])).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            let bookmarkedAt = bookmark.bookmarked_at ?? now

            // Check if tweet already exists
            var existingId: String?
            let checkSql = "SELECT id FROM bookmarks WHERE tweet_id = ?"
            var checkStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, checkSql, -1, &checkStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(checkStmt, 1, bookmark.tweet_id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                if sqlite3_step(checkStmt) == SQLITE_ROW {
                    existingId = String(cString: sqlite3_column_text(checkStmt, 0))
                }
            }
            sqlite3_finalize(checkStmt)

            if let existingId = existingId {
                // Update existing bookmark (preserve tags, folders, favorites)
                let updateSql = """
                UPDATE bookmarks SET
                    content = ?,
                    author_name = ?,
                    author_avatar = ?,
                    media_urls = ?
                WHERE id = ?
                """

                var updateStmt: OpaquePointer?
                if sqlite3_prepare_v2(db, updateSql, -1, &updateStmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(updateStmt, 1, bookmark.content, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                    sqlite3_bind_text(updateStmt, 2, bookmark.author_name, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                    if let avatar = bookmark.author_avatar {
                        sqlite3_bind_text(updateStmt, 3, avatar, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                    } else {
                        sqlite3_bind_null(updateStmt, 3)
                    }
                    sqlite3_bind_text(updateStmt, 4, mediaUrlsJson, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                    sqlite3_bind_text(updateStmt, 5, existingId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

                    if sqlite3_step(updateStmt) == SQLITE_DONE {
                        updatedCount += 1
                    }
                }
                sqlite3_finalize(updateStmt)
            } else {
                // Insert new bookmark
                let id = UUID().uuidString
                let insertSql = """
                INSERT INTO bookmarks
                (id, tweet_id, author_handle, author_name, author_avatar, content, posted_at, bookmarked_at, url, media_urls)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """

                var insertStmt: OpaquePointer?
                if sqlite3_prepare_v2(db, insertSql, -1, &insertStmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(insertStmt, 1, id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                    sqlite3_bind_text(insertStmt, 2, bookmark.tweet_id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                    sqlite3_bind_text(insertStmt, 3, bookmark.author_handle, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                    sqlite3_bind_text(insertStmt, 4, bookmark.author_name, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                    if let avatar = bookmark.author_avatar {
                        sqlite3_bind_text(insertStmt, 5, avatar, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                    } else {
                        sqlite3_bind_null(insertStmt, 5)
                    }
                    sqlite3_bind_text(insertStmt, 6, bookmark.content, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                    sqlite3_bind_text(insertStmt, 7, bookmark.posted_at, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                    sqlite3_bind_text(insertStmt, 8, bookmarkedAt, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                    sqlite3_bind_text(insertStmt, 9, bookmark.url, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                    sqlite3_bind_text(insertStmt, 10, mediaUrlsJson, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

                    if sqlite3_step(insertStmt) == SQLITE_DONE {
                        newCount += 1
                    }
                }
                sqlite3_finalize(insertStmt)
            }
        }

        print("✅ Import complete: \(newCount) new, \(updatedCount) updated (total processed: \(newCount + updatedCount))")
        loadData()
        notifyDataChanged()
        return ImportResult(newCount: newCount, updatedCount: updatedCount)
    }

    func importFromJSONFile(_ path: String) {
        _ = importFromJSONFileWithCount(path)
    }

    func importFromJSONFileWithCount(_ path: String) -> ImportResult {
        guard let data = FileManager.default.contents(atPath: path),
              let bookmarks = try? JSONDecoder().decode([ImportedBookmark].self, from: data) else {
            return ImportResult(newCount: 0, updatedCount: 0)
        }
        return importBookmarks(bookmarks)
    }

    private func copyTable(from sourceDb: OpaquePointer?, to destDb: OpaquePointer?, tableName: String) {
        var statement: OpaquePointer?
        let sql = "SELECT * FROM \(tableName)"

        if sqlite3_prepare_v2(sourceDb, sql, -1, &statement, nil) == SQLITE_OK {
            let columnCount = sqlite3_column_count(statement)

            while sqlite3_step(statement) == SQLITE_ROW {
                var values: [String] = []
                for i in 0..<columnCount {
                    if let text = sqlite3_column_text(statement, i) {
                        values.append("'\(String(cString: text).replacingOccurrences(of: "'", with: "''"))'")
                    } else {
                        values.append("NULL")
                    }
                }

                let insertSql = "INSERT OR REPLACE INTO \(tableName) VALUES (\(values.joined(separator: ", ")))"
                executeSQL(insertSql)
            }
        }
        sqlite3_finalize(statement)
    }

    // MARK: - Embeddings

    struct StoredEmbedding {
        let bookmarkId: String
        let vector: [Float]
        let model: String
    }

    func saveEmbedding(bookmarkId: String, embedding: Data, model: String) {
        let sql = "INSERT OR REPLACE INTO bookmark_embeddings (bookmark_id, embedding, embedding_model) VALUES (?, ?, ?)"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, bookmarkId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_blob(statement, 2, (embedding as NSData).bytes, Int32(embedding.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 3, model, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }

    func loadAllEmbeddings() -> [StoredEmbedding] {
        var embeddings: [StoredEmbedding] = []
        var statement: OpaquePointer?

        let sql = "SELECT bookmark_id, embedding, embedding_model FROM bookmark_embeddings"

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let bookmarkId = String(cString: sqlite3_column_text(statement, 0))
                let blobPointer = sqlite3_column_blob(statement, 1)
                let blobSize = Int(sqlite3_column_bytes(statement, 1))
                let model = String(cString: sqlite3_column_text(statement, 2))

                if let blobPointer = blobPointer {
                    let data = Data(bytes: blobPointer, count: blobSize)
                    let vector = EmbeddingService.shared.dataToVector(data)
                    embeddings.append(StoredEmbedding(bookmarkId: bookmarkId, vector: vector, model: model))
                }
            }
        }
        sqlite3_finalize(statement)

        return embeddings
    }

    func getBookmarksWithoutEmbedding() -> [Bookmark] {
        let sql = """
        SELECT b.* FROM bookmarks b
        LEFT JOIN bookmark_embeddings e ON b.id = e.bookmark_id
        WHERE e.bookmark_id IS NULL
        """
        return queryBookmarks(sql)
    }

    func getEmbeddingCount() -> Int {
        return queryScalar("SELECT COUNT(*) FROM bookmark_embeddings") ?? 0
    }

    func hasEmbedding(bookmarkId: String) -> Bool {
        let count = queryScalar("SELECT COUNT(*) FROM bookmark_embeddings WHERE bookmark_id = '\(bookmarkId)'") ?? 0
        return count > 0
    }

    // MARK: - Chat Messages

    struct ChatMessage {
        let id: String
        let role: String
        let content: String
        let contextBookmarkIds: [String]
        let createdAt: Date
    }

    func saveChatMessage(id: String, role: String, content: String, contextBookmarkIds: [String]?) {
        let contextJson = contextBookmarkIds.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
        let escapedContent = content.replacingOccurrences(of: "'", with: "''")

        var sql: String
        if let contextJson = contextJson {
            let escapedContext = contextJson.replacingOccurrences(of: "'", with: "''")
            sql = "INSERT INTO chat_messages (id, role, content, context_bookmark_ids) VALUES ('\(id)', '\(role)', '\(escapedContent)', '\(escapedContext)')"
        } else {
            sql = "INSERT INTO chat_messages (id, role, content) VALUES ('\(id)', '\(role)', '\(escapedContent)')"
        }

        executeSQL(sql)
    }

    func loadChatHistory(limit: Int = 50) -> [ChatMessage] {
        var messages: [ChatMessage] = []
        var statement: OpaquePointer?

        let sql = "SELECT id, role, content, context_bookmark_ids, created_at FROM chat_messages ORDER BY created_at DESC LIMIT \(limit)"

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let role = String(cString: sqlite3_column_text(statement, 1))
                let content = String(cString: sqlite3_column_text(statement, 2))
                let contextJson = sqlite3_column_text(statement, 3).map { String(cString: $0) }
                let createdAtStr = String(cString: sqlite3_column_text(statement, 4))

                var contextIds: [String] = []
                if let json = contextJson, let data = json.data(using: .utf8) {
                    contextIds = (try? JSONDecoder().decode([String].self, from: data)) ?? []
                }

                messages.append(ChatMessage(
                    id: id,
                    role: role,
                    content: content,
                    contextBookmarkIds: contextIds,
                    createdAt: parseDate(createdAtStr) ?? Date()
                ))
            }
        }
        sqlite3_finalize(statement)

        return messages.reversed()  // Return in chronological order
    }

    func clearChatHistory() {
        executeSQL("DELETE FROM chat_messages")
    }

    // MARK: - Helpers

    private func executeSQL(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let errMsg = errMsg {
                print("SQL Error: \(String(cString: errMsg))")
                sqlite3_free(errMsg)
            }
        }
    }

    private func queryScalar(_ sql: String) -> Int? {
        var statement: OpaquePointer?
        var result: Int?

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                result = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)

        return result
    }

    deinit {
        sqlite3_close(db)
    }
}
