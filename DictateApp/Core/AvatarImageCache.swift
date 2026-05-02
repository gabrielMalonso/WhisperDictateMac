import AppKit
import os

private let logger = Logger(subsystem: "com.gmalonso.dictate-mac", category: "AvatarImageCache")

final class AvatarImageCache {

    static let shared = AvatarImageCache()

    // MARK: - Configuration

    private let cacheDirectoryName = "AvatarCache"
    private let imageFileName = "avatar.jpg"
    private let urlFileName = "avatar-url.txt"

    // MARK: - In-Memory Cache

    private var inMemoryImage: NSImage?
    private(set) var inMemoryURLString: String?

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Returns the cached image instantly from memory if available for the given URL.
    func cachedImage(for urlString: String) -> NSImage? {
        if inMemoryURLString == urlString, let image = inMemoryImage {
            return image
        }

        // Fallback: try disk cache and promote to memory
        if cachedURLString == urlString, let image = loadImageFromDisk() {
            inMemoryImage = image
            inMemoryURLString = urlString
            return image
        }

        return nil
    }

    func loadImage() -> NSImage? {
        if let image = inMemoryImage {
            return image
        }
        guard let image = loadImageFromDisk() else { return nil }
        inMemoryImage = image
        return image
    }

    private func loadImageFromDisk() -> NSImage? {
        guard let imageURL = imageFileURL else { return nil }
        do {
            let data = try Data(contentsOf: imageURL)
            guard let image = NSImage(data: data) else {
                logger.warning("Avatar cache image is invalid or corrupted")
                return nil
            }
            return image
        } catch {
            if isFileNotFoundError(error) {
                return nil
            }
            logger.error("Failed to load avatar cache image: \(error.localizedDescription)")
            return nil
        }
    }

    var cachedURLString: String? {
        guard let urlFileURL = urlFileURL else { return nil }
        do {
            return try String(contentsOf: urlFileURL, encoding: .utf8)
        } catch {
            if isFileNotFoundError(error) {
                return nil
            }
            logger.error("Failed to load avatar cache URL: \(error.localizedDescription)")
            return nil
        }
    }

    func save(_ imageData: Data, for urlString: String) {
        guard let cacheDir = cacheDirectoryURL else { return }

        // Update in-memory cache immediately
        if let image = NSImage(data: imageData) {
            inMemoryImage = image
            inMemoryURLString = urlString
        }

        do {
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create avatar cache directory: \(error.localizedDescription)")
            return
        }

        do {
            let imageURL = cacheDir.appendingPathComponent(imageFileName)
            try imageData.write(to: imageURL, options: .atomic)

            let urlFileURL = cacheDir.appendingPathComponent(urlFileName)
            try urlString.write(to: urlFileURL, atomically: true, encoding: .utf8)

            logger.debug("Avatar cached successfully for URL: \(urlString)")
        } catch {
            logger.error("Failed to save avatar cache: \(error.localizedDescription)")
        }
    }

    func clear() {
        inMemoryImage = nil
        inMemoryURLString = nil
        guard let cacheDir = cacheDirectoryURL else { return }

        let imageURL = cacheDir.appendingPathComponent(imageFileName)
        let urlFileURL = cacheDir.appendingPathComponent(urlFileName)

        let imageRemoved = removeFileIfExists(at: imageURL, label: "image")
        let urlRemoved = removeFileIfExists(at: urlFileURL, label: "url")

        if imageRemoved && urlRemoved {
            logger.debug("Avatar cache cleared")
        } else {
            logger.warning("Avatar cache clear finished with partial failures")
        }
    }

    // MARK: - Private Helpers

    private var cacheDirectoryURL: URL? {
        guard let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return cachesURL
            .appendingPathComponent(AppConfig.appBundleId)
            .appendingPathComponent(cacheDirectoryName)
    }

    private var imageFileURL: URL? {
        cacheDirectoryURL?.appendingPathComponent(imageFileName)
    }

    private var urlFileURL: URL? {
        cacheDirectoryURL?.appendingPathComponent(urlFileName)
    }

    private func removeFileIfExists(at url: URL, label: String) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            if isFileNotFoundError(error) {
                return true
            }
            logger.error("Failed to remove avatar cache \(label): \(error.localizedDescription)")
            return false
        }
    }

    private func isFileNotFoundError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSCocoaErrorDomain else { return false }
        return nsError.code == NSFileNoSuchFileError || nsError.code == NSFileReadNoSuchFileError
    }
}
