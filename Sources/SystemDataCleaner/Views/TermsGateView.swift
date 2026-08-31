import SwiftUI
import AppKit

/// Blocking gate shown before the very first scan (and again after any terms change).
/// Nothing else in the app is reachable until this is explicitly accepted.
struct TermsGateView: View {
    @EnvironmentObject var appState: AppState
    @State private var agreed = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                AppLogoImage(size: 56)
                Text("Before you use SDC").font(.system(.title2, design: .rounded)).bold()
                Text(Legal.shortDisclaimer)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
            .padding(.top, 28)
            .padding(.bottom, 18)
            .padding(.horizontal, 32)

            Divider()

            ScrollView {
                Text(Legal.fullTermsText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .frame(maxHeight: .infinity)
            .background(Color.primary.opacity(0.03))

            Divider()

            VStack(spacing: 14) {
                Toggle(isOn: $agreed) {
                    Text("I have read and agree to the Terms of Use above, including that I am solely responsible for reviewing and selecting what SDC scans and deletes, and that SDC is provided with no warranty.")
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .toggleStyle(.checkbox)

                HStack {
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                    Spacer()
                    Button {
                        Legal.recordAcceptance()
                        appState.phase = .welcome
                    } label: {
                        Text("I Agree & Continue")
                            .font(.system(.headline, design: .rounded))
                            .padding(.horizontal, 18).padding(.vertical, 9)
                    }
                    .buttonStyle(.gradientProminent(enabled: agreed))
                    .disabled(!agreed)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
