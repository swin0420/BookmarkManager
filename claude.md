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

---

## State Machine Diagrams

### Scout Chat States

```
                              ┌─────────────┐
                              │    IDLE     │
                              │  (Welcome)  │
                              └──────┬──────┘
                                     │ user sends message
                                     ▼
                              ┌─────────────┐
                              │   PARSING   │
                              │ "Understanding│
                              │   query..."  │
                              └──────┬──────┘
                                     │ keywords extracted
                                     ▼
                              ┌─────────────┐
                              │  SEARCHING  │
                              │ "Searching  │
                              │ bookmarks..." │
                              └──────┬──────┘
                                     │ sources found
                                     ▼
                              ┌─────────────┐
                              │  THINKING   │
                              │ "Generating │
                              │  answer..." │
                              └──────┬──────┘
                                     │ first chunk arrives
                                     ▼
                              ┌─────────────┐
                              │  STREAMING  │
                              │ text appears │
                              │ + cursor    │
                              └──────┬──────┘
                                     │ stream complete
                                     ▼
                              ┌─────────────┐
                              │  COMPLETE   │
                              │ full message │
                              │ + follow-ups │
                              └──────┬──────┘
                                     │
                      ┌──────────────┴──────────────┐
                      ▼                              ▼
               [user asks]                    [click follow-up]
               new question                      question
                      │                              │
                      └──────────────┬───────────────┘
                                     ▼
                                 PARSING
```

### RAG Pipeline

```
  Question
     │
     ▼
┌──────────┐    keywords,     ┌──────────┐    relevant    ┌──────────┐
│  PARSE   │───dates, authors─▶│  SEARCH  │────bookmarks──▶│ CONTEXT  │
│  QUERY   │                  │BOOKMARKS │               │  BUILD   │
└──────────┘                  └──────────┘               └────┬─────┘
     │                              │                         │
  Haiku LLM                   Keyword +                  Format for
                              Semantic                     Claude
                                                             │
                                                             ▼
┌──────────┐    clean answer  ┌──────────┐    stream     ┌──────────┐
│  PARSE   │◀───+ follow-ups──│ GENERATE │◀───chunks─────│  CALL    │
│ RESPONSE │                  │  ANSWER  │               │  CLAUDE  │
└────┬─────┘                  └──────────┘               └──────────┘
     │
     ▼
   SAVE HISTORY
```

### Streaming Connection

```
┌────────────┐
│   IDLE     │
└─────┬──────┘
      │ streamConversation() called
      ▼
┌────────────┐
│ CONNECTING │──────────────────┐
└─────┬──────┘                  │
      │ HTTP 200                │ HTTP 429
      ▼                         ▼
┌────────────┐            ┌────────────┐
│ STREAMING  │            │RATE LIMITED│
│            │            └────────────┘
│  Buffer    │                  │
│    ↓       │                  ▼
│ parse SSE  │            ┌────────────┐
│    ↓       │            │   ERROR    │
│ onChunk()  │            └────────────┘
└─────┬──────┘
      │ [DONE]
      ▼
┌────────────┐
│ COMPLETE   │
└────────────┘
```

### Bookmark View States

```
                    ┌──────────────┐
                    │    NORMAL    │
                    │   (browse)   │
                    └───────┬──────┘
                            │
         ┌──────────────────┼──────────────────┐
         ▼                  ▼                  ▼
  ┌────────────┐    ┌────────────┐    ┌────────────┐
  │ SELECTION  │    │  FILTERED  │    │ SEARCHING  │
  │    MODE    │    │   (folder/ │    │  (query)   │
  │ (bulk ops) │    │    tag)    │    │            │
  └─────┬──────┘    └─────┬──────┘    └─────┬──────┘
        │                 │                 │
        └─────────────────┴─────────────────┘
                          │
                          ▼
                   ┌────────────┐
                   │  CONTEXT   │
                   │   MENU     │──▶ Move / Tag / Favorite / Delete
                   └────────────┘
```

### Database Import

```
┌─────────┐   import    ┌──────────┐   process   ┌─────────────┐
│  IDLE   │────JSON────▶│ IMPORTING│────each────▶│  UPSERTING  │
└─────────┘             └──────────┘   bookmark  └──────┬──────┘
                                                       │
                                                       ▼
                                    ┌──────────┐  notify   ┌─────────┐
                                    │  DONE    │──views───▶│ REFRESH │
                                    └──────────┘           └─────────┘
```
