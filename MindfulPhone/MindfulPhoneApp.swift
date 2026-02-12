import SwiftUI
import SwiftData
import UIKit
import UserNotifications

extension Notification.Name {
    static let unlockRequestNotificationTapped = Notification.Name("unlockRequestNotificationTapped")
}

final class MindfulPhoneAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureUnlockRequestNotifications()
        return true
    }

    private func configureUnlockRequestNotifications() {
        let openAction = UNNotificationAction(
            identifier: "OPEN_UNLOCK_REQUEST",
            title: "Open",
            options: [.foreground]
        )
        let unlockCategory = UNNotificationCategory(
            identifier: "UNLOCK_REQUEST",
            actions: [openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([unlockCategory])
        center.delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.content.categoryIdentifier == "UNLOCK_REQUEST" {
            AppGroupManager.shared.appendExtensionLog(
                source: "MainApp",
                message: "didReceive UNLOCK_REQUEST notification tap"
            )
            persistPendingRequestFromNotification(userInfo: response.notification.request.content.userInfo)
            NotificationCenter.default.post(
                name: .unlockRequestNotificationTapped,
                object: nil,
                userInfo: response.notification.request.content.userInfo
            )
        }
        completionHandler()
    }

    private func persistPendingRequestFromNotification(userInfo: [AnyHashable: Any]) {
        saveExtensionDiagnosticsFromNotification(userInfo: userInfo)

        // If extension couldn't persist to App Group, recover the request payload from notification data.
        guard AppGroupManager.shared.getPendingUnlockRequest() == nil else {
            AppGroupManager.shared.appendExtensionLog(
                source: "MainApp",
                message: "pending request already exists, skip notification recovery"
            )
            return
        }
        guard let appName = userInfo["appName"] as? String,
              let tokenDataBase64 = userInfo["tokenDataBase64"] as? String,
              let tokenData = Data(base64Encoded: tokenDataBase64) else {
            AppGroupManager.shared.appendExtensionLog(
                source: "MainApp",
                message: "notification recovery failed: missing appName/tokenDataBase64"
            )
            return
        }
        let request = PendingUnlockRequest(tokenData: tokenData, appName: appName)
        let result = AppGroupManager.shared.savePendingUnlockRequest(request)
        AppGroupManager.shared.saveShieldActionDiagnostics([
            "recoveredFromNotificationTap": "YES",
            "recoveredAppName": appName
        ])
        AppGroupManager.shared.appendExtensionLog(
            source: "MainApp",
            message: "recovered request from notification app=\(appName) success=\(result.success)"
        )
    }

    private func saveExtensionDiagnosticsFromNotification(userInfo: [AnyHashable: Any]) {
        var diagnostics: [String: String] = [:]

        if let value = userInfo["saveSuccess"] as? Bool {
            diagnostics["notif.saveSuccess"] = value ? "YES" : "NO"
        }
        if let value = userInfo["saveWroteFile"] as? Bool {
            diagnostics["notif.saveWroteFile"] = value ? "YES" : "NO"
        }
        if let value = userInfo["saveWroteSharedDefaults"] as? Bool {
            diagnostics["notif.saveWroteSharedDefaults"] = value ? "YES" : "NO"
        }
        if let value = userInfo["saveSharedContainerAvailable"] as? Bool {
            diagnostics["notif.saveSharedContainerAvailable"] = value ? "YES" : "NO"
        }
        if let value = userInfo["saveSharedDefaultsAvailable"] as? Bool {
            diagnostics["notif.saveSharedDefaultsAvailable"] = value ? "YES" : "NO"
        }

        if !diagnostics.isEmpty {
            AppGroupManager.shared.saveShieldActionDiagnostics(diagnostics)
        }
    }
}

@main
struct MindfulPhoneApp: App {
    @UIApplicationDelegateAdaptor(MindfulPhoneAppDelegate.self) private var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Conversation.self,
            ChatMessage.self,
            UnlockRecord.self,
        ])

        // Ensure the default SwiftData/CoreData parent directory exists up-front.
        if let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            try? FileManager.default.createDirectory(
                at: appSupport,
                withIntermediateDirectories: true
            )
        }

        // groupContainer: .none prevents SwiftData from using the App Group
        // container (which causes sandbox permission errors). The app group
        // is for IPC with extensions only, not for SwiftData storage.
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    AccountabilityService.shared.startObserving()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
