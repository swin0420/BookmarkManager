# BookmarkManager

A native macOS app for managing your Twitter/X bookmarks with AI-powered search and chat.

## Features

### Core
- **Beautiful dark UI** with glassmorphism design
- **Full-text search** across all bookmarks
- **Semantic search** - find bookmarks by meaning, not just keywords
- **Folders & Tags** - organize bookmarks with custom colors
- **Filter by author** or date range
- **Favorites** - star your most important bookmarks
- **Bulk actions** - select multiple bookmarks to move, tag, or delete
- **Media preview** - see images and video thumbnails inline

### Scout AI Chat
- **Natural language queries** - ask questions about your bookmarks
- **Streaming responses** - see answers generate in real-time
- **Inline tweet previews** - cited tweets appear as compact cards
- **Follow-up suggestions** - clickable questions after each response
- **Quick actions** - add sources to folders, apply tags, copy responses
- **Conversation history** - continue previous chats

## Requirements

- macOS 14.0+
- Claude API key (for AI features)

## Installation

### From Release
1. Download `BookmarkManager.dmg` from [Releases](../../releases)
2. Open the DMG and drag to Applications
3. Open the app and add your Claude API key in Settings

### Build from Source
```bash
git clone https://github.com/swin0420/BookmarkManager.git
cd BookmarkManager
xcodebuild -scheme BookmarkManager -configuration Release build
```

## Usage

### Importing Bookmarks
1. Export bookmarks from Twitter using a compatible extension
2. Click **File → Import** or drag JSON file into the app
3. Duplicates are automatically handled

### Using Scout AI
1. Click the **sparkles icon** in the header to open Scout
2. Ask questions like:
   - "What are people saying about AI?"
   - "Show me tweets from @username"
   - "Summarize the tech tweets from last week"
3. Click follow-up suggestions or type new questions
4. Use quick actions to organize sources

### Organizing Bookmarks
- **Create folders** - click + next to Folders in sidebar
- **Create tags** - click + next to Tags in sidebar
- **Move to folder** - right-click bookmark or use bulk actions
- **Add tags** - right-click bookmark or use bulk actions

## Project Structure

```
BookmarkManager/
├── Models/           # Bookmark, Tag, Folder
├── Database/         # SQLite via DatabaseManager
├── Services/
│   ├── ClaudeAPIService    # Claude API + SSE streaming
│   ├── RAGService          # AI search pipeline
│   ├── SemanticSearchService
│   └── EmbeddingService
├── Views/
│   ├── AI/           # ChatView, AISettingsView
│   ├── SidebarView
│   ├── BookmarkGridView
│   └── FilterBarView
└── Styles/           # GlassmorphismStyle
```

## Data Privacy

All data is stored **locally on your machine**:
- Database in `~/Library/Application Support/BookmarkManager/`
- API calls go directly to Claude (Anthropic)
- No intermediary servers
- Your bookmarks stay private

## License

MIT
