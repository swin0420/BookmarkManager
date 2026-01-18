import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var showNewFolderSheet = false
    @State private var showNewTagSheet = false
    @State private var showClearAllConfirm = false
    @State private var showSettingsSheet = false
    @State private var showChatSheet = false
    @State private var showBatchProcessingSheet = false
    @State private var showEmbeddingSheet = false
    @State private var embeddingProgress: (current: Int, total: Int)?
    @State private var isGeneratingEmbeddings = false
    @State private var foldersExpanded = true
    @State private var tagsExpanded = true
    @State private var smartCollectionsExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Drag area for window
            Color.clear
                .frame(height: 52)

            // Sidebar content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Library section
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LIBRARY")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(1)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)

                        SidebarItem(
                            icon: "bookmark.fill",
                            title: "All Bookmarks",
                            count: dbManager.stats.total,
                            accentColor: .appAccent,
                            isSelected: appState.selectedSection == .allBookmarks
                        ) {
                            appState.selectedSection = .allBookmarks
                        }

                        SidebarItem(
                            icon: "star.fill",
                            title: "Favorites",
                            count: dbManager.stats.favorites,
                            accentColor: .yellow,
                            isSelected: appState.selectedSection == .favorites
                        ) {
                            appState.selectedSection = .favorites
                        }
                    }

                    // Smart Collections section
                    VStack(alignment: .leading, spacing: 4) {
                        Button(action: { withAnimation { smartCollectionsExpanded.toggle() } }) {
                            HStack(spacing: 6) {
                                Image(systemName: smartCollectionsExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                                    .frame(width: 12)

                                Text("SMART")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                                    .tracking(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)

                        if smartCollectionsExpanded {
                            SidebarItem(
                                icon: "photo.fill",
                                title: "With Media",
                                accentColor: .pink,
                                isSelected: appState.selectedSection == .smartCollection(.withMedia)
                            ) {
                                appState.selectedSection = .smartCollection(.withMedia)
                            }

                            SidebarItem(
                                icon: "text.alignleft",
                                title: "Text Only",
                                accentColor: .cyan,
                                isSelected: appState.selectedSection == .smartCollection(.textOnly)
                            ) {
                                appState.selectedSection = .smartCollection(.textOnly)
                            }

                        }
                    }

                    // AI section
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(1)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)

                        Button(action: { showChatSheet = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "brain")
                                    .font(.system(size: 14))
                                    .foregroundColor(.purple)
                                    .frame(width: 20)

                                Text("Scout")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.8))

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.clear)
                            )
                        }
                        .buttonStyle(.plain)

                        Button(action: { showBatchProcessingSheet = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14))
                                    .foregroundColor(.purple)
                                    .frame(width: 20)

                                Text("Batch Summarize")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.8))

                                Spacer()

                                if dbManager.stats.unprocessed > 0 {
                                    Text("\(dbManager.stats.unprocessed)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.purple)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(Color.purple.opacity(0.2))
                                        )
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.clear)
                            )
                        }
                        .buttonStyle(.plain)

                        Button(action: { startEmbeddingGeneration() }) {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass.circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(.cyan)
                                    .frame(width: 20)

                                Text("Build Search Index")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.8))

                                Spacer()

                                if isGeneratingEmbeddings, let progress = embeddingProgress {
                                    Text("\(progress.current)/\(progress.total)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.cyan)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(Color.cyan.opacity(0.2))
                                        )
                                } else {
                                    let missing = SemanticSearchService.shared.missingEmbeddingCount()
                                    if missing > 0 {
                                        Text("\(missing)")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.cyan)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(
                                                Capsule()
                                                    .fill(Color.cyan.opacity(0.2))
                                            )
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isGeneratingEmbeddings)
                        .contextMenu {
                            Button(action: { rebuildEmbeddingIndex() }) {
                                Label("Rebuild Entire Index", systemImage: "arrow.clockwise")
                            }
                        }
                    }

                    // Folders section
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Button(action: { withAnimation { foldersExpanded.toggle() } }) {
                                HStack(spacing: 6) {
                                    Image(systemName: foldersExpanded ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.4))
                                        .frame(width: 12)

                                    Text("FOLDERS")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.4))
                                        .tracking(1)
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button(action: { showNewFolderSheet = true }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                                    .frame(width: 20, height: 20)
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(0.05))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)

                        if foldersExpanded {
                            if dbManager.folders.isEmpty {
                                Text("No folders")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.3))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(dbManager.folders) { folder in
                                    SidebarFolderItem(
                                        folder: folder,
                                        isSelected: appState.selectedSection == .folder(folder.id),
                                        action: {
                                            appState.selectedSection = .folder(folder.id)
                                        },
                                        selectedSection: $appState.selectedSection
                                    )
                                }
                            }
                        }
                    }

                    // Tags section
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Button(action: { withAnimation { tagsExpanded.toggle() } }) {
                                HStack(spacing: 6) {
                                    Image(systemName: tagsExpanded ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.4))
                                        .frame(width: 12)

                                    Text("QUICK TAGS")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.4))
                                        .tracking(1)
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button(action: { showNewTagSheet = true }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                                    .frame(width: 20, height: 20)
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(0.05))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)

                        if tagsExpanded {
                            ForEach(dbManager.tags.filter { $0.isQuickTag }) { tag in
                                SidebarTagItem(
                                    tag: tag,
                                    isSelected: appState.selectedSection == .tag(tag.id),
                                    action: {
                                        appState.selectedSection = .tag(tag.id)
                                    },
                                    selectedSection: $appState.selectedSection
                                )
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }

            // Bottom section with import
            VStack(spacing: 12) {
                Divider()
                    .background(Color.white.opacity(0.1))

                Button(action: { showSettingsSheet = true }) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                        Text("AI Settings")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)

                Button(action: importDatabase) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14))
                        Text("Import Database")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)

                Button(action: { showClearAllConfirm = true }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                        Text("Clear All Bookmarks")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.red.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 16)
        }
        .alert("Clear All Bookmarks", isPresented: $showClearAllConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                dbManager.deleteAllBookmarks()
                appState.selectedSection = .allBookmarks
            }
        } message: {
            Text("Are you sure you want to delete all \(dbManager.stats.total) bookmarks? This cannot be undone.")
        }
        .background(
            Color.sidebarBackground
                .background(.ultraThinMaterial)
        )
        .sheet(isPresented: $showNewFolderSheet) {
            NewFolderSheet(isPresented: $showNewFolderSheet)
        }
        .sheet(isPresented: $showNewTagSheet) {
            NewTagSheet(isPresented: $showNewTagSheet)
        }
        .sheet(isPresented: $showSettingsSheet) {
            AISettingsView()
        }
        .sheet(isPresented: $showChatSheet) {
            ChatView()
        }
        .sheet(isPresented: $showBatchProcessingSheet) {
            BatchProcessingView(mode: .summarize)
        }
    }

    private func startEmbeddingGeneration() {
        guard !isGeneratingEmbeddings else { return }

        isGeneratingEmbeddings = true
        embeddingProgress = (0, SemanticSearchService.shared.missingEmbeddingCount())

        SemanticSearchService.shared.generateMissingEmbeddings(
            onProgress: { current, total in
                embeddingProgress = (current, total)
            },
            onComplete: {
                isGeneratingEmbeddings = false
                embeddingProgress = nil
            }
        )
    }

    private func rebuildEmbeddingIndex() {
        guard !isGeneratingEmbeddings else { return }

        // Delete all embeddings first
        dbManager.deleteAllEmbeddings()
        SemanticSearchService.shared.clearCache()

        // Then regenerate all
        startEmbeddingGeneration()
    }

    private func importDatabase() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.database, .json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select your bookmarks.db or bookmarks-export.json file"

        if panel.runModal() == .OK, let url = panel.url {
            if url.pathExtension.lowercased() == "json" {
                let result = dbManager.importFromJSONFileWithCount(url.path)
                DispatchQueue.main.async {
                    appState.importedNewCount = result.newCount
                    appState.importedUpdatedCount = result.updatedCount
                    appState.showImportSuccess = true
                }
            } else {
                dbManager.importFromPath(url.path)
            }
        }
    }
}

