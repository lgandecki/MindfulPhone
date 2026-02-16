import Foundation
import FamilyControls
import ManagedSettings

@MainActor
@Observable
final class OnboardingViewModel {
    var currentStep: OnboardingStep = .welcome
    var isAuthorized = false
    var isRequestingAuth = false
    var isActivating = false
    var userName = ""
    var partnerEmail = ""

    // App selection (includeEntireCategory expands category selections into individual app tokens)
    var allAppsSelection = FamilyActivitySelection(includeEntireCategory: true)

    enum OnboardingStep: Int, CaseIterable {
        case welcome
        case authorization
        case appSelection
        case partnerSetup
        case activate

        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .authorization: return "Authorization"
            case .appSelection: return "Block Apps"
            case .partnerSetup: return "Partner"
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
        isRequestingAuth = true
        do {
            try await BlockingService.shared.requestAuthorization()
            isAuthorized = BlockingService.shared.isAuthorized

            // Request notification permission immediately after authorization
            // so the ShieldActionExtension can post notifications later
            _ = await NotificationService.requestPermission()
        } catch {
            isAuthorized = false
        }
        isRequestingAuth = false
    }

    // MARK: - Activation

    func activate() async {
        isActivating = true

        _ = await NotificationService.requestPermission()

        // Persist partner info if provided
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = partnerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            AppGroupManager.shared.userName = trimmedName
        }
        if !trimmedEmail.isEmpty {
            AppGroupManager.shared.partnerEmail = trimmedEmail
        }

        // Save all-apps selection for later reapply cycles
        if let data = try? JSONEncoder().encode(allAppsSelection) {
            AppGroupManager.shared.saveAllAppsSelection(data)
        }

        let allTokens = allAppsSelection.applicationTokens
        let exemptTokens = AppGroupManager.shared.getExemptTokens()

        NSLog("[Onboarding] Activating: selected=%d exempt=%d blocking=%d",
              allTokens.count, exemptTokens.count, allTokens.subtracting(exemptTokens).count)

        BlockingService.shared.applyShields(
            blockTokens: allTokens.subtracting(exemptTokens),
            exemptTokens: exemptTokens
        )

        AppGroupManager.shared.isOnboardingComplete = true
        AppGroupManager.shared.activationDate = Date()
        isActivating = false
    }
}
