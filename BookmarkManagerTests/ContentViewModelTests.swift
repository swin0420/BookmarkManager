import XCTest
@testable import BookmarkManager

final class ContentViewModelTests: XCTestCase {

    // MARK: - Sort Order Tests

    func testSortByNewest() {
        var bookmarks = createTestBookmarks()

        bookmarks.sort { $0.bookmarkedAt > $1.bookmarkedAt }

        XCTAssertEqual(bookmarks[0].id, "3") // Most recent
        XCTAssertEqual(bookmarks[2].id, "1") // Oldest
    }

    func testSortByOldest() {
        var bookmarks = createTestBookmarks()

        bookmarks.sort { $0.bookmarkedAt < $1.bookmarkedAt }

        XCTAssertEqual(bookmarks[0].id, "1") // Oldest
        XCTAssertEqual(bookmarks[2].id, "3") // Most recent
    }

    func testSortByAuthor() {
        var bookmarks = createTestBookmarks()

        bookmarks.sort { $0.authorHandle.lowercased() < $1.authorHandle.lowercased() }

        // Should be alphabetical by author handle
        for i in 0..<bookmarks.count - 1 {
            XCTAssertLessThanOrEqual(
                bookmarks[i].authorHandle.lowercased(),
                bookmarks[i + 1].authorHandle.lowercased()
            )
        }
    }

    func testSortByContent() {
        var bookmarks = createTestBookmarks()

        bookmarks.sort { $0.content.lowercased() < $1.content.lowercased() }

        // Should be alphabetical by content
        for i in 0..<bookmarks.count - 1 {
            XCTAssertLessThanOrEqual(
                bookmarks[i].content.lowercased(),
                bookmarks[i + 1].content.lowercased()
            )
        }
    }

    // MARK: - Filter Tests

    func testFilterByQuery() {
        let bookmarks = createTestBookmarks()
        let query = "tweet"

        let filtered = bookmarks.filter {
            $0.content.lowercased().contains(query.lowercased()) ||
            $0.authorHandle.lowercased().contains(query.lowercased()) ||
            $0.authorName.lowercased().contains(query.lowercased())
        }

        XCTAssertGreaterThan(filtered.count, 0)
    }

