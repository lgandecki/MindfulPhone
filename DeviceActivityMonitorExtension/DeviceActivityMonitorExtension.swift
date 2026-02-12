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

        // Find the matching active unlock record
        let manager = AppGroupManager.shared
        let unlocks = manager.getActiveUnlocks()

        if let record = unlocks.first(where: { $0.activityName == activity.rawValue }) {
            // Re-apply shield for this specific app
            if let token = manager.decodeToken(from: record.tokenData) {
                reapplyShield(removing: token)
            }

            // Remove the active unlock record
            manager.removeActiveUnlock(activityName: activity.rawValue)

            // Post a notification
            postReblockNotification(appName: record.appName)
        } else {
            // Safety net: if we can't find the record, reapply full shield
            reapplyFullShield()
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

    // MARK: - Shield Management

    private func reapplyShield(removing token: ApplicationToken) {
        // Build exempt set from permanent exemptions + still-active unlocks, minus this token
        var exemptTokens = getExemptTokens()
        exemptTokens.remove(token)
        store.shield.applicationCategories = .all(except: exemptTokens)
        store.shield.webDomainCategories = .all()
    }

    private func reapplyFullShield() {
        let exemptTokens = getExemptTokens()
        store.shield.applicationCategories = .all(except: exemptTokens)
        store.shield.webDomainCategories = .all()
    }

    private func getExemptTokens() -> Set<ApplicationToken> {
        var tokens = Set<ApplicationToken>()
        let manager = AppGroupManager.shared

        // Permanent exemptions
        if let selectionData = manager.getExemptSelectionData(),
           let selection = try? JSONDecoder().decode(
               FamilyActivitySelection.self, from: selectionData
           ) {
            tokens.formUnion(selection.applicationTokens)
        }

        // Still-active temporary unlocks (not yet expired)
        let activeUnlocks = manager.getActiveUnlocks()
        for unlock in activeUnlocks where unlock.expiresAt > Date() {
            if let token = manager.decodeToken(from: unlock.tokenData) {
                tokens.insert(token)
            }
        }

        return tokens
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
