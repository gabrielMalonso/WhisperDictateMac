import SwiftUI

// MARK: - DetailRoute

enum DetailRoute: Hashable {
    case statsDetail
    case replacementRules
    case dictionary
    case permissions
    case feedback
}

enum SettingsModal: String, Identifiable {
    case general
    case system

    var id: String { rawValue }
}

enum SettingsModalLayout {
    static let maxWidth: CGFloat = 620
    static let maxHeight: CGFloat = 700
    static let outerPadding: CGFloat = 28
    static let minWidth: CGFloat = 320
    static let minHeight: CGFloat = 320

    static func size(for availableSize: CGSize) -> CGSize {
        let width = max(minWidth, min(maxWidth, availableSize.width - (outerPadding * 2)))
        let height = max(minHeight, min(maxHeight, availableSize.height - (outerPadding * 2)))
        return CGSize(width: width, height: height)
    }

    static let transition = AnyTransition.asymmetric(
        insertion: .offset(y: -36).combined(with: .opacity),
        removal: .offset(y: -18).combined(with: .opacity)
    )

    static let animation = Animation.spring(response: 0.34, dampingFraction: 0.88, blendDuration: 0.12)
}

// MARK: - SidebarItem

enum SidebarItem: String, CaseIterable, Identifiable {
    case home
    case history
    case dictateSettings
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: String(localized: "Início")
        case .history: String(localized: "Histórico")
        case .dictateSettings: "dictate."
        case .settings: String(localized: "Ajustes")
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .history: "clock"
        case .dictateSettings: "waveform"
        case .settings: "gearshape"
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    private enum WindowLayout {
        static let minWidth: CGFloat = 800
        static let minHeight: CGFloat = 560
    }

    @AppStorage(MacAppKeys.onboardingCompleted, store: .app)
    private var onboardingCompleted = false

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    @State private var selectedTab: SidebarItem? = .home
    @State private var detailPath = NavigationPath()
    @State private var stackID = UUID()
    @State private var activeSettingsModal: SettingsModal?
    @Namespace private var sidebarAnimation

    static let rootTransitionAnimation = Animation.spring(response: 0.42, dampingFraction: 0.9, blendDuration: 0.12)

    private let onboardingTransition: AnyTransition = .asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .move(edge: .bottom).combined(with: .opacity)
    )

    private let appContentTransition: AnyTransition = .opacity

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    var body: some View {
        ZStack {
            if !onboardingCompleted {
                OnboardingView()
                    .transition(onboardingTransition)
                    .zIndex(1)
            } else {
                authenticatedContent
                    .transition(appContentTransition)
            }
        }
        .frame(minWidth: WindowLayout.minWidth, minHeight: WindowLayout.minHeight)
        .animation(Self.rootTransitionAnimation, value: onboardingCompleted)
    }

    // MARK: - Authenticated Content

    @ViewBuilder
    private var authenticatedContent: some View {
        ZStack {
            NavigationSplitView {
                sidebar
                    .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            } detail: {
                NavigationStack(path: $detailPath) {
                    detailContent
                        .id(selectedTab)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: selectedTab)
                        .navigationDestination(for: DetailRoute.self) { route in
                            switch route {
                            case .statsDetail: StatsDetailView()
                            case .replacementRules: ReplacementRulesView()
                            case .dictionary: DictionaryView()
                            case .permissions: PermissionsView()
                            case .feedback: FeedbackView()
                            }
                        }
                }
                .id(stackID)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: stackID)
            }
            .zIndex(0)

            if let activeSettingsModal {
                Rectangle()
                    .fill(Color.black.opacity(0.14))
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(10)
                    .onTapGesture {
                        withAnimation(SettingsModalLayout.animation) {
                            self.activeSettingsModal = nil
                        }
                    }

                GeometryReader { proxy in
                    settingsModalView(
                        activeSettingsModal,
                        modalSize: SettingsModalLayout.size(for: proxy.size)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(SettingsModalLayout.outerPadding)
                }
                .ignoresSafeArea()
                .transition(SettingsModalLayout.transition)
                .zIndex(11)
            }
        }
        .toolbar(activeSettingsModal == nil ? .visible : .hidden, for: .windowToolbar)
        .onChange(of: selectedTab) { _, newValue in
            if newValue != .settings {
                withAnimation(SettingsModalLayout.animation) {
                    activeSettingsModal = nil
                }
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Branded header — aligned left
            SettingsComponents.brandedHeader()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)

            // Custom sidebar items
            VStack(spacing: 2) {
                ForEach(SidebarItem.allCases) { item in
                    sidebarButton(item)
                }
            }
            .padding(.horizontal, 8)

            Spacer()
        }
    }

    private func sidebarButton(_ item: SidebarItem) -> some View {
        let isSelected = selectedTab == item

        return Button {
            withAnimation(.snappy(duration: 0.25)) {
                if !detailPath.isEmpty {
                    stackID = UUID()
                }
                detailPath = NavigationPath()
                selectedTab = item
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.icon)
                    .font(SettingsComponents.rowFont)
                    .foregroundStyle(isSelected ? accentColor : .secondary)
                    .frame(width: 20)
                Text(item.label)
                    .font(SettingsComponents.rowFont)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accentColor.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
                        )
                        .matchedGeometryEffect(id: "sidebarSelection", in: sidebarAnimation)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .home:
            HomeView()
        case .history:
            HistoryView()
        case .dictateSettings:
            DictateSettingsView()
        case .settings:
            SettingsView(activeSettingsModal: $activeSettingsModal)
        case .none:
            Text(String(localized: "Selecione um item na barra lateral"))
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func settingsModalView(_ modal: SettingsModal, modalSize: CGSize) -> some View {
        switch modal {
        case .general:
            GeneralSettingsSheetView(modalSize: modalSize)
        case .system:
            SystemSettingsSheetView(
                modalSize: modalSize,
                openPermissions: {
                    withAnimation(SettingsModalLayout.animation) {
                        activeSettingsModal = nil
                    }
                    detailPath.append(DetailRoute.permissions)
                },
                resetOnboarding: {
                    withAnimation(SettingsModalLayout.animation) {
                        activeSettingsModal = nil
                    }
                    withAnimation(Self.rootTransitionAnimation) {
                        onboardingCompleted = false
                    }
                }
            )
        }
    }
}

#Preview {
    ContentView()
}
