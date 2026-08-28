import SwiftUI

struct ScanningView: View {
    let progressText: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            AppLogoImage(size: 64)
                .opacity(0.9)
            ProgressView()
                .controlSize(.large)
                .tint(Theme.accent)
            Text("Scanning your Mac…")
                .font(.system(.title2, design: .rounded)).bold()
            Text(progressText)
                .font(.body)
                .foregroundStyle(.secondary)
                .animation(nil, value: progressText)
            Text("This is read-only — nothing is being changed or deleted.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

struct CleaningView: View {
    let progressText: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(Theme.accent)
            Text("Cleaning up…")
                .font(.system(.title2, design: .rounded)).bold()
            Text(progressText)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
