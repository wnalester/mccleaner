import SwiftUI

func sizeLabel(for item: CleanupItem) -> String {
    switch item.action {
    case .tmutilSnapshot, .simctlDeleteUnavailable:
        return item.sizeBytes > 0 ? "~\(Sizes.format(item.sizeBytes)) (estimate)" : "size varies"
    default:
        return Sizes.format(item.sizeBytes)
    }
}

struct CategoryRowView: View {
    @ObservedObject var category: CleanupCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if category.isExpanded {
                expandedDetail
            }
        }
        .background(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous).stroke(Color.primary.opacity(0.07), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    private var header: some View {
        HStack(spacing: 12) {
            if category.isManualOnly {
                Image(systemName: "hand.point.right.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            } else {
                Toggle("", isOn: Binding(
                    get: { category.allSelected },
                    set: { _ in category.toggleSelectAll() }
                ))
                .toggleStyle(.checkbox)
                .disabled(category.items.isEmpty)
                .labelsHidden()
            }

            ZStack {
                Circle().fill(tierColor.opacity(0.15))
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tierColor)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(category.name).font(.system(.headline, design: .rounded))
                    tierBadge
                }
                Text(category.shortDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if category.items.isEmpty {
                Text(category.scanError == nil ? "Nothing found" : "Couldn't scan")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Sizes.format(category.totalSize)).font(.system(.subheadline, design: .rounded)).bold()
                    if category.someSelected || category.allSelected {
                        Text("\(category.selectedIDs.count) selected").font(.caption2).foregroundStyle(Theme.accent)
                    }
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) { category.isExpanded.toggle() }
            } label: {
                Image(systemName: category.isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(category.items.isEmpty)
        }
        .padding(14)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !category.items.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.15)) { category.isExpanded.toggle() }
        }
    }

    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Group {
                detailLine(label: "What this is", text: category.whatItIs)
                detailLine(label: "Why it's \(category.tier.label.lowercased())", text: category.whyThisTier)
                detailLine(label: "If you clear it", text: category.ifYouDeleteIt)
            }
            .padding(.horizontal, 12)

            if let error = category.scanError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
            }

            if !category.items.isEmpty {
                Divider().padding(.horizontal, 12)
                VStack(spacing: 0) {
                    ForEach(category.items) { item in
                        (category.isManualOnly || !item.isActionable) ? AnyView(plainItemRow(item)) : AnyView(itemRow(item))
                        if item.id != category.items.last?.id { Divider().padding(.leading, 40) }
                    }
                }
            }

            if category.isManualOnly, let instructions = category.manualInstructions {
                manualPanel(instructions: instructions)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
            }
        }
        .padding(.bottom, 12)
    }

    private func plainItemRow(_ item: CleanupItem) -> some View {
        HStack {
            Text(item.displayName).font(.subheadline)
            Spacer()
            Text(sizeLabel(for: item)).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func manualPanel(instructions: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("This one needs one manual step", systemImage: "hand.point.right.fill")
                .font(.system(.subheadline, design: .rounded)).bold()
                .foregroundStyle(Theme.accent)
            Text(instructions)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            if let title = category.manualButtonTitle, let action = category.manualAction {
                Button(title, action: action)
                    .tint(Theme.accent)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accent.opacity(0.08)))
    }

    private func detailLine(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2).bold().foregroundStyle(.secondary)
            Text(text).font(.caption).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func itemRow(_ item: CleanupItem) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { category.selectedIDs.contains(item.id) },
                set: { isOn in
                    if isOn { category.selectedIDs.insert(item.id) } else { category.selectedIDs.remove(item.id) }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            Text(item.displayName)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(sizeLabel(for: item))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            if category.selectedIDs.contains(item.id) { category.selectedIDs.remove(item.id) }
            else { category.selectedIDs.insert(item.id) }
        }
    }

    private var tierBadge: some View {
        Label(category.tier.label, systemImage: tierSymbol)
            .font(.system(.caption2, design: .rounded)).bold()
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(tierColor.opacity(0.15)))
            .foregroundStyle(tierColor)
    }

    private var tierSymbol: String {
        switch category.tier {
        case .safe: return "checkmark.seal.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .advanced: return "exclamationmark.octagon.fill"
        }
    }

    private var tierColor: Color {
        switch category.tier {
        case .safe: return .green
        case .caution: return .orange
        case .advanced: return .red
        }
    }
}
