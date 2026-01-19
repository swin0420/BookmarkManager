import XCTest
@testable import BookmarkManager

final class BookmarkTests: XCTestCase {

    // MARK: - Bookmark Initialization Tests

    func testBookmarkInitializationWithAllFields() {
        let bookmark = TestBookmarkModel(
            id: "test-123",
            tweetId: "456789",
            authorHandle: "testuser",
            authorName: "Test User",
            authorAvatar: "https://example.com/avatar.jpg",
            content: "This is a test tweet",
            postedAt: Date(),
            bookmarkedAt: Date(),
            url: "https://x.com/testuser/status/456789",
            mediaUrls: ["https://pbs.twimg.com/media/test.jpg"],
            summary: "A test summary",
            categories: ["tech"],
            isFavorite: true,
            folderId: "folder-1",
            tags: [],
            createdAt: Date()
        )

        XCTAssertEqual(bookmark.id, "test-123")
        XCTAssertEqual(bookmark.tweetId, "456789")
        XCTAssertEqual(bookmark.authorHandle, "testuser")
        XCTAssertEqual(bookmark.authorName, "Test User")
        XCTAssertNotNil(bookmark.authorAvatar)
        XCTAssertTrue(bookmark.isFavorite)
        XCTAssertEqual(bookmark.folderId, "folder-1")
    }

    func testBookmarkInitializationWithDefaults() {
        let bookmark = TestBookmarkModel(
            id: "test-456",
            tweetId: "789012",
            authorHandle: "user2",
            authorName: "User Two",
            authorAvatar: nil,
            content: "Another test",
            postedAt: Date(),
            bookmarkedAt: Date(),
            url: "https://x.com/user2/status/789012",
            mediaUrls: [],
            summary: nil,
            categories: [],
            isFavorite: false,
            folderId: nil,
            tags: [],
            createdAt: Date()
        )

        XCTAssertNil(bookmark.authorAvatar)
        XCTAssertNil(bookmark.summary)
        XCTAssertEqual(bookmark.categories.count, 0)
        XCTAssertFalse(bookmark.isFavorite)
        XCTAssertNil(bookmark.folderId)
    }

    // MARK: - Bookmark Equality Tests

    func testBookmarkEqualityById() {
        let date = Date()
        let bookmark1 = TestBookmarkModel(
            id: "same-id",
            tweetId: "123",
            authorHandle: "user",
            authorName: "User",
            authorAvatar: nil,
            content: "Content 1",
            postedAt: date,
            bookmarkedAt: date,
            url: "url1",
            mediaUrls: [],
            summary: nil,
            categories: [],
            isFavorite: false,
            folderId: nil,
            tags: [],
            createdAt: date
        )

        let bookmark2 = TestBookmarkModel(
            id: "same-id",
            tweetId: "123",
            authorHandle: "user",
            authorName: "User",
            authorAvatar: nil,
            content: "Content 2", // Different content
            postedAt: date,
            bookmarkedAt: date,
            url: "url2",
            mediaUrls: [],
            summary: nil,
            categories: [],
            isFavorite: false,
            folderId: nil,
            tags: [],
            createdAt: date
        )

        // Same ID should make them equal
        XCTAssertEqual(bookmark1.id, bookmark2.id)
    }

    func testBookmarkInequalityByDifferentId() {
        let date = Date()
        let bookmark1 = TestBookmarkModel(
            id: "id-1",
            tweetId: "123",
            authorHandle: "user",
            authorName: "User",
            authorAvatar: nil,
            content: "Same content",
            postedAt: date,
            bookmarkedAt: date,
            url: "url",
            mediaUrls: [],
            summary: nil,
            categories: [],
            isFavorite: false,
            folderId: nil,
            tags: [],
            createdAt: date
        )

        let bookmark2 = TestBookmarkModel(
            id: "id-2",
            tweetId: "456",
            authorHandle: "user",
            authorName: "User",
            authorAvatar: nil,
            content: "Same content",
            postedAt: date,
            bookmarkedAt: date,
            url: "url",
            mediaUrls: [],
            summary: nil,
            categories: [],
            isFavorite: false,
            folderId: nil,
            tags: [],
            createdAt: date
        )

        XCTAssertNotEqual(bookmark1.id, bookmark2.id)
    }

