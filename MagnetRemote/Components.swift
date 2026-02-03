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
            VStack(spacing: MRSpacing.xs + 2) {
                Image(systemName: client.icon)
                    .font(.system(size: 22, weight: .medium))

                Text(client.shortName)
                    .font(Font.MR.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MRSpacing.md)
            .padding(.horizontal, MRSpacing.sm)
            .foregroundColor(isSelected ? .white : Color.MR.textSecondary)
            .background(isSelected ? Color.MR.accent : Color.MR.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.MR.border, lineWidth: 1)
            )
        }
        .buttonStyle(MRButtonPressStyle())
        .accessibilityLabel("\(client.displayName) torrent client")
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
    @State private var showPassword: Bool = false

    var body: some View {
        HStack(spacing: MRSpacing.sm) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isFocused ? Color.MR.accent : Color.MR.textTertiary)
                .frame(width: 18)

            // Input field
            Group {
                if isSecure && !showPassword {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundColor(Color.MR.textPrimary)
            .focused($isFocused)

            // Password visibility toggle
            if isSecure {
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.MR.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showPassword ? "Hide password" : "Show password")
            }
        }
        .padding(.horizontal, MRSpacing.md)
        .padding(.vertical, MRSpacing.sm + 2)
        .frame(width: width)
        .frame(height: 40)
        .background(Color.MR.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous)
                .stroke(
                    isFocused ? Color.MR.accent : Color.MR.border,
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .animation(.mrQuick, value: isFocused)
        .accessibilityLabel(label)
    }
}

// MARK: - Compact Input (for inline fields like port)

struct MRCompactInput: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat? = nil
    var numericOnly: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundColor(Color.MR.textPrimary)
            .multilineTextAlignment(width != nil ? .center : .leading)
            .focused($isFocused)
            .padding(.horizontal, MRSpacing.sm)
            .frame(width: width)
            .frame(height: 40)
            .background(Color.MR.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous)
                    .stroke(
                        isFocused ? Color.MR.accent : Color.MR.border,
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .animation(.mrQuick, value: isFocused)
            .onChange(of: text) { newValue in
                if numericOnly {
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue {
                        text = filtered
                    }
                }
            }
            .accessibilityLabel(placeholder)
    }
}

// MARK: - Labeled Field Row

struct MRFieldRow: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: MRSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.MR.accent)
                .frame(width: 18)

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.MR.textSecondary)
                .tracking(0.5)
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
            .foregroundColor(isDisabled ? Color.MR.textTertiary : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, MRSpacing.md)
            .background(isDisabled ? Color.MR.surface : Color.MR.accent)
            .clipShape(RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous)
                    .stroke(isDisabled ? Color.MR.border : Color.clear, lineWidth: 1)
            )
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .buttonStyle(MRButtonPressStyle())
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(title)
        .accessibilityHint(isDisabled ? "Button disabled. Enter server host to enable." : "Double tap to test connection")
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
    var accessibilityText: String = "Button"
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
        .accessibilityLabel(accessibilityText)
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
                .font(.system(size: 14, weight: .medium))

            Text(message)
                .font(Font.MR.headline)
        }
        .foregroundColor(status.color)
        .padding(.horizontal, MRSpacing.md)
        .padding(.vertical, MRSpacing.sm + 2)
        .background(status.color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous)
                .stroke(status.color.opacity(0.3), lineWidth: 1)
        )
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle ?? "")")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint("Double tap to toggle")
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

// MARK: - Connection Status Indicator

struct MRConnectionStatus: View {
    let isConfigured: Bool
    let lastConnected: String?

    var body: some View {
        HStack(spacing: MRSpacing.xs) {
            Circle()
                .fill(isConfigured ? Color.MR.success : Color.MR.textTertiary)
                .frame(width: 8, height: 8)

            if let lastConnected = lastConnected {
                Text("Connected \(lastConnected)")
                    .font(Font.MR.caption)
                    .foregroundColor(Color.MR.textTertiary)
            } else if isConfigured {
                Text("Configured")
                    .font(Font.MR.caption)
                    .foregroundColor(Color.MR.textTertiary)
            } else {
                Text("Not configured")
                    .font(Font.MR.caption)
                    .foregroundColor(Color.MR.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isConfigured ? "Server configured. Last connected \(lastConnected ?? "unknown")" : "Server not configured")
    }
}

// MARK: - Error Message Helper

enum ConnectionError {
    static func userFriendlyMessage(from error: Error) -> String {
        // Handle specific BackendError types first
        if let backendError = error as? BackendError {
            switch backendError {
            case .timeout:
                return "Connection timed out. Is server running?"
            case .insecureConnection(let reason):
                return reason
            case .encodingFailed:
                return "Failed to process magnet URL."
            case .invalidURL:
                return "Invalid server URL."
            case .authenticationFailed:
                return "Invalid username or password."
            case .connectionFailed(let reason):
                return reason
            case .serverError(let reason):
                return reason
            }
        }

        let message = error.localizedDescription.lowercased()

        // Connection refused / host unreachable
        if message.contains("connection refused") ||
           message.contains("could not connect") ||
           message.contains("network is unreachable") ||
           message.contains("host") {
            return "Server not reachable. Check host and port."
        }

        // Timeout
        if message.contains("timed out") || message.contains("timeout") {
            return "Connection timed out. Is server running?"
        }

        // Authentication
        if message.contains("401") ||
           message.contains("unauthorized") ||
           message.contains("authentication") ||
           message.contains("forbidden") ||
           message.contains("403") {
            return "Invalid username or password."
        }

        // SSL/TLS errors
        if message.contains("ssl") ||
           message.contains("certificate") ||
           message.contains("tls") ||
           message.contains("secure connection") {
            return "SSL error. Try disabling HTTPS."
        }

        // DNS errors
        if message.contains("hostname") ||
           message.contains("dns") ||
           message.contains("name or service not known") {
            return "Invalid hostname. Check server address."
        }

        // 404 - wrong path
        if message.contains("404") || message.contains("not found") {
            return "API not found. Check client type and port."
        }

        // Generic network error
        if message.contains("network") || message.contains("internet") {
            return "Network error. Check your connection."
        }

        // Fallback - truncate if too long
        let originalMessage = error.localizedDescription
        if originalMessage.count > 40 {
            return String(originalMessage.prefix(37)) + "..."
        }
        return originalMessage
    }
}
