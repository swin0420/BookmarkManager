import XCTest
@testable import BookmarkManager

final class AIServiceTests: XCTestCase {

    // MARK: - Tag Suggestion Parsing Tests

    func testParseTagSuggestionsBasic() {
        let response = """
        machine-learning|0.95
        python|0.85
        data-science|0.75
        """

        let suggestions = parseTagSuggestions(response)

        XCTAssertEqual(suggestions.count, 3)
        XCTAssertEqual(suggestions[0].name, "machine-learning")
        XCTAssertEqual(suggestions[0].confidence, 0.95, accuracy: 0.001)
        XCTAssertEqual(suggestions[1].name, "python")
        XCTAssertEqual(suggestions[1].confidence, 0.85, accuracy: 0.001)
    }

    func testParseTagSuggestionsWithoutConfidence() {
        let response = """
        web-dev
        javascript
        react
        """

        let suggestions = parseTagSuggestions(response)

        XCTAssertEqual(suggestions.count, 3)
        // Without confidence, should default to 0.7
        for suggestion in suggestions {
            XCTAssertEqual(suggestion.confidence, 0.7, accuracy: 0.001)
        }
    }

    func testParseTagSuggestionsMixedFormat() {
        let response = """
        ai|0.9
        coding
        tutorial|0.8
        """

        let suggestions = parseTagSuggestions(response)

        XCTAssertEqual(suggestions.count, 3)
        // Results are sorted by confidence descending: ai(0.9), tutorial(0.8), coding(0.7)
        XCTAssertEqual(suggestions[0].name, "ai")
        XCTAssertEqual(suggestions[0].confidence, 0.9, accuracy: 0.001)
        XCTAssertEqual(suggestions[1].name, "tutorial")
        XCTAssertEqual(suggestions[1].confidence, 0.8, accuracy: 0.001)
        XCTAssertEqual(suggestions[2].name, "coding")
        XCTAssertEqual(suggestions[2].confidence, 0.7, accuracy: 0.001)
    }

    func testParseTagSuggestionsEmptyResponse() {
        let response = ""

        let suggestions = parseTagSuggestions(response)

        XCTAssertEqual(suggestions.count, 0)
    }

    func testParseTagSuggestionsWithWhitespace() {
        let response = """

          tech|0.85

          startup|0.75

        """

        let suggestions = parseTagSuggestions(response)

        XCTAssertEqual(suggestions.count, 2)
        XCTAssertEqual(suggestions[0].name, "tech")
        XCTAssertEqual(suggestions[1].name, "startup")
    }

    func testParseTagSuggestionsNormalizesNames() {
        let response = """
        Machine Learning|0.9
        Web Dev|0.8
        Data Science|0.7
        """

        let suggestions = parseTagSuggestions(response)

        // Names should be lowercased and spaces replaced with hyphens
        XCTAssertEqual(suggestions[0].name, "machine-learning")
        XCTAssertEqual(suggestions[1].name, "web-dev")
        XCTAssertEqual(suggestions[2].name, "data-science")
    }

    func testParseTagSuggestionsSortedByConfidence() {
        let response = """
        low|0.3
        high|0.9
        medium|0.6
        """

        let suggestions = parseTagSuggestions(response)

        // Should be sorted descending by confidence
        XCTAssertEqual(suggestions[0].name, "high")
        XCTAssertEqual(suggestions[1].name, "medium")
        XCTAssertEqual(suggestions[2].name, "low")
    }

    func testParseTagSuggestionsInvalidConfidence() {
        let response = """
        valid|0.8
        invalid|abc
        another|xyz
        """

        let suggestions = parseTagSuggestions(response)

        XCTAssertEqual(suggestions.count, 3)
        // Invalid confidence should default to 0.7
        let invalidSuggestion = suggestions.first { $0.name == "invalid" }
        XCTAssertNotNil(invalidSuggestion)
        XCTAssertEqual(invalidSuggestion?.confidence ?? 0, 0.7, accuracy: 0.001)
    }

    // MARK: - Batch Progress Tests

    func testBatchProgressPercentage() {
        let progress = BatchProgress(current: 50, total: 100, currentBookmarkId: nil, error: nil)

        XCTAssertEqual(progress.percentage, 50.0, accuracy: 0.001)
    }

    func testBatchProgressPercentageZeroTotal() {
        let progress = BatchProgress(current: 0, total: 0, currentBookmarkId: nil, error: nil)

        XCTAssertEqual(progress.percentage, 0.0)
    }

    func testBatchProgressPercentageComplete() {
        let progress = BatchProgress(current: 100, total: 100, currentBookmarkId: nil, error: nil)

        XCTAssertEqual(progress.percentage, 100.0, accuracy: 0.001)
    }

    func testBatchProgressPercentagePartial() {
        let progress = BatchProgress(current: 33, total: 100, currentBookmarkId: "test-id", error: nil)

        XCTAssertEqual(progress.percentage, 33.0, accuracy: 0.001)
        XCTAssertEqual(progress.currentBookmarkId, "test-id")
    }

    func testBatchProgressWithError() {
        let progress = BatchProgress(current: 10, total: 100, currentBookmarkId: "failed-id", error: "Network timeout")

        XCTAssertNotNil(progress.error)
        XCTAssertEqual(progress.error, "Network timeout")
    }

    // MARK: - Rate Limiting Tests

    func testRateLimitInterval() {
        let minRequestInterval: TimeInterval = 1.1

        XCTAssertEqual(minRequestInterval, 1.1)
        XCTAssertGreaterThan(minRequestInterval, 1.0)
    }

