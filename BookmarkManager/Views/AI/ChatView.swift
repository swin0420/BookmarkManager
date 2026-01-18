import SwiftUI

struct ChatView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var inputText = ""
    @State private var messages: [ChatMessageItem] = []
    @State private var isParsing = false
    @State private var isSearching = false
    @State private var isThinking = false
    @State private var isStreaming = false
    @State private var streamingText = ""
    @State private var streamingBuffer = ""  // Buffer for batching updates
    @State private var foundCount = 0
    @State private var foundSources: [Bookmark] = []
    @State private var parsedKeywords: [String] = []
    @State private var showReferencedTweets = false
    @State private var currentSources: [Bookmark] = []

    struct ChatMessageItem: Identifiable {
        let id = UUID()
        let role: String
        let content: String
        let sources: [Bookmark]
        let timestamp: Date
        var followUpQuestions: [String] = []
    }

    var body: some View {
        ZStack {
            // Gradient glow on edges - simplified for performance
            HStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.15),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 4)

                Spacer()

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.cyan.opacity(0.15)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 4)
            }
            .ignoresSafeArea()
            .drawingGroup()

            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.cyan.opacity(0.6), Color.purple.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)

                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scout")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Text("POWERED BY YOUR BOOKMARKS")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(0.5)
                        }
                    }

                    Spacer()

                    // Clear chat button
                    Button(action: { clearChat() }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Start new chat")

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()
                    .background(Color.white.opacity(0.1))

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            if messages.isEmpty && !isSearching && !isThinking {
                                WelcomeView(onQuestionTap: { question in
                                    sendMessage(question)
                                })
                            }

                            ForEach(messages) { message in
                                ChatMessageView(
                                    message: message,
                                    onShowSources: {
                                        currentSources = message.sources
                                        showReferencedTweets = true
                                    },
                                    onFollowUpTap: { question in
                                        sendMessage(question)
                                    },
                                    onAddToFolder: { folderId in
                                        addSourcesToFolder(message.sources, folderId: folderId)
                                    },
                                    onAddTag: { tagId in
                                        addTagToSources(message.sources, tagId: tagId)
                                    }
                                )
                                .id(message.id)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                            // Loading states (parsing, searching, thinking)
                            if isParsing || isSearching || isThinking {
                                SearchingStateView(
                                    isParsing: isParsing,
                                    isSearching: isSearching,
                                    isThinking: isThinking,
                                    foundCount: foundCount,
                                    sources: foundSources,
                                    keywords: parsedKeywords
                                )
                                .id("loading")
                            }

                            // Streaming response (shows after first chunk arrives)
                            if isStreaming && !streamingText.isEmpty {
                                StreamingMessageView(text: streamingText, sources: foundSources)
                                    .id("streaming")
                                    .transition(.opacity)
                            }
                        }
                        .padding(.vertical, 20)
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            if let lastMessage = messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: isThinking) { _, newValue in
                        if newValue {
                            withAnimation {
                                proxy.scrollTo("loading", anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: streamingText) { oldValue, newValue in
                        // Only scroll when streaming text first appears or grows significantly
                        if oldValue.isEmpty && !newValue.isEmpty {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("streaming", anchor: .bottom)
                            }
                        } else if newValue.count - oldValue.count > 50 || newValue.contains("\n") && !oldValue.hasSuffix("\n") {
                            // Scroll on new paragraphs or significant content
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                // Input
                HStack(spacing: 12) {
                    TextField("Search...", text: $inputText)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .foregroundColor(.white)
                        .onSubmit {
                            if !inputText.isEmpty && !isSearching && !isThinking {
                                sendMessage(inputText)
                            }
                        }

                    Button(action: { sendMessage(inputText) }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16))
                            .foregroundColor(inputText.isEmpty ? .white.opacity(0.3) : .white)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(inputText.isEmpty ? Color.white.opacity(0.1) : Color.cyan.opacity(0.8))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.isEmpty || isSearching || isThinking)
                }
                .padding(16)
            }
        }
        .frame(width: 650, height: 750)
        .background(Color(red: 0.08, green: 0.08, blue: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            // Defer loading so sheet animation completes smoothly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                loadChatHistory()
            }
        }
        .sheet(isPresented: $showReferencedTweets) {
            ReferencedTweetsModal(sources: currentSources)
        }
    }

    private func clearChat() {
        dbManager.clearChatHistory()
        withAnimation(.easeOut(duration: 0.2)) {
            messages = []
            streamingText = ""
            streamingBuffer = ""
            isStreaming = false
        }
    }

    private func addSourcesToFolder(_ sources: [Bookmark], folderId: String) {
        let bookmarkIds = sources.map { $0.id }
        dbManager.moveBookmarksToFolder(bookmarkIds, folderId: folderId)
    }

    private func addTagToSources(_ sources: [Bookmark], tagId: String) {
        let bookmarkIds = sources.map { $0.id }
        dbManager.addTagToBookmarks(bookmarkIds, tagId: tagId)
    }

    private func loadChatHistory() {
        let history = dbManager.loadChatHistory()
        let allBookmarks = dbManager.searchBookmarks(limit: 10000)
        let bookmarkMap = Dictionary(uniqueKeysWithValues: allBookmarks.map { ($0.id, $0) })

        messages = history.map { msg in
            let sources = msg.contextBookmarkIds.compactMap { bookmarkMap[$0] }
            return ChatMessageItem(
                role: msg.role,
                content: msg.content,
                sources: sources,
                timestamp: msg.createdAt
            )
        }
    }

    private func sendMessage(_ text: String) {
        guard !text.isEmpty else { return }
        guard KeychainService.shared.hasClaudeAPIKey() else {
            messages.append(ChatMessageItem(
                role: "assistant",
                content: "Please add your Claude API key in Settings first.",
                sources: [],
                timestamp: Date()
            ))
            return
        }

        let userMessage = ChatMessageItem(
            role: "user",
            content: text,
            sources: [],
            timestamp: Date()
        )

        withAnimation(.easeOut(duration: 0.2)) {
            messages.append(userMessage)
        }
        inputText = ""

        // Reset states
        isParsing = true
        isSearching = false
        isThinking = false
        isStreaming = false
        streamingText = ""
        foundCount = 0
        foundSources = []
        parsedKeywords = []

        Task {
            do {
                // Phase 1: Parse query with Claude
                let searchParams = try await RAGService.shared.parseQuery(text)

                await MainActor.run {
                    parsedKeywords = searchParams.keywords
                    isParsing = false
                    isSearching = true
                }

                // Phase 2: Search bookmarks
                let sources = RAGService.shared.searchBookmarks(with: searchParams)

                await MainActor.run {
                    foundCount = sources.count
                    foundSources = sources
                    isSearching = false
                    isThinking = true
                }

                // Phase 3: Stream answer from Claude
                let history = messages.dropLast().map { msg in
                    ClaudeAPIService.Message(role: msg.role, content: msg.content)
                }

                // Keep isThinking true, set isStreaming true
                // The view will show streaming once first chunk arrives
                await MainActor.run {
                    isStreaming = true
                    streamingText = ""
                    streamingBuffer = ""
                }

                var firstChunkReceived = false
                var lastUpdateTime = Date()
                let updateInterval: TimeInterval = 0.05 // 50ms batching

                let response = try await RAGService.shared.askStreaming(
                    question: text,
                    conversationHistory: Array(history.suffix(10))
                ) { chunk in
                    DispatchQueue.main.async {
                        streamingBuffer += chunk

                        let now = Date()
                        let shouldUpdate = now.timeIntervalSince(lastUpdateTime) >= updateInterval
                            || streamingBuffer.contains("\n")
                            || !firstChunkReceived

                        if shouldUpdate {
                            // Hide "thinking" indicator on first chunk
                            if !firstChunkReceived {
                                firstChunkReceived = true
                                isThinking = false
                            }
                            streamingText += streamingBuffer
                            streamingBuffer = ""
                            lastUpdateTime = now
                        }
                    }
                }

                // Flush any remaining buffer
                await MainActor.run {
                    if !streamingBuffer.isEmpty {
                        streamingText += streamingBuffer
                        streamingBuffer = ""
                    }
                    isStreaming = false
                    isThinking = false
                    streamingText = ""
                    withAnimation(.easeOut(duration: 0.3)) {
                        messages.append(ChatMessageItem(
                            role: "assistant",
                            content: response.answer,
                            sources: response.sourceBookmarks,
                            timestamp: Date(),
                            followUpQuestions: response.followUpQuestions
                        ))
                    }
                }
            } catch {
                await MainActor.run {
                    messages.append(ChatMessageItem(
                        role: "assistant",
                        content: "Error: \(error.localizedDescription)",
                        sources: [],
                        timestamp: Date()
                    ))
                    isParsing = false
                    isSearching = false
                    isThinking = false
                    isStreaming = false
                    streamingText = ""
                    streamingBuffer = ""
                }
            }
        }
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    let onQuestionTap: (String) -> Void

    let suggestedQuestions = [
        "What are the main topics in my bookmarks?",
        "Summarize the tech-related tweets",
        "What are people saying about AI?",
        "Find interesting programming tips"
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Ask anything about your bookmarks")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 40)

            VStack(spacing: 10) {
                ForEach(suggestedQuestions, id: \.self) { question in
                    Button(action: { onQuestionTap(question) }) {
                        Text(question)
                            .font(.system(size: 13))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.cyan.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Searching State View

struct SearchingStateView: View {
    let isParsing: Bool
    let isSearching: Bool
    let isThinking: Bool
    let foundCount: Int
    let sources: [Bookmark]
    let keywords: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Phase 1: Understanding query
            HStack(spacing: 12) {
                if isParsing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Understanding query")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)

                    if !isParsing && !keywords.isEmpty {
                        Text("Keywords: \(keywords.joined(separator: ", "))")
                            .font(.system(size: 12))
                            .foregroundColor(.purple.opacity(0.8))
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
            )

            // Phase 2: Search status card
            if !isParsing {
                HStack(spacing: 12) {
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.green)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Searching bookmarks")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)

                        if !isSearching {
                            Text("Found \(foundCount) tweets")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    Spacer()

                    if !isSearching && !sources.isEmpty {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                )

                // Source avatars preview
                if !isSearching && !sources.isEmpty {
                    HStack(spacing: 8) {
                        Text("Source:")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))

                        // Stacked avatars
                        HStack(spacing: -8) {
                            ForEach(sources.prefix(5).indices, id: \.self) { index in
                                AsyncImage(url: URL(string: sources[index].authorAvatar ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(Color.purple.opacity(0.5))
                                }
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color(red: 0.08, green: 0.08, blue: 0.1), lineWidth: 2))
                            }

                            if sources.count > 5 {
                                Text("+\(sources.count - 5)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(Color.white.opacity(0.2)))
                            }
                        }

                        Text("\(sources.count) tweets")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.leading, 14)
                }
            }

            // Phase 3: Thinking indicator
            if isThinking {
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))

                    Text("Generating answer...")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.08))
                )
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Streaming Message View

struct StreamingMessageView: View {
    let text: String
    let sources: [Bookmark]

    @State private var cursorVisible = true

    // Clean up raw formatting for display during streaming
    private var displayText: String {
        var result = text

        // Remove ---FOLLOWUPS--- section and everything after
        if let markerRange = result.range(of: "---FOLLOWUPS---") {
            result = String(result[..<markerRange.lowerBound])
        }
        // Hide partial followups marker
        if let dashRange = result.range(of: "\n---FOLLOW", options: .backwards) {
            result = String(result[..<dashRange.lowerBound])
        }
        if let dashRange = result.range(of: "\n---", options: .backwards), result.hasSuffix("---") || result.hasSuffix("-") {
            result = String(result[..<dashRange.lowerBound])
        }

        // Replace [TWEET:id]@handle[/TWEET] with just @handle
        let tweetPattern = "\\[TWEET:[^\\]]+\\](@[a-zA-Z0-9_]+)\\[/TWEET\\]"
        if let regex = try? NSRegularExpression(pattern: tweetPattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "$1")
        }

        // Hide incomplete [TWEET: markers
        if let openBracket = result.range(of: "[TWEET:", options: .backwards) {
            if result.range(of: "[/TWEET]", range: openBracket.lowerBound..<result.endIndex) == nil {
                result = String(result[..<openBracket.lowerBound])
            }
        }

        // Clean up markdown for streaming display
        result = result
            .replacingOccurrences(of: "## ", with: "")  // Headers
            .replacingOccurrences(of: "**", with: "")    // Bold markers
            .replacingOccurrences(of: "- **", with: "• ") // List items

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            Text(displayText)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(4)
                .textSelection(.enabled)
                .animation(.none, value: displayText) // Disable text animation

            // Typing cursor
            Rectangle()
                .fill(Color.cyan)
                .frame(width: 2, height: 16)
                .opacity(cursorVisible ? 1 : 0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        cursorVisible.toggle()
                    }
                }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Chat Message View

struct ChatMessageView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let message: ChatView.ChatMessageItem
    let onShowSources: () -> Void
    let onFollowUpTap: (String) -> Void
    let onAddToFolder: (String) -> Void
    let onAddTag: (String) -> Void

    var isUser: Bool {
        message.role == "user"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isUser {
                // User message - blue pill on right
                HStack {
                    Spacer()
                    Text(message.content)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.cyan.opacity(0.8))
                        )
                }
                .padding(.horizontal, 20)
            } else {
                // Assistant message - formatted response
                VStack(alignment: .leading, spacing: 12) {
                    // Response content with clickable handles and inline tweets
                    FormattedResponseView(
                        content: message.content,
                        sources: message.sources
                    )
                    .padding(.horizontal, 20)

                    // Source preview bar
                    if !message.sources.isEmpty {
                        Button(action: onShowSources) {
                            HStack(spacing: 10) {
                                Text("Source:")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))

                                // Stacked avatars
                                HStack(spacing: -6) {
                                    ForEach(message.sources.prefix(4).indices, id: \.self) { index in
                                        AsyncImage(url: URL(string: message.sources[index].authorAvatar ?? "")) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Circle()
                                                .fill(Color.purple.opacity(0.5))
                                        }
                                        .frame(width: 22, height: 22)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color(red: 0.08, green: 0.08, blue: 0.1), lineWidth: 2))
                                    }

                                    if message.sources.count > 4 {
                                        Text("+\(message.sources.count - 4)")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(width: 22, height: 22)
                                            .background(Circle().fill(Color.white.opacity(0.2)))
                                    }
                                }

                                Text("\(message.sources.count) tweets")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.05))
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)

                        // Quick Actions Bar
                        QuickActionsBar(
                            sources: message.sources,
                            responseText: message.content,
                            onAddToFolder: onAddToFolder,
                            onAddTag: onAddTag
                        )
                        .padding(.horizontal, 20)
                    }

                    // Follow-up Questions
                    if !message.followUpQuestions.isEmpty {
                        FollowUpQuestionsView(
                            questions: message.followUpQuestions,
                            onTap: onFollowUpTap
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                    }
                }
            }
        }
    }
}

