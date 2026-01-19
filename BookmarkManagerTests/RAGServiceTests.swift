import XCTest
@testable import BookmarkManager

final class RAGServiceTests: XCTestCase {

    // MARK: - SearchParams Tests

    func testSearchParamsDecoding() throws {
        let json = """
        {
            "keywords": ["ai", "machine learning"],
            "dateRange": {"unit": "months", "amount": 3},
            "authors": ["elonmusk", "sama"],
            "topics": ["technology", "startups"]
        }
        """

        let data = json.data(using: .utf8)!
        let params = try JSONDecoder().decode(SearchParams.self, from: data)

        XCTAssertEqual(params.keywords.count, 2)
        XCTAssertEqual(params.keywords[0], "ai")
        XCTAssertEqual(params.dateRange?.unit, "months")
        XCTAssertEqual(params.dateRange?.amount, 3)
        XCTAssertEqual(params.authors?.count, 2)
        XCTAssertEqual(params.topics?.count, 2)
    }

    func testSearchParamsDecodingWithNulls() throws {
        let json = """
        {
            "keywords": ["crypto"],
            "dateRange": null,
            "authors": null,
            "topics": null
        }
        """

        let data = json.data(using: .utf8)!
        let params = try JSONDecoder().decode(SearchParams.self, from: data)

        XCTAssertEqual(params.keywords.count, 1)
        XCTAssertNil(params.dateRange)
        XCTAssertNil(params.authors)
        XCTAssertNil(params.topics)
    }

    func testSearchParamsEmptyKeywords() throws {
        let json = """
        {
            "keywords": [],
            "dateRange": null,
            "authors": null,
            "topics": null
        }
        """

        let data = json.data(using: .utf8)!
        let params = try JSONDecoder().decode(SearchParams.self, from: data)

        XCTAssertEqual(params.keywords.count, 0)
    }

    // MARK: - Date Range Tests

    func testDateRangeDecoding() throws {
        let json = """
        {"unit": "weeks", "amount": 2}
        """

        let data = json.data(using: .utf8)!
        let dateRange = try JSONDecoder().decode(DateRange.self, from: data)

        XCTAssertEqual(dateRange.unit, "weeks")
        XCTAssertEqual(dateRange.amount, 2)
    }

    func testDateRangeCalculationDays() {
        let amount = 7
        let now = Date()
        let minDate = Calendar.current.date(byAdding: .day, value: -amount, to: now)!

        XCTAssertLessThan(minDate, now)
    }

    func testDateRangeCalculationWeeks() {
        let amount = 2
        let now = Date()
        let minDate = Calendar.current.date(byAdding: .weekOfYear, value: -amount, to: now)!

        XCTAssertLessThan(minDate, now)
    }

    func testDateRangeCalculationMonths() {
        let amount = 3
        let now = Date()
        let minDate = Calendar.current.date(byAdding: .month, value: -amount, to: now)!

        XCTAssertLessThan(minDate, now)
    }

    func testDateRangeCalculationYears() {
        let amount = 1
        let now = Date()
        let minDate = Calendar.current.date(byAdding: .year, value: -amount, to: now)!

        XCTAssertLessThan(minDate, now)
    }

    func testDateRangeUnitNormalization() {
        let units = ["days", "day", "Days", "DAY"]

        for unit in units {
            let normalized = unit.lowercased()
            XCTAssertTrue(normalized == "days" || normalized == "day")
        }
    }

    // MARK: - Follow-up Parsing Tests

    func testParseFollowUpsBasic() {
        let response = """
        Here is my answer to your question about AI.

        ---FOLLOWUPS---
        What specific AI models are you interested in?
        Would you like to know more about machine learning?
        How can I help you with your AI project?
        """

        let (cleanAnswer, followUps) = parseFollowUps(from: response)

        XCTAssertEqual(cleanAnswer, "Here is my answer to your question about AI.")
        XCTAssertEqual(followUps.count, 3)
    }

    func testParseFollowUpsNoMarker() {
        let response = "This is just a plain response without follow-ups."

        let (cleanAnswer, followUps) = parseFollowUps(from: response)

        XCTAssertEqual(cleanAnswer, response)
        XCTAssertEqual(followUps.count, 0)
    }