struct SidebarItem: View {
    let icon: String
    let title: String
    var count: Int?
    let accentColor: Color
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? accentColor : .white.opacity(0.6))
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.8))

                Spacer()

                if let count = count {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? accentColor : .white.opacity(0.4))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(isSelected ? accentColor.opacity(0.2) : Color.white.opacity(0.05))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? accentColor.opacity(0.15) : (isHovered ? Color.white.opacity(0.05) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct SidebarFolderItem: View {
    let folder: Folder
    let isSelected: Bool
    let action: () -> Void
    @Binding var selectedSection: SidebarSection

    @EnvironmentObject var dbManager: DatabaseManager
    @State private var isHovered = false
    @State private var isTargeted = false
    @State private var showRenameSheet = false
    @State private var showDeleteConfirm = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? folder.color : .white.opacity(0.6))
                    .frame(width: 20)

                Text(folder.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.8))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isTargeted ? folder.color.opacity(0.3) : (isSelected ? folder.color.opacity(0.15) : (isHovered ? Color.white.opacity(0.05) : Color.clear)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isTargeted ? folder.color : (isSelected ? folder.color.opacity(0.3) : Color.clear), lineWidth: isTargeted ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button {
                showRenameSheet = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Divider()
            if let index = dbManager.folders.firstIndex(where: { $0.id == folder.id }) {
                Button {
                    moveFolderUp(from: index)
                } label: {
                    Label("Move Up", systemImage: "arrow.up")
                }
                .disabled(index == 0)

                Button {
                    moveFolderDown(from: index)
                } label: {
                    Label("Move Down", systemImage: "arrow.down")
                }
                .disabled(index == dbManager.folders.count - 1)
                Divider()
            }
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }

            provider.loadItem(forTypeIdentifier: "public.text", options: nil) { data, error in
                if let data = data as? Data, let bookmarkId = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        dbManager.setFolder(bookmarkId, folderId: folder.id)
                    }
                }
            }
            return true
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameFolderSheet(isPresented: $showRenameSheet, folder: folder)
        }
        .alert("Delete Folder", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if selectedSection == .folder(folder.id) {
                    selectedSection = .allBookmarks
                }
                dbManager.deleteFolder(folder.id)
            }
        } message: {
            Text("Are you sure you want to delete the folder \"\(folder.name)\"? Bookmarks in this folder will not be deleted.")
        }
    }

    private func moveFolderUp(from index: Int) {
        guard index > 0 else { return }
        var ids = dbManager.folders.map { $0.id }
        ids.swapAt(index, index - 1)
        dbManager.reorderFolders(ids)
    }

    private func moveFolderDown(from index: Int) {
        guard index < dbManager.folders.count - 1 else { return }
        var ids = dbManager.folders.map { $0.id }
        ids.swapAt(index, index + 1)
        dbManager.reorderFolders(ids)
    }
}

