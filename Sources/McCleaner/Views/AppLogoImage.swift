import SwiftUI
import AppKit

/// The app's real icon artwork, wherever the UI needs a logo (not just the Dock/Finder
/// icon, which comes from the bundled .icns separately). Falls back to a system symbol if
/// the bundled resource is ever missing, so a packaging mistake degrades gracefully instead
/// of crashing.
struct AppLogoImage: View {
    var size: CGFloat = 64

    var body: some View {
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        } else {
            Image(systemName: "internaldrive.fill")
                .font(.system(size: size * 0.7))
                .foregroundStyle(.tint)
                .frame(width: size, height: size)
        }
    }
}
