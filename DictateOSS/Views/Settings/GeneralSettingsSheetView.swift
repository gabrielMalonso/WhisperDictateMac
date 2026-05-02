import SwiftUI

struct GeneralSettingsSheetView: View {
    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    @AppStorage(MacAppKeys.preferredMicrophoneID, store: .app)
    private var preferredMicrophoneID = ""

    @State private var launchAtLogin: Bool
    @State private var availableMicrophones: [MicrophoneDevice] = []

    let modalSize: CGSize

    private let defaults = UserDefaults.app
    private let microphoneProvider = SystemMicrophoneProvider()

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    private let rowFont = SettingsComponents.rowFont

    init(
        modalSize: CGSize = CGSize(
            width: SettingsModalLayout.maxWidth,
            height: SettingsModalLayout.maxHeight
        )
    ) {
        self.modalSize = modalSize
        _launchAtLogin = State(initialValue: UserDefaults.app.bool(forKey: MacAppKeys.launchAtLogin))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                appBehaviorCard
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(width: modalSize.width, height: modalSize.height)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 24, y: 10)
        .onAppear {
            reloadMicrophones()
        }
    }

    private var header: some View {
        HStack {
            Text(String(localized: "Geral"))
                .font(.system(size: 28, weight: .bold, design: .serif))

            Spacer()
        }
    }

    private var appBehaviorCard: some View {
        SettingsComponents.card {
            HStack {
                Text(String(localized: "Abrir ao iniciar sessão"))
                    .font(rowFont)

                Spacer()

                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .onChange(of: launchAtLogin) { _, newValue in
                defaults.set(newValue, forKey: MacAppKeys.launchAtLogin)
                LaunchAtLoginManager.setEnabled(newValue)
            }

            SettingsComponents.divider()

            HotkeySettingView(style: .compactRow)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

            SettingsComponents.divider()

            HotkeySettingView(style: .compactRow, kind: .translation)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

            SettingsComponents.divider()

            HotkeySettingView(style: .compactRow, kind: .pasteLast)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

            SettingsComponents.divider()

            microphoneSelectionSection
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

            SettingsComponents.divider()

            OverlaySettingsView(style: .embedded)
        }
    }

    private var microphoneSelectionSection: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(String(localized: "Microfone de entrada"))
                .font(rowFont)

            Spacer(minLength: 16)

            Picker(String(localized: "Microfone de entrada"), selection: $preferredMicrophoneID) {
                Text(systemDefaultPickerLabel)
                    .tag("")

                if !savedMicrophoneAvailable && !preferredMicrophoneID.isEmpty {
                    Text(String(localized: "Microfone indisponível"))
                        .tag(preferredMicrophoneID)
                }

                ForEach(availableMicrophones) { microphone in
                    Text(microphone.name)
                        .tag(microphone.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 280)
        }
    }

    private var systemDefaultMicrophoneName: String {
        availableMicrophones.first(where: \.isSystemDefault)?.name ?? String(localized: "Padrão do sistema")
    }

    private var systemDefaultPickerLabel: String {
        String(localized: "Padrão do sistema (\(systemDefaultMicrophoneName))")
    }

    private var savedMicrophoneAvailable: Bool {
        MicrophoneSelectionResolver.resolve(
            savedDeviceID: preferredMicrophoneID,
            availableDevices: availableMicrophones
        ).savedSelectionAvailable
    }

    private func reloadMicrophones() {
        availableMicrophones = microphoneProvider.availableMicrophones()
    }
}

#Preview {
    GeneralSettingsSheetView()
}
