# BookmarkManager - Claude Context

macOS SwiftUI app for managing Twitter/X bookmarks with AI-powered features.

## Architecture

```
BookmarkManager/
├── Models/           # Bookmark, Tag, Folder
├── Database/         # SQLite via DatabaseManager
├── Services/
│   ├── ClaudeAPIService    # Claude API + SSE streaming
│   ├── RAGService          # Parse → Search → Answer pipeline
│   ├── SemanticSearchService
│   └── EmbeddingService
├── Views/
│   ├── AI/           # ChatView, AISettingsView, BatchProcessingView
│   ├── SidebarView
│   ├── BookmarkGridView
│   └── FilterBarView
└── Styles/           # GlassmorphismStyle
```

## Scout Chat (ChatView.swift)

- **Streaming**: SSE via `URLSession.bytes`, batched UI updates (50ms)
- **Follow-ups**: Parsed from `---FOLLOWUPS---` marker in response
- **Inline tweets**: `[TWEET:id]@handle[/TWEET]` → compact preview cards
- **Quick actions**: Add to folder, tag, copy (below source bar)

## ClaudeAPIService

- `sendMessage()` - Single prompt
- `sendConversation()` - Multi-turn
- `streamConversation(onChunk:)` - Real-time streaming

## RAGService

- `parseQuery()` - Extract keywords/dates/authors via Haiku
- `searchBookmarks()` - Keyword + semantic hybrid search
- `ask()` / `askStreaming()` - Full RAG with context injection

## Database (SQLite)

Tables: `bookmarks`, `folders`, `tags`, `bookmark_tags`, `chat_history`, `embeddings`

## UI

Dark theme, purple/cyan gradients, glassmorphism. App icon: bookmark + sparkles.
