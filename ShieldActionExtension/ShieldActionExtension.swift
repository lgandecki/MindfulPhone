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
            NSLog("[ShieldAction] primaryButtonPressed")
            AppGroupManager.shared.appendExtensionLog(
                source: "ShieldAction",
                message: "primaryButtonPressed",
                persistToSharedFile: false
            )
            handleRequestAccess(
                for: application,
                trigger: "primaryButtonPressed",
                completionHandler: completionHandler
            )

        case .secondaryButtonPressed:
            NSLog("[ShieldAction] secondaryButtonPressed")
            AppGroupManager.shared.appendExtensionLog(
                source: "ShieldAction",
                message: "secondaryButtonPressed (routing to request flow)",
                persistToSharedFile: false
            )
            handleRequestAccess(
                for: application,
                trigger: "secondaryButtonPressed",
                completionHandler: completionHandler
            )
        @unknown default:
            NSLog("[ShieldAction] unknownAction")
            AppGroupManager.shared.appendExtensionLog(
                source: "ShieldAction",
                message: "unknownAction",
                persistToSharedFile: false
            )
            completionHandler(.close)
        }
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            NSLog("[ShieldAction] webDomain primaryButtonPressed")
            handleRequestAccessWithoutToken(
                trigger: "webDomain.primaryButtonPressed",
                completionHandler: completionHandler
            )
        case .secondaryButtonPressed:
            NSLog("[ShieldAction] webDomain secondaryButtonPressed")
            handleRequestAccessWithoutToken(
                trigger: "webDomain.secondaryButtonPressed",
                completionHandler: completionHandler
            )
        @unknown default:
            NSLog("[ShieldAction] webDomain unknownAction")
            completionHandler(.close)
        }
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            NSLog("[ShieldAction] category primaryButtonPressed")
            handleRequestAccessWithoutToken(
                trigger: "category.primaryButtonPressed",
                completionHandler: completionHandler
            )
        case .secondaryButtonPressed:
            NSLog("[ShieldAction] category secondaryButtonPressed")
            handleRequestAccessWithoutToken(
                trigger: "category.secondaryButtonPressed",
                completionHandler: completionHandler
            )
        @unknown default:
            NSLog("[ShieldAction] category unknownAction")
            completionHandler(.close)
        }
    }

    // MARK: - Request Access Flow

    private func handleRequestAccess(
        for token: ApplicationToken,
        trigger: String,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let manager = AppGroupManager.shared

        let appName = "this app"

        let tokenData = manager.encodeToken(token)
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
        content.body = "Tap to explain why you need \(appName)"
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

    private func handleRequestAccessWithoutToken(
        trigger: String,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let manager = AppGroupManager.shared
        let requestPayload = PendingUnlockRequest(tokenData: Data(), appName: "this app")

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
            NSLog("[ShieldAction] no-token completion timeout fallback")
            completeOnce(.defer)
        }

        postNotification(for: requestPayload, appName: "this app") { error in
            NSLog("[ShieldAction] notificationScheduled no-token trigger=%@ success=%@ error=%@",
                  trigger,
                  error == nil ? "YES" : "NO",
                  error?.localizedDescription ?? "(none)")
            manager.appendExtensionLog(
                source: "ShieldAction",
                message: "notificationScheduled no-token trigger=\(trigger) success=\(error == nil) error=\(error?.localizedDescription ?? "(none)")",
                persistToSharedFile: false
            )
            completeOnce(.defer)
        }
    }
}
