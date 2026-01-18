# BookmarkManager - Claude Context

## Project Overview

macOS SwiftUI app for managing Twitter/X bookmarks with AI-powered features.

## Architecture

```
BookmarkManager/
├── Models/           # Bookmark, Tag, Folder data models
├── Database/         # SQLite via DatabaseManager
├── Services/         # API and AI services
│   ├── ClaudeAPIService    # Claude API with streaming SSE
│   ├── RAGService          # Retrieval-augmented generation
│   ├── SemanticSearchService
│   └── EmbeddingService
├── Views/
│   ├── AI/           # ChatView, AISettingsView
│   ├── SidebarView
│   ├── BookmarkGridView
│   └── FilterBarView
└── Styles/           # GlassmorphismStyle
```

## Key Components

### Scout Chat (ChatView.swift)
- Streaming responses with batched UI updates (50ms)
- Follow-up question suggestions parsed from `---FOLLOWUPS---` marker
- Inline tweet previews via `[TWEET:id]@handle[/TWEET]` markers
- Quick actions bar (folder, tag, copy)

### ClaudeAPIService
- `sendMessage()` - Single message
- `sendConversation()` - Multi-turn chat
- `streamConversation()` - SSE streaming with `onChunk` callback

### RAGService
- `parseQuery()` - Extract search params with Haiku
- `searchBookmarks()` - Keyword + semantic search
- `ask()` / `askStreaming()` - Full RAG pipeline

## Database

SQLite with tables: bookmarks, folders, tags, bookmark_tags, chat_history, embeddings

## UI Style

Dark theme with purple/cyan gradients, glassmorphism effects.
