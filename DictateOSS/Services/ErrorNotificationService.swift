import Foundation
import UserNotifications

final class ErrorNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ErrorNotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let debounceLock = NSLock()
    private var lastNotificationTimes: [String: Date] = [:]
    private let debounceInterval: TimeInterval = 30

    private override init() {
        super.init()
        notificationCenter.delegate = self
        requestPermission()
    }

    // MARK: - Public API

    func showError(title: String, message: String) {
        postNotification(id: "error-\(title)", title: title, body: message)
    }

    func showInfo(title: String, message: String) {
        postNotification(id: "info-\(title)", title: title, body: message)
    }

    func showPermissionRequired(_ permission: String) {
        showError(
            title: String(localized: "Permissão Necessária"),
            message: AppText.permissionRequired(permission)
        )
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }

    // MARK: - Private

    private func requestPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func postNotification(id: String, title: String, body: String) {
        guard shouldShowNotification(for: id) else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(id)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request)
    }

    private func shouldShowNotification(for key: String) -> Bool {
        debounceLock.lock()
        defer { debounceLock.unlock() }

        let now = Date()
        if let lastTime = lastNotificationTimes[key],
           now.timeIntervalSince(lastTime) < debounceInterval {
            return false
        }

        lastNotificationTimes[key] = now
        return true
    }
}
