import SwiftUI

// MARK: - Card Background (adaptive light/dark)

extension Color {
    /// Matches the iOS `.regularMaterial` card look on macOS.
    static let cardBackground = Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
            return NSColor(srgbRed: 0.110, green: 0.110, blue: 0.118, alpha: 1)
        } else {
            return NSColor(white: 0.955, alpha: 1)
        }
    })
}

// MARK: - Shared Settings Components

enum SettingsComponents {
    static let rowFont = AppTypography.row
    static let helperFont = AppTypography.helper
    static let rowHorizontalPadding: CGFloat = 20
    static let rowIconWidth: CGFloat = 24
    static let rowSpacing: CGFloat = 8

    // MARK: - Card

    static func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
                )
        )
    }

    // MARK: - Section Header

    static func sectionHeader(_ title: String) -> some View {
        Text(title.localizedUppercased())
            .font(.caption.weight(.semibold))
            .tracking(1)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }

    // MARK: - Row

    static func row<Trailing: View>(
        icon: String,
        title: String,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) -> some View {
        SettingsRowView(icon: icon, title: title, trailing: trailing)
    }

    static func row(icon: String, title: String) -> some View {
        row(icon: icon, title: title) {
            EmptyView()
        }
    }

    static func rowWithDescription<Trailing: View>(
        icon: String,
        title: String,
        description: String,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) -> some View {
        SettingsDetailRowView(
            icon: icon,
            title: title,
            description: description,
            trailing: trailing
        )
    }

    // MARK: - Divider

    static func divider() -> some View {
        Rectangle()
            .frame(height: 1)
            .foregroundStyle(Color.primary.opacity(0.04))
    }

    // MARK: - Branded Header

    static func brandedHeader(_ title: String = "DictateOSS") -> some View {
        BrandedHeaderView(title: title)
    }

    static func sidebarBrandHeader() -> some View {
        SidebarBrandHeaderView()
    }
}

private struct SettingsRowView<Trailing: View>: View {
    let icon: String
    let title: String
    let trailing: () -> Trailing

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    var body: some View {
        HStack(spacing: SettingsComponents.rowSpacing) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(accentColor)
                .frame(width: SettingsComponents.rowIconWidth)
            Text(title)
                .font(SettingsComponents.rowFont)
            Spacer()
            trailing()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, SettingsComponents.rowHorizontalPadding)
        .contentShape(Rectangle())
    }
}

private struct SettingsDetailRowView<Trailing: View>: View {
    let icon: String
    let title: String
    let description: String
    let trailing: () -> Trailing

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    var body: some View {
        HStack(alignment: .top, spacing: SettingsComponents.rowSpacing) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(accentColor)
                .frame(width: SettingsComponents.rowIconWidth)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SettingsComponents.rowFont)
                Text(description)
                    .font(SettingsComponents.helperFont)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            trailing()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, SettingsComponents.rowHorizontalPadding)
        .contentShape(Rectangle())
    }
}

// MARK: - Detail Card Style

struct DetailCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            .padding(EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.windowBackgroundColor))
    }
}

extension View {
    func detailCardStyle() -> some View {
        modifier(DetailCardModifier())
    }
}

// MARK: - BrandedHeaderView

private struct BrandedHeaderView: View {
    let title: String

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .serif))
            Text(".")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(accentColor)
        }
    }
}

private struct SidebarBrandHeaderView: View {
    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: -5) {
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("dictate")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                Text(".")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(accentColor)
            }

            Text("(OSS)")
                .font(.system(size: 10, weight: .bold, design: .serif))
                .padding(.trailing, 1)
        }
        .fixedSize()
        .accessibilityLabel("Dictate OSS")
    }
}
