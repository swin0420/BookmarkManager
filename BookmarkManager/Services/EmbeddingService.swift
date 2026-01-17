import Foundation
import NaturalLanguage

class EmbeddingService {
    static let shared = EmbeddingService()

    private let embedding: NLEmbedding?
    let modelName = "Apple-NLEmbedding-English"
    let dimensions = 512  // NLEmbedding uses 512 dimensions

    private init() {
        embedding = NLEmbedding.sentenceEmbedding(for: .english)
    }

    // MARK: - Public API

    /// Check if embedding service is available
    var isAvailable: Bool {
        return embedding != nil
    }

    /// Generate embedding vector for text
    func embed(text: String) -> [Float]? {
        guard let embedding = embedding else { return nil }

        // Clean and normalize text
        let cleanedText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")

        guard !cleanedText.isEmpty else { return nil }

        // Get vector
        guard let vector = embedding.vector(for: cleanedText) else { return nil }

        // Convert to Float array
        return vector.map { Float($0) }
    }

    /// Generate embeddings for multiple texts (batch processing)
    func embedBatch(texts: [String]) -> [[Float]?] {
        return texts.map { embed(text: $0) }
    }

    /// Calculate cosine similarity between two vectors
    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }

    /// Find most similar vectors to query
    func findSimilar(
        queryVector: [Float],
        candidates: [(id: String, vector: [Float])],
        topK: Int = 20,
        threshold: Float = 0.3
    ) -> [(id: String, score: Float)] {
        var results: [(id: String, score: Float)] = []

        for candidate in candidates {
            let score = cosineSimilarity(queryVector, candidate.vector)
            if score >= threshold {
                results.append((candidate.id, score))
            }
        }

        // Sort by score descending
        results.sort { $0.score > $1.score }

        // Return top K
        return Array(results.prefix(topK))
    }

    // MARK: - Vector Serialization

    /// Convert float array to Data for storage
    func vectorToData(_ vector: [Float]) -> Data {
        return vector.withUnsafeBytes { Data($0) }
    }

    /// Convert Data back to float array
    func dataToVector(_ data: Data) -> [Float] {
        return data.withUnsafeBytes { pointer in
            Array(pointer.bindMemory(to: Float.self))
        }
    }
}
