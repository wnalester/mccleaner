import SwiftUI
import AppKit

struct DoneView: View {
    @EnvironmentObject var appState: AppState
    let freedBytes: Int64
    let failures: Int
    @State private var trashEmptied = false

    var body: some View {
        ScrollView {
        VStack(spacing: 20) {
            Spacer(minLength: 24)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("All done").font(.appDisplay(.title))

            Text("Moved \(Sizes.format(freedBytes)) to the Trash (or removed it directly, where noted).")
                .font(.body)
                .multilineTextAlignment(.center)

            if let billingText {
                Text(billingText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 460)
            }

            if failures > 0 {
                VStack(spacing: 8) {
                    Label("\(failures) item(s) couldn't be removed. Nothing was harmed; they were simply skipped.", systemImage: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 460)
                        .multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(appState.lastResults.filter { !$0.success }.enumerated()), id: \.offset) { _, result in
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(result.categoryName) — \(result.item.displayName)")
                                    .font(.caption).bold()
                                Text(result.errorMessage ?? "unknown error")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: 460, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
                }
            }

            VStack(spacing: 10) {
                if trashEmptied {
                    Label("Trash emptied", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        appState.emptyTrashNow()
                        trashEmptied = true
                    } label: {
                        Text("Empty Trash Now to Free the Space")
                            .font(.appDisplay(.headline))
                            .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                    .buttonStyle(.gradientProminent())
                    Text("Space isn't actually freed up until the Trash is emptied.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                Button("View Cleanup Log") {
                    NSWorkspace.shared.selectFile(Logger.logFilePath, inFileViewerRootedAtPath: "")
                }
                Button("Scan Again") { appState.startScan() }
                Button("Done") { appState.startOver() }
            }
            .padding(.top, 8)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var billingText: String? {
        switch appState.lastCleanBilling {
        case .freeFirstClean: return "This one was free — your first cleanup with SDC."
        case .usedCredit(let remaining): return "Used 1 credit. \(remaining) remaining."
        case .subscription: return "Included in your annual plan."
        case .lifetime: return "Included in your lifetime plan."
        case .purchased(let plan): return "Billed \(plan.priceLabel) for \(plan.title) via Stripe."
        case nil: return nil
        }
    }
}
