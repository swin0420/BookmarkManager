import SwiftUI

// MARK: - Glassmorphism Background
struct GlassBackground: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
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
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06), lineWidth: 1)
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
    @Environment(\.colorScheme) var colorScheme
    var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color(white: 0.1) : Color.white)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        colorScheme == .dark
                            ? LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.2 : 0.1),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.black.opacity(isHovered ? 0.12 : 0.06),
                                    Color.black.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: colorScheme == .dark ? .black.opacity(0.3) : .black.opacity(0.08),
                radius: isHovered ? 15 : 8,
                y: isHovered ? 8 : 4
            )
    }
}

extension View {
    func glassCard(isHovered: Bool = false) -> some View {
        modifier(GlassCard(isHovered: isHovered))
    }
}

// MARK: - Sidebar Button Style
struct SidebarButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    var isSelected: Bool
    var accentColor: Color

    func makeBody(configuration: Configuration) -> some View {
        let textColor = colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.75)

        return configuration.label
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
            .foregroundColor(isSelected ? accentColor : textColor)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Tag Pill Style
struct TagPill: View {
    @Environment(\.colorScheme) var colorScheme
    let tag: Tag
    var isSelected: Bool = false
    var showRemove: Bool = false
    var onRemove: (() -> Void)?

    var body: some View {
        let textColor = colorScheme == .dark ? Color.white : Color.black.opacity(0.8)
        let removeColor = colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.5)

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
                        .foregroundColor(removeColor)
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
        .foregroundColor(textColor)
    }
}

// MARK: - Search Field Style
struct GlassSearchField: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var text: String
    var placeholder: String = "Search..."

    var body: some View {
        let iconColor = colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.4)
        let textColor = colorScheme == .dark ? Color.white : Color.black.opacity(0.85)
        let bgColor = colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
        let borderColor = colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)

        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(iconColor)
                .font(.system(size: 14))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(textColor)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(iconColor)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(bgColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Theme Colors
struct ThemeColors {
    let colorScheme: ColorScheme

    // Backgrounds
    var background: Color {
        colorScheme == .dark
            ? Color(red: 0.05, green: 0.05, blue: 0.07)
            : Color(red: 0.96, green: 0.96, blue: 0.98)
    }

    var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.08, green: 0.08, blue: 0.1)
            : Color.white
    }

    var sidebarBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.06, green: 0.06, blue: 0.08)
            : Color(red: 0.94, green: 0.94, blue: 0.96)
    }

    // Text colors
    var primaryText: Color {
        colorScheme == .dark
            ? Color.white
            : Color(red: 0.1, green: 0.1, blue: 0.1)
    }

    var secondaryText: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.7)
            : Color(red: 0.4, green: 0.4, blue: 0.4)
    }

    var tertiaryText: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.5)
            : Color(red: 0.55, green: 0.55, blue: 0.55)
    }

    var mutedText: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.4)
            : Color(red: 0.6, green: 0.6, blue: 0.6)
    }

    // UI Elements
    var divider: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.1)
            : Color.black.opacity(0.08)
    }

    var cardBorder: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.1)
            : Color.black.opacity(0.06)
    }

    var hoverBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.05)
            : Color.black.opacity(0.04)
    }

    var inputBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.04)
    }

    // Accent (slightly adjusted for light mode contrast)
    var accent: Color {
        colorScheme == .dark
            ? Color(red: 0.4, green: 0.6, blue: 1.0)
            : Color(red: 0.2, green: 0.4, blue: 0.8)
    }
}

// Environment key for theme colors
private struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue = ThemeColors(colorScheme: .dark)
}

extension EnvironmentValues {
    var themeColors: ThemeColors {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}

// MARK: - Custom Colors (legacy, for backwards compatibility during migration)
extension Color {
    static let background = Color(red: 0.05, green: 0.05, blue: 0.07)
    static let cardBackground = Color(red: 0.08, green: 0.08, blue: 0.1)
    static let sidebarBackground = Color(red: 0.06, green: 0.06, blue: 0.08)
    static let appAccent = Color(red: 0.4, green: 0.6, blue: 1.0)

    // Light mode equivalents
    static let backgroundLight = Color(red: 0.96, green: 0.96, blue: 0.98)
    static let cardBackgroundLight = Color.white
    static let sidebarBackgroundLight = Color(red: 0.94, green: 0.94, blue: 0.96)
    static let appAccentLight = Color(red: 0.2, green: 0.4, blue: 0.8)
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
