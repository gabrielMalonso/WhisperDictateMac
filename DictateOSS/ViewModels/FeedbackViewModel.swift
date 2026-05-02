import AppKit
import os
import SwiftUI

private let logger = Logger(subsystem: "com.gmalonso.dictate-oss", category: "FeedbackViewModel")

// MARK: - FeedbackTopic

enum FeedbackTopic: String, CaseIterable, Identifiable {
    case bug
    case suggestion
    case question
    case praise

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bug: return String(localized: "Bug")
        case .suggestion: return String(localized: "Sugestão")
        case .question: return String(localized: "Dúvida")
        case .praise: return String(localized: "Elogio")
        }
    }

    var symbolName: String {
        switch self {
        case .bug: return "ladybug"
        case .suggestion: return "lightbulb"
        case .question: return "questionmark.circle"
        case .praise: return "heart"
        }
    }
}

// MARK: - FeedbackViewModel

@MainActor
final class FeedbackViewModel: ObservableObject {

    private static let maxImages = 3
    private static let maxImageDimension: CGFloat = 1024
    private static let jpegQuality: CGFloat = 0.7

    // MARK: Published properties

    @Published var selectedTopic: FeedbackTopic?
    @Published var subject: String = ""
    @Published var descriptionText: String = ""
    @Published var loadedImageData: [Data] = []
    @Published var loadedImages: [NSImage] = []
    @Published var isSubmitting: Bool = false
    @Published var showSuccess: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    // MARK: Computed properties

    var isValid: Bool {
        selectedTopic != nil
            && !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && subject.count <= 100
            && !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && descriptionText.count <= 1000
    }

    // MARK: Image handling

    func loadImages(from urls: [URL]) {
        let urlsToLoad = Array(urls.prefix(Self.maxImages))

        var newImageData: [Data] = []
        var newImages: [NSImage] = []

        for url in urlsToLoad {
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            guard let data = try? Data(contentsOf: url) else {
                logger.warning("Failed to read image data from \(url.path)")
                continue
            }

            guard let nsImage = NSImage(data: data) else {
                logger.warning("Failed to create NSImage from data (\(data.count) bytes)")
                continue
            }

            let resized = resizeImage(nsImage, maxDimension: Self.maxImageDimension)
            guard let jpegData = jpegData(from: resized, quality: Self.jpegQuality) else {
                logger.warning("Failed to create JPEG data from resized image")
                continue
            }

            logger.info("Feedback image prepared (\(jpegData.count) bytes JPEG)")
            newImageData.append(jpegData)
            newImages.append(resized)
        }

        loadedImageData = newImageData
        loadedImages = newImages
    }

    func removeImage(at index: Int) {
        guard loadedImageData.indices.contains(index) else { return }
        loadedImageData.remove(at: index)
        loadedImages.remove(at: index)
    }

    // MARK: Submit

    func submitFeedback() async {
        guard let topic = selectedTopic else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        var components = URLComponents(string: "https://github.com/gabrielMalonso/WhisperDictateMac/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: "[\(topic.label)] \(subject)"),
            URLQueryItem(name: "body", value: """
            ## \(topic.label)

            \(descriptionText)

            ---
            App: \(appVersion)
            Locale: \(Locale.current.identifier)
            Plataforma: macOS
            Imagens anexadas localmente: \(loadedImages.count)
            """)
        ]

        guard let url = components?.url else {
            errorMessage = AppText.feedbackURLFailure()
            showError = true
            return
        }

        NSWorkspace.shared.open(url)
        logger.info("Opened GitHub issue URL for feedback")
        showSuccess = true
    }

    // MARK: Private helpers

    private func resizeImage(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }

        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()
        return newImage
    }

    private func jpegData(from image: NSImage, quality: CGFloat) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
}
