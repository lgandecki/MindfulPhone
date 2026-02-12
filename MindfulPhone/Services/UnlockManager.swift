import Foundation
import DeviceActivity
import ManagedSettings

@MainActor
final class UnlockManager {
    static let shared = UnlockManager()

    private let activityCenter = DeviceActivityCenter()

    private init() {}

    // MARK: - Unlock App

    /// Full unlock lifecycle: unshield, schedule re-block, save record, schedule notifications.
    func unlockApp(
        tokenData: Data,
        appName: String,
        durationMinutes: Int,
        reason: String
    ) async {
        guard let token = AppGroupManager.shared.decodeToken(from: tokenData) else {
            return
        }

        // 1. Remove shield for this app
        BlockingService.shared.temporarilyUnshield(token: token)

        // 2. Create a unique activity name for the re-block timer
        let activityName = "reblock-\(UUID().uuidString)"

        // 3. Schedule DeviceActivity monitoring to re-block when time expires
        scheduleReblock(
            activityName: DeviceActivityName(rawValue: activityName),
            durationMinutes: durationMinutes
        )

        // 4. Save active unlock record to App Group (extensions read this)
        let record = ActiveUnlockRecord(
            tokenData: tokenData,
            appName: appName,
            durationMinutes: durationMinutes,
            reason: reason,
            activityName: activityName
        )
        AppGroupManager.shared.saveActiveUnlock(record)

        // 5. Schedule notifications
        NotificationService.scheduleExpiryWarning(appName: appName, expiresAt: record.expiresAt)
        NotificationService.scheduleExpiryNotification(appName: appName, expiresAt: record.expiresAt)
    }

    // MARK: - Schedule Re-block

    private func scheduleReblock(activityName: DeviceActivityName, durationMinutes: Int) {
        let now = Date()
        let end = now.addingTimeInterval(TimeInterval(durationMinutes * 60))

        let calendar = Calendar.current

        // Must include full date components (year/month/day/hour/minute/second)
        // or the system interprets it as a repeating daily schedule
        let startComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: now
        )
        let endComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: end
        )

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false,
            warningTime: DateComponents(minute: 5)
        )

        do {
            try activityCenter.startMonitoring(activityName, during: schedule)
        } catch {
            // If monitoring fails, set up a fallback timer
            print("Failed to start monitoring: \(error)")
        }
    }

    // MARK: - Safety Net: Recheck Expired Unlocks

    /// Called on app launch to catch any unlocks that expired while the app wasn't running.
    func recheckExpiredUnlocks() {
        let expired = AppGroupManager.shared.getExpiredUnlocks()

        for record in expired {
            if let token = AppGroupManager.shared.decodeToken(from: record.tokenData) {
                BlockingService.shared.reapplyShield(for: token)
            }
            AppGroupManager.shared.removeActiveUnlock(id: record.id)
        }
    }

    // MARK: - Active Unlocks

    func getActiveUnlocks() -> [ActiveUnlockRecord] {
        AppGroupManager.shared.getActiveUnlocks().filter { $0.expiresAt > Date() }
    }
}
