import SwiftUI

struct BatchProcessingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dbManager: DatabaseManager

    enum ProcessingMode {
        case summarize
        case generateTags
    }

    let mode: ProcessingMode

    @State private var isProcessing = false
    @State private var progress: AIService.BatchProgress?
    @State private var completedCount = 0
    @State private var errorCount = 0
    @State private var errors: [String] = []
    @State private var isDone = false

    private var bookmarksToProcess: [Bookmark] {
        switch mode {
        case .summarize:
            return dbManager.getBookmarksWithoutSummary()
        case .generateTags:
            // For now, return all bookmarks
            return dbManager.searchBookmarks()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode == .summarize ? "Batch Summarization" : "Batch Tag Generation")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Text("\(bookmarksToProcess.count) bookmarks to process")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                if !isProcessing {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()
                .background(Color.white.opacity(0.1))

            // Content
            VStack(spacing: 24) {
                if !isProcessing && !isDone {
                    // Pre-processing info
                    VStack(spacing: 16) {
                        Image(systemName: mode == .summarize ? "sparkles" : "tag.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.purple)

                        Text(mode == .summarize
                            ? "Generate AI summaries for all bookmarks without summaries"
                            : "Generate AI tag suggestions for bookmarks")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)

                        // Cost estimate
                        let estimatedCost = Double(bookmarksToProcess.count) * 0.00002
                        HStack(spacing: 6) {
                            Image(systemName: "dollarsign.circle")
                                .foregroundColor(.green)
                            Text("Estimated cost: ~$\(String(format: "%.4f", estimatedCost))")
                                .foregroundColor(.green)
                        }
                        .font(.system(size: 12))

                        // Time estimate
                        let estimatedTime = Double(bookmarksToProcess.count) * 1.1
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .foregroundColor(.orange)
                            Text("Estimated time: ~\(formatTime(estimatedTime))")
                                .foregroundColor(.orange)
                        }
                        .font(.system(size: 12))
                    }
                    .padding(24)

                    // Start button
                    Button(action: startProcessing) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Start Processing")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.purple)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .disabled(bookmarksToProcess.isEmpty)
                    .opacity(bookmarksToProcess.isEmpty ? 0.5 : 1)

                } else if isProcessing {
                    // Processing view
                    VStack(spacing: 20) {
                        // Progress ring
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 8)
                                .frame(width: 100, height: 100)

                            Circle()
                                .trim(from: 0, to: (progress?.percentage ?? 0) / 100)
                                .stroke(Color.purple, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 100, height: 100)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.3), value: progress?.percentage)

                            VStack(spacing: 2) {
                                Text("\(Int(progress?.percentage ?? 0))%")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }

                        // Stats
                        HStack(spacing: 24) {
                            VStack {
                                Text("\(completedCount)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                                Text("Completed")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                            }

                            VStack {
                                Text("\(progress?.current ?? 0)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("Processing")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                            }

                            VStack {
                                Text("\(errorCount)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(errorCount > 0 ? .red : .white.opacity(0.5))
                                Text("Errors")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }

                        // Current item indicator
                        if let currentId = progress?.currentBookmarkId {
                            Text("Processing bookmark...")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }

                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                    }
                    .padding(24)

                } else if isDone {
                    // Completed view
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)

                        Text("Processing Complete!")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)

                        HStack(spacing: 24) {
                            VStack {
                                Text("\(completedCount)")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                                Text("Successful")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                            }

                            if errorCount > 0 {
                                VStack {
                                    Text("\(errorCount)")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundColor(.red)
                                    Text("Failed")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }

                        // Show errors if any
                        if !errors.isEmpty {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(errors.prefix(5), id: \.self) { error in
                                        Text(error)
                                            .font(.system(size: 11))
                                            .foregroundColor(.red.opacity(0.8))
                                    }
                                    if errors.count > 5 {
                                        Text("... and \(errors.count - 5) more errors")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                            }
                            .frame(maxHeight: 100)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.1))
                            )
                        }
                    }
                    .padding(24)

                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.purple)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                }

                Spacer()
            }
            .padding(.top, 24)
        }
        .frame(width: 400, height: 450)
        .background(Color.cardBackground)
    }

    private func startProcessing() {
        guard KeychainService.shared.hasClaudeAPIKey() else {
            errors.append("No API key configured. Please add your Claude API key in Settings.")
            isDone = true
            return
        }

        isProcessing = true
        completedCount = 0
        errorCount = 0
        errors = []

        let bookmarks = bookmarksToProcess.map { ($0.id, $0.content, $0.authorName) }

        Task {
            await AIService.shared.batchSummarize(
                bookmarks: bookmarks,
                onProgress: { prog in
                    Task { @MainActor in
                        self.progress = prog
                        if let error = prog.error {
                            self.errorCount += 1
                            self.errors.append(error)
                        }
                    }
                },
                onComplete: { bookmarkId, summary in
                    Task { @MainActor in
                        self.dbManager.updateSummary(bookmarkId, summary: summary)
                        self.completedCount += 1
                    }
                }
            )

            await MainActor.run {
                isProcessing = false
                isDone = true
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        if seconds < 60 {
            return "\(Int(seconds)) seconds"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60)) minutes"
        } else {
            let hours = Int(seconds / 3600)
            let mins = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(mins)m"
        }
    }
}
