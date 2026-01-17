import Foundation

class AIService {
    static let shared = AIService()

    private let claudeAPI = ClaudeAPIService.shared

    // Rate limiting: 1.1 seconds between requests
    private var lastRequestTime: Date?
    private let minRequestInterval: TimeInterval = 1.1

    private init() {}

    // MARK: - Summarization

    /// Generate a short summary for a single bookmark
    func summarize(content: String, authorName: String) async throws -> String {
        await respectRateLimit()

        let systemPrompt = """
        You are a helpful assistant that creates concise summaries of tweets.
        Keep summaries to 1-2 sentences maximum. Focus on the main point or insight.
        Don't start with "This tweet" or "The author". Just state the key point directly.
        """

        let prompt = """
        Summarize this tweet from @\(authorName):

        \(content)
        """

        let response = try await claudeAPI.sendMessage(
            prompt: prompt,
            systemPrompt: systemPrompt,
            model: .haiku,
            maxTokens: 150
        )

        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Tag Suggestions

    struct TagSuggestion {
        let name: String
        let confidence: Double
    }

    /// Get tag suggestions for a bookmark based on its content
    func suggestTags(content: String, existingTags: [String]) async throws -> [TagSuggestion] {
        await respectRateLimit()

        let existingTagsList = existingTags.isEmpty ? "none" : existingTags.joined(separator: ", ")

        let systemPrompt = """
        You are a helpful assistant that suggests relevant tags for tweets.
        Return only tag names, one per line, with a confidence score 0-1.
        Format: tagname|0.85
        Suggest 3-5 tags maximum.
        Use lowercase, hyphenated tags (e.g., machine-learning, web-dev).
        Focus on topics, technologies, or themes mentioned.
        """

        let prompt = """
        Suggest tags for this tweet. Existing tags in the system: \(existingTagsList)

        Tweet:
        \(content)

        Return tags in format: tagname|confidence
        """

        let response = try await claudeAPI.sendMessage(
            prompt: prompt,
            systemPrompt: systemPrompt,
            model: .haiku,
            maxTokens: 100
        )

        return parseTagSuggestions(response)
    }

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
                // Just a tag name without confidence
                let name = trimmed.lowercased().replacingOccurrences(of: " ", with: "-")
                suggestions.append(TagSuggestion(name: name, confidence: 0.7))
            }
        }

        return suggestions.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Batch Processing

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

    /// Process multiple bookmarks for summarization
    func batchSummarize(
        bookmarks: [(id: String, content: String, authorName: String)],
        onProgress: @escaping (BatchProgress) -> Void,
        onComplete: @escaping (String, String) -> Void
    ) async {
        let total = bookmarks.count

        for (index, bookmark) in bookmarks.enumerated() {
            onProgress(BatchProgress(
                current: index,
                total: total,
                currentBookmarkId: bookmark.id,
                error: nil
            ))

            do {
                let summary = try await summarize(content: bookmark.content, authorName: bookmark.authorName)
                onComplete(bookmark.id, summary)
            } catch {
                onProgress(BatchProgress(
                    current: index,
                    total: total,
                    currentBookmarkId: bookmark.id,
                    error: error.localizedDescription
                ))
            }
        }

        onProgress(BatchProgress(
            current: total,
            total: total,
            currentBookmarkId: nil,
            error: nil
        ))
    }

    // MARK: - Rate Limiting

    private func respectRateLimit() async {
        if let lastTime = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minRequestInterval {
                let waitTime = minRequestInterval - elapsed
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
    }
}
