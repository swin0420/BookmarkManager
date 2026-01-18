# BookmarkManager

A macOS app for managing Twitter/X bookmarks with AI-powered search and chat.

## Features

- **Import & Organize** - Import bookmarks from JSON, organize with folders and tags
- **Smart Search** - Full-text and semantic search across all bookmarks
- **AI Chat (Scout)** - Ask questions about your bookmarks using natural language

### Scout AI Features

- **Streaming Responses** - See answers as they generate in real-time
- **Inline Tweet Previews** - Cited tweets appear as compact cards
- **Follow-up Suggestions** - Clickable question suggestions after each response
- **Quick Actions** - Add sources to folders, apply tags, or copy responses

## Requirements

- macOS 14.0+
- Claude API key (for AI features)

## Setup

1. Build and run in Xcode
2. Go to Settings and add your Claude API key
3. Import your bookmarks (JSON format)
4. Click the sparkles icon to open Scout chat

## Building

```bash
xcodebuild -scheme BookmarkManager -configuration Release build
```

## Creating DMG

```bash
# Build release version
xcodebuild -scheme BookmarkManager -configuration Release build

# Create DMG (requires create-dmg or similar tool)
create-dmg 'BookmarkManager.dmg' 'path/to/BookmarkManager.app'
```
