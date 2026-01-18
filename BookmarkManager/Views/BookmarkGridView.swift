import SwiftUI

struct BookmarkGridView: View {
    let bookmarks: [Bookmark]
    let accentColor: Color
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var dbManager: DatabaseManager

    private var column1: [Bookmark] {
        stride(from: 0, to: bookmarks.count, by: 3).compactMap { bookmarks.indices.contains($0) ? bookmarks[$0] : nil }
    }

    private var column2: [Bookmark] {
        stride(from: 1, to: bookmarks.count, by: 3).compactMap { bookmarks.indices.contains($0) ? bookmarks[$0] : nil }
    }

    private var column3: [Bookmark] {
        stride(from: 2, to: bookmarks.count, by: 3).compactMap { bookmarks.indices.contains($0) ? bookmarks[$0] : nil }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            LazyVStack(spacing: 16) {
                ForEach(column1) { bookmark in
                    BookmarkCardView(bookmark: bookmark, accentColor: accentColor)
                }
            }
            .frame(maxWidth: .infinity)

            LazyVStack(spacing: 16) {
                ForEach(column2) { bookmark in
                    BookmarkCardView(bookmark: bookmark, accentColor: accentColor)
                }
            }
            .frame(maxWidth: .infinity)

            LazyVStack(spacing: 16) {
                ForEach(column3) { bookmark in
                    BookmarkCardView(bookmark: bookmark, accentColor: accentColor)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(24)
    }
}

struct BookmarkCardView: View {
    let bookmark: Bookmark
    let accentColor: Color

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var isHovered = false
    @State private var showDetailSheet = false
    @State private var isGeneratingSummary = false
    @State private var showTagSuggestions = false
    @State private var tagSuggestions: [AIService.TagSuggestion] = []
    @State private var isLoadingTags = false
    @State private var localSummary: String?

    var isSelected: Bool {
        appState.selectedBookmarkIds.contains(bookmark.id)
    }

    // Check if content is truncated (more than ~6 lines worth)
    var isContentLong: Bool {
        bookmark.content.count > 280
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 10) {
                // Avatar
                AsyncImage(url: URL(string: bookmark.authorAvatar ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [accentColor, accentColor.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text(String(bookmark.authorName.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(bookmark.authorName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text("@\(bookmark.authorHandle)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()

                // Favorite indicator
                if bookmark.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.yellow)
                }

                // Selection checkbox
                if appState.isSelectionMode {
                    Button {
                        if isSelected {
                            appState.selectedBookmarkIds.remove(bookmark.id)
                        } else {
                            appState.selectedBookmarkIds.insert(bookmark.id)
                        }
                    } label: {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(isSelected ? accentColor : .white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Content - show more lines for text-only tweets
            VStack(alignment: .leading, spacing: 4) {
                Text(bookmark.content)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(bookmark.mediaUrls.isEmpty ? 15 : 6)
                    .multilineTextAlignment(.leading)

                if isContentLong && !bookmark.mediaUrls.isEmpty {
                    Text("Show more...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(accentColor)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showDetailSheet = true
            }

            // AI Summary (use localSummary for immediate updates, fallback to bookmark.summary)
            if let summary = localSummary ?? bookmark.summary, !summary.isEmpty {
                Button(action: { showDetailSheet = true }) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundColor(.purple)
                        Text(summary)
                            .font(.system(size: 11))
                            .foregroundColor(.purple.opacity(0.9))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }

            // Media - enhanced grid
            if !bookmark.mediaUrls.isEmpty {
                MediaGridViewCompact(mediaUrls: bookmark.mediaUrls, onTap: { _ in
                    showDetailSheet = true
                })
            }

            // Tags with remove option
            if !bookmark.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(bookmark.tags) { tag in
                            TagPill(tag: tag, showRemove: true) {
                                dbManager.removeTagFromBookmark(bookmark.id, tagId: tag.id)
                            }
                        }
                    }
                }
            }

            // Footer
            HStack {
                Text(formatDate(bookmark.postedAt))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))

                Spacer()

                // Action buttons - always visible
                HStack(spacing: 10) {
                    // AI Summarize button
                    Button(action: generateSummary) {
                        if isGeneratingSummary {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 13, height: 13)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13))
                                .foregroundColor(bookmark.summary != nil ? .purple : .white.opacity(0.4))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isGeneratingSummary)
                    .help("Generate AI summary")

                    // AI Tag suggestions
                    Menu {
                        if isLoadingTags {
                            Text("Loading suggestions...")
                        } else if tagSuggestions.isEmpty {
                            Button("Get tag suggestions") {
                                loadTagSuggestions()
                            }
                        } else {
                            ForEach(tagSuggestions, id: \.name) { suggestion in
                                Button {
                                    applyTagSuggestion(suggestion)
                                } label: {
                                    HStack {
                                        Text(suggestion.name)
                                        Spacer()
                                        Text("\(Int(suggestion.confidence * 100))%")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            Divider()
                            Button("Refresh suggestions") {
                                loadTagSuggestions()
                            }
                        }
                    } label: {
                        Image(systemName: "tag")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .menuStyle(.borderlessButton)
                    .help("AI tag suggestions")

                    Button(action: { dbManager.toggleFavorite(bookmark.id) }) {
                        Image(systemName: bookmark.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 13))
                            .foregroundColor(bookmark.isFavorite ? .yellow : .white.opacity(0.4))
                    }
                    .buttonStyle(.plain)

                    // Folder menu
                    Menu {
                        Button("Remove from folder") {
                            dbManager.setFolder(bookmark.id, folderId: nil)
                        }
                        Divider()
                        ForEach(dbManager.folders) { folder in
                            Button {
                                dbManager.setFolder(bookmark.id, folderId: folder.id)
                            } label: {
                                HStack {
                                    Circle().fill(folder.color).frame(width: 8, height: 8)
                                    Text(folder.name)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .menuStyle(.borderlessButton)

                    Button(action: {
                        if let url = URL(string: bookmark.url) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)

                    Button(action: { showDetailSheet = true }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
                .opacity(isHovered ? 1 : 0)
            }
        }
        .padding(16)
        .glassCard(isHovered: isHovered)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? accentColor : Color.clear, lineWidth: 2)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .sheet(isPresented: $showDetailSheet) {
            BookmarkDetailSheet(bookmark: bookmark, accentColor: accentColor, overrideSummary: localSummary)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func generateSummary() {
        guard !isGeneratingSummary else { return }
        guard KeychainService.shared.hasClaudeAPIKey() else { return }

        isGeneratingSummary = true

        Task {
            do {
                let summary = try await AIService.shared.summarize(
                    content: bookmark.content,
                    authorName: bookmark.authorName
                )
                await MainActor.run {
                    // Update local state immediately for instant UI feedback
                    localSummary = summary
                    // Also persist to database
                    dbManager.updateSummary(bookmark.id, summary: summary)
                    isGeneratingSummary = false
                }
            } catch {
                await MainActor.run {
                    isGeneratingSummary = false
                }
                print("Summary generation failed: \(error)")
            }
        }
    }

    private func loadTagSuggestions() {
        guard !isLoadingTags else { return }
        guard KeychainService.shared.hasClaudeAPIKey() else { return }

        isLoadingTags = true

        Task {
            do {
                let existingTags = dbManager.tags.map { $0.name }
                let suggestions = try await AIService.shared.suggestTags(
                    content: bookmark.content,
                    existingTags: existingTags
                )
                await MainActor.run {
                    tagSuggestions = suggestions
                    isLoadingTags = false
                }
            } catch {
                await MainActor.run {
                    isLoadingTags = false
                }
                print("Tag suggestion failed: \(error)")
            }
        }
    }

    private func applyTagSuggestion(_ suggestion: AIService.TagSuggestion) {
        // Check if tag exists
        if let existingTag = dbManager.tags.first(where: { $0.name.lowercased() == suggestion.name.lowercased() }) {
            dbManager.addTagToBookmark(bookmark.id, tagId: existingTag.id)
        } else {
            // Create new tag as a quick tag so it shows in sidebar
            let colors = ["#ef4444", "#f59e0b", "#22c55e", "#3b82f6", "#8b5cf6", "#ec4899"]
            let randomColor = colors.randomElement() ?? "#6b7280"
            dbManager.createTag(name: suggestion.name, color: randomColor, isQuickTag: true)

            // Find the newly created tag and add it
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let newTag = dbManager.tags.first(where: { $0.name.lowercased() == suggestion.name.lowercased() }) {
                    dbManager.addTagToBookmark(bookmark.id, tagId: newTag.id)
                }
            }
        }
    }
}

// MARK: - Bookmark Detail Sheet
struct BookmarkDetailSheet: View {
    let bookmark: Bookmark
    let accentColor: Color
    var overrideSummary: String? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dbManager: DatabaseManager

    private var displaySummary: String? {
        overrideSummary ?? bookmark.summary
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar with close button
            HStack {
                // Author info
                HStack(spacing: 10) {
                    AsyncImage(url: URL(string: bookmark.authorAvatar ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Circle()
                            .fill(accentColor.opacity(0.3))
                            .overlay(
                                Text(String(bookmark.authorName.prefix(1)).uppercased())
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(bookmark.authorName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("@\(bookmark.authorHandle)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                Spacer()

                Text(formatFullDate(bookmark.postedAt))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.7), Color.white.opacity(0.1))
                }
                .buttonStyle(.plain)
                .padding(.leading, 12)
            }
            .padding(16)
            .background(Color.black.opacity(0.3))

            // Scrollable content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    // Full content / Caption
                    Text(bookmark.content)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // AI Summary (full text)
                    if let summary = displaySummary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12))
                                    .foregroundColor(.purple)
                                Text("AI Summary")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.purple)
                            }
                            Text(summary)
                                .font(.system(size: 13))
                                .foregroundColor(.purple.opacity(0.9))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.purple.opacity(0.15))
                        )
                    }

                    // Media images
                    if !bookmark.mediaUrls.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(bookmark.mediaUrls.indices, id: \.self) { index in
                                AsyncImage(url: URL(string: bookmark.mediaUrls[index])) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: .infinity)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 200)
                                        .overlay(ProgressView())
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    // Tags
                    if !bookmark.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(bookmark.tags) { tag in
                                    HStack(spacing: 4) {
                                        Circle().fill(tag.color).frame(width: 8, height: 8)
                                        Text(tag.name)
                                            .font(.system(size: 12))
                                    }
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(tag.color.opacity(0.2)))
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }

            // Bottom button
            Button(action: {
                if let url = URL(string: bookmark.url) {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right.square")
                    Text("Open in Twitter")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appAccent)
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .frame(width: 500, height: 600)
        .background(Color.background)
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Flow Layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - Compact Media Grid for Cards
struct MediaGridViewCompact: View {
    let mediaUrls: [String]
    let onTap: (Int) -> Void

    var body: some View {
        let count = mediaUrls.count

        Group {
            if count == 1 {
                AsyncImage(url: URL(string: mediaUrls[0])) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture { onTap(0) }
            } else if count == 2 {
                HStack(spacing: 4) {
                    ForEach(0..<2, id: \.self) { index in
                        AsyncImage(url: URL(string: mediaUrls[index])) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture { onTap(index) }
                    }
                }
            } else if count >= 3 {
                VStack(spacing: 4) {
                    AsyncImage(url: URL(string: mediaUrls[0])) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onTapGesture { onTap(0) }

                    HStack(spacing: 4) {
                        ForEach(1..<min(4, count), id: \.self) { index in
                            ZStack {
                                AsyncImage(url: URL(string: mediaUrls[index])) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.1))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 70)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                if index == min(3, count - 1) && count > 4 {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.black.opacity(0.6))
                                    Text("+\(count - 4)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .onTapGesture { onTap(index) }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Media Viewer Sheet
struct MediaViewerSheet: View {
    let mediaUrls: [String]
    var content: String = ""
    var authorName: String = ""
    var authorHandle: String = ""
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 0) {
            // Main media view with close button overlay
            ZStack(alignment: .topTrailing) {
                Color.black

                if !mediaUrls.isEmpty {
                    TabView(selection: $selectedIndex) {
                        ForEach(mediaUrls.indices, id: \.self) { index in
                            AsyncImage(url: URL(string: mediaUrls[index])) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(1.5)
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.automatic)
                }

                // Close button
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white, Color.black.opacity(0.6))
                        .shadow(color: .black.opacity(0.5), radius: 4)
                }
                .buttonStyle(.plain)
                .padding(16)
            }
            .frame(minWidth: 500)

            // Sidebar with tweet content
            if !content.isEmpty || !authorName.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    // Author info
                    if !authorName.isEmpty {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.appAccent.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(String(authorName.prefix(1)).uppercased())
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(authorName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)

                                Text("@\(authorHandle)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }

                    Divider()
                        .background(Color.white.opacity(0.1))

                    // Tweet content
                    ScrollView {
                        Text(content)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer()

                    // Image counter
                    if mediaUrls.count > 1 {
                        HStack {
                            Spacer()
                            Text("\(selectedIndex + 1) / \(mediaUrls.count)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                        }
                    }
                }
                .padding(20)
                .frame(width: 280)
                .background(Color.sidebarBackground)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(Color.black)
    }
}
