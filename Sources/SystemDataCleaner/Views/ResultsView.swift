import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    tierSection(.safe)
                    tierSection(.caution)
                    tierSection(.advanced)
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: Binding(
            get: { appState.phase == .confirming },
            set: { if !$0 { appState.phase = .results } }
        )) {
            ConfirmationSheet()
        }
    }

    private var header: some View {
        HStack {
            AppLogoImage(size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text("Here's what's in your System Data").font(.system(.title2, design: .rounded)).bold()
                Text("\(Sizes.format(appState.totalFoundSize)) found across \(appState.categories.filter { !$0.items.isEmpty }.count) categories. Nothing is selected yet — pick what you'd like to clean below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Scan Again") { appState.startScan() }
        }
        .padding(20)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func tierSection(_ tier: RiskTier) -> some View {
        let cats = appState.categories.filter { $0.tier == tier && !$0.items.isEmpty }
        if !cats.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: tierSymbol(tier)).foregroundStyle(tierColor(tier))
                    Text(tier.label).font(.system(.title3, design: .rounded)).bold()
                    Text("— \(tier.shortBlurb)").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(cats) { category in
                    CategoryRowView(category: category)
                }
            }
        }
    }

    private func tierSymbol(_ tier: RiskTier) -> String {
        switch tier {
        case .safe: return "checkmark.seal.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .advanced: return "exclamationmark.octagon.fill"
        }
    }

    private func tierColor(_ tier: RiskTier) -> Color {
        switch tier {
        case .safe: return .green
        case .caution: return .orange
        case .advanced: return .red
        }
    }

    private var footer: some View {
        HStack {
            if appState.hasAnySelection {
                Text("\(appState.totalSelectedCount) item(s) selected — \(Sizes.format(appState.totalSelectedSize))")
                    .font(.system(.headline, design: .rounded))
            } else {
                Text("Nothing selected yet").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                appState.requestClean()
            } label: {
                Text("Review & Clean Selected…")
                    .font(.system(.headline, design: .rounded))
                    .padding(.horizontal, 16).padding(.vertical, 8)
            }
            .buttonStyle(.gradientProminent(enabled: appState.hasAnySelection))
            .disabled(!appState.hasAnySelection)
        }
        .padding(20)
        .background(.regularMaterial)
    }
}