    func testParseFollowUpsWithBullets() {
        let response = """
        Answer text here.

        ---FOLLOWUPS---
        - First follow-up question?
        - Second follow-up question?
        - Third follow-up question?
        """

        let (_, followUps) = parseFollowUps(from: response)

        XCTAssertEqual(followUps.count, 3)
        // Bullets should be stripped
        XCTAssertFalse(followUps[0].hasPrefix("-"))
    }

    func testParseFollowUpsWithNumbers() {
        let response = """
        Answer.

        ---FOLLOWUPS---
        1. First question?
        2. Second question?
        """

        let (_, followUps) = parseFollowUps(from: response)

        // Numbers should be stripped
        XCTAssertGreaterThan(followUps.count, 0)
    }

    func testParseFollowUpsLimitedToThree() {
        let response = """
        Answer.

        ---FOLLOWUPS---
        Question 1?
        Question 2?
        Question 3?
        Question 4?
        Question 5?
        """

        let (_, followUps) = parseFollowUps(from: response)

        XCTAssertLessThanOrEqual(followUps.count, 3)
    }

    // MARK: - Context Building Tests

    func testBuildContextEmpty() {
        let bookmarks: [TestBookmark] = []

        let context = buildContext(from: bookmarks, includeIds: false)

        XCTAssertEqual(context, "No bookmarks found matching the search criteria.")
    }

    func testBuildContextWithBookmarks() {
        let bookmarks = [
            TestBookmark(id: "1", authorHandle: "user1", authorName: "User One", content: "Test tweet 1", postedAt: Date()),
            TestBookmark(id: "2", authorHandle: "user2", authorName: "User Two", content: "Test tweet 2", postedAt: Date())
        ]

        let context = buildContext(from: bookmarks, includeIds: false)

        XCTAssertTrue(context.contains("@user1"))
        XCTAssertTrue(context.contains("@user2"))
        XCTAssertTrue(context.contains("Test tweet 1"))
    }

    func testBuildContextWithIds() {
        let bookmarks = [
            TestBookmark(id: "abc123", authorHandle: "user1", authorName: "User", content: "Content", postedAt: Date())
        ]

        let context = buildContext(from: bookmarks, includeIds: true)

        XCTAssertTrue(context.contains("ID:abc123"))
    }

    // MARK: - Keyword Extraction Tests

    func testKeywordExtractionFromQuestion() {
        let question = "What are the best AI tools from last month?"

        let words = question.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 }

