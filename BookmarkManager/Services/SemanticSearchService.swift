import Foundation

class SemanticSearchService {
    static let shared = SemanticSearchService()

    private let embeddingService = EmbeddingService.shared
    private let dbManager = DatabaseManager.shared

    private init() {}

    // MARK: - Public API

    /// Check if semantic search is available
    var isAvailable: Bool {
        return embeddingService.isAvailable
    }

    /// Perform semantic search
    func search(query: String, limit: Int = 50) -> [SemanticSearchResult] {
        // Generate query embedding
        guard let queryVector = embeddingService.embed(text: query) else {
            print("Failed to embed query")
            return []
        }

        // Load all embeddings from database
        let embeddings = dbManager.loadAllEmbeddings()

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
            threshold: 0.25  // Lower threshold for more results
        )

        return results.map { SemanticSearchResult(bookmarkId: $0.id, score: $0.score) }
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

            await MainActor.run {
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
