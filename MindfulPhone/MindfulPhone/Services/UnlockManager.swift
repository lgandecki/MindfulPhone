import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings

@MainActor
final class UnlockManager {
    static let shared = UnlockManager()

    private let activityCenter = DeviceActivityCenter()

    /// In-app timers that fire at expiry to reblock from the main app process.
    /// Keyed by activity name so we can cancel them if needed.
    private var reblockTimers: [String: DispatchWorkItem] = [:]

    private init() {}

    // MARK: - Unlock App

    /// Full unlock lifecycle: unshield, schedule re-block, save record, schedule notifications.
    /// Returns `true` if unlock succeeded, `false` if token decode failed.
    @discardableResult
    func unlockApp(
        tokenData: Data,
        appName: String,
        durationMinutes: Int,
        reason: String
    ) async -> Bool {
        NSLog("[UnlockManager] unlockApp called — tokenData size=%d appName=%@ duration=%d",
              tokenData.count, appName, durationMinutes)

        guard let token = AppGroupManager.shared.decodeToken(from: tokenData) else {
            NSLog("[UnlockManager] Token decode FAILED — tokenData size=%d", tokenData.count)
            return false
        }
        NSLog("[UnlockManager] Token decoded successfully — per-app unshield")
        BlockingService.shared.temporarilyUnshield(token: token)

        // Create a unique activity name for the re-block timer
        let activityName = "reblock-\(UUID().uuidString)"

        // Schedule DeviceActivity monitoring to re-block when time expires
        // (extension process — may or may not reliably write to ManagedSettingsStore)
        let expiresAt = Date().addingTimeInterval(TimeInterval(durationMinutes * 60))
        scheduleReblock(
            activityName: DeviceActivityName(rawValue: activityName),
            durationMinutes: durationMinutes
        )

        // Schedule an in-app timer as the PRIMARY re-block mechanism.
        // Runs in the main app process where ManagedSettingsStore writes are reliable.
        scheduleInAppReblock(
            activityName: activityName,
            token: token,
            appName: appName,
            expiresAt: expiresAt
        )

        // Save active unlock record to App Group (extensions read this)
        let record = ActiveUnlockRecord(
            tokenData: tokenData,
            appName: appName,
            durationMinutes: durationMinutes,
            reason: reason,
            activityName: activityName
        )
        AppGroupManager.shared.saveActiveUnlock(record)

        // Schedule warning notification
        NotificationService.scheduleExpiryWarning(appName: appName, expiresAt: record.expiresAt)

        NSLog("[UnlockManager] Unlock completed successfully for %@", appName)
        return true
    }

    // MARK: - In-App Re-block Timer (Primary — runs in main app process)

    private func scheduleInAppReblock(
        activityName: String,
        token: ApplicationToken,
        appName: String,
        expiresAt: Date
    ) {
        let delay = max(expiresAt.timeIntervalSinceNow, 1)

        // Capture values for the closure
        let capturedToken = token
        let capturedAppName = appName
        let capturedActivityName = activityName

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            NSLog("[UnlockManager] In-app reblock timer fired for %@", capturedAppName)

            // Re-apply the shield from the main app process (reliable)
            BlockingService.shared.reapplyShield(for: capturedToken)

            // Clean up the active unlock record
            AppGroupManager.shared.removeActiveUnlock(activityName: capturedActivityName)

            // Post notification
            NotificationService.postReblockNotification(appName: capturedAppName)

            // Stop DeviceActivity monitoring (extension may have already handled it)
            self.activityCenter.stopMonitoring(
                [DeviceActivityName(rawValue: capturedActivityName)]
            )

            self.reblockTimers.removeValue(forKey: capturedActivityName)
            NSLog("[UnlockManager] In-app reblock completed for %@", capturedAppName)
        }

        reblockTimers[activityName] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)

        NSLog("[UnlockManager] Scheduled in-app reblock timer: %@ in %.0f seconds",
              activityName, delay)
    }

    // MARK: - DeviceActivity Schedule (Backup — runs in extension process)

    private func scheduleReblock(activityName: DeviceActivityName, durationMinutes: Int) {
        let now = Date()
        let end = now.addingTimeInterval(TimeInterval(durationMinutes * 60))

        let calendar = Calendar.current
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
            warningTime: nil
        )

        do {
            try activityCenter.startMonitoring(activityName, during: schedule)
            NSLog("[UnlockManager] DeviceActivity monitor scheduled: %@", activityName.rawValue)
        } catch {
            NSLog("[UnlockManager] Failed to start DeviceActivity monitoring: %@",
                  error.localizedDescription)
        }
    }

    // MARK: - Restore Timers After App Relaunch

    /// Called on app launch / foreground to restore in-app timers for any
    /// active unlocks and catch any that already expired.
    func recheckExpiredUnlocks() {
        let manager = AppGroupManager.shared
        let allActive = manager.getActiveUnlocks()
        let now = Date()

        for record in allActive {
            if record.expiresAt <= now {
                // Already expired — reblock immediately
                NSLog("[UnlockManager] recheckExpiredUnlocks: %@ expired, reblocking", record.appName)
                if let token = manager.decodeToken(from: record.tokenData) {
                    BlockingService.shared.reapplyShield(for: token)
                }
                manager.removeActiveUnlock(id: record.id)
                activityCenter.stopMonitoring(
                    [DeviceActivityName(rawValue: record.activityName)]
                )
            } else if reblockTimers[record.activityName] == nil {
                // Still active but no in-app timer (app was relaunched) — reschedule
                NSLog("[UnlockManager] recheckExpiredUnlocks: restoring timer for %@ (expires %@)",
                      record.appName, record.expiresAt.description)
                if let token = manager.decodeToken(from: record.tokenData) {
                    scheduleInAppReblock(
                        activityName: record.activityName,
                        token: token,
                        appName: record.appName,
                        expiresAt: record.expiresAt
                    )
                }
            }
        }
    }

    // MARK: - Active Unlocks

    func getActiveUnlocks() -> [ActiveUnlockRecord] {
        AppGroupManager.shared.getActiveUnlocks().filter { $0.expiresAt > Date() }
    }
}
