import Foundation
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
            NSLog("[ShieldAction] primaryButtonPressed — request access flow")
            handleRequestAccess(
                for: application,
                trigger: "primaryButtonPressed",
                completionHandler: completionHandler
            )

        case .secondaryButtonPressed:
            NSLog("[ShieldAction] secondaryButtonPressed — permanent exempt")
            handlePermanentExempt(
                for: application,
                completionHandler: completionHandler
            )

        @unknown default:
            completionHandler(.close)
        }
    }

    // MARK: - Permanent Exempt (Secondary Button = "Always Allow")

    private func handlePermanentExempt(
        for token: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let manager = AppGroupManager.shared

        // 1. Remove this app from per-app shields
        let store = ManagedSettingsStore()
        store.shield.applications?.remove(token)
        NSLog("[ShieldAction] Removed token from shield.applications")

        // 2. Persist the exemption so it survives reapply cycles
        var exemptTokens = manager.getExemptTokens()
        exemptTokens.insert(token)
        manager.saveExemptTokens(exemptTokens)
        NSLog("[ShieldAction] Saved token to exempt set (count=%d)", exemptTokens.count)

        // 3. Close the shield — app opens immediately
        completionHandler(.close)
    }

    // MARK: - Request Access Flow

    private func handleRequestAccess(
        for token: ApplicationToken,
        trigger: String,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let manager = AppGroupManager.shared

        let tokenData = manager.encodeToken(token)
        let appName = manager.getTokenName(for: token) ?? "this app"
        let requestPayload = PendingUnlockRequest(tokenData: tokenData, appName: appName)

        // Complete only after scheduling returns (or timeout). If we complete too early,
        // the extension can be torn down before the notification request is committed.
        let completionLock = NSLock()
        var didComplete = false
        func completeOnce(_ response: ShieldActionResponse) {
            completionLock.lock()
            defer { completionLock.unlock() }
            guard !didComplete else { return }
            didComplete = true
            completionHandler(response)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            NSLog("[ShieldAction] completion timeout fallback")
            manager.appendExtensionLog(
                source: "ShieldAction",
                message: "completion timeout fallback",
                persistToSharedFile: false
            )
            completeOnce(.defer)
        }

        postNotification(for: requestPayload, appName: appName) { error in
            NSLog("[ShieldAction] notificationScheduled trigger=%@ success=%@ error=%@",
                  trigger,
                  error == nil ? "YES" : "NO",
                  error?.localizedDescription ?? "(none)")
            manager.appendExtensionLog(
                source: "ShieldAction",
                message: "notificationScheduled trigger=\(trigger) success=\(error == nil) error=\(error?.localizedDescription ?? "(none)")",
                persistToSharedFile: false
            )
            completeOnce(.defer)
        }
    }

    private func postNotification(
        for requestPayload: PendingUnlockRequest,
        appName: String,
        completion: @escaping (Error?) -> Void
    ) {
        let content = UNMutableNotificationContent()
        content.title = "MindfulPhone"
        content.body = appName == "this app"
            ? "Tap to explain why you need this app"
            : "Tap to explain why you need \(appName)"
        content.sound = .default
        content.categoryIdentifier = "UNLOCK_REQUEST"
        content.userInfo = [
            "requestID": requestPayload.id.uuidString,
            "appName": appName,
            "requestTimestamp": requestPayload.timestamp.timeIntervalSince1970,
            "tokenDataBase64": requestPayload.tokenData.base64EncodedString()
        ]

        let request = UNNotificationRequest(
            identifier: "unlock-request-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { error in
            completion(error)
        }
    }

}
