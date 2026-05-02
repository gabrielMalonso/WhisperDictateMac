import AppKit
import Combine
import SwiftUI

@MainActor
final class RecordingOverlayPanelController {
    static let shared = RecordingOverlayPanelController()
    static let compactSize = NSSize(width: 220, height: 44)
    static let bannerWidth = CGFloat(260)
    static let expandedSize = NSSize(width: 300, height: 92)

    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    private let dictationManager: DictationManager
    private let defaults: UserDefaults
    private var lastPosition: OverlayPosition?

    private init() {
        self.dictationManager = DictationManager.shared
        self.defaults = .app
        observeState()
        observeRepositioning()
    }

    // MARK: - State Observation

    private func observeState() {
        Publishers.CombineLatest(dictationManager.$state, dictationManager.$overlayBanner)
            .receive(on: RunLoop.main)
            .sink { [weak self] state, overlayBanner in
                guard let self else { return }
                if self.shouldShowPanel(state: state, overlayBanner: overlayBanner) {
                    self.showPanel()
                    self.repositionPanel(force: true)
                } else {
                    self.hidePanel()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Repositioning Observation

    private func observeRepositioning() {
        // Reposition when user changes position in Settings
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.repositionPanel()
            }
            .store(in: &cancellables)

        // Reposition when screen parameters change (monitor switch, resolution change)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.repositionPanel(force: true)
            }
            .store(in: &cancellables)
    }

    // MARK: - Panel Management

    private func showPanel() {
        if panel == nil {
            createPanel()
        }
        lastPosition = nil
        repositionPanel(force: true)
        guard let panel else { return }
        guard !panel.isVisible else { return }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1
        }
    }

    private func hidePanel() {
        guard let panel else { return }
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                self?.panel?.orderOut(nil)
            }
        })
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.compactSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false
        panel.becomesKeyOnlyIfNeeded = true

        let hostingView = NSHostingView(rootView: RecordingOverlayView())
        panel.contentView = hostingView

        self.panel = panel
    }

    private func repositionPanel(force: Bool = false) {
        guard let panel else { return }
        guard force || panel.isVisible else { return }
        guard let screen = NSScreen.main else { return }

        let position = loadPosition()
        let overlaySize = Self.overlaySize(for: dictationManager.overlayBanner)
        guard force || position != lastPosition else { return }
        lastPosition = position

        let frame = Self.panelFrame(
            for: position,
            overlaySize: Self.compactSize,
            panelSize: overlaySize,
            screenFrame: screen.visibleFrame
        )
        panel.setFrame(frame, display: true, animate: true)
    }

    // MARK: - Helpers

    private func shouldShowPanel(
        state: DictationState,
        overlayBanner: RecordingOverlayBanner?
    ) -> Bool {
        state != .idle || overlayBanner != nil
    }

    private static func overlaySize(for overlayBanner: RecordingOverlayBanner?) -> NSSize {
        overlayBanner == nil ? compactSize : expandedSize
    }

    static func panelFrame(
        for position: OverlayPosition,
        overlaySize: NSSize,
        panelSize: NSSize,
        screenFrame: NSRect
    ) -> NSRect {
        let compactFrame = position.frame(overlaySize: overlaySize, screenFrame: screenFrame)

        let originX: CGFloat
        switch position.gridColumn {
        case 0:
            originX = compactFrame.minX
        case 2:
            originX = compactFrame.maxX - panelSize.width
        default:
            originX = compactFrame.midX - panelSize.width / 2
        }

        let bannerAboveOverlay = position.gridRow == 2
        let originY: CGFloat
        if bannerAboveOverlay {
            originY = compactFrame.minY
        } else {
            originY = compactFrame.minY - (panelSize.height - overlaySize.height)
        }

        return NSRect(origin: CGPoint(x: originX, y: originY), size: panelSize)
    }

    private func loadPosition() -> OverlayPosition {
        guard let raw = defaults.string(forKey: MacAppKeys.overlayPosition) else {
            return .default
        }
        return OverlayPosition(rawValue: raw) ?? .default
    }
}
