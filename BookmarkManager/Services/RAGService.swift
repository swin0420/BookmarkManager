import Foundation

class RAGService {
    static let shared = RAGService()

    private let claudeAPI = ClaudeAPIService.shared
    private let semanticSearch = SemanticSearchService.shared
    private let dbManager = DatabaseManager.shared

    private init() {}

    // MARK: - Public API

    struct RAGResponse {
        let answer: String
        let sourceBookmarks: [Bookmark]
        let searchParams: SearchParams?
        let followUpQuestions: [String]
    }

    struct SearchParams: Codable {
        let keywords: [String]
        let dateRange: DateRange?
        let authors: [String]?
        let topics: [String]?

        struct DateRange: Codable {
            let unit: String  // "days", "weeks", "months", "years"
            let amount: Int
        }
    }

    /// Parse user query using Claude to extract search parameters
    func parseQuery(_ question: String) async throws -> SearchParams {
        let systemPrompt = """
        You are a search query parser. Extract search parameters from the user's question about their Twitter/X bookmarks.

        Return ONLY valid JSON in this exact format (no markdown, no explanation):
        {
            "keywords": ["keyword1", "keyword2"],
            "dateRange": {"unit": "months", "amount": 3},
            "authors": ["handle1", "handle2"],
            "topics": ["topic1", "topic2"]
        }

        Rules:
        - keywords: Important search terms (nouns, topics, specific words). Exclude common words like "tell", "show", "find", "bookmarks", "tweets", "saved".
        - dateRange: If user mentions time like "last 3 months", "past week", "yesterday". Use unit: "days"/"weeks"/"months"/"years". Set to null if no time mentioned.
        - authors: Twitter handles if user mentions specific people (without @). Set to null if none.
        - topics: General topics/categories mentioned. Set to null if just searching keywords.

        Examples:
        - "anime tweets from last 3 months" → {"keywords": ["anime"], "dateRange": {"unit": "months", "amount": 3}, "authors": null, "topics": ["anime", "entertainment"]}
        - "what did @elonmusk say about AI" → {"keywords": ["AI"], "dateRange": null, "authors": ["elonmusk"], "topics": ["AI", "technology"]}
        - "crypto news" → {"keywords": ["crypto", "news"], "dateRange": null, "authors": null, "topics": ["cryptocurrency", "finance"]}
        """

        let response = try await claudeAPI.sendMessage(
            prompt: question,
            systemPrompt: systemPrompt,
            model: .haiku,
            maxTokens: 500
        )

        // Parse JSON response
        let cleanedResponse = response
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        guard let data = cleanedResponse.data(using: String.Encoding.utf8) else {
            throw RAGError.parseError("Failed to convert response to data")
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(SearchParams.self, from: data)
        } catch {
            // Fallback: extract keywords manually
            let words = question.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 3 }
            return SearchParams(keywords: words, dateRange: nil, authors: nil, topics: nil)
        }
    }

    /// Search bookmarks using parsed parameters
    func searchBookmarks(with params: SearchParams) -> [Bookmark] {
        var allBookmarks = dbManager.searchBookmarks(limit: 10000)
            .sorted { $0.postedAt > $1.postedAt }

        // Apply date filter
        if let dateRange = params.dateRange {
            let component: Calendar.Component
            switch dateRange.unit.lowercased() {
            case "days", "day": component = .day
            case "weeks", "week": component = .weekOfYear
            case "months", "month": component = .month
            case "years", "year": component = .year
            default: component = .month
            }

            if let minDate = Calendar.current.date(byAdding: component, value: -dateRange.amount, to: Date()) {
                allBookmarks = allBookmarks.filter { $0.postedAt >= minDate }
            }
        }

        var relevantBookmarks: [Bookmark] = []
        var addedIds = Set<String>()

        // Filter by author if specified
        if let authors = params.authors, !authors.isEmpty {
            let authorSet = Set(authors.map { $0.lowercased() })
            for bookmark in allBookmarks {
                if authorSet.contains(bookmark.authorHandle.lowercased()) {
                    relevantBookmarks.append(bookmark)
                    addedIds.insert(bookmark.id)
                }
                if relevantBookmarks.count >= 30 { break }
            }
        }

        // Keyword search
        let keywords = params.keywords.map { $0.lowercased() }
        if !keywords.isEmpty {
            for bookmark in allBookmarks {
                guard !addedIds.contains(bookmark.id) else { continue }

                let content = bookmark.content.lowercased()
                let authorHandle = bookmark.authorHandle.lowercased()
                let authorName = bookmark.authorName.lowercased()

                for keyword in keywords {
                    if content.contains(keyword) || authorHandle.contains(keyword) || authorName.contains(keyword) {
                        relevantBookmarks.append(bookmark)
                        addedIds.insert(bookmark.id)
                        break
                    }
                }

                if relevantBookmarks.count >= 30 { break }
            }
        }

        // If still not enough, try semantic search
        if relevantBookmarks.count < 20 {
            let query = (params.keywords + (params.topics ?? [])).joined(separator: " ")
            if !query.isEmpty {
                let searchResults = semanticSearch.search(query: query, limit: 20)
                let bookmarkMap = Dictionary(uniqueKeysWithValues: allBookmarks.map { ($0.id, $0) })

                for result in searchResults {
                    guard !addedIds.contains(result.bookmarkId) else { continue }
                    if let bookmark = bookmarkMap[result.bookmarkId] {
                        relevantBookmarks.append(bookmark)
                        addedIds.insert(bookmark.id)
                    }
                    if relevantBookmarks.count >= 30 { break }
                }
            }
        }

        return relevantBookmarks
    }

    /// Full RAG pipeline: Parse → Search → Answer
    func ask(question: String, conversationHistory: [ClaudeAPIService.Message] = []) async throws -> RAGResponse {
        // Step 1: Parse query with Claude
        let searchParams = try await parseQuery(question)

        // Step 2: Search bookmarks
        let relevantBookmarks = searchBookmarks(with: searchParams)

        // Step 3: Build context and get answer from Claude
        let context = buildContext(from: relevantBookmarks, includeIds: true)

        let systemPrompt = buildSystemPrompt(context: context)

        var messages = conversationHistory
        messages.append(ClaudeAPIService.Message(role: "user", content: question))

        let response = try await claudeAPI.sendConversation(
            messages: messages,
            systemPrompt: systemPrompt,
            model: .sonnet,
            maxTokens: 1500
        )

        // Parse follow-up questions from response
        let (cleanAnswer, followUps) = parseFollowUps(from: response)

        // Save to chat history
        let questionId = UUID().uuidString
        let answerId = UUID().uuidString
        let contextIds = relevantBookmarks.map { $0.id }

        dbManager.saveChatMessage(id: questionId, role: "user", content: question, contextBookmarkIds: nil)
        dbManager.saveChatMessage(id: answerId, role: "assistant", content: cleanAnswer, contextBookmarkIds: contextIds)

        return RAGResponse(answer: cleanAnswer, sourceBookmarks: relevantBookmarks, searchParams: searchParams, followUpQuestions: followUps)
    }

    /// Streaming RAG pipeline: Parse → Search → Stream Answer
    func askStreaming(
        question: String,
        conversationHistory: [ClaudeAPIService.Message] = [],
        onChunk: @escaping (String) -> Void
    ) async throws -> RAGResponse {
        // Step 1: Parse query with Claude
        let searchParams = try await parseQuery(question)

        // Step 2: Search bookmarks
        let relevantBookmarks = searchBookmarks(with: searchParams)

        // Step 3: Build context and stream answer from Claude
        let context = buildContext(from: relevantBookmarks, includeIds: true)

        let systemPrompt = buildSystemPrompt(context: context)

        var messages = conversationHistory
        messages.append(ClaudeAPIService.Message(role: "user", content: question))

        let response = try await claudeAPI.streamConversation(
            messages: messages,
            systemPrompt: systemPrompt,
            model: .sonnet,
            maxTokens: 1500,
            onChunk: onChunk
        )

        // Parse follow-up questions from response
        let (cleanAnswer, followUps) = parseFollowUps(from: response)

        // Save to chat history
        let questionId = UUID().uuidString
        let answerId = UUID().uuidString
        let contextIds = relevantBookmarks.map { $0.id }

        dbManager.saveChatMessage(id: questionId, role: "user", content: question, contextBookmarkIds: nil)
        dbManager.saveChatMessage(id: answerId, role: "assistant", content: cleanAnswer, contextBookmarkIds: contextIds)

        return RAGResponse(answer: cleanAnswer, sourceBookmarks: relevantBookmarks, searchParams: searchParams, followUpQuestions: followUps)
    }

    /// Build the system prompt for RAG queries
    private func buildSystemPrompt(context: String) -> String {
        return """
        You are a helpful assistant that answers questions about the user's saved Twitter/X bookmarks.

        CONTEXT - These are the bookmarks found based on the user's query:
        \(context)

        Instructions:
        - Answer based ONLY on the bookmarks provided above
        - If the bookmarks don't contain relevant information, say so honestly
        - When citing specific tweets, use the format [TWEET:bookmark_id]@handle[/TWEET] where bookmark_id is the ID from the context
        - Include the date when relevant
        - Format your response clearly with bullet points or numbered lists when appropriate
        - For technical terms or code, use `backticks`
        - Keep answers informative but concise

        At the end of your response, suggest 2-3 natural follow-up questions the user might ask.
        Format them after a "---FOLLOWUPS---" marker, one per line. These should be relevant to the topic discussed.
        """
    }

    /// Parse follow-up questions from response
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
            .filter { !$0.isEmpty && !$0.hasPrefix("-") || $0.hasPrefix("-") }
            .map { line -> String in
                // Remove leading bullets or numbers
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

    /// Get suggested questions based on bookmarks
    func getSuggestedQuestions() -> [String] {
        return [
            "What are the main topics in my bookmarks?",
            "Summarize the tech tweets from last week",
            "What are people saying about AI?",
            "Find crypto-related tweets from last month"
        ]
    }

    // MARK: - Private

    private func buildContext(from bookmarks: [Bookmark], includeIds: Bool = false) -> String {
        guard !bookmarks.isEmpty else {
            return "No bookmarks found matching the search criteria."
        }

        var context = ""
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"

        for (index, bookmark) in bookmarks.enumerated() {
            let date = dateFormatter.string(from: bookmark.postedAt)
            if includeIds {
                context += """
                [\(index + 1)] ID:\(bookmark.id) @\(bookmark.authorHandle) (\(bookmark.authorName)) - \(date):
                \(bookmark.content)
                ---
                """
            } else {
                context += """
                [\(index + 1)] @\(bookmark.authorHandle) (\(bookmark.authorName)) - \(date):
                \(bookmark.content)
                ---
                """
            }
        }

        return context
    }
}

enum RAGError: Error {
    case parseError(String)
    case searchError(String)
    case apiError(String)
}
