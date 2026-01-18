# BookmarkManager

A native macOS app for managing your Twitter/X bookmarks with AI-powered search and chat, paired with a Chrome extension for exporting bookmarks from Twitter.

## Features

### macOS App
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

### Chrome Extension
- **One-click export** from Twitter bookmarks page
- **Auto-scroll** to capture all bookmarks
- **Continue from last export** - resume where you left off
- **Captures full tweet data** - text, author, date, media URLs

## Requirements

- macOS 14.0+
- Claude API key (for AI features)
- Chrome/Brave browser (for extension)

## Installation

### macOS App

**From Release:**
1. Download `BookmarkManager.dmg` from [Releases](../../releases)
2. Open the DMG and drag to Applications
3. Add your Claude API key in Settings

**Build from Source:**
```bash
git clone https://github.com/swin0420/BookmarkManager.git
cd BookmarkManager
xcodebuild -scheme BookmarkManager -configuration Release build
```

### Chrome Extension

1. Open Chrome and go to `chrome://extensions`
2. Enable **Developer mode** (toggle in top right)
3. Click **Load unpacked**
4. Select the `extension` folder from this repo

## Usage

### Exporting Bookmarks

1. Go to [x.com/i/bookmarks](https://x.com/i/bookmarks) in Chrome
2. Click the extension icon in toolbar
3. Configure options:
   - **Auto-scroll** - automatically load more bookmarks
   - **Continue from last export** - skip already exported
4. Click **Export** and save the JSON file

### Importing to App

1. Open BookmarkManager
2. Click **File → Import** or drag JSON into the app
3. Duplicates are automatically handled

### Using Scout AI

1. Click the **sparkles icon** to open Scout
2. Ask questions like:
   - "What are people saying about AI?"
   - "Show me tweets from @username"
   - "Summarize the tech tweets from last week"
3. Click follow-up suggestions or type new questions

### Organizing

- **Create folders** - click + next to Folders in sidebar
- **Create tags** - click + next to Tags in sidebar
- **Move/tag** - right-click bookmark or use bulk actions

## Project Structure

```
BookmarkManager/
├── BookmarkManager/      # macOS SwiftUI app
│   ├── Models/
│   ├── Database/
│   ├── Services/         # Claude API, RAG, Search
│   └── Views/
└── extension/            # Chrome extension
    ├── manifest.json
    ├── popup.html
    └── popup.js
```

## Data Privacy

All data is stored **locally on your machine**:
- Database in `~/Library/Application Support/BookmarkManager/`
- API calls go directly to Claude (Anthropic)
- No intermediary servers
- Your bookmarks stay private

## License

MIT
