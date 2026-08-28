import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        // A ScrollView, not a fixed VStack with top/bottom Spacers: the old layout would get
        // silently clipped from the top whenever the window was shorter than its content
        // (e.g. a restored window frame from before the Full Disk Access banner existed).
        // Scrolling degrades gracefully instead of cutting content off.
        ScrollView {
            VStack(spacing: 28) {
                hero

                VStack(alignment: .leading, spacing: 10) {
                    bullet("Nothing is ever deleted without you personally selecting it and confirming.")
                    bullet("Everything defaults to moving to the Trash first, so it's recoverable.")
                    bullet("Every category is explained: what it is, why it's safe (or not), and what happens if you clear it.")
                }
                .frame(maxWidth: 480, alignment: .leading)
                .cardStyle()

                if !appState.fullDiskAccessGranted {
                    FullDiskAccessBanner()
                }

                VStack(spacing: 10) {
                    Button {
                        appState.startScan()
                    } label: {
                        Text("Scan My Mac")
                            .font(.system(.headline, design: .rounded))
                            .frame(maxWidth: 260)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.gradientProminent())

                    Text("Read-only. Nothing changes on your Mac until you say so.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .padding(32)
            .frame(maxWidth: .infinity)
        }
        .background(heroBackground)
        .onAppear { appState.refreshFullDiskAccessStatus() }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            AppLogoImage(size: 96)
                .shadow(color: Theme.accent.opacity(0.35), radius: 20, x: 0, y: 10)

            VStack(spacing: 6) {
                Text("SDC")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accentGradient)
                Text("System Data Cleaner")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text("If you've looked at About This Mac → Storage and seen a huge \u{201C}System Data\u{201D} bar, this app finds out exactly what's in it, explains it in plain English, and only removes what you approve.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
        }
        .padding(.top, 12)
    }

    private var heroBackground: some View {
        RadialGradient(
            colors: [Theme.accent.opacity(0.12), Color.clear],
            center: .top, startRadius: 0, endRadius: 420
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.accent)
            Text(text).font(.subheadline)
        }
    }
}

struct FullDiskAccessBanner: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("Full Disk Access isn't granted yet").font(.system(.headline, design: .rounded))
            }
            Text("Without it, some folders (like Mail and Time Machine info) will be under-counted or skipped. The app still works, but for the most complete and accurate scan:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("1. Click \u{201C}Open Privacy Settings\u{201D} below").font(.subheadline)
                Text("2. Click the \u{2795} button and add this app (or turn its toggle on if it's already listed)").font(.subheadline)
                Text("3. Come back here and click Scan My Mac again").font(.subheadline)
            }
            HStack {
                Button("Open Privacy Settings") { FullDiskAccess.openSettings() }
                Button("I've granted it — recheck") { appState.refreshFullDiskAccessStatus() }
            }
        }
        .frame(maxWidth: 480, alignment: .leading)
        .cardStyle()
        .overlay(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous).stroke(Color.orange.opacity(0.35), lineWidth: 1))
    }
}