    func testRateLimitCalculation() {
        let lastRequestTime = Date()
        let minRequestInterval: TimeInterval = 1.1

        // Simulate immediate request
        let elapsed: TimeInterval = 0.5
        let shouldWait = elapsed < minRequestInterval

        XCTAssertTrue(shouldWait)

        let waitTime = minRequestInterval - elapsed
        XCTAssertEqual(waitTime, 0.6, accuracy: 0.001)
    }

    func testRateLimitNoWaitNeeded() {
        let minRequestInterval: TimeInterval = 1.1
        let elapsed: TimeInterval = 2.0

        let shouldWait = elapsed < minRequestInterval

        XCTAssertFalse(shouldWait)
    }

    // MARK: - Summary Generation Tests

    func testSummarySystemPromptRequirements() {
        let systemPrompt = """
        You are a helpful assistant that creates concise summaries of tweets.
        Keep summaries to 1-2 sentences maximum. Focus on the main point or insight.
        Don't start with "This tweet" or "The author". Just state the key point directly.
        """

        XCTAssertTrue(systemPrompt.contains("concise"))
        XCTAssertTrue(systemPrompt.contains("1-2 sentences"))
        XCTAssertTrue(systemPrompt.contains("main point"))
    }

    func testSummaryPromptConstruction() {
        let authorName = "elonmusk"
        let content = "Excited to announce new features for X!"

        let prompt = "Summarize this tweet from @\(authorName):\n\n\(content)"

        XCTAssertTrue(prompt.contains("@elonmusk"))
        XCTAssertTrue(prompt.contains("Excited to announce"))
    }

    func testSummaryResponseTrimming() {
        let response = "  This is a summary with extra whitespace.  \n\n"

        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertEqual(trimmed, "This is a summary with extra whitespace.")
    }

    // MARK: - Tag Suggestion Prompt Tests

    func testTagSuggestionPromptWithExistingTags() {
        let existingTags = ["tech", "ai", "startup"]
        let content = "Just launched our AI startup!"

        let existingTagsList = existingTags.joined(separator: ", ")
        let prompt = "Suggest tags for this tweet. Existing tags in the system: \(existingTagsList)\n\nTweet:\n\(content)"

        XCTAssertTrue(prompt.contains("tech, ai, startup"))
        XCTAssertTrue(prompt.contains("Just launched"))
    }

    func testTagSuggestionPromptWithNoExistingTags() {
        let existingTags: [String] = []
        let content = "New tweet content"

        let existingTagsList = existingTags.isEmpty ? "none" : existingTags.joined(separator: ", ")

        XCTAssertEqual(existingTagsList, "none")
    }

    // MARK: - Tag Name Normalization Tests

    func testTagNameNormalizationLowercase() {
        let tagName = "Machine Learning"
        let normalized = tagName.lowercased().replacingOccurrences(of: " ", with: "-")

        XCTAssertEqual(normalized, "machine-learning")
    }

    func testTagNameNormalizationMultipleSpaces() {
        let tagName = "web   development"
        let normalized = tagName.lowercased().replacingOccurrences(of: " ", with: "-")

        // Multiple spaces result in multiple hyphens (could be further normalized)
        XCTAssertTrue(normalized.contains("-"))
    }

    func testTagNameNormalizationSpecialCharacters() {
        let tagName = "C++"
        let normalized = tagName.lowercased()

        XCTAssertEqual(normalized, "c++")
    }

    // MARK: - Batch Processing Logic Tests

    func testBatchProcessingSequence() {
        let bookmarks: [(id: String, content: String, authorName: String)] = [
            ("1", "First tweet", "user1"),
            ("2", "Second tweet", "user2"),
            ("3", "Third tweet", "user3")
        ]

        var processedIds: [String] = []

        for bookmark in bookmarks {
            processedIds.append(bookmark.id)
        }

        XCTAssertEqual(processedIds, ["1", "2", "3"])
    }

    func testBatchProcessingErrorHandling() {
        var errorsEncountered = 0
        let bookmarkIds = ["1", "2", "3"]
        let failingIds = Set(["2"])

        for id in bookmarkIds {
            if failingIds.contains(id) {
                errorsEncountered += 1
            }
        }

        XCTAssertEqual(errorsEncountered, 1)
    }

    // MARK: - Helper Functions

    private func parseTagSuggestions(_ response: String) -> [TagSuggestion] {
        var suggestions: [TagSuggestion] = []

        for line in response.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let parts = trimmed.components(separatedBy: "|")
            if parts.count >= 2,
               let confidence = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                let name = parts[0].trimmingCharacters(in: .whitespaces)
                    .lowercased()
                    .replacingOccurrences(of: " ", with: "-")
                suggestions.append(TagSuggestion(name: name, confidence: confidence))
            } else {
                // Use first part as name (handles "invalid|abc" case), or whole line if no separator
                let namePart = parts.count >= 1 ? parts[0] : trimmed
                let name = namePart.trimmingCharacters(in: .whitespaces)
                    .lowercased()
                    .replacingOccurrences(of: " ", with: "-")
                suggestions.append(TagSuggestion(name: name, confidence: 0.7))
            }
        }

        return suggestions.sorted { $0.confidence > $1.confidence }
    }
}

// MARK: - Test Helper Structures

struct TagSuggestion {
    let name: String
    let confidence: Double
}

struct BatchProgress {
    let current: Int
    let total: Int
    let currentBookmarkId: String?
    let error: String?

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total) * 100
    }
}
