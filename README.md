# BookmarkManager

A macOS app for managing Twitter/X bookmarks with AI-powered search and chat.

## Download

Get the latest release from [Releases](../../releases) - download the `.dmg`, open it, and drag to Applications.

## Features

- **Import & Organize** - Import bookmarks from JSON, organize with folders and tags
- **Smart Search** - Full-text and semantic search across all bookmarks
- **AI Chat (Scout)** - Ask questions about your bookmarks using natural language

### Scout AI

- **Streaming Responses** - See answers generate in real-time
- **Inline Tweet Previews** - Cited tweets appear as compact cards
- **Follow-up Suggestions** - Clickable questions after each response
- **Quick Actions** - Add sources to folders, apply tags, copy responses

## Requirements

- macOS 14.0+
- Claude API key (for AI features)

## Setup

1. Download DMG from Releases and install
2. Open Settings → Add your Claude API key
3. Import bookmarks (JSON format)
4. Click sparkles icon to open Scout

## Build from Source

```bash
git clone https://github.com/YOUR_USERNAME/BookmarkManager.git
cd BookmarkManager
xcodebuild -scheme BookmarkManager -configuration Release build
```

## License

MIT
