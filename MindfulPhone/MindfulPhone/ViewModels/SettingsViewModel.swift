import Foundation
import FamilyControls
import ManagedSettings

@MainActor
@Observable
final class SettingsViewModel {
    var allAppsSelection = FamilyActivitySelection(includeEntireCategory: true)
    var showingRevokeConfirmation = false

    func loadSettings() {
        // Load all-apps selection
        if let data = AppGroupManager.shared.getAllAppsSelectionData(),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            allAppsSelection = selection
        }
    }

    func saveUpdatedAppList() {
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

    func revokeAuthorization() {
        BlockingService.shared.revokeAuthorization()
        AppGroupManager.shared.isOnboardingComplete = false
    }
}
