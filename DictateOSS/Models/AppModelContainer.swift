import Foundation
import os.log
import SwiftData

enum AppModelContainer {

    private static let logger = Logger(
        subsystem: "com.gmalonso.dictate-oss",
        category: "AppModelContainer"
    )

    static let schema = Schema([
        TranscriptionRecord.self,
        ReplacementRule.self,
        DictionaryEntry.self
    ])

    private static var appSupportURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.gmalonso.dictate-oss", isDirectory: true)
    }

    private static func ensureAppSupportDirectoryExists() {
        try? FileManager.default.createDirectory(
            at: appSupportURL,
            withIntermediateDirectories: true
        )
    }

    private static func makeContainer() -> ModelContainer {
        ensureAppSupportDirectoryExists()

        let storeURL = appSupportURL.appendingPathComponent("DictateOSS.store")
        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            logger.error("ModelContainer creation failed: \(error.localizedDescription). Attempting recovery...")
        }

        deleteStoreFiles()

        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            logger.fault("ModelContainer recreation failed after store deletion: \(error.localizedDescription). Falling back to in-memory.")
        }

        do {
            let inMemoryConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            return try ModelContainer(for: schema, configurations: inMemoryConfig)
        } catch {
            fatalError("Failed to create even in-memory ModelContainer: \(error)")
        }
    }

    private static func deleteStoreFiles() {
        let storeExtensions: Set<String> = ["store", "store-shm", "store-wal"]

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: appSupportURL,
            includingPropertiesForKeys: nil
        ) else { return }

        for fileURL in contents where storeExtensions.contains(fileURL.pathExtension) {
            try? FileManager.default.removeItem(at: fileURL)
            logger.warning("Deleted corrupted store file: \(fileURL.lastPathComponent)")
        }
    }

    // MARK: - App Container (local-only)
    static let container: ModelContainer = makeContainer()
}
