import SwiftUI

enum OverlaySettingsViewStyle {
    case card
    case embedded
}

struct OverlaySettingsView: View {
    @AppStorage(MacAppKeys.overlayPosition, store: .app)
    private var overlayPositionRaw: String = OverlayPosition.default.rawValue

    @AppStorage(MacAppKeys.soundFeedbackEnabled, store: .app)
    private var soundFeedbackEnabled: Bool = true

    @AppStorage(MacAppKeys.soundFeedbackVolume, store: .app)
    private var soundFeedbackVolume: Double = 0.7

    private let audioFeedback = AudioFeedbackManager()
    let style: OverlaySettingsViewStyle
    private let rowFont = SettingsComponents.rowFont
    private let helperFont = SettingsComponents.helperFont

    init(style: OverlaySettingsViewStyle = .card) {
        self.style = style
    }

    private var selectedPosition: OverlayPosition {
        OverlayPosition(rawValue: overlayPositionRaw) ?? .default
    }

    private var verticalBinding: Binding<Int> {
        Binding(
            get: { selectedPosition.gridRow },
            set: { overlayPositionRaw = OverlayPosition.grid[$0][selectedPosition.gridColumn].rawValue }
        )
    }

    private var horizontalBinding: Binding<Int> {
        Binding(
            get: { selectedPosition.gridColumn },
            set: { overlayPositionRaw = OverlayPosition.grid[selectedPosition.gridRow][$0].rawValue }
        )
    }

    var body: some View {
        Group {
            if style == .card {
                SettingsComponents.card {
                    content
                }
            } else {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Posição do overlay"))
                .font(rowFont)

            HStack(spacing: 12) {
                Text(String(localized: "Vertical"))
                    .font(helperFont)
                    .foregroundStyle(.secondary)

                Picker("", selection: verticalBinding) {
                    Text(String(localized: "Superior")).tag(0)
                    Text(String(localized: "Centro")).tag(1)
                    Text(String(localized: "Inferior")).tag(2)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 120)

                Text(String(localized: "Horizontal"))
                    .font(helperFont)
                    .foregroundStyle(.secondary)

                Picker("", selection: horizontalBinding) {
                    Text(String(localized: "Esquerda")).tag(0)
                    Text(String(localized: "Centro")).tag(1)
                    Text(String(localized: "Direita")).tag(2)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 120)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)

        SettingsComponents.divider()

        // Sound feedback toggle
        HStack {
            Text(String(localized: "Sons de feedback"))
                .font(rowFont)

            Spacer()

            Toggle("", isOn: $soundFeedbackEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)

        if soundFeedbackEnabled {
            SettingsComponents.divider()

            // Volume
            HStack {
                Text(String(localized: "Volume"))
                    .font(rowFont)
                Slider(value: $soundFeedbackVolume, in: 0.1...1.0, step: 0.1)
                Text("\(Int(soundFeedbackVolume * 100))%")
                    .font(helperFont)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)

                Button {
                    audioFeedback.playTest()
                } label: {
                    Text(String(localized: "Testar"))
                        .font(rowFont)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }
}

#Preview {
    OverlaySettingsView()
        .frame(width: 500, height: 400)
}
