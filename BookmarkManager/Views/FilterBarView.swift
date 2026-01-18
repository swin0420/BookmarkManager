import SwiftUI

struct FilterBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.colorScheme) var colorScheme
    let accentColor: Color
    @State private var showFromPicker = false
    @State private var showToPicker = false

    private var themeColors: ThemeColors {
        ThemeColors(colorScheme: colorScheme)
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            // Search field
            GlassSearchField(text: $appState.searchQuery, placeholder: appState.isSemanticSearchEnabled ? "Search by meaning..." : "Search bookmarks...")
                .frame(maxWidth: 300)

            // Semantic search toggle (only shown in All Bookmarks)
            if appState.selectedSection == .allBookmarks {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.isSemanticSearchEnabled.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain")
                            .font(.system(size: 12))
                        Text("Semantic")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(appState.isSemanticSearchEnabled ? .purple : themeColors.tertiaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(appState.isSemanticSearchEnabled ? Color.purple.opacity(0.2) : themeColors.hoverBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(appState.isSemanticSearchEnabled ? Color.purple.opacity(0.5) : themeColors.divider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("Toggle semantic search (search by meaning)")
            }

            // Author filter
            Menu {
                Button("All Authors") {
                    appState.selectedAuthor = nil
                }

                Divider()

                ForEach(dbManager.authors.prefix(50), id: \.self) { author in
                    Button("@\(author)") {
                        appState.selectedAuthor = author
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person")
                        .font(.system(size: 12))
                    Text(appState.selectedAuthor.map { "@\($0)" } ?? "All Authors")
                        .font(.system(size: 13))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundColor(themeColors.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeColors.inputBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeColors.divider, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)

            // Date range - From
            Button(action: { showFromPicker.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text(appState.dateFrom != nil ? dateFormatter.string(from: appState.dateFrom!) : "From")
                        .font(.system(size: 13))
                    if appState.dateFrom != nil {
                        Button(action: {
                            appState.dateFrom = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(themeColors.mutedText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .foregroundColor(themeColors.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeColors.inputBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeColors.divider, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showFromPicker) {
                VStack(spacing: 0) {
                    DatePicker(
                        "From Date",
                        selection: Binding(
                            get: { appState.dateFrom ?? Date() },
                            set: { appState.dateFrom = $0 }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding()

                    Divider()

                    Button("Clear") {
                        appState.dateFrom = nil
                        showFromPicker = false
                    }
                    .padding(.vertical, 8)
                }
                .frame(width: 280)
            }

            // Date range - To
            Button(action: { showToPicker.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text(appState.dateTo != nil ? dateFormatter.string(from: appState.dateTo!) : "To")
                        .font(.system(size: 13))
                    if appState.dateTo != nil {
                        Button(action: {
                            appState.dateTo = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(themeColors.mutedText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .foregroundColor(themeColors.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeColors.inputBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeColors.divider, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showToPicker) {
                VStack(spacing: 0) {
                    DatePicker(
                        "To Date",
                        selection: Binding(
                            get: { appState.dateTo ?? Date() },
                            set: { appState.dateTo = $0 }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding()

                    Divider()

                    Button("Clear") {
                        appState.dateTo = nil
                        showToPicker = false
                    }
                    .padding(.vertical, 8)
                }
                .frame(width: 280)
            }

            Spacer()

            // Clear filters
            if !appState.searchQuery.isEmpty || appState.selectedAuthor != nil || appState.dateFrom != nil || appState.dateTo != nil {
                Button(action: clearFilters) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Clear")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(accentColor.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func clearFilters() {
        appState.searchQuery = ""
        appState.selectedAuthor = nil
        appState.dateFrom = nil
        appState.dateTo = nil
    }
}