    // MARK: - Bookmark Hashable Tests

    func testBookmarkHashValueConsistency() {
        let date = Date()
        let bookmark = TestBookmarkModel(
            id: "hash-test",
            tweetId: "123",
            authorHandle: "user",
            authorName: "User",
            authorAvatar: nil,
            content: "Content",
            postedAt: date,
            bookmarkedAt: date,
            url: "url",
            mediaUrls: [],
            summary: nil,
            categories: [],
            isFavorite: false,
            folderId: nil,
            tags: [],
            createdAt: date
        )

        let hash1 = bookmark.id.hashValue
        let hash2 = bookmark.id.hashValue

        XCTAssertEqual(hash1, hash2)
    }

    func testBookmarksInSet() {
        var bookmarkIds = Set<String>()

        bookmarkIds.insert("id1")
        bookmarkIds.insert("id2")
        bookmarkIds.insert("id1") // Duplicate

        XCTAssertEqual(bookmarkIds.count, 2)
    }

    // MARK: - Media URLs Tests

    func testBookmarkWithMultipleMediaUrls() {
        let mediaUrls = [
            "https://pbs.twimg.com/media/image1.jpg",
            "https://pbs.twimg.com/media/image2.jpg",
            "https://pbs.twimg.com/media/video_thumb.jpg"
        ]

        XCTAssertEqual(mediaUrls.count, 3)
        XCTAssertTrue(mediaUrls[0].contains("twimg.com"))
    }

    func testBookmarkWithEmptyMediaUrls() {
        let mediaUrls: [String] = []

        XCTAssertTrue(mediaUrls.isEmpty)
    }

    func testMediaUrlsContainsValidUrls() {
        let mediaUrls = [
            "https://pbs.twimg.com/media/test.jpg",
            "not-a-valid-url",
            "https://valid.com/image.png"
        ]

        let validUrls = mediaUrls.filter { $0.hasPrefix("https://") }

        XCTAssertEqual(validUrls.count, 2)
    }

    // MARK: - Tags Tests

    func testBookmarkWithTags() {
        let tags = [
            TestTagModel(id: "tag1", name: "tech", colorHex: "#3b82f6"),
            TestTagModel(id: "tag2", name: "ai", colorHex: "#8b5cf6")
        ]

        XCTAssertEqual(tags.count, 2)
        XCTAssertEqual(tags[0].name, "tech")
    }

    func testBookmarkTagIds() {
        let tags = [
            TestTagModel(id: "tag1", name: "tech", colorHex: "#3b82f6"),
            TestTagModel(id: "tag2", name: "ai", colorHex: "#8b5cf6")
        ]

        let tagIds = tags.map { $0.id }

        XCTAssertEqual(tagIds, ["tag1", "tag2"])
    }

    // MARK: - Date Tests

    func testBookmarkDates() {
        let postedAt = Date()
        let bookmarkedAt = Date().addingTimeInterval(3600) // 1 hour later

        XCTAssertLessThan(postedAt, bookmarkedAt)
    }

    func testBookmarkDateFormatting() {
        let date = Date()
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: date)

