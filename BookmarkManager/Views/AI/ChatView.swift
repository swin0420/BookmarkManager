import SwiftUI

struct ChatView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var inputText = ""
    @State private var messages: [ChatMessageItem] = []
    @State private var isLoading = false
    @State private var showSources = false
    @State private var currentSources: [Bookmark] = []

    struct ChatMessageItem: Identifiable {
        let id = UUID()
        let role: String
        let content: String
        let sources: [Bookmark]
        let timestamp: Date
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "brain")
                        .font(.system(size: 18))
                        .foregroundColor(.purple)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Chat with Bookmarks")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Ask questions about your saved tweets")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                Spacer()

                Button(action: clearChat) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Clear chat history")

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.sidebarBackground)

            Divider()
                .background(Color.white.opacity(0.1))

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if messages.isEmpty && !isLoading {
                            // Suggested questions
                            VStack(spacing: 12) {
                                Text("Try asking:")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.top, 20)

                                ForEach(RAGService.shared.getSuggestedQuestions(), id: \.self) { question in
                                    Button(action: { sendMessage(question) }) {
                                        Text(question)
                                            .font(.system(size: 13))
                                            .foregroundColor(.purple)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .fill(Color.purple.opacity(0.15))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }

                        ForEach(messages) { message in
                            MessageBubble(
                                message: message,
                                onShowSources: {
                                    currentSources = message.sources
                                    showSources = true
                                }
                            )
                            .id(message.id)
                        }

                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                                Text("Thinking...")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .id("loading")
                        }
                    }
                    .padding(.vertical, 16)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation {
                        if let lastMessage = messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Input
            HStack(spacing: 12) {
                TextField("Ask about your bookmarks...", text: $inputText)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.08))
                    )
                    .foregroundColor(.white)
                    .onSubmit {
                        if !inputText.isEmpty {
                            sendMessage(inputText)
                        }
                    }

                Button(action: { sendMessage(inputText) }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(inputText.isEmpty ? .white.opacity(0.3) : .purple)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding(16)
            .background(Color.sidebarBackground)
        }
        .frame(width: 500, height: 600)
        .background(Color.cardBackground)
        .onAppear {
            loadChatHistory()
        }
        .sheet(isPresented: $showSources) {
            SourcesSheet(sources: currentSources)
        }
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
        messages.append(userMessage)
        inputText = ""
        isLoading = true

        Task {
            do {
                // Build conversation history for context
                let history = messages.dropLast().map { msg in
                    ClaudeAPIService.Message(role: msg.role, content: msg.content)
                }

                let response = try await RAGService.shared.ask(
                    question: text,
                    conversationHistory: Array(history.suffix(10))  // Keep last 10 messages for context
                )

                await MainActor.run {
                    messages.append(ChatMessageItem(
                        role: "assistant",
                        content: response.answer,
                        sources: response.sourceBookmarks,
                        timestamp: Date()
                    ))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    messages.append(ChatMessageItem(
                        role: "assistant",
                        content: "Error: \(error.localizedDescription)",
                        sources: [],
                        timestamp: Date()
                    ))
                    isLoading = false
                }
            }
        }
    }

    private func clearChat() {
        dbManager.clearChatHistory()
        messages = []
    }
}

struct MessageBubble: View {
    let message: ChatView.ChatMessageItem
    let onShowSources: () -> Void

    var isUser: Bool {
        message.role == "user"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(isUser ? .white : .white.opacity(0.9))
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isUser ? Color.purple : Color.white.opacity(0.1))
                    )

                if !isUser && !message.sources.isEmpty {
                    Button(action: onShowSources) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 10))
                            Text("\(message.sources.count) sources")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.purple)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !isUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct SourcesSheet: View {
    let sources: [Bookmark]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sources")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()
                .background(Color.white.opacity(0.1))

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(sources) { bookmark in
                        SourceCard(bookmark: bookmark)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 400, height: 500)
        .background(Color.cardBackground)
    }
}

struct SourceCard: View {
    let bookmark: Bookmark

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AsyncImage(url: URL(string: bookmark.authorAvatar ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Circle()
                        .fill(Color.purple.opacity(0.3))
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())

                Text("@\(bookmark.authorHandle)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                Button(action: {
                    if let url = URL(string: bookmark.url) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            Text(bookmark.content)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
}
