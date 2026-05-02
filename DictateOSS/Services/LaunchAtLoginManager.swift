import Foundation
import os
import ServiceManagement

/// Manages launch at login via SMAppService (macOS 13+).
enum LaunchAtLoginManager {
    private static let logger = Logger(
        subsystem: "com.gmalonso.dictate-oss",
        category: "LaunchAtLoginManager"
    )

    /// Whether launch at login is currently enabled according to the system.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters the app for launch at login.
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                logger.info("Launch at login registered")
            } else {
                try SMAppService.mainApp.unregister()
                logger.info("Launch at login unregistered")
            }
        } catch {
            logger.error("Failed to set launch at login: \(error.localizedDescription)")
        }
    }
}
