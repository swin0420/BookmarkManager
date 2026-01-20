import Foundation

class SemanticSearchService {
    static let shared = SemanticSearchService()

    private let embeddingService = EmbeddingService.shared
    private let dbManager = DatabaseManager.shared

    // Cache embeddings in memory to avoid repeated DB reads
    private var cachedEmbeddings: [DatabaseManager.StoredEmbedding]?
    private var cacheTimestamp: Date?
    private let cacheValiditySeconds: TimeInterval = 60  // Refresh cache every 60 seconds

    // Cache bookmarks for hybrid search
    private var cachedBookmarks: [String: Bookmark]?
    private var bookmarksCacheTimestamp: Date?

    // Hybrid search weights (semantic vs keyword)
    private let semanticWeight: Float = 0.6
    private let keywordWeight: Float = 0.4

    private init() {}

    // MARK: - Public API

    /// Check if semantic search is available
    var isAvailable: Bool {
        return embeddingService.isAvailable
    }

    /// Clear all caches (call after generating new embeddings or data changes)
    func clearCache() {
        cachedEmbeddings = nil
        cacheTimestamp = nil
        cachedBookmarks = nil
        bookmarksCacheTimestamp = nil
    }

    /// Perform hybrid search (semantic + keyword matching)
    func search(query: String, limit: Int = 50) -> [SemanticSearchResult] {
        // Generate query embedding
        guard let queryVector = embeddingService.embed(text: query) else {
            #if DEBUG
            print("Failed to embed query")
            #endif
            return []
        }

        // Load embeddings (from cache if available)
        let embeddings = loadEmbeddingsWithCache()

        guard !embeddings.isEmpty else {
            #if DEBUG
            print("No embeddings in database")
            #endif
            return []
        }

        // Load bookmarks for keyword matching
        let bookmarksMap = loadBookmarksWithCache()

        // Extract query terms for keyword matching
        let queryTerms = extractSearchTerms(from: query)

        // Calculate hybrid scores for all candidates
        var hybridResults: [(id: String, score: Float)] = []

        for embedding in embeddings {
            // Semantic score
            let semanticScore = embeddingService.cosineSimilarity(queryVector, embedding.vector)

            // Keyword score
            var keywordScore: Float = 0
            if let bookmark = bookmarksMap[embedding.bookmarkId] {
                keywordScore = calculateKeywordScore(queryTerms: queryTerms, bookmark: bookmark)
            }

            // Hybrid score (weighted combination)
            let hybridScore = (semanticWeight * semanticScore) + (keywordWeight * keywordScore)

            // Include if either semantic or keyword score is meaningful
            if semanticScore >= 0.15 || keywordScore >= 0.3 || hybridScore >= 0.2 {
                hybridResults.append((embedding.bookmarkId, hybridScore))
            }
        }

        // Sort by hybrid score descending
        hybridResults.sort { $0.score > $1.score }

        // Return top results
        let topResults = Array(hybridResults.prefix(limit))
        return topResults.map { SemanticSearchResult(bookmarkId: $0.id, score: $0.score) }
    }

    /// Extract search terms from query (lowercase, remove stopwords)
    private func extractSearchTerms(from query: String) -> [String] {
        let stopwords = Set(["the", "a", "an", "is", "are", "was", "were", "be", "been",
                             "being", "have", "has", "had", "do", "does", "did", "will",
                             "would", "could", "should", "may", "might", "must", "shall",
                             "can", "need", "dare", "ought", "used", "to", "of", "in",
                             "for", "on", "with", "at", "by", "from", "as", "into",
                             "through", "during", "before", "after", "above", "below",
                             "between", "under", "again", "further", "then", "once",
                             "here", "there", "when", "where", "why", "how", "all",
                             "each", "few", "more", "most", "other", "some", "such",
                             "no", "nor", "not", "only", "own", "same", "so", "than",
                             "too", "very", "just", "and", "but", "if", "or", "because",
                             "until", "while", "about", "against", "any", "what", "which",
                             "who", "whom", "this", "that", "these", "those", "am", "it", "i"])

        let words = query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 1 && !stopwords.contains($0) }

