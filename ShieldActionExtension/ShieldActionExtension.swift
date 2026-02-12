import ManagedSettings
import UserNotifications

class ShieldActionExtension: ShieldActionDelegate {

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            // Do ALL work BEFORE calling completionHandler.
            // The system can kill the extension immediately after the handler fires.
            handleRequestAccess(for: application)
            completionHandler(.defer)

        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }

    // MARK: - Request Access Flow

    private func handleRequestAccess(for token: ApplicationToken) {
        let manager = AppGroupManager.shared

        // Look up the app name from the mapping saved by ShieldConfigurationExtension
        let appName = manager.getTokenName(for: token) ?? "Unknown App"

        // Encode the token so the main app can decode it later
        let tokenData = manager.encodeToken(token)

        // Save the pending unlock request to App Group (file-based)
        let request = PendingUnlockRequest(tokenData: tokenData, appName: appName)
        manager.savePendingUnlockRequest(request)

        // Post a local notification to guide the user to the main app
        postNotification(appName: appName)
    }

    private func postNotification(appName: String) {
        // Fire-and-forget: no async settings check (extension is too short-lived).
        // Permission must be granted during onboarding in the main app.
        let content = UNMutableNotificationContent()
        content.title = "MindfulPhone"
        content.body = "Tap to explain why you need \(appName)"
        content.sound = .default
        content.categoryIdentifier = "UNLOCK_REQUEST"

        let request = UNNotificationRequest(
            identifier: "unlock-request-\(UUID().uuidString)",
            content: content,
            trigger: nil  // Deliver immediately, no delay
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