// MARK: - Follow-up Questions View

struct FollowUpQuestionsView: View {
    let questions: [String]
    let onTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Follow-up questions")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .textCase(.uppercase)
                .tracking(0.5)

            ChatFlowLayout(spacing: 8) {
                ForEach(questions, id: \.self) { question in
                    Button(action: { onTap(question) }) {
                        Text(question)
                            .font(.system(size: 12))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.cyan.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Flow Layout for Follow-up Questions

struct ChatFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

// MARK: - Quick Actions Bar

struct QuickActionsBar: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let sources: [Bookmark]
    let responseText: String
    let onAddToFolder: (String) -> Void
    let onAddTag: (String) -> Void

    @State private var showCopiedFeedback = false

    var body: some View {
        HStack(spacing: 16) {
            // Add to Folder
            Menu {
                ForEach(dbManager.folders) { folder in
                    Button(action: { onAddToFolder(folder.id) }) {
                        Label(folder.name, systemImage: "folder")
                    }
                }
            } label: {
                Label("Add to Folder", systemImage: "folder.badge.plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Add Tag
            Menu {
                ForEach(dbManager.tags) { tag in
                    Button(action: { onAddTag(tag.id) }) {
                        Label(tag.name, systemImage: "tag")
                    }
                }
            } label: {
                Label("Tag", systemImage: "tag")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Copy response
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(responseText, forType: .string)
                showCopiedFeedback = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showCopiedFeedback = false
                }
            }) {
                Label(showCopiedFeedback ? "Copied!" : "Copy", systemImage: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(showCopiedFeedback ? .green : .white.opacity(0.6))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
    }
}

// MARK: - Formatted Response View

struct FormattedResponseView: View {
    let content: String
    let sources: [Bookmark]

    // Parse content into segments (text and inline tweets)
    var segments: [ResponseSegment] {
        parseContent()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let text):
                    Text(attributedContent(for: text))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .textSelection(.enabled)
                        .lineSpacing(4)
                case .inlineTweet(let bookmarkId, _):
                    if let bookmark = sources.first(where: { $0.id == bookmarkId }) {
                        InlineTweetPreview(bookmark: bookmark)
                    }
                }
            }
        }
    }

    enum ResponseSegment {
        case text(String)
        case inlineTweet(bookmarkId: String, handle: String)
    }

    private func parseContent() -> [ResponseSegment] {
        var segments: [ResponseSegment] = []
        var currentText = ""
        var remaining = content

        // Pattern: [TWEET:bookmark_id]@handle[/TWEET]
        let pattern = "\\[TWEET:([^\\]]+)\\](@[a-zA-Z0-9_]+)\\[/TWEET\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(content)]
        }

        while !remaining.isEmpty {
            let nsString = remaining as NSString
            if let match = regex.firstMatch(in: remaining, range: NSRange(location: 0, length: nsString.length)) {
                // Add text before the match
                let beforeRange = NSRange(location: 0, length: match.range.location)
                let beforeText = nsString.substring(with: beforeRange)
                if !beforeText.isEmpty {
                    currentText += beforeText
                }

                // Save accumulated text as segment
                if !currentText.isEmpty {
                    segments.append(.text(currentText))
                    currentText = ""
                }

                // Extract bookmark ID and handle
                let bookmarkId = nsString.substring(with: match.range(at: 1))
                let handle = nsString.substring(with: match.range(at: 2))
                segments.append(.inlineTweet(bookmarkId: bookmarkId, handle: handle))

                // Continue with remaining text
                let afterStart = match.range.location + match.range.length
                remaining = String(nsString.substring(from: afterStart))
            } else {
                // No more matches, add remaining text
                currentText += remaining
                break
            }
        }

        // Add any remaining text
        if !currentText.isEmpty {
            segments.append(.text(currentText))
        }

        // If no segments found, return the entire content as text
        return segments.isEmpty ? [.text(content)] : segments
    }

    func attributedContent(for text: String) -> AttributedString {
        var result = AttributedString(text)

        // Find and style @handles
        let pattern = "@[a-zA-Z0-9_]+"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

            for match in matches {
                let handleRange = match.range
                let handle = nsString.substring(with: handleRange)

                if let range = result.range(of: handle) {
                    result[range].foregroundColor = .cyan
                    result[range].underlineStyle = .single

                    // Find matching source and add link
                    let handleWithoutAt = String(handle.dropFirst())
                    if let source = sources.first(where: { $0.authorHandle.lowercased() == handleWithoutAt.lowercased() }) {
                        if let url = URL(string: source.url) {
                            result[range].link = url
                        }
                    }
                }
            }
        }

        // Style bold text (between **)
        let boldPattern = "\\*\\*(.+?)\\*\\*"
        if let boldRegex = try? NSRegularExpression(pattern: boldPattern) {
            let nsString = text as NSString
            let matches = boldRegex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                let fullRange = match.range
                let fullText = nsString.substring(with: fullRange)

                if let range = result.range(of: fullText) {
                    let cleanText = fullText.replacingOccurrences(of: "**", with: "")
                    var replacement = AttributedString(cleanText)
                    replacement.font = .system(size: 14, weight: .semibold)
                    replacement.foregroundColor = .white
                    result.replaceSubrange(range, with: replacement)
                }
            }
        }

