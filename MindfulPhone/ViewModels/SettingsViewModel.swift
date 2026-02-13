import Foundation
import FamilyControls
import ManagedSettings

@MainActor
@Observable
final class SettingsViewModel {
    var allAppsSelection = FamilyActivitySelection(includeEntireCategory: true)
    var apiKey = ""
    var isTestingKey = false
    var apiKeyError: String?
    var apiKeyValid = false
    var showingRevokeConfirmation = false

    func loadSettings() {
        // Load all-apps selection
        if let data = AppGroupManager.shared.getAllAppsSelectionData(),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            allAppsSelection = selection
        }

        // Check API key status
        apiKeyValid = KeychainService.hasAPIKey
        if apiKeyValid {
            apiKey = "••••••••••••"
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

    func updateAPIKey() async {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.hasPrefix("•") else { return }

        isTestingKey = true
        apiKeyError = nil

        do {
            try KeychainService.saveAPIKey(key)
            let response = try await ClaudeAPIService.shared.sendMessage(
                conversationMessages: [(role: "user", content: "Say 'connected' in one word.")],
                appName: "Test",
                unlockHistory: []
            )
            apiKeyValid = !response.message.isEmpty
            if apiKeyValid {
                apiKey = "••••••••••••"
            }
        } catch {
            apiKeyError = error.localizedDescription
            apiKeyValid = false
        }

        isTestingKey = false
    }

    func revokeAuthorization() {
        BlockingService.shared.revokeAuthorization()
        AppGroupManager.shared.isOnboardingComplete = false
    }
}
