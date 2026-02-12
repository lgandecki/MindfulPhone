import Combine
import Foundation
import FamilyControls
import ManagedSettings

@MainActor
final class BlockingService: ObservableObject {
    static let shared = BlockingService()

    private let store = ManagedSettingsStore()
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined

    private init() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    var isAuthorized: Bool {
        authorizationStatus == .approved
    }

    // MARK: - Shield Policy

    /// Applies the "block everything except exempt apps" policy.
    /// This must be called with the COMPLETE set of exempt tokens every time.
    func applyShieldAll(exemptTokens: Set<ApplicationToken> = []) {
        store.shield.applicationCategories = .all(except: exemptTokens)
        store.shield.webDomainCategories = .all()
        AppGroupManager.shared.areShieldsActive = true
    }

    /// Temporarily removes the shield for a specific app token
    /// by adding it to the exempt set and reapplying the full policy.
    func temporarilyUnshield(token: ApplicationToken) {
        var exemptTokens = getAllExemptTokens()
        exemptTokens.insert(token)
        applyShieldAll(exemptTokens: exemptTokens)
    }

    /// Re-applies the shield for a specific app by removing it
    /// from the exempt set and reapplying the full policy.
    func reapplyShield(for token: ApplicationToken) {
        var exemptTokens = getAllExemptTokens()
        exemptTokens.remove(token)
        applyShieldAll(exemptTokens: exemptTokens)
    }

    /// Removes all shields entirely.
    func removeAllShields() {
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
        AppGroupManager.shared.areShieldsActive = false
    }

    // MARK: - Exempt Token Management

    /// Builds the complete set of currently exempt tokens:
    /// permanent exemptions + temporarily unlocked apps.
    func getAllExemptTokens() -> Set<ApplicationToken> {
        var tokens = Set<ApplicationToken>()

        // Add permanently exempt tokens from FamilyActivitySelection
        if let selectionData = AppGroupManager.shared.getExemptSelectionData(),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: selectionData) {
            tokens.formUnion(selection.applicationTokens)
        }

        // Add temporarily unlocked tokens from active unlocks
        let activeUnlocks = AppGroupManager.shared.getActiveUnlocks()
        for unlock in activeUnlocks where unlock.expiresAt > Date() {
            if let token = AppGroupManager.shared.decodeToken(from: unlock.tokenData) {
                tokens.insert(token)
            }
        }

        return tokens
    }

    /// Revokes Family Controls authorization entirely.
    func revokeAuthorization() {
        AuthorizationCenter.shared.revokeAuthorization(completionHandler: { _ in })
        removeAllShields()
        authorizationStatus = .notDetermined
    }
}
