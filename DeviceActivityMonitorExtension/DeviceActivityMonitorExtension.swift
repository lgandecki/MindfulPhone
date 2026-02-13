import DeviceActivity
import FamilyControls
import ManagedSettings
import UserNotifications

/// Runs in a separate process. Handles re-blocking apps when their unlock timer expires.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // Nothing to do when the interval starts — the app is already unshielded
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        let manager = AppGroupManager.shared
        let unlocks = manager.getActiveUnlocks()

        if let record = unlocks.first(where: { $0.activityName == activity.rawValue }) {
            // Re-add this app's token to per-app shields
            if let token = manager.decodeToken(from: record.tokenData) {
                reapplyPerAppShield(token: token)
            }

            manager.removeActiveUnlock(activityName: activity.rawValue)
            postReblockNotification(appName: record.appName)
        } else {
            // Safety net: reapply all per-app shields from persisted data
            reapplyAllShields()
        }
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)

        let manager = AppGroupManager.shared
        let unlocks = manager.getActiveUnlocks()

        if let record = unlocks.first(where: { $0.activityName == activity.rawValue }) {
            postWarningNotification(appName: record.appName)
        }
    }

    // MARK: - Shield Management (Per-App Only)

    private func reapplyPerAppShield(token: ApplicationToken) {
        if store.shield.applications != nil {
            store.shield.applications?.insert(token)
        } else {
            store.shield.applications = [token]
        }
    }

    /// Safety net: rebuild all per-app shields from persisted data.
    private func reapplyAllShields() {
        let manager = AppGroupManager.shared

        guard let data = manager.getAllAppsSelectionData(),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return
        }

        let allTokens = selection.applicationTokens
        let exemptTokens = manager.getExemptTokens()

        // Subtract exempt + still-active unlocks
        var activeTokens = Set<ApplicationToken>()
        for unlock in manager.getActiveUnlocks() where unlock.expiresAt > Date() {
            if let token = manager.decodeToken(from: unlock.tokenData) {
                activeTokens.insert(token)
            }
        }

        let blockTokens = allTokens.subtracting(exemptTokens).subtracting(activeTokens)
        store.shield.applications = blockTokens.isEmpty ? nil : blockTokens
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
    }

    // MARK: - Notifications

    private func postWarningNotification(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = "5 minutes remaining"
        content.body = "\(appName) will be blocked again soon."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "reblock-warning-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    private func postReblockNotification(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Time's up"
        content.body = "\(appName) has been blocked again."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "reblock-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