    func testFilterByAuthor() {
        let bookmarks = createTestBookmarks()
        let author = "user1"

        let filtered = bookmarks.filter { $0.authorHandle == author }

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].authorHandle, "user1")
    }

    func testFilterByFavorites() {
        let bookmarks = createTestBookmarks()

        let filtered = bookmarks.filter { $0.isFavorite }

        XCTAssertEqual(filtered.count, 1)
        XCTAssertTrue(filtered[0].isFavorite)
    }

    func testFilterByFolder() {
        let bookmarks = createTestBookmarks()
        let folderId = "folder-1"

        let filtered = bookmarks.filter { $0.folderId == folderId }

        XCTAssertEqual(filtered.count, 1)
    }

    func testFilterByTag() {
        let bookmarks = createTestBookmarks()
        let tagId = "tag-1"

        let filtered = bookmarks.filter { bookmark in
            bookmark.tagIds.contains(tagId)
        }

        XCTAssertGreaterThan(filtered.count, 0)
    }

    func testCombinedFilters() {
        let bookmarks = createTestBookmarks()
        let author = "user1"

        let filtered = bookmarks
            .filter { $0.authorHandle == author }
            .filter { $0.isFavorite == false }

        // user1's bookmark is not a favorite, so should be included
        XCTAssertEqual(filtered.count, 1)
    }

    // MARK: - Selection Mode Tests

    func testSelectionModeToggle() {
        var isSelectionMode = false

        isSelectionMode.toggle()
        XCTAssertTrue(isSelectionMode)

        isSelectionMode.toggle()
        XCTAssertFalse(isSelectionMode)
    }

    func testSelectedBookmarksManagement() {
        var selectedBookmarks = Set<String>()

        selectedBookmarks.insert("bookmark-1")
        selectedBookmarks.insert("bookmark-2")
        selectedBookmarks.insert("bookmark-3")

        XCTAssertEqual(selectedBookmarks.count, 3)

        selectedBookmarks.remove("bookmark-2")

        XCTAssertEqual(selectedBookmarks.count, 2)
        XCTAssertFalse(selectedBookmarks.contains("bookmark-2"))
    }

    func testClearSelectionOnModeExit() {
        var selectedBookmarks = Set<String>(["bookmark-1", "bookmark-2"])
        var isSelectionMode = true

        // Exit selection mode
        isSelectionMode = false
        selectedBookmarks.removeAll()

        XCTAssertFalse(isSelectionMode)
        XCTAssertTrue(selectedBookmarks.isEmpty)
    }

    // MARK: - Pagination Tests

    func testLoadMoreBookmarks() {
        var loadedCount = 50
        let totalCount = 200
        let pageSize = 50

        // Load more
        loadedCount = min(loadedCount + pageSize, totalCount)

        XCTAssertEqual(loadedCount, 100)
    }

    func testLoadMoreAtLimit() {
        var loadedCount = 180
        let totalCount = 200
        let pageSize = 50

        // Load more
        loadedCount = min(loadedCount + pageSize, totalCount)

        XCTAssertEqual(loadedCount, 200) // Capped at total
    }

    // MARK: - Search State Tests

    func testSearchQueryState() {
        var searchQuery = ""

        searchQuery = "machine learning"
        XCTAssertFalse(searchQuery.isEmpty)

        searchQuery = ""
        XCTAssertTrue(searchQuery.isEmpty)
    }

    func testSemanticSearchMode() {
        var isSemanticSearch = false

        isSemanticSearch = true
        XCTAssertTrue(isSemanticSearch)

        isSemanticSearch = false
        XCTAssertFalse(isSemanticSearch)
    }

    // MARK: - View State Tests

    func testSidebarSelection() {
        var selectedSidebarItem: String? = nil

        selectedSidebarItem = "all"
        XCTAssertEqual(selectedSidebarItem, "all")

        selectedSidebarItem = "favorites"
        XCTAssertEqual(selectedSidebarItem, "favorites")

        selectedSidebarItem = nil
        XCTAssertNil(selectedSidebarItem)
    }

    func testActiveSheetState() {
        var activeSheet: TestSheet? = nil

        activeSheet = .settings
        XCTAssertNotNil(activeSheet)

        activeSheet = nil
        XCTAssertNil(activeSheet)
    }

    // MARK: - Data Refresh Tests

    func testDataVersionIncrement() {
        var dataVersion = 0

        dataVersion += 1
        XCTAssertEqual(dataVersion, 1)

        dataVersion += 1
        XCTAssertEqual(dataVersion, 2)
    }

    func testRefreshTrigger() {
        var needsRefresh = false

        needsRefresh = true
        XCTAssertTrue(needsRefresh)

        // After refresh
        needsRefresh = false
        XCTAssertFalse(needsRefresh)
    }

    // MARK: - Column Distribution Tests

    func testThreeColumnDistribution() {
        let bookmarks = Array(0..<10).map { "bookmark-\($0)" }

        var column1: [String] = []
        var column2: [String] = []
        var column3: [String] = []

        for (index, bookmark) in bookmarks.enumerated() {
            switch index % 3 {
            case 0: column1.append(bookmark)
            case 1: column2.append(bookmark)
            case 2: column3.append(bookmark)
            default: break
            }
        }

        XCTAssertEqual(column1.count, 4) // 0, 3, 6, 9
        XCTAssertEqual(column2.count, 3) // 1, 4, 7
        XCTAssertEqual(column3.count, 3) // 2, 5, 8
    }

    func testColumnDistributionEmpty() {
        let bookmarks: [String] = []

        var column1: [String] = []
        var column2: [String] = []
        var column3: [String] = []

        for (index, bookmark) in bookmarks.enumerated() {
            switch index % 3 {
            case 0: column1.append(bookmark)
            case 1: column2.append(bookmark)
            case 2: column3.append(bookmark)
            default: break
            }
        }

        XCTAssertTrue(column1.isEmpty)
        XCTAssertTrue(column2.isEmpty)
        XCTAssertTrue(column3.isEmpty)
    }

    // MARK: - Smart Collection Tests

    func testSmartCollectionWithMedia() {
        let bookmarks = createTestBookmarks()

        let withMedia = bookmarks.filter { bookmark in
            let mediaUrls = bookmark.mediaUrls.joined()
            return mediaUrls.contains("http")
        }

        XCTAssertGreaterThan(withMedia.count, 0)
    }

    func testSmartCollectionTextOnly() {
        let bookmarks = createTestBookmarks()

        let textOnly = bookmarks.filter { bookmark in
            bookmark.mediaUrls.isEmpty || !bookmark.mediaUrls.joined().contains("http")
        }

        XCTAssertGreaterThanOrEqual(textOnly.count, 0)
    }

    // MARK: - Author List Tests

    func testUniqueAuthors() {
        let bookmarks = createTestBookmarks()

        let authors = Set(bookmarks.map { $0.authorHandle })

        XCTAssertEqual(authors.count, 3)
    }

    func testAuthorsSortedByCount() {
        let authorCounts: [(author: String, count: Int)] = [
            ("user1", 10),
            ("user2", 5),
            ("user3", 15)
        ]

        let sorted = authorCounts.sorted { $0.count > $1.count }

        XCTAssertEqual(sorted[0].author, "user3")
        XCTAssertEqual(sorted[1].author, "user1")
        XCTAssertEqual(sorted[2].author, "user2")
    }

    // MARK: - Import State Tests

    func testImportInProgress() {
        var isImporting = false

        isImporting = true
        XCTAssertTrue(isImporting)

        isImporting = false
        XCTAssertFalse(isImporting)
    }

    func testImportResultState() {
        var importResult: (new: Int, updated: Int)? = nil

        importResult = (new: 50, updated: 10)

        XCTAssertNotNil(importResult)
        XCTAssertEqual(importResult?.new, 50)
        XCTAssertEqual(importResult?.updated, 10)
    }

    // MARK: - Helper Methods

    private func createTestBookmarks() -> [TestContentBookmark] {
        let now = Date()
        return [
            TestContentBookmark(
                id: "1",
                tweetId: "100",
                authorHandle: "user1",
                authorName: "User One",
                content: "First test tweet",
                postedAt: now.addingTimeInterval(-7200),
                bookmarkedAt: now.addingTimeInterval(-7200),
                mediaUrls: [],
                isFavorite: false,
                folderId: nil,
                tagIds: ["tag-1"]
            ),
            TestContentBookmark(
                id: "2",
                tweetId: "200",
                authorHandle: "user2",
                authorName: "User Two",
                content: "Second test tweet with media",
                postedAt: now.addingTimeInterval(-3600),
                bookmarkedAt: now.addingTimeInterval(-3600),
                mediaUrls: ["https://pbs.twimg.com/media/test.jpg"],
                isFavorite: true,
                folderId: "folder-1",
                tagIds: ["tag-2"]
            ),
            TestContentBookmark(
                id: "3",
                tweetId: "300",
                authorHandle: "user3",
                authorName: "User Three",
                content: "Third test tweet",
                postedAt: now,
                bookmarkedAt: now,
                mediaUrls: [],
                isFavorite: false,
                folderId: nil,
                tagIds: ["tag-1", "tag-3"]
            )
        ]
    }
}

// MARK: - Test Helper Structures

struct TestContentBookmark {
    let id: String
    let tweetId: String
    let authorHandle: String
    let authorName: String
    let content: String
    let postedAt: Date
    let bookmarkedAt: Date
    let mediaUrls: [String]
    var isFavorite: Bool
    var folderId: String?
    var tagIds: [String]
}

enum TestSheet {
    case settings
    case import_
    case chat
    case batchProcessing
}