        return words
    }

    /// Calculate keyword match score for a bookmark
    private func calculateKeywordScore(queryTerms: [String], bookmark: Bookmark) -> Float {
        guard !queryTerms.isEmpty else { return 0 }

        let content = bookmark.content.lowercased()
        let authorHandle = bookmark.authorHandle.lowercased()
        let authorName = bookmark.authorName.lowercased()

        var matchCount: Float = 0
        var totalWeight: Float = 0

        for term in queryTerms {
            // Check content (weight: 1.0)
            if content.contains(term) {
                matchCount += 1.0
                // Bonus for multiple occurrences
                let occurrences = content.components(separatedBy: term).count - 1
                if occurrences > 1 {
                    matchCount += min(Float(occurrences - 1) * 0.2, 0.5)
                }
            }
            totalWeight += 1.0

            // Check author handle (weight: 1.5 - author matches are important)
            if authorHandle.contains(term) {
                matchCount += 1.5
            }
            totalWeight += 0.5

            // Check author name (weight: 1.2)
            if authorName.contains(term) {
                matchCount += 1.2
            }
            totalWeight += 0.3
        }

        // Normalize score to 0-1 range
        return min(matchCount / max(totalWeight, 1), 1.0)
    }

    /// Load bookmarks into cache for keyword matching
    private func loadBookmarksWithCache() -> [String: Bookmark] {
        // Check if cache is valid
        if let cached = cachedBookmarks,
           let timestamp = bookmarksCacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValiditySeconds {
            return cached
        }

        // Reload from database
        let bookmarks = dbManager.searchBookmarks(limit: 10000)
        let bookmarksMap = Dictionary(uniqueKeysWithValues: bookmarks.map { ($0.id, $0) })
        cachedBookmarks = bookmarksMap
        bookmarksCacheTimestamp = Date()
        return bookmarksMap
    }

    private func loadEmbeddingsWithCache() -> [DatabaseManager.StoredEmbedding] {
        // Check if cache is valid
        if let cached = cachedEmbeddings,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValiditySeconds {
            return cached
        }

        // Reload from database
        let embeddings = dbManager.loadAllEmbeddings()
        cachedEmbeddings = embeddings
        cacheTimestamp = Date()
        return embeddings
    }

    /// Generate and store embedding for a single bookmark
    func generateEmbedding(for bookmark: Bookmark) async {
        guard let vector = embeddingService.embed(text: bookmark.content) else {
            #if DEBUG
            print("Failed to generate embedding for bookmark \(bookmark.id)")
            #endif
            return
        }

        let data = embeddingService.vectorToData(vector)
        dbManager.saveEmbedding(
            bookmarkId: bookmark.id,
            embedding: data,
            model: embeddingService.modelName
        )
    }

    /// Generate embeddings for all bookmarks without embeddings
    func generateMissingEmbeddings(
        onProgress: @escaping (Int, Int) -> Void,
        onComplete: @escaping () -> Void
    ) {
        let bookmarks = dbManager.getBookmarksWithoutEmbedding()
        let total = bookmarks.count

        guard total > 0 else {
            onComplete()
            return
        }

        Task {
            for (index, bookmark) in bookmarks.enumerated() {
                await generateEmbedding(for: bookmark)

                await MainActor.run {
                    onProgress(index + 1, total)
                }
            }

            // Clear cache so new embeddings are picked up
            await MainActor.run {
                clearCache()
                onComplete()
            }
        }
    }

    /// Check how many bookmarks need embeddings
    func missingEmbeddingCount() -> Int {
        return dbManager.getBookmarksWithoutEmbedding().count
    }

    /// Total embedding count
    func embeddingCount() -> Int {
        return dbManager.getEmbeddingCount()
    }
}

struct SemanticSearchResult {
    let bookmarkId: String
    let score: Float  // Cosine similarity score (0-1)

    var relevancePercentage: Int {
        return Int(score * 100)
    }
}
