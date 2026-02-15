import DeviceActivity
import FamilyControls
import ManagedSettings
import UserNotifications

/// Runs in a separate process. Handles re-blocking apps when their unlock timer expires.
///
/// Also serves as a backup re-block mechanism. The PRIMARY re-block runs from
/// the main app process (in-app timer in UnlockManager), which reliably writes
/// to ManagedSettingsStore. This extension callback is a second line of defense.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        NSLog("[DAMonitor] intervalDidEnd for activity=%@", activity.rawValue)

        let manager = AppGroupManager.shared

        // Check if the in-app timer already handled this (record would be gone)
        let unlocks = manager.getActiveUnlocks()
        guard let record = unlocks.first(where: { $0.activityName == activity.rawValue }) else {
            NSLog("[DAMonitor] Record already cleaned up (in-app timer handled it)")
            return
        }

        NSLog("[DAMonitor] In-app timer didn't fire — extension handling reblock for %@",
              record.appName)

        // Remove record first so the full rebuild includes this app
        manager.removeActiveUnlock(activityName: activity.rawValue)

        // Create a FRESH store instance for each callback — don't use a stored
        // property which may hold stale state from the extension process lifecycle.
        let store = ManagedSettingsStore()

        // Log current state for debugging
        let beforeCount = store.shield.applications?.count ?? -1
        NSLog("[DAMonitor] Shield count BEFORE reapply: %d", beforeCount)

        // Full rebuild from persisted data
        reapplyAllShields(store: store, manager: manager)

        let afterCount = store.shield.applications?.count ?? -1
        NSLog("[DAMonitor] Shield count AFTER reapply: %d", afterCount)

        postReblockNotification(appName: record.appName)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        // Warning notifications are handled by NotificationService.scheduleExpiryWarning
        // (timer-based from the main app process).
    }

    // MARK: - Shield Management

    /// Rebuild all per-app shields from persisted data using the provided store instance.
    private func reapplyAllShields(store: ManagedSettingsStore, manager: AppGroupManager) {
        guard let data = manager.getAllAppsSelectionData(),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            NSLog("[DAMonitor] reapplyAllShields: FAILED to read persisted selection data")
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

        NSLog("[DAMonitor] reapplyAllShields: all=%d exempt=%d active=%d → blocking=%d",
              allTokens.count, exemptTokens.count, activeTokens.count, blockTokens.count)

        // Full re-assignment to ensure the setter fires
        store.shield.applications = blockTokens.isEmpty ? nil : blockTokens
    }

    // MARK: - Notifications

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
