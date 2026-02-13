import Foundation
import FamilyControls
import ManagedSettings

@MainActor
@Observable
final class OnboardingViewModel {
    var currentStep: OnboardingStep = .welcome
    var isAuthorized = false
    var apiKey = ""
    var isTestingKey = false
    var apiKeyError: String?
    var apiKeyValid = false
    var isActivating = false

    // App selection (includeEntireCategory expands category selections into individual app tokens)
    var allAppsSelection = FamilyActivitySelection(includeEntireCategory: true)

    enum OnboardingStep: Int, CaseIterable {
        case welcome
        case authorization
        case appSelection
        case apiKey
        case activate

        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .authorization: return "Authorization"
            case .appSelection: return "App Selection"
            case .apiKey: return "API Key"
            case .activate: return "Activate"
            }
        }
    }

    func advance() {
        let allSteps = OnboardingStep.allCases
        if let currentIndex = allSteps.firstIndex(of: currentStep),
           currentIndex + 1 < allSteps.count {
            currentStep = allSteps[currentIndex + 1]
        }
    }

    func goBack() {
        let allSteps = OnboardingStep.allCases
        if let currentIndex = allSteps.firstIndex(of: currentStep),
           currentIndex > 0 {
            currentStep = allSteps[currentIndex - 1]
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            try await BlockingService.shared.requestAuthorization()
            isAuthorized = BlockingService.shared.isAuthorized

            // Request notification permission immediately after authorization
            // so the ShieldActionExtension can post notifications later
            _ = await NotificationService.requestPermission()
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - API Key

    func testAPIKey() async {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            apiKeyError = "Please enter an API key."
            return
        }

        isTestingKey = true
        apiKeyError = nil

        do {
            try KeychainService.saveAPIKey(key)

            // Test with a simple request
            let response = try await ClaudeAPIService.shared.sendMessage(
                conversationMessages: [(role: "user", content: "Say 'connected' in one word.")],
                appName: "Test",
                unlockHistory: []
            )

            if !response.message.isEmpty {
                apiKeyValid = true
            }
        } catch {
            apiKeyError = error.localizedDescription
            apiKeyValid = false
            KeychainService.deleteAPIKey()
        }

        isTestingKey = false
    }

    #if DEBUG
    func testProxyConnection() async {
        isTestingKey = true
        apiKeyError = nil

        do {
            let response = try await ClaudeAPIService.shared.sendMessage(
                conversationMessages: [(role: "user", content: "Say 'connected' in one word.")],
                appName: "Test",
                unlockHistory: []
            )

            if !response.message.isEmpty {
                apiKeyValid = true
            }
        } catch {
            apiKeyError = "Proxy unreachable: \(error.localizedDescription)"
            apiKeyValid = false
        }

        isTestingKey = false
    }
    #endif

    // MARK: - Activation

    func activate() async {
        isActivating = true

        _ = await NotificationService.requestPermission()

        // Save all-apps selection for later reapply cycles
        if let data = try? JSONEncoder().encode(allAppsSelection) {
            AppGroupManager.shared.saveAllAppsSelection(data)
        }

        // Block ALL selected apps — no exemptions during onboarding.
        // Users exempt apps organically by tapping "Always Allow" on the shield.
        let allTokens = allAppsSelection.applicationTokens
        let exemptTokens = AppGroupManager.shared.getExemptTokens() // empty initially

        NSLog("[Onboarding] Activating: allTokens=%d exempt=%d block=%d",
              allTokens.count, exemptTokens.count, allTokens.subtracting(exemptTokens).count)

        BlockingService.shared.applyShields(
            blockTokens: allTokens.subtracting(exemptTokens),
            exemptTokens: exemptTokens
        )

        AppGroupManager.shared.isOnboardingComplete = true
        isActivating = false
    }
}