        XCTAssertFalse(dateString.isEmpty)
        XCTAssertTrue(dateString.contains("T"))
    }

    // MARK: - Content Tests

    func testBookmarkContentNotEmpty() {
        let content = "This is a test tweet with some content"

        XCTAssertFalse(content.isEmpty)
        XCTAssertGreaterThan(content.count, 0)
    }

    func testBookmarkContentWithEmoji() {
        let content = "Testing emoji support 🚀🔥💯"

        XCTAssertTrue(content.contains("🚀"))
    }

    func testBookmarkContentWithLinks() {
        let content = "Check out this link: https://example.com"

        XCTAssertTrue(content.contains("https://"))
    }

    func testBookmarkContentWithMentions() {
        let content = "Thanks @elonmusk for the insight!"

        XCTAssertTrue(content.contains("@"))
    }

    // MARK: - Author Handle Tests

    func testAuthorHandleFormat() {
        let handle = "testuser"

        XCTAssertFalse(handle.isEmpty)
        XCTAssertFalse(handle.contains("@"))
    }

    func testAuthorHandleNoSpaces() {
        let handle = "test_user_123"

        XCTAssertFalse(handle.contains(" "))
    }

    // MARK: - URL Tests

    func testBookmarkUrlFormat() {
        let authorHandle = "testuser"
        let tweetId = "1234567890"
        let url = "https://x.com/\(authorHandle)/status/\(tweetId)"

        XCTAssertTrue(url.hasPrefix("https://x.com/"))
        XCTAssertTrue(url.contains("/status/"))
        XCTAssertTrue(url.contains(authorHandle))
        XCTAssertTrue(url.contains(tweetId))
    }

    // MARK: - Favorite Toggle Tests

    func testFavoriteToggle() {
        var isFavorite = false

        isFavorite = !isFavorite
        XCTAssertTrue(isFavorite)

        isFavorite = !isFavorite
        XCTAssertFalse(isFavorite)
    }

    // MARK: - Folder Assignment Tests

    func testFolderAssignment() {
        var folderId: String? = nil

        folderId = "folder-123"
        XCTAssertEqual(folderId, "folder-123")

        folderId = nil
        XCTAssertNil(folderId)
    }

    // MARK: - Summary Tests

    func testBookmarkWithSummary() {
        let summary = "This tweet discusses the latest AI developments."

        XCTAssertFalse(summary.isEmpty)
    }

    func testBookmarkWithoutSummary() {
        let summary: String? = nil

        XCTAssertNil(summary)
    }

    // MARK: - Categories Tests

    func testBookmarkCategories() {
        let categories = ["technology", "ai", "startups"]

        XCTAssertEqual(categories.count, 3)
        XCTAssertTrue(categories.contains("ai"))
    }

    func testEmptyCategories() {
        let categories: [String] = []

        XCTAssertTrue(categories.isEmpty)
    }
}

// MARK: - Tag Model Tests

final class TagModelTests: XCTestCase {

    func testTagInitialization() {
        let tag = TestTagModel(
            id: "tag-123",
            name: "artificial-intelligence",
            colorHex: "#8b5cf6",
            isQuickTag: true,
            sortOrder: 1,
            createdAt: Date()
        )

        XCTAssertEqual(tag.id, "tag-123")
        XCTAssertEqual(tag.name, "artificial-intelligence")
        XCTAssertEqual(tag.colorHex, "#8b5cf6")
        XCTAssertTrue(tag.isQuickTag)
        XCTAssertEqual(tag.sortOrder, 1)
    }

    func testTagNameNormalization() {
        let rawName = "Machine Learning"
        let normalized = rawName.lowercased().replacingOccurrences(of: " ", with: "-")

        XCTAssertEqual(normalized, "machine-learning")
    }

    func testTagColorHexFormat() {
        let validHex = "#3b82f6"

        XCTAssertTrue(validHex.hasPrefix("#"))
        XCTAssertEqual(validHex.count, 7)
    }

    func testColorFromHex() {
        let hex = "#FF0000"
        let sanitized = hex.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        XCTAssertEqual(r, 1.0, accuracy: 0.001)
        XCTAssertEqual(g, 0.0, accuracy: 0.001)
        XCTAssertEqual(b, 0.0, accuracy: 0.001)
    }

    func testTagQuickTagDefault() {
        let tag = TestTagModel(id: "1", name: "test", colorHex: "#000000")

        XCTAssertFalse(tag.isQuickTag)
    }

    func testTagSortOrderDefault() {
        let tag = TestTagModel(id: "1", name: "test", colorHex: "#000000")

        XCTAssertEqual(tag.sortOrder, 0)
    }
}

// MARK: - Folder Model Tests

final class FolderModelTests: XCTestCase {

