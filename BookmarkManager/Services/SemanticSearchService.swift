import Foundation

class SemanticSearchService {
    static let shared = SemanticSearchService()

    private let embeddingService = EmbeddingService.shared
    private let dbManager = DatabaseManager.shared

    // Cache embeddings in memory to avoid repeated DB reads
    private var cachedEmbeddings: [DatabaseManager.StoredEmbedding]?
    private var cacheTimestamp: Date?
    private let cacheValiditySeconds: TimeInterval = 60  // Refresh cache every 60 seconds

    private init() {}

    // MARK: - Public API

    /// Check if semantic search is available
    var isAvailable: Bool {
        return embeddingService.isAvailable
    }

    /// Clear the embeddings cache (call after generating new embeddings)
    func clearCache() {
        cachedEmbeddings = nil
        cacheTimestamp = nil
    }

    /// Perform semantic search
    func search(query: String, limit: Int = 50) -> [SemanticSearchResult] {
        // Generate query embedding
        guard let queryVector = embeddingService.embed(text: query) else {
            print("Failed to embed query")
            return []
        }

        // Load embeddings (from cache if available)
        let embeddings = loadEmbeddingsWithCache()

        guard !embeddings.isEmpty else {
            print("No embeddings in database")
            return []
        }

        // Find similar
        let candidates = embeddings.map { ($0.bookmarkId, $0.vector) }
        let results = embeddingService.findSimilar(
            queryVector: queryVector,
            candidates: candidates,
            topK: limit,
            threshold: 0.25
        )

        return results.map { SemanticSearchResult(bookmarkId: $0.id, score: $0.score) }
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
            print("Failed to generate embedding for bookmark \(bookmark.id)")
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
