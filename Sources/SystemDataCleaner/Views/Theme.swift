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
