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
    }

    /// Ask a question about bookmarks using RAG
    func ask(question: String, conversationHistory: [ClaudeAPIService.Message] = []) async throws -> RAGResponse {
        // 1. Find relevant bookmarks using semantic search
        let searchResults = semanticSearch.search(query: question, limit: 10)

        // 2. Load the actual bookmarks
        let allBookmarks = dbManager.searchBookmarks(limit: 10000)
        let bookmarkMap = Dictionary(uniqueKeysWithValues: allBookmarks.map { ($0.id, $0) })

        var relevantBookmarks: [Bookmark] = []
        for result in searchResults {
            if let bookmark = bookmarkMap[result.bookmarkId] {
                relevantBookmarks.append(bookmark)
            }
        }

        // 3. Build context from bookmarks
        let context = buildContext(from: relevantBookmarks)

        // 4. Build system prompt
        let systemPrompt = """
        You are a helpful assistant that answers questions about the user's saved Twitter/X bookmarks.
        You have access to the following bookmarks as context. Use them to answer questions accurately.
        If the bookmarks don't contain relevant information, say so honestly.
        Always cite which bookmark(s) you're referencing in your answer by mentioning the author's handle.
        Keep answers concise but informative.

        CONTEXT (Bookmarks):
        \(context)
        """

        // 5. Build messages
        var messages = conversationHistory
        messages.append(ClaudeAPIService.Message(role: "user", content: question))

        // 6. Call Claude API
        let response = try await claudeAPI.sendConversation(
            messages: messages,
            systemPrompt: systemPrompt,
            model: .sonnet,
            maxTokens: 1024
        )

        // 7. Save to chat history
        let questionId = UUID().uuidString
        let answerId = UUID().uuidString
        let contextIds = relevantBookmarks.map { $0.id }

        dbManager.saveChatMessage(id: questionId, role: "user", content: question, contextBookmarkIds: nil)
        dbManager.saveChatMessage(id: answerId, role: "assistant", content: response, contextBookmarkIds: contextIds)

        return RAGResponse(answer: response, sourceBookmarks: relevantBookmarks)
    }

    /// Get suggested questions based on bookmarks
    func getSuggestedQuestions() -> [String] {
        return [
            "What are the main topics in my bookmarks?",
            "Summarize the tech-related tweets I've saved",
            "What are people saying about AI/ML?",
            "Find interesting programming tips",
            "What trending discussions have I bookmarked?"
        ]
    }

    // MARK: - Private

    private func buildContext(from bookmarks: [Bookmark]) -> String {
        var context = ""

        for (index, bookmark) in bookmarks.enumerated() {
            context += """
            [\(index + 1)] @\(bookmark.authorHandle) (\(bookmark.authorName)):
            \(bookmark.content)
            ---
            """
        }

        return context
    }
}
