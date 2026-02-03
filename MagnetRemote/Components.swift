import SwiftUI

// MARK: - Section Card

struct MRSectionCard<Content: View>: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MRSpacing.md) {
            HStack(spacing: MRSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.MR.accent)
                    .frame(width: 18)

                Text(title)
                    .font(Font.MR.headline)
                    .foregroundColor(Color.MR.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(Font.MR.caption)
                        .foregroundColor(Color.MR.textTertiary)
                }

                Spacer()
            }

            content()
        }
        .mrCard()
    }
}

// MARK: - Client Selector

struct MRClientSelector: View {
    @Binding var selection: ClientType

    var body: some View {
        HStack(spacing: MRSpacing.sm) {
            ForEach(ClientType.allCases) { client in
                MRClientChip(
                    client: client,
                    isSelected: selection == client
                ) {
                    withAnimation(.mrQuick) {
                        selection = client
                    }
                }
            }
        }
    }
}

struct MRClientChip: View {
    let client: ClientType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: MRSpacing.xs) {
                Image(systemName: client.icon)
                    .font(.system(size: 16, weight: .medium))

                Text(client.displayName)
                    .font(Font.MR.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MRSpacing.sm)
            .padding(.horizontal, MRSpacing.xs)
            .foregroundColor(isSelected ? .white : Color.MR.textSecondary)
            .background(isSelected ? Color.MR.accent : Color.MR.background)
            .clipShape(RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.MR.border, lineWidth: 1)
            )
        }
        .buttonStyle(MRButtonPressStyle())
    }
}

// MARK: - Protocol Toggle

struct MRProtocolToggle: View {
    @Binding var useHTTPS: Bool

    var body: some View {
        HStack(spacing: 0) {
            protocolButton(title: "http", isSelected: !useHTTPS) {
                useHTTPS = false
            }
            protocolButton(title: "https", isSelected: useHTTPS) {
                useHTTPS = true
            }
        }
        .background(Color.MR.background)
        .clipShape(RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous)
                .stroke(Color.MR.border, lineWidth: 1)
        )
    }

    private func protocolButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.mrQuick) { action() } }) {
            Text(title)
                .font(Font.MR.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : Color.MR.textSecondary)
                .padding(.horizontal, MRSpacing.md)
                .padding(.vertical, MRSpacing.sm)
                .background(isSelected ? Color.MR.accent : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Input Field

struct MRInputField: View {
    let icon: String
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var width: CGFloat? = nil

    @FocusState private var isFocused: Bool

    private var hasContent: Bool { !text.isEmpty }
    private var showFloatingLabel: Bool { isFocused || hasContent }

    var body: some View {
        HStack(spacing: MRSpacing.sm) {
            // Icon with background circle
            ZStack {
                Circle()
                    .fill(isFocused ? Color.MR.accent.opacity(0.15) : Color.MR.textTertiary.opacity(0.1))
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isFocused ? Color.MR.accent : Color.MR.textTertiary)
            }
            .animation(.mrQuick, value: isFocused)

            // Field container
            VStack(alignment: .leading, spacing: 2) {
                // Always show label
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(isFocused ? Color.MR.accent : Color.MR.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                // Input
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(Font.MR.body)
                .foregroundColor(Color.MR.textPrimary)
                .focused($isFocused)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, MRSpacing.md)
        .padding(.vertical, MRSpacing.sm)
        .frame(width: width)
        .frame(minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: MRRadius.lg, style: .continuous)
                .fill(isFocused ? Color.MR.inputBackgroundFocused : Color.MR.inputBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MRRadius.lg, style: .continuous)
                .stroke(
                    isFocused ? Color.MR.accent : Color.MR.border.opacity(0.5),
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .animation(.mrQuick, value: isFocused)
    }
}

// MARK: - Compact Input (for inline fields like port)

struct MRCompactInput: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .font(Font.MR.body)
            .foregroundColor(Color.MR.textPrimary)
            .multilineTextAlignment(width != nil ? .center : .leading)
            .focused($isFocused)
            .padding(.horizontal, MRSpacing.md)
            .padding(.vertical, MRSpacing.sm + 4)
            .frame(width: width)
            .frame(minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: MRRadius.lg, style: .continuous)
                    .fill(isFocused ? Color.MR.inputBackgroundFocused : Color.MR.inputBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MRRadius.lg, style: .continuous)
                    .stroke(
                        isFocused ? Color.MR.accent : Color.MR.border.opacity(0.5),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .animation(.mrQuick, value: isFocused)
    }
}

// MARK: - Labeled Field Row

struct MRFieldRow: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: MRSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.MR.accent)
                .frame(width: 16)

            Text(label)
                .font(Font.MR.caption)
                .foregroundColor(Color.MR.textTertiary)
        }
    }
}

// MARK: - Primary Button

