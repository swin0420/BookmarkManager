import SwiftUI

struct AISettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var apiKey = ""
    @State private var showKey = false
    @State private var isValidating = false
    @State private var validationResult: ValidationResult?
    @State private var hasExistingKey = false

    enum ValidationResult {
        case success
        case failure(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AI Settings")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()
                .background(Color.white.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // API Key Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.purple)
                            Text("Claude API Key")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        Text("Your API key is stored securely in the macOS Keychain and never leaves your device.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))

                        HStack(spacing: 8) {
                            Group {
                                if showKey {
                                    TextField("sk-ant-...", text: $apiKey)
                                        .textFieldStyle(.plain)
                                } else {
                                    SecureField("sk-ant-...", text: $apiKey)
                                        .textFieldStyle(.plain)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .foregroundColor(.white)

                            Button(action: { showKey.toggle() }) {
                                Image(systemName: showKey ? "eye.slash" : "eye")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 36, height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white.opacity(0.08))
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: 12) {
                            Button(action: validateAndSaveKey) {
                                HStack(spacing: 6) {
                                    if isValidating {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "checkmark.shield")
                                    }
                                    Text(hasExistingKey ? "Update Key" : "Save Key")
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.purple)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(apiKey.isEmpty || isValidating)
                            .opacity(apiKey.isEmpty ? 0.5 : 1)

                            if hasExistingKey {
                                Button(action: deleteKey) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "trash")
                                        Text("Remove Key")
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.red.opacity(0.15))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Validation result
                        if let result = validationResult {
                            HStack(spacing: 6) {
                                switch result {
                                case .success:
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("API key is valid and saved!")
                                        .foregroundColor(.green)
                                case .failure(let message):
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text(message)
                                        .foregroundColor(.red)
                                }
                            }
                            .font(.system(size: 12))
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )

                    // Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("About AI Features")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(
                                icon: "sparkles",
                                color: .purple,
                                title: "Auto-Summarize",
                                description: "Generate short summaries of tweets using Claude AI"
                            )
                            FeatureRow(
                                icon: "tag.fill",
                                color: .orange,
                                title: "Smart Tagging",
                                description: "Get AI-suggested tags based on tweet content"
                            )
                            FeatureRow(
                                icon: "magnifyingglass",
                                color: .cyan,
                                title: "Semantic Search",
                                description: "Search by meaning using local embeddings (no API needed)"
                            )
                            FeatureRow(
                                icon: "bubble.left.and.bubble.right.fill",
                                color: .green,
                                title: "Chat with Bookmarks",
                                description: "Ask questions about your saved tweets"
                            )
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )

                    // Cost Info
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.green)
                            Text("Estimated Costs")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        Text("Using Claude 3 Haiku (fast & affordable):")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))

                        VStack(alignment: .leading, spacing: 4) {
                            CostRow(feature: "Summarize 1000 bookmarks", cost: "~$0.02")
                            CostRow(feature: "Tag 1000 bookmarks", cost: "~$0.02")
                            CostRow(feature: "Chat question", cost: "~$0.01")
                            CostRow(feature: "Semantic search", cost: "Free (local)")
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )

                    // Get API Key Link
                    Link(destination: URL(string: "https://console.anthropic.com/settings/keys")!) {
                        HStack {
                            Image(systemName: "arrow.up.right.square")
                            Text("Get your API key from Anthropic Console")
                        }
                        .font(.system(size: 13))
                        .foregroundColor(.appAccent)
                    }
                    .padding(.top, 8)
                }
                .padding(24)
            }
        }
        .frame(width: 480, height: 600)
        .background(Color.cardBackground)
        .onAppear {
            loadExistingKey()
        }
    }

    private func loadExistingKey() {
        hasExistingKey = KeychainService.shared.hasClaudeAPIKey()
        if hasExistingKey {
            // Show masked placeholder
            apiKey = "sk-ant-••••••••••••••••••••"
        }
    }

    private func validateAndSaveKey() {
        // Don't validate the masked placeholder
        if apiKey.contains("••••") {
            validationResult = .failure("Please enter a new API key")
            return
        }

        isValidating = true
        validationResult = nil

        Task {
            let isValid = await ClaudeAPIService.shared.testAPIKey(apiKey)

            await MainActor.run {
                isValidating = false

                if isValid {
                    let saved = KeychainService.shared.saveClaudeAPIKey(apiKey)
                    if saved {
                        validationResult = .success
                        hasExistingKey = true
                        apiKey = "sk-ant-••••••••••••••••••••"
                    } else {
                        validationResult = .failure("Failed to save key to Keychain")
                    }
                } else {
                    validationResult = .failure("Invalid API key. Please check and try again.")
                }
            }
        }
    }

    private func deleteKey() {
        _ = KeychainService.shared.deleteClaudeAPIKey()
        hasExistingKey = false
        apiKey = ""
        validationResult = nil
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

struct CostRow: View {
    let feature: String
    let cost: String

    var body: some View {
        HStack {
            Text(feature)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(cost)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.green)
        }
    }
}
