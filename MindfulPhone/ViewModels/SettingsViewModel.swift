import Foundation
import FamilyControls

@MainActor
@Observable
final class SettingsViewModel {
    var activitySelection = FamilyActivitySelection()
    var apiKey = ""
    var isTestingKey = false
    var apiKeyError: String?
    var apiKeyValid = false
    var showingRevokeConfirmation = false

    func loadSettings() {
        // Load exempt apps selection
        if let data = AppGroupManager.shared.getExemptSelectionData(),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            activitySelection = selection
        }

        // Check API key status
        apiKeyValid = KeychainService.hasAPIKey
        if apiKeyValid {
            apiKey = "••••••••••••"
        }
    }

    func saveExemptApps() {
        if let data = try? JSONEncoder().encode(activitySelection) {
            AppGroupManager.shared.saveExemptSelection(data)
        }
        // Reapply shields with updated exemptions
        let exemptTokens = BlockingService.shared.getAllExemptTokens()
        BlockingService.shared.applyShieldAll(exemptTokens: exemptTokens)
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