struct SidebarTagItem: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void
    @Binding var selectedSection: SidebarSection

    @EnvironmentObject var dbManager: DatabaseManager
    @State private var isHovered = false
    @State private var showDeleteConfirm = false
    @State private var showRenameSheet = false

    private var quickTags: [Tag] {
        dbManager.tags.filter { $0.isQuickTag }
    }

    private var tagIndex: Int? {
        quickTags.firstIndex(where: { $0.id == tag.id })
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Reorder buttons on hover
                if isHovered {
                    VStack(spacing: 0) {
                        Button {
                            if let index = tagIndex {
                                moveTagUp(from: index, in: quickTags)
                            }
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(tagIndex == 0 ? .white.opacity(0.15) : .white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .disabled(tagIndex == 0)

                        Button {
                            if let index = tagIndex {
                                moveTagDown(from: index, in: quickTags)
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(tagIndex == quickTags.count - 1 ? .white.opacity(0.15) : .white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .disabled(tagIndex == quickTags.count - 1)
                    }
                    .frame(width: 14)
                }

                Circle()
                    .fill(tag.color)
                    .frame(width: 10, height: 10)

                Text(tag.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.8))

                Spacer()

                // Delete button on hover
                if isHovered {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, isHovered ? 6 : 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? tag.color.opacity(0.15) : (isHovered ? Color.white.opacity(0.05) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? tag.color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button {
                showRenameSheet = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameTagSheet(isPresented: $showRenameSheet, tag: tag)
        }
        .alert("Delete Tag", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if selectedSection == .tag(tag.id) {
                    selectedSection = .allBookmarks
                }
                dbManager.deleteTag(tag.id)
            }
        } message: {
            Text("Are you sure you want to delete the tag \"\(tag.name)\"? This will remove it from all bookmarks.")
        }
    }

    private func moveTagUp(from index: Int, in quickTags: [Tag]) {
        guard index > 0 else { return }
        var ids = quickTags.map { $0.id }
        ids.swapAt(index, index - 1)
        dbManager.reorderTags(ids)
    }

    private func moveTagDown(from index: Int, in quickTags: [Tag]) {
        guard index < quickTags.count - 1 else { return }
        var ids = quickTags.map { $0.id }
        ids.swapAt(index, index + 1)
        dbManager.reorderTags(ids)
    }
}

// MARK: - Sheets

struct NewFolderSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var name = ""
    @State private var selectedColor = "#6b7280"

    let colors = ["#ef4444", "#f59e0b", "#22c55e", "#3b82f6", "#8b5cf6", "#ec4899", "#6b7280"]

    var body: some View {
        VStack(spacing: 20) {
            Text("New Folder")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            TextField("Folder name", text: $name)
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                )
                .foregroundColor(.white)

            HStack(spacing: 12) {
                ForEach(colors, id: \.self) { color in
                    Circle()
                        .fill(Color(hex: color) ?? .gray)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: selectedColor == color ? 2 : 0)
                        )
                        .onTapGesture {
                            selectedColor = color
                        }
                }
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.6))

                Button("Create") {
                    if !name.isEmpty {
                        dbManager.createFolder(name: name, color: selectedColor)
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(Color.cardBackground)
    }
}

struct RenameFolderSheet: View {
    @Binding var isPresented: Bool
    let folder: Folder
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var name = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Rename Folder")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            TextField("Folder name", text: $name)
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                )
                .foregroundColor(.white)

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.6))

                Button("Rename") {
                    if !name.isEmpty {
                        dbManager.renameFolder(folder.id, newName: name)
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(Color.cardBackground)
        .onAppear {
            name = folder.name
        }
    }
}

