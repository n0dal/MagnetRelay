import SwiftUI

/// Popover list of the last few links sent. Clicking one sends it again.
struct RecentLinksView: View {
    @ObservedObject var recent: RecentMagnets = .shared
    let onResend: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if recent.items.isEmpty {
                Text("No links yet.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.Relay.secondary)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            } else {
                ForEach(Array(recent.items.prefix(5).enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.Relay.hairline)
                            .frame(height: RelayMetrics.hairlineWidth)
                    }
                    Button {
                        onResend(item.magnetURL)
                    } label: {
                        Text(item.displayName)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.Relay.ink)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Send \(item.displayName) again")
                }
            }

            HStack {
                Spacer()
                Button("Clear") { recent.clear() }
                    .buttonStyle(RelaySecondaryButtonStyle())
                    .disabled(recent.items.isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(14)
        .frame(width: 280)
    }
}
