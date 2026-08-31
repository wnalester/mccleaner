import SwiftUI

/// Shared visual language for the app — a calm, trustworthy blue (matching the app icon)
/// plus rounded, softly-elevated cards instead of the plain flat-fill boxes used in v1.
enum Theme {
    static let accent = Color(red: 0.16, green: 0.47, blue: 0.94)
    static let accentDeep = Color(red: 0.08, green: 0.28, blue: 0.72)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let cardCorner: CGFloat = 18

    /// Approximate point sizes matching macOS's system text styles, used when rendering
    /// those same styles in a custom font (Font.custom needs an explicit size, not a style).
    static func pointSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 30
        case .title: return 24
        case .title2: return 19
        case .title3: return 16
        case .headline: return 14
        case .body: return 13
        case .callout: return 12
        case .subheadline: return 12
        case .footnote: return 11
        case .caption: return 11
        case .caption2: return 10
        @unknown default: return 13
        }
    }
}

extension Font {
    /// The app's display typeface (Bricolage Grotesque) — used for headings, titles, and
    /// buttons, everywhere the app previously used the generic `.fontDesign(.rounded)`
    /// system font. Falls back to system rounded automatically if the bundled font somehow
    /// failed to register.
    static func appDisplay(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        appDisplay(size: Theme.pointSize(for: style), weight: weight)
    }

    static func appDisplay(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        guard FontRegistration.isRegistered else {
            return .system(size: size, weight: weight, design: .rounded)
        }
        return .custom("Bricolage Grotesque", size: size).weight(weight)
    }

    /// The app's body typeface (Hanken Grotesk) — used for the handful of prominent
    /// descriptive/lede paragraphs where a distinct body face reinforces the brand; ordinary
    /// UI copy (captions, item rows, etc.) intentionally stays on the system font, which is
    /// what makes native controls feel native.
    static func appBody(_ style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        guard FontRegistration.isRegistered else {
            return .system(style).weight(weight)
        }
        return .custom("Hanken Grotesk", size: Theme.pointSize(for: style)).weight(weight)
    }
}

extension View {
    /// A soft, modern card: rounded corners, translucent material, a hairline border, and a
    /// gentle shadow — used in place of the flat opacity-fill boxes from the original design.
    func cardStyle(padding: CGFloat = 16, corner: CGFloat = Theme.cardCorner) -> some View {
        self
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: corner, style: .continuous).fill(.regularMaterial))
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).stroke(Color.primary.opacity(0.07), lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

/// A filled, gradient-tinted button style for the app's primary actions — replaces the plain
/// system-accent `.borderedProminent` look with something that matches the icon's blue.
struct GradientProminentButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                Capsule(style: .continuous)
                    .fill(isEnabled ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.gray.opacity(0.4)))
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GradientProminentButtonStyle {
    static func gradientProminent(enabled: Bool = true) -> GradientProminentButtonStyle {
        GradientProminentButtonStyle(isEnabled: enabled)
    }
}
