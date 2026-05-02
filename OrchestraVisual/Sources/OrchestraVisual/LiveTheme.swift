import SwiftUI

/// Paleta alto contraste para uso ao vivo / pouca luz.
enum LiveTheme {
    static let background = Color(red: 0.04, green: 0.04, blue: 0.06)
    static let panel = Color(red: 0.08, green: 0.08, blue: 0.11)
    static let border = Color(red: 1.0, green: 0.92, blue: 0.2)
    static let accent = Color(red: 1.0, green: 0.85, blue: 0.0)
    static let danger = Color(red: 1.0, green: 0.35, blue: 0.35)
    static let success = Color(red: 0.3, green: 1.0, blue: 0.55)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.82)
}

struct LiveOutlineModifier: ViewModifier {
    let isFocused: Bool
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isFocused ? LiveTheme.border : LiveTheme.border.opacity(0.45), lineWidth: isFocused ? 3 : 2)
            )
    }
}

extension View {
    func liveOutline(focused: Bool = false) -> some View {
        modifier(LiveOutlineModifier(isFocused: focused))
    }
}

struct LiveProminentButtonStyle: ButtonStyle {
    var tint: Color = LiveTheme.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(Color.black.opacity(0.92))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(configuration.isPressed ? tint.opacity(0.75) : tint)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 2)
            )
    }
}

struct LiveSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(LiveTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(configuration.isPressed ? LiveTheme.panel : LiveTheme.panel.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(LiveTheme.border.opacity(0.95), lineWidth: 2)
            )
    }
}

struct LiveToggleButtonStyle: ButtonStyle {
    var isOn: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(isOn ? Color.black.opacity(0.9) : LiveTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(configuration.isPressed
                ? (isOn ? LiveTheme.success.opacity(0.85) : LiveTheme.panel.opacity(0.95))
                : (isOn ? LiveTheme.success : LiveTheme.panel))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isOn ? LiveTheme.border : LiveTheme.border.opacity(0.5), lineWidth: 2)
            )
    }
}