        return result
    }
}

// MARK: - Inline Tweet Preview

struct InlineTweetPreview: View {
    let bookmark: Bookmark

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: bookmark.postedAt)
    }

    private var truncatedContent: String {
        let maxLength = 80
        if bookmark.content.count <= maxLength {
            return bookmark.content
        }
        return String(bookmark.content.prefix(maxLength)) + "..."
    }

    var body: some View {
        HStack(spacing: 10) {
            // Avatar
            AsyncImage(url: URL(string: bookmark.authorAvatar ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.purple.opacity(0.3))
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                // Header: @handle · date
                HStack(spacing: 4) {
                    Text("@\(bookmark.authorHandle)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cyan)

                    Text("·")
                        .foregroundColor(.white.opacity(0.4))

                    Text(formattedDate)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }

                // Truncated content
                Text("\"\(truncatedContent)\"")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }

            Spacer()

            // Open button
            Button(action: {
                if let url = URL(string: bookmark.url) {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                )
        )
        .frame(maxWidth: 400)
    }
}

// MARK: - Referenced Tweets Modal

struct ReferencedTweetsModal: View {
    let sources: [Bookmark]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Results (\(sources.count))")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()
                .background(Color.white.opacity(0.1))

            // Tweet cards
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(sources) { bookmark in
                        TweetCard(bookmark: bookmark)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 450, height: 550)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
    }
}

// MARK: - Tweet Card

struct TweetCard: View {
    let bookmark: Bookmark

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy, h:mm a"
        return formatter.string(from: bookmark.postedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                AsyncImage(url: URL(string: bookmark.authorAvatar ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.purple.opacity(0.3))
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(bookmark.authorName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)

                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.cyan)
                    }

                    Text("@\(bookmark.authorHandle)")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                // X logo
                Text("𝕏")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Content
            Text(bookmark.content)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(4)

            // Date
            Text(formattedDate)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))

            // Open button
            Button(action: {
                if let url = URL(string: bookmark.url) {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11))
                    Text("Open on X")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.cyan)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
