import SwiftUI

// MARK: - Card & rows

/// A grouped card: `card` fill, 10pt continuous radius, 0.5pt hairline outline, and a 0.5pt
/// full-width hairline between each child row. No shadow.
struct RelayCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        _VariadicView.Tree(SeparatedRows()) {
            content
        }
        .background(Color.Relay.card)
        .clipShape(RoundedRectangle(cornerRadius: RelayMetrics.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RelayMetrics.cardRadius, style: .continuous)
                .strokeBorder(Color.Relay.hairline, lineWidth: RelayMetrics.hairlineWidth)
        )
    }

    /// Lays children out top to bottom with a hairline above every row except the first.
    private struct SeparatedRows: _VariadicView_MultiViewRoot {
        func body(children: _VariadicView.Children) -> some View {
            VStack(spacing: 0) {
                ForEach(children) { child in
                    if child.id != children.first?.id {
                        Rectangle()
                            .fill(Color.Relay.hairline)
                            .frame(height: RelayMetrics.hairlineWidth)
                    }
                    child
                }
            }
        }
    }
}

/// A 40pt row: title on the left in `ink`, trailing content on the right.
struct RelayRow<Trailing: View>: View {
    let title: String
    private let trailing: Trailing

    init(title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(Color.Relay.ink)
            Spacer(minLength: 8)
            trailing
        }
        .font(Font.Relay.body)
        .padding(.horizontal, 14)
        .frame(height: RelayMetrics.rowHeight)
    }
}

// MARK: - Buttons

/// Ink fill, background-coloured text, 32pt tall, radius 8. 50% opacity when disabled.
/// No scale-on-press; pressing only dims slightly.
struct RelayPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RelayButtonBody(configuration: configuration, isPrimary: true)
    }
}

/// Card fill, ink text, 0.5pt hairline border, same metrics as the primary button.
struct RelaySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RelayButtonBody(configuration: configuration, isPrimary: false)
    }
}

private struct RelayButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isPrimary: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isPrimary ? Color.Relay.background : Color.Relay.ink)
            .padding(.horizontal, 18)
            .frame(height: 32)
            .background(shape.fill(isPrimary ? Color.Relay.ink : Color.Relay.card))
            .overlay {
                if !isPrimary {
                    shape.strokeBorder(Color.Relay.hairline, lineWidth: RelayMetrics.hairlineWidth)
                }
            }
            .contentShape(shape)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
    }
}

// MARK: - Step progress

/// Segmented progress: 3pt tall, 30pt wide segments with 6pt gaps; `accent` when filled, hairline when not.
struct StepProgress: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(total, 0), id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(index < current ? Color.Relay.accent : Color.Relay.hairline)
                    .frame(width: 30, height: 3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current) of \(total)")
    }
}

// MARK: - Client tile

/// A 62pt selectable tile with the name bottom-left. Selected: 2pt `accent` outline drawn outside
/// the tile edge (like the mockup's box-shadow ring); otherwise a 0.5pt hairline.
struct ClientTile: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: RelayMetrics.cardRadius, style: .continuous)
        Button(action: action) {
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.Relay.ink)
                .lineLimit(1)
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 62, maxHeight: 62, alignment: .bottomLeading)
                .background(shape.fill(Color.Relay.card))
                .overlay {
                    if isSelected {
                        shape.inset(by: -1).stroke(Color.Relay.accent, lineWidth: 2)
                    } else {
                        shape.strokeBorder(Color.Relay.hairline, lineWidth: RelayMetrics.hairlineWidth)
                    }
                }
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}

// MARK: - Status pill

/// Capsule with a 7pt dot (`ready` when connected, `secondary` otherwise) and 12pt secondary text.
struct StatusPill: View {
    let isReady: Bool
    let text: String

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(isReady ? Color.Relay.ready : Color.Relay.secondary)
                .frame(width: 7, height: 7)
            Text(text)
                .font(Font.Relay.secondary)
                .foregroundStyle(Color.Relay.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        // Circular, not continuous: a continuous capsule's hairline leaves a stray vertical tick
        // just outside each end cap.
        .background(Capsule(style: .circular).fill(Color.Relay.card))
        .overlay(Capsule(style: .circular).strokeBorder(Color.Relay.hairline, lineWidth: RelayMetrics.hairlineWidth))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isReady ? "Connected. \(text)" : text)
    }
}

// MARK: - Inline error

/// A 7pt `accent` dot followed by one plain sentence in `ink` at 12.5pt.
struct InlineError: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.Relay.accent)
                .frame(width: 7, height: 7)
                .padding(.top, 5)
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.Relay.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Error: \(text)")
    }
}

// MARK: - Previews

/// Shows the same content in light and dark side by side on the window background.
private struct LightDark<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
                content()
                    .padding(RelayMetrics.gutter)
                    .frame(width: RelayMetrics.windowSize.width)
                    .background(Color.Relay.background)
                    .environment(\.colorScheme, scheme)
            }
        }
    }
}

#Preview("RelayCard + RelayRow") {
    LightDark {
        RelayCard {
            RelayRow(title: "Address") { Text("192.168.0.100").foregroundStyle(Color.Relay.ink) }
            RelayRow(title: "Port") { Text("8080").foregroundStyle(Color.Relay.ink) }
            RelayRow(title: "Use HTTPS") { Toggle("", isOn: .constant(true)).labelsHidden().toggleStyle(.switch).tint(Color.Relay.ready) }
        }
    }
}

#Preview("Buttons") {
    LightDark {
        HStack {
            Button("Back") {}.buttonStyle(RelaySecondaryButtonStyle())
            Spacer()
            Button("Continue") {}.buttonStyle(RelayPrimaryButtonStyle()).disabled(true)
            Button("Connect") {}.buttonStyle(RelayPrimaryButtonStyle())
        }
    }
}

#Preview("StepProgress") {
    LightDark {
        VStack(alignment: .trailing, spacing: 12) {
            StepProgress(current: 1, total: 3)
            StepProgress(current: 2, total: 3)
            StepProgress(current: 3, total: 3)
        }
    }
}

#Preview("ClientTile") {
    LightDark {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ClientTile(name: "qBittorrent", isSelected: true) {}
            ClientTile(name: "Transmission", isSelected: false) {}
            ClientTile(name: "Deluge", isSelected: false) {}
            ClientTile(name: "rTorrent", isSelected: false) {}
            ClientTile(name: "Synology", isSelected: false) {}
        }
    }
}

#Preview("StatusPill") {
    LightDark {
        VStack(spacing: 10) {
            StatusPill(isReady: true, text: "qBittorrent · 192.168.0.100:8080 · checked 2 min ago")
            StatusPill(isReady: false, text: "Not checked yet")
        }
    }
}

#Preview("InlineError") {
    LightDark {
        InlineError(text: "qBittorrent said the username or password is wrong. Check them on its web page and try again.")
    }
}
