import Foundation

struct Bookmark: Identifiable, Hashable {
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
    var tags: [Tag]
    let createdAt: Date

    init(
        id: String,
        tweetId: String,
        authorHandle: String,
        authorName: String,
        authorAvatar: String? = nil,
        content: String,
        postedAt: Date,
        bookmarkedAt: Date,
        url: String,
        mediaUrls: [String] = [],
        summary: String? = nil,
        categories: [String] = [],
        isFavorite: Bool = false,
        folderId: String? = nil,
        tags: [Tag] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.tweetId = tweetId
        self.authorHandle = authorHandle
        self.authorName = authorName
        self.authorAvatar = authorAvatar
        self.content = content
        self.postedAt = postedAt
        self.bookmarkedAt = bookmarkedAt
        self.url = url
        self.mediaUrls = mediaUrls
        self.summary = summary
        self.categories = categories
        self.isFavorite = isFavorite
        self.folderId = folderId
        self.tags = tags
        self.createdAt = createdAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Bookmark, rhs: Bookmark) -> Bool {
        lhs.id == rhs.id &&
        lhs.isFavorite == rhs.isFavorite &&
        lhs.folderId == rhs.folderId &&
        lhs.tags.map(\.id) == rhs.tags.map(\.id)
    }
}

struct BookmarkStats {
    let total: Int
    let favorites: Int
    let authors: Int
    let unprocessed: Int
}