struct MRPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MRSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                }

                Text(title)
                    .font(Font.MR.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, MRSpacing.md)
            .background(isDisabled ? Color.MR.textTertiary : Color.MR.accent)
            .clipShape(RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous))
        }
        .buttonStyle(MRButtonPressStyle())
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Secondary Button

struct MRSecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MRSpacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                }

                Text(title)
                    .font(Font.MR.subheadline)
            }
            .foregroundColor(Color.MR.accent)
            .padding(.horizontal, MRSpacing.md)
            .padding(.vertical, MRSpacing.sm)
            .background(Color.MR.accentMuted)
            .clipShape(RoundedRectangle(cornerRadius: MRRadius.sm, style: .continuous))
        }
        .buttonStyle(MRButtonPressStyle())
    }
}

// MARK: - Icon Button

struct MRIconButton: View {
    let icon: String
    var size: CGFloat = 32
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.MR.textSecondary)
                .frame(width: size, height: size)
                .background(Color.MR.surface)
                .clipShape(RoundedRectangle(cornerRadius: MRRadius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: MRRadius.sm, style: .continuous)
                        .stroke(Color.MR.border, lineWidth: 1)
                )
        }
        .buttonStyle(MRButtonPressStyle())
    }
}

// MARK: - Button Press Style

struct MRButtonPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.mrQuick, value: configuration.isPressed)
    }
}

// MARK: - Text Field (Full)

struct MRTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: MRSpacing.xs) {
            Text(label)
                .font(Font.MR.caption)
                .foregroundColor(Color.MR.textTertiary)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(Font.MR.body)
            .padding(.horizontal, MRSpacing.md)
            .padding(.vertical, MRSpacing.sm + 2)
            .background(Color.MR.background)
            .clipShape(RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous)
                    .stroke(Color.MR.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Picker Field

struct MRPickerField<T: Hashable & Identifiable>: View where T: CaseIterable {
    let label: String
    @Binding var selection: T
    let displayName: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: MRSpacing.xs) {
            Text(label)
                .font(Font.MR.caption)
                .foregroundColor(Color.MR.textTertiary)

            Picker("", selection: $selection) {
                ForEach(Array(T.allCases), id: \.self) { item in
                    Text(displayName(item)).tag(item)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .padding(.horizontal, MRSpacing.sm)
            .padding(.vertical, MRSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.MR.background)
            .clipShape(RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous)
                    .stroke(Color.MR.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Status Badge

struct MRStatusBadge: View {
    enum Status {
        case success
        case error
        case warning
        case neutral

        var color: Color {
            switch self {
            case .success: return Color.MR.success
            case .error: return Color.MR.error
            case .warning: return Color.MR.warning
            case .neutral: return Color.MR.textSecondary
            }
        }

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.circle.fill"
            case .neutral: return "circle.fill"
            }
        }
    }

    let status: Status
    let message: String

    var body: some View {
        HStack(spacing: MRSpacing.sm) {
            Image(systemName: status.icon)
                .font(.system(size: 14))

            Text(message)
                .font(Font.MR.subheadline)
        }
        .foregroundColor(status.color)
        .padding(.horizontal, MRSpacing.md)
        .padding(.vertical, MRSpacing.sm)
        .background(status.color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: MRRadius.full, style: .continuous))
    }
}

// MARK: - Toggle Row

struct MRToggleRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: MRSpacing.md) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.MR.accent)
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: MRSpacing.xxs) {
                Text(title)
                    .font(Font.MR.body)
                    .foregroundColor(Color.MR.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(Font.MR.caption)
                        .foregroundColor(Color.MR.textTertiary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color.MR.accent)
        }
    }
}

// MARK: - Divider

struct MRDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.MR.divider)
            .frame(height: 1)
    }
}

// MARK: - Empty State

struct MREmptyState: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: MRSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color.MR.textTertiary)

            VStack(spacing: MRSpacing.xs) {
                Text(title)
                    .font(Font.MR.headline)
                    .foregroundColor(Color.MR.textPrimary)

                Text(message)
                    .font(Font.MR.subheadline)
                    .foregroundColor(Color.MR.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let buttonTitle = buttonTitle, let buttonAction = buttonAction {
                MRSecondaryButton(title: buttonTitle, action: buttonAction)
            }
        }
        .padding(MRLayout.gutter)
    }
}

// MARK: - Info Row

struct MRInfoRow: View {
    let label: String
    let value: String
    var icon: String? = nil

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.MR.textTertiary)
                    .frame(width: 20)
            }

            Text(label)
                .font(Font.MR.subheadline)
                .foregroundColor(Color.MR.textSecondary)

            Spacer()

            Text(value)
                .font(Font.MR.subheadline)
                .foregroundColor(Color.MR.textPrimary)
        }
    }
}
