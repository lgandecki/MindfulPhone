import Foundation
import FamilyControls
import ManagedSettings

@MainActor
@Observable
final class SettingsViewModel {
    var allAppsSelection = FamilyActivitySelection(includeEntireCategory: true)
    var userName = ""
    var partnerEmail = ""

    // MARK: - Disable Timer

    var showingDisableTimer = false
    var disableTimeRemaining: Int = 300
    var disableTimerCompleted = false
    private var disableTimer: Timer?

    // MARK: - App Removal Protection

    var showingRemovalRejected = false
    var showingRemovalTimer = false
    var removalTimeRemaining: Int = 300
    var removalTimerCompleted = false
    private var removalTimer: Timer?
    private var previousTokens: Set<ApplicationToken> = []
    private var pendingSelection: FamilyActivitySelection?

    func loadSettings() {
        // Load all-apps selection
        if let data = AppGroupManager.shared.getAllAppsSelectionData(),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            allAppsSelection = selection
        }

        // Load partner info
        userName = AppGroupManager.shared.userName ?? ""
        partnerEmail = AppGroupManager.shared.partnerEmail ?? ""

        // Capture current tokens for removal detection
        captureCurrentTokens()
    }

    // MARK: - App List Management

    func handleAppSelectionChange() {
        let newTokens = allAppsSelection.applicationTokens
        let removedTokens = previousTokens.subtracting(newTokens)

        if removedTokens.isEmpty {
            // Additive only — save immediately
            saveUpdatedAppList()
            captureCurrentTokens()
        } else if removalTimerCompleted {
            // Timer already completed — allow removal + notify
            saveUpdatedAppList()
            captureCurrentTokens()
            removalTimerCompleted = false

            let email = AppGroupManager.shared.partnerEmail
            let name = AppGroupManager.shared.userName ?? "Someone"
            if let email {
                Task {
                    await NotifyService.shared.notify(.appRemoved, email: email, userName: name)
                }
            }
        } else {
            // Removals without completed timer — revert and show alert
            pendingSelection = FamilyActivitySelection(includeEntireCategory: true)
            pendingSelection?.applicationTokens = allAppsSelection.applicationTokens
            allAppsSelection.applicationTokens = previousTokens
            showingRemovalRejected = true
        }
    }

    func startRemovalTimer() {
        removalTimeRemaining = 300
        removalTimerCompleted = false
        showingRemovalTimer = true

        removalTimer?.invalidate()
        removalTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            nonisolated(unsafe) let t = timer
            Task { @MainActor [weak self] in
                guard let self else {
                    t.invalidate()
                    return
                }
                self.removalTimeRemaining -= 1
                if self.removalTimeRemaining <= 0 {
                    t.invalidate()
                    self.removalTimerCompleted = true
                    self.showingRemovalTimer = false
                }
            }
        }
    }

    func cancelRemovalTimer() {
        removalTimer?.invalidate()
        removalTimer = nil
        removalTimeRemaining = 300
        removalTimerCompleted = false
        showingRemovalTimer = false
    }

    private func saveUpdatedAppList() {
        let manager = AppGroupManager.shared

        // Save the updated all-apps selection
        if let data = try? JSONEncoder().encode(allAppsSelection) {
            manager.saveAllAppsSelection(data)
        }

        // Rebuild token → name map from updated selection
        for app in allAppsSelection.applications {
            guard let name = app.localizedDisplayName, let token = app.token else { continue }
            manager.saveTokenName(name, for: token)
        }

        // Reapply shields with existing exempt tokens
        BlockingService.shared.reapplyFromPersistedData()
    }

    private func captureCurrentTokens() {
        previousTokens = allAppsSelection.applicationTokens
    }

    // MARK: - Disable Timer

    func startDisableTimer() {
        disableTimeRemaining = 300
        disableTimerCompleted = false
        showingDisableTimer = true

        disableTimer?.invalidate()
        disableTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            nonisolated(unsafe) let t = timer
            Task { @MainActor [weak self] in
                guard let self else {
                    t.invalidate()
                    return
                }
                self.disableTimeRemaining -= 1
                if self.disableTimeRemaining <= 0 {
                    t.invalidate()
                    self.disableTimerCompleted = true
                }
            }
        }
    }

    func cancelDisableTimer() {
        disableTimer?.invalidate()
        disableTimer = nil
        disableTimeRemaining = 300
        disableTimerCompleted = false
        showingDisableTimer = false
    }

    func resetDisableTimerIfBackgrounded() {
        if showingDisableTimer {
            cancelDisableTimer()
        }
        if showingRemovalTimer {
            cancelRemovalTimer()
        }
    }

    func confirmDisable() {
        let email = AppGroupManager.shared.partnerEmail
        let name = AppGroupManager.shared.userName ?? "Someone"
        if let email {
            Task.detached {
                await NotifyService.shared.notify(.protectionDisabled, email: email, userName: name)
            }
        }

        BlockingService.shared.revokeAuthorization()
        AppGroupManager.shared.isOnboardingComplete = false
        AppGroupManager.shared.activationDate = nil
        cancelDisableTimer()
    }
}
