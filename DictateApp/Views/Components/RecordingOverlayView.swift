import SwiftUI

struct RecordingOverlayView: View {
    @ObservedObject var dictationManager = DictationManager.shared

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    @AppStorage(MacAppKeys.overlayPosition, store: .app)
    private var overlayPositionRaw: String = OverlayPosition.default.rawValue

    @State private var amplitudeHistory: [Float] = Array(repeating: 0, count: 12)

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    private var timerText: String {
        formatRecordingTimer(seconds: dictationManager.elapsedSeconds)
    }

    private var isNearRecordingLimit: Bool {
        checkNearRecordingLimit(elapsedSeconds: dictationManager.elapsedSeconds)
    }

    private var isPreparing: Bool {
        dictationManager.state == .arming
    }

    private var canStop: Bool {
        dictationManager.state == .recording
    }

    private var overlayBanner: RecordingOverlayBanner? {
        dictationManager.overlayBanner
    }

    private var overlayPosition: OverlayPosition {
        OverlayPosition(rawValue: overlayPositionRaw) ?? .default
    }

    private var overlayWidth: CGFloat {
        overlayBanner == nil
            ? RecordingOverlayPanelController.compactSize.width
            : RecordingOverlayPanelController.expandedSize.width
    }

    private var stackAlignment: HorizontalAlignment {
        switch overlayPosition.gridColumn {
        case 0: .leading
        case 2: .trailing
        default: .center
        }
    }

    private var frameAlignment: Alignment {
        switch overlayPosition.gridColumn {
        case 0: .leading
        case 2: .trailing
        default: .center
        }
    }

    private var showsBannerAboveOverlay: Bool {
        overlayPosition.gridRow == 2
    }

    var body: some View {
        VStack(alignment: stackAlignment, spacing: overlayBanner == nil ? 0 : 8) {
            if showsBannerAboveOverlay, let overlayBanner {
                overlayBannerView(overlayBanner)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            mainRow

            if !showsBannerAboveOverlay, let overlayBanner {
                overlayBannerView(overlayBanner)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(width: overlayWidth)
        .onReceive(dictationManager.$currentAmplitude) { amplitude in
            withAnimation(.easeOut(duration: 0.1)) {
                amplitudeHistory.removeFirst()
                amplitudeHistory.append(amplitude)
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: overlayBanner)
    }

    private var mainRow: some View {
        HStack(spacing: 6) {
            Button {
                guard canStop else { return }
                Task { await dictationManager.toggle() }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(accentColor, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: isPreparing ? "Preparando..." : "Parar gravação"))

            if dictationManager.state == .transcribing || isPreparing {
                ProgressView()
                    .controlSize(.small)
                    .tint(accentColor)
                    .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 4) {
                    waveformView
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(String(localized: "Nível de áudio"))

                    Text(timerText)
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(isNearRecordingLimit ? .red : .primary.opacity(0.75))
                        .fixedSize()
                        .accessibilityLabel(String(localized: "Tempo de gravação: \(timerText)"))
                }
            }

            Button {
                dictationManager.cancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Cancelar gravação"))
        }
        .padding(.horizontal, 10)
        .frame(width: RecordingOverlayPanelController.compactSize.width,
               height: RecordingOverlayPanelController.compactSize.height)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(accentColor.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        )
        .clipShape(Capsule())
        .frame(maxWidth: overlayWidth, alignment: frameAlignment)
    }

    @ViewBuilder
    private func overlayBannerView(_ banner: RecordingOverlayBanner) -> some View {
        let palette = bannerPalette(for: banner.style)

        HStack(spacing: 8) {
            Image(systemName: banner.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.foreground)

            Text(banner.message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary.opacity(0.88))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(width: RecordingOverlayPanelController.bannerWidth)
        .background(
            Capsule()
                .fill(palette.background)
                .overlay(
                    Capsule()
                        .strokeBorder(palette.border, lineWidth: 1)
                )
        )
        .frame(maxWidth: overlayWidth, alignment: frameAlignment)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(banner.message))
    }

    private var waveformView: some View {
        HStack(spacing: 2) {
            ForEach(0..<12, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(accentColor.opacity(0.85))
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .frame(height: 24)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let amplitude = CGFloat(amplitudeHistory[index])
        let boosted = pow(amplitude, 0.4)
        let minHeight: CGFloat = 3
        let maxHeight: CGFloat = 24
        return minHeight + (maxHeight - minHeight) * boosted
    }

    private func bannerPalette(for style: RecordingOverlayBannerStyle) -> (
        foreground: Color,
        background: Color,
        border: Color
    ) {
        switch style {
        case .info:
            return (.blue.opacity(0.95), .blue.opacity(0.12), .blue.opacity(0.22))
        case .warning:
            return (.orange.opacity(0.95), .orange.opacity(0.13), .orange.opacity(0.24))
        case .error:
            return (.red.opacity(0.95), .red.opacity(0.13), .red.opacity(0.24))
        }
    }
}
