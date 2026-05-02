import Foundation
import AppKit

enum OverlayPosition: String, CaseIterable, Identifiable, Codable {
    case topLeft, top, topRight
    case left, center, right
    case bottomLeft, bottom, bottomRight

    var id: String { rawValue }
    static var `default`: OverlayPosition { .bottom }

    var displayName: String {
        switch self {
        case .topLeft: return String(localized: "Superior esquerdo")
        case .top: return String(localized: "Superior")
        case .topRight: return String(localized: "Superior direito")
        case .left: return String(localized: "Esquerda")
        case .center: return String(localized: "Centro")
        case .right: return String(localized: "Direita")
        case .bottomLeft: return String(localized: "Inferior esquerdo")
        case .bottom: return String(localized: "Inferior")
        case .bottomRight: return String(localized: "Inferior direito")
        }
    }

    var gridRow: Int {
        switch self {
        case .topLeft, .top, .topRight: return 0
        case .left, .center, .right: return 1
        case .bottomLeft, .bottom, .bottomRight: return 2
        }
    }

    var gridColumn: Int {
        switch self {
        case .topLeft, .left, .bottomLeft: return 0
        case .top, .center, .bottom: return 1
        case .topRight, .right, .bottomRight: return 2
        }
    }

    /// Direct O(1) lookup from grid coordinates to position.
    static let grid: [[OverlayPosition]] = [
        [.topLeft, .top, .topRight],
        [.left, .center, .right],
        [.bottomLeft, .bottom, .bottomRight],
    ]

    /// Pure function - computes frame without depending on NSScreen
    func frame(overlaySize: CGSize, screenFrame: NSRect, inset: CGFloat = 20) -> NSRect {
        let x: CGFloat
        let y: CGFloat

        switch gridColumn {
        case 0: x = screenFrame.minX + inset
        case 2: x = screenFrame.maxX - overlaySize.width - inset
        default: x = screenFrame.midX - overlaySize.width / 2
        }

        switch gridRow {
        case 0: y = screenFrame.maxY - overlaySize.height - inset
        case 2: y = screenFrame.minY + inset
        default: y = screenFrame.midY - overlaySize.height / 2
        }

        return NSRect(origin: CGPoint(x: x, y: y), size: overlaySize)
    }
}