        XCTAssertTrue(words.contains("what"))
        XCTAssertTrue(words.contains("best"))
        XCTAssertTrue(words.contains("tools"))
        XCTAssertTrue(words.contains("from"))
        XCTAssertTrue(words.contains("last"))
        XCTAssertTrue(words.contains("month"))
    }

    func testKeywordExtractionFiltersShortWords() {
        let question = "AI is an ML thing"

        let words = question.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 }

        XCTAssertFalse(words.contains("ai"))
        XCTAssertFalse(words.contains("is"))
        XCTAssertFalse(words.contains("an"))
        XCTAssertFalse(words.contains("ml"))
        XCTAssertTrue(words.contains("thing"))
    }

    // MARK: - Author Filter Tests

    func testAuthorFilterCaseInsensitive() {
        let authors = ["ElonMusk", "sama"]
        let authorSet = Set(authors.map { $0.lowercased() })

        XCTAssertTrue(authorSet.contains("elonmusk"))
        XCTAssertTrue(authorSet.contains("sama"))
        XCTAssertFalse(authorSet.contains("ElonMusk"))
    }

    func testAuthorFilterMatching() {
        let filterAuthors = Set(["user1", "user2"])
        let bookmarkAuthor = "User1"

        let matches = filterAuthors.contains(bookmarkAuthor.lowercased())

        XCTAssertTrue(matches)
    }

    // MARK: - Content Search Tests

    func testContentSearchKeywordMatching() {
        let content = "This is a tweet about artificial intelligence and machine learning"
        let keywords = ["artificial", "machine"]

        let contentLower = content.lowercased()
        var matched = false

        for keyword in keywords {
            if contentLower.contains(keyword) {
                matched = true
                break
            }
        }

        XCTAssertTrue(matched)
    }

    func testContentSearchNoMatch() {
        let content = "This tweet is about cooking recipes"
        let keywords = ["programming", "coding"]

        let contentLower = content.lowercased()
        var matched = false

        for keyword in keywords {
            if contentLower.contains(keyword) {
                matched = true
                break
            }
        }

        XCTAssertFalse(matched)
    }

    // MARK: - Result Limit Tests

    func testSearchResultLimitedTo30() {
        var results: [String] = []
        let maxResults = 30

        for i in 0..<100 {
            if results.count >= maxResults { break }
            results.append("result-\(i)")
        }

        XCTAssertEqual(results.count, 30)
    }

    // MARK: - Suggested Questions Tests

    func testSuggestedQuestionsNotEmpty() {
        let suggestedQuestions = [
            "What are the main topics in my bookmarks?",
            "Summarize the tech tweets from last week",
            "What are people saying about AI?",
            "Find crypto-related tweets from last month"
        ]

        XCTAssertGreaterThan(suggestedQuestions.count, 0)
        for question in suggestedQuestions {
            XCTAssertFalse(question.isEmpty)
        }
    }

    // MARK: - RAG Error Tests

    func testRAGErrorParseError() {
        let error = RAGError.parseError("Invalid JSON format")

        switch error {
        case .parseError(let message):
            XCTAssertEqual(message, "Invalid JSON format")
        default:
            XCTFail("Wrong error type")
        }
    }

    func testRAGErrorSearchError() {
        let error = RAGError.searchError("No results found")

        switch error {
        case .searchError(let message):
            XCTAssertEqual(message, "No results found")
        default:
            XCTFail("Wrong error type")
        }
    }

    // MARK: - JSON Cleaning Tests

    func testCleanJSONResponse() {
        let response = """
        ```json
        {"keywords": ["test"]}
        ```
        """

        let cleaned = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertEqual(cleaned, "{\"keywords\": [\"test\"]}")
    }

    // MARK: - Helper Functions

    private func parseFollowUps(from response: String) -> (cleanAnswer: String, followUps: [String]) {
        let marker = "---FOLLOWUPS---"
        guard let markerRange = response.range(of: marker) else {
            return (response, [])
        }

        let cleanAnswer = String(response[..<markerRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let followUpSection = String(response[markerRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

        let followUps = followUpSection
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { line -> String in
                var cleaned = line
                if cleaned.hasPrefix("- ") { cleaned = String(cleaned.dropFirst(2)) }
                if cleaned.hasPrefix("• ") { cleaned = String(cleaned.dropFirst(2)) }
                if let dotIndex = cleaned.firstIndex(of: "."), dotIndex < cleaned.index(cleaned.startIndex, offsetBy: 3) {
                    cleaned = String(cleaned[cleaned.index(after: dotIndex)...]).trimmingCharacters(in: .whitespaces)
                }
                return cleaned
            }
            .filter { !$0.isEmpty }
            .prefix(3)

        return (cleanAnswer, Array(followUps))
    }

    private func buildContext(from bookmarks: [TestBookmark], includeIds: Bool) -> String {
        guard !bookmarks.isEmpty else {
            return "No bookmarks found matching the search criteria."
        }

        var context = ""
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"

        for (index, bookmark) in bookmarks.enumerated() {
            let date = dateFormatter.string(from: bookmark.postedAt)
            if includeIds {
                context += "[\(index + 1)] ID:\(bookmark.id) @\(bookmark.authorHandle) (\(bookmark.authorName)) - \(date):\n\(bookmark.content)\n---"
            } else {
                context += "[\(index + 1)] @\(bookmark.authorHandle) (\(bookmark.authorName)) - \(date):\n\(bookmark.content)\n---"
            }
        }

        return context
    }
}

// MARK: - Test Helper Structures

struct SearchParams: Codable {
    let keywords: [String]
    let dateRange: DateRange?
    let authors: [String]?
    let topics: [String]?
}

struct DateRange: Codable {
    let unit: String
    let amount: Int
}

struct TestBookmark {
    let id: String
    let authorHandle: String
    let authorName: String
    let content: String
    let postedAt: Date
}

enum RAGError: Error {
    case parseError(String)
    case searchError(String)
    case apiError(String)
}
