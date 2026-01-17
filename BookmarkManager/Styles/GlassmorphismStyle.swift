import SwiftUI

// MARK: - Glassmorphism Background
struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 12
    var opacity: Double = 0.15

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .opacity(opacity)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = 12, opacity: Double = 0.15) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius, opacity: opacity))
    }
}

// MARK: - Card Style
struct GlassCard: ViewModifier {
    var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.1))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.2 : 0.1),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.3), radius: isHovered ? 15 : 8, y: isHovered ? 8 : 4)
    }
}

extension View {
    func glassCard(isHovered: Bool = false) -> some View {
        modifier(GlassCard(isHovered: isHovered))
    }
}

// MARK: - Sidebar Button Style
struct SidebarButtonStyle: ButtonStyle {
    var isSelected: Bool
    var accentColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? accentColor.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .foregroundColor(isSelected ? accentColor : .white.opacity(0.8))
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Tag Pill Style
struct TagPill: View {
    let tag: Tag
    var isSelected: Bool = false
    var showRemove: Bool = false
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tag.color)
                .frame(width: 6, height: 6)

            Text(tag.name)
                .font(.caption)
                .fontWeight(.medium)

            if showRemove {
                Button(action: { onRemove?() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(tag.color.opacity(isSelected ? 0.4 : 0.2))
        )
        .overlay(
            Capsule()
                .stroke(tag.color.opacity(0.5), lineWidth: 1)
        )
        .foregroundColor(.white)
    }
}

// MARK: - Search Field Style
struct GlassSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search..."

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.5))
                .font(.system(size: 14))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(.white)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Custom Colors
extension Color {
    static let background = Color(red: 0.05, green: 0.05, blue: 0.07)
    static let cardBackground = Color(red: 0.08, green: 0.08, blue: 0.1)
    static let sidebarBackground = Color(red: 0.06, green: 0.06, blue: 0.08)
    static let appAccent = Color(red: 0.4, green: 0.6, blue: 1.0)
}

// MARK: - Hover Effect
struct HoverEffect: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func hoverEffect() -> some View {
        modifier(HoverEffect())
    }
}