struct RenameTagSheet: View {
    @Binding var isPresented: Bool
    let tag: Tag
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var name = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Rename Tag")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            TextField("Tag name", text: $name)
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                )
                .foregroundColor(.white)

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.6))

                Button("Rename") {
                    if !name.isEmpty {
                        dbManager.renameTag(tag.id, newName: name)
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(Color.cardBackground)
        .onAppear {
            name = tag.name
        }
    }
}

struct NewTagSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var name = ""
    @State private var selectedColor = "#6b7280"

    let colors = ["#ef4444", "#f59e0b", "#22c55e", "#3b82f6", "#8b5cf6", "#ec4899", "#6b7280"]

    var body: some View {
        VStack(spacing: 20) {
            Text("New Tag")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            TextField("Tag name", text: $name)
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                )
                .foregroundColor(.white)

            HStack(spacing: 12) {
                ForEach(colors, id: \.self) { color in
                    Circle()
                        .fill(Color(hex: color) ?? .gray)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: selectedColor == color ? 2 : 0)
                        )
                        .onTapGesture {
                            selectedColor = color
                        }
                }
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.6))

                Button("Create") {
                    if !name.isEmpty {
                        dbManager.createTag(name: name, color: selectedColor, isQuickTag: true)
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(Color.cardBackground)
    }
}
