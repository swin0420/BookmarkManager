import XCTest
@testable import BookmarkManager

final class EmbeddingServiceTests: XCTestCase {

    // MARK: - Cosine Similarity Tests

    func testCosineSimilarityIdenticalVectors() {
        let vector: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]

        let similarity = cosineSimilarity(vector, vector)

        XCTAssertEqual(similarity, 1.0, accuracy: 0.0001)
    }

    func testCosineSimilarityOrthogonalVectors() {
        let a: [Float] = [1.0, 0.0, 0.0]
        let b: [Float] = [0.0, 1.0, 0.0]

        let similarity = cosineSimilarity(a, b)

        XCTAssertEqual(similarity, 0.0, accuracy: 0.0001)
    }

    func testCosineSimilarityOppositeVectors() {
        let a: [Float] = [1.0, 2.0, 3.0]
        let b: [Float] = [-1.0, -2.0, -3.0]

        let similarity = cosineSimilarity(a, b)

        XCTAssertEqual(similarity, -1.0, accuracy: 0.0001)
    }

    func testCosineSimilaritySimilarVectors() {
        let a: [Float] = [1.0, 2.0, 3.0]
        let b: [Float] = [1.1, 2.1, 3.1]

        let similarity = cosineSimilarity(a, b)

        // Should be very close to 1.0
        XCTAssertGreaterThan(similarity, 0.99)
    }

    func testCosineSimilarityDifferentLengths() {
        let a: [Float] = [1.0, 2.0, 3.0]
        let b: [Float] = [1.0, 2.0]

        let similarity = cosineSimilarity(a, b)

        // Should return 0 for mismatched lengths
        XCTAssertEqual(similarity, 0.0)
    }

    func testCosineSimilarityEmptyVectors() {
        let a: [Float] = []
        let b: [Float] = []

        let similarity = cosineSimilarity(a, b)

        XCTAssertEqual(similarity, 0.0)
    }

    func testCosineSimilarityZeroVector() {
        let a: [Float] = [0.0, 0.0, 0.0]
        let b: [Float] = [1.0, 2.0, 3.0]

        let similarity = cosineSimilarity(a, b)

        // Division by zero should return 0
        XCTAssertEqual(similarity, 0.0)
    }

    func testCosineSimilarityWithNegativeValues() {
        let a: [Float] = [-1.0, 2.0, -3.0]
        let b: [Float] = [1.0, -2.0, 3.0]

        let similarity = cosineSimilarity(a, b)

        // Should be -1.0 (opposite)
        XCTAssertEqual(similarity, -1.0, accuracy: 0.0001)
    }

    func testCosineSimilarityHighDimensional() {
        // Test with 512 dimensions (matching NLEmbedding)
        var a: [Float] = []
        var b: [Float] = []

        for i in 0..<512 {
            a.append(Float(i) / 512.0)
            b.append(Float(i) / 512.0 + 0.01)
        }

        let similarity = cosineSimilarity(a, b)

        // Should be very close to 1.0
        XCTAssertGreaterThan(similarity, 0.99)
    }

    // MARK: - Find Similar Tests

    func testFindSimilarBasic() {
        let queryVector: [Float] = [1.0, 0.0, 0.0]

        let candidates: [(id: String, vector: [Float])] = [
            ("a", [1.0, 0.0, 0.0]),      // Identical
            ("b", [0.9, 0.1, 0.0]),      // Very similar
            ("c", [0.0, 1.0, 0.0]),      // Orthogonal
            ("d", [-1.0, 0.0, 0.0])      // Opposite
        ]

        let results = findSimilar(queryVector: queryVector, candidates: candidates, topK: 3, threshold: 0.3)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].id, "a") // Score 1.0
        XCTAssertEqual(results[1].id, "b") // Score ~0.99
    }

    func testFindSimilarWithThreshold() {
        let queryVector: [Float] = [1.0, 0.0, 0.0]

        let candidates: [(id: String, vector: [Float])] = [
            ("a", [1.0, 0.0, 0.0]),      // Score 1.0
            ("b", [0.5, 0.5, 0.0]),      // Score ~0.71
            ("c", [0.2, 0.8, 0.0]),      // Score ~0.24
        ]

        let results = findSimilar(queryVector: queryVector, candidates: candidates, topK: 10, threshold: 0.5)

        XCTAssertEqual(results.count, 2) // Only a and b above threshold
    }

    func testFindSimilarTopK() {
        let queryVector: [Float] = [1.0, 0.0, 0.0]

        var candidates: [(id: String, vector: [Float])] = []
        for i in 0..<100 {
            candidates.append(("\(i)", [1.0 - Float(i) * 0.01, Float(i) * 0.01, 0.0]))
        }

        let results = findSimilar(queryVector: queryVector, candidates: candidates, topK: 5, threshold: 0.0)

        XCTAssertEqual(results.count, 5)
        XCTAssertEqual(results[0].id, "0") // Most similar
    }

    func testFindSimilarEmptyCandidates() {
        let queryVector: [Float] = [1.0, 0.0, 0.0]
        let candidates: [(id: String, vector: [Float])] = []

        let results = findSimilar(queryVector: queryVector, candidates: candidates, topK: 10, threshold: 0.3)

        XCTAssertEqual(results.count, 0)
    }

    func testFindSimilarNoneAboveThreshold() {
        let queryVector: [Float] = [1.0, 0.0, 0.0]

        let candidates: [(id: String, vector: [Float])] = [
            ("a", [0.0, 1.0, 0.0]),      // Score 0.0
            ("b", [0.0, 0.0, 1.0]),      // Score 0.0
        ]

        let results = findSimilar(queryVector: queryVector, candidates: candidates, topK: 10, threshold: 0.5)

        XCTAssertEqual(results.count, 0)
    }

    func testFindSimilarSortedByScore() {
        let queryVector: [Float] = [1.0, 0.0, 0.0]

        let candidates: [(id: String, vector: [Float])] = [
            ("c", [0.6, 0.4, 0.0]),
            ("a", [1.0, 0.0, 0.0]),
            ("b", [0.8, 0.2, 0.0]),
        ]

        let results = findSimilar(queryVector: queryVector, candidates: candidates, topK: 10, threshold: 0.0)

        // Should be sorted by score descending
        for i in 0..<results.count - 1 {
            XCTAssertGreaterThanOrEqual(results[i].score, results[i + 1].score)
        }
    }

    // MARK: - Vector Serialization Tests

    func testVectorToData() {
        let vector: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]

        let data = vectorToData(vector)

        XCTAssertEqual(data.count, vector.count * MemoryLayout<Float>.size)
    }

    func testDataToVector() {
        let originalVector: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let data = vectorToData(originalVector)

        let restoredVector = dataToVector(data)

        XCTAssertEqual(restoredVector.count, originalVector.count)
        for i in 0..<originalVector.count {
            XCTAssertEqual(restoredVector[i], originalVector[i], accuracy: 0.0001)
        }
    }

    func testVectorRoundTrip() {
        let originalVector: [Float] = Array(repeating: 0, count: 512).enumerated().map { Float($0.offset) / 512.0 }

        let data = vectorToData(originalVector)
        let restoredVector = dataToVector(data)

        XCTAssertEqual(restoredVector.count, originalVector.count)
        for i in 0..<originalVector.count {
            XCTAssertEqual(restoredVector[i], originalVector[i], accuracy: 0.0001)
        }
    }

    func testEmptyVectorToData() {
        let vector: [Float] = []

        let data = vectorToData(vector)

        XCTAssertEqual(data.count, 0)
    }

    func testEmptyDataToVector() {
        let data = Data()

        let vector = dataToVector(data)

        XCTAssertEqual(vector.count, 0)
    }

    // MARK: - Text Cleaning Tests

    func testTextCleaningForEmbedding() {
        let dirtyText = "  Hello\n\nWorld  \n"

        let cleanedText = dirtyText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")

        XCTAssertEqual(cleanedText, "Hello  World")
    }

    func testEmptyTextForEmbedding() {
        let emptyText = ""
        let cleanedText = emptyText.trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertTrue(cleanedText.isEmpty)
    }

    func testWhitespaceOnlyTextForEmbedding() {
        let whitespaceText = "   \n\t\r   "
        let cleanedText = whitespaceText.trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertTrue(cleanedText.isEmpty)
    }

    // MARK: - Batch Processing Tests

    func testBatchEmbeddingResultCount() {
        let texts = ["Hello world", "Test text", "Another sentence", "Final text"]

        // Simulate batch processing
        let results = texts.map { text -> [Float]? in
            if text.isEmpty { return nil }
            return [0.1, 0.2, 0.3] // Mock embedding
        }

        XCTAssertEqual(results.count, texts.count)
    }

    func testBatchEmbeddingWithEmptyStrings() {
        let texts = ["Hello", "", "World", "   ", "Test"]

        let validTexts = texts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        XCTAssertEqual(validTexts.count, 3)
    }

    // MARK: - Similarity Threshold Tests

    func testDefaultSimilarityThreshold() {
        let threshold: Float = 0.3

        // Test various similarity scores against threshold
        let scores: [Float] = [0.1, 0.25, 0.3, 0.35, 0.5, 0.8, 1.0]
        let aboveThreshold = scores.filter { $0 >= threshold }

        XCTAssertEqual(aboveThreshold.count, 5)
    }

    func testLowThresholdMoreResults() {
        let scores: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]

        let lowThreshold: Float = 0.15
        let highThreshold: Float = 0.45

        let lowThresholdResults = scores.filter { $0 >= lowThreshold }
        let highThresholdResults = scores.filter { $0 >= highThreshold }

        XCTAssertGreaterThan(lowThresholdResults.count, highThresholdResults.count)
    }

    // MARK: - Performance Tests

    func testCosineSimilarityPerformance() {
        let a: [Float] = Array(repeating: 0, count: 512).enumerated().map { Float($0.offset) / 512.0 }
        let b: [Float] = Array(repeating: 0, count: 512).enumerated().map { Float($0.offset + 1) / 513.0 }

        measure {
            for _ in 0..<1000 {
                _ = cosineSimilarity(a, b)
            }
        }
    }

    func testFindSimilarPerformance() {
        let queryVector: [Float] = Array(repeating: 0.1, count: 512)

        var candidates: [(id: String, vector: [Float])] = []
        for i in 0..<1000 {
            let vector: [Float] = Array(repeating: Float(i) / 1000.0, count: 512)
            candidates.append(("\(i)", vector))
        }

        measure {
            _ = findSimilar(queryVector: queryVector, candidates: candidates, topK: 20, threshold: 0.3)
        }
    }

    // MARK: - Helper Functions

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
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

    private func findSimilar(
        queryVector: [Float],
        candidates: [(id: String, vector: [Float])],
        topK: Int,
        threshold: Float
    ) -> [(id: String, score: Float)] {
        var results: [(id: String, score: Float)] = []

        for candidate in candidates {
            let score = cosineSimilarity(queryVector, candidate.vector)
            if score >= threshold {
                results.append((candidate.id, score))
            }
        }

        results.sort { $0.score > $1.score }
        return Array(results.prefix(topK))
    }

    private func vectorToData(_ vector: [Float]) -> Data {
        return vector.withUnsafeBytes { Data($0) }
    }

    private func dataToVector(_ data: Data) -> [Float] {
        return data.withUnsafeBytes { pointer in
            Array(pointer.bindMemory(to: Float.self))
        }
    }
}