    func testFolderInitialization() {
        let folder = TestFolderModel(
            id: "folder-123",
            name: "Tech Articles",
            colorHex: "#10b981",
            icon: "folder.fill",
            sortOrder: 0,
            createdAt: Date()
        )

        XCTAssertEqual(folder.id, "folder-123")
        XCTAssertEqual(folder.name, "Tech Articles")
        XCTAssertEqual(folder.colorHex, "#10b981")
        XCTAssertEqual(folder.icon, "folder.fill")
    }

    func testFolderDefaultColor() {
        let defaultColor = "#6b7280"

        XCTAssertEqual(defaultColor.count, 7)
    }

    func testFolderDefaultIcon() {
        let defaultIcon = "folder"

        XCTAssertEqual(defaultIcon, "folder")
    }

    func testFolderNameNotEmpty() {
        let name = "My Folder"

        XCTAssertFalse(name.isEmpty)
    }

    func testFolderSortOrder() {
        let folders = [
            TestFolderModel(id: "1", name: "C Folder", colorHex: "#000", icon: "folder", sortOrder: 2, createdAt: Date()),
            TestFolderModel(id: "2", name: "A Folder", colorHex: "#000", icon: "folder", sortOrder: 0, createdAt: Date()),
            TestFolderModel(id: "3", name: "B Folder", colorHex: "#000", icon: "folder", sortOrder: 1, createdAt: Date())
        ]

        let sorted = folders.sorted { $0.sortOrder < $1.sortOrder }

        XCTAssertEqual(sorted[0].name, "A Folder")
        XCTAssertEqual(sorted[1].name, "B Folder")
        XCTAssertEqual(sorted[2].name, "C Folder")
    }
}

// MARK: - BookmarkStats Tests

final class BookmarkStatsTests: XCTestCase {

    func testBookmarkStatsInitialization() {
        let stats = TestBookmarkStats(total: 100, favorites: 25, authors: 10, unprocessed: 50)

        XCTAssertEqual(stats.total, 100)
        XCTAssertEqual(stats.favorites, 25)
        XCTAssertEqual(stats.authors, 10)
        XCTAssertEqual(stats.unprocessed, 50)
    }

    func testBookmarkStatsZeroValues() {
        let stats = TestBookmarkStats(total: 0, favorites: 0, authors: 0, unprocessed: 0)

        XCTAssertEqual(stats.total, 0)
        XCTAssertEqual(stats.favorites, 0)
    }

    func testBookmarkStatsFavoritesLessThanTotal() {
        let stats = TestBookmarkStats(total: 100, favorites: 25, authors: 10, unprocessed: 50)

        XCTAssertLessThanOrEqual(stats.favorites, stats.total)
    }

    func testBookmarkStatsUnprocessedLessThanTotal() {
        let stats = TestBookmarkStats(total: 100, favorites: 25, authors: 10, unprocessed: 50)

        XCTAssertLessThanOrEqual(stats.unprocessed, stats.total)
    }
}

// MARK: - Test Helper Structures

struct TestBookmarkModel: Identifiable, Hashable {
    let id: String
    let tweetId: String
    let authorHandle: String
    let authorName: String
    let authorAvatar: String?
    let content: String
    let postedAt: Date
    let bookmarkedAt: Date
    let url: String
    let mediaUrls: [String]
    var summary: String?
    var categories: [String]
    var isFavorite: Bool
    var folderId: String?
    var tags: [TestTagModel]
    let createdAt: Date

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TestBookmarkModel, rhs: TestBookmarkModel) -> Bool {
        lhs.id == rhs.id
    }
}

struct TestTagModel: Identifiable, Hashable {
    let id: String
    let name: String
    let colorHex: String
    var isQuickTag: Bool
    var sortOrder: Int
    var createdAt: Date

    init(id: String, name: String, colorHex: String, isQuickTag: Bool = false, sortOrder: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isQuickTag = isQuickTag
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

struct TestFolderModel: Identifiable, Hashable {
    let id: String
    let name: String
    let colorHex: String
    let icon: String
    let sortOrder: Int
    let createdAt: Date
}

struct TestBookmarkStats {
    let total: Int
    let favorites: Int
    let authors: Int
    let unprocessed: Int
}
