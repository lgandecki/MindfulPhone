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

    // MARK: - Shield Policy (Hybrid: Per-App + Category Catch-All)

    /// Applies per-app shielding. Each blocked app gets its own shield,
    /// so ShieldActionExtension receives the specific ApplicationToken.
    func applyShields(
        blockTokens: Set<ApplicationToken>,
        exemptTokens: Set<ApplicationToken>
    ) {
        store.shield.applications = blockTokens.isEmpty ? nil : blockTokens
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
        AppGroupManager.shared.areShieldsActive = true
        NSLog("[BlockingService] Applied per-app shields: block=%d exempt=%d",
              blockTokens.count, exemptTokens.count)
    }

    /// Temporarily removes the shield for a specific app token.
    func temporarilyUnshield(token: ApplicationToken) {
        store.shield.applications?.remove(token)
    }

    /// Re-applies the shield for a specific app token.
    func reapplyShield(for token: ApplicationToken) {
        if store.shield.applications != nil {
            store.shield.applications?.insert(token)
        } else {
            store.shield.applications = [token]
        }
    }

    /// Removes all shields entirely.
    func removeAllShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
        AppGroupManager.shared.areShieldsActive = false
    }

    // MARK: - Exempt Token Management

    /// Loads the saved exempt tokens from persistent storage.
    func getPersistedExemptTokens() -> Set<ApplicationToken> {
        AppGroupManager.shared.getExemptTokens()
    }

    /// Loads the full set of all-apps tokens from the saved selection.
    func getPersistedAllAppsTokens() -> Set<ApplicationToken> {
        guard let data = AppGroupManager.shared.getAllAppsSelectionData(),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return []
        }
        return selection.applicationTokens
    }

    /// Recomputes and reapplies shields from persisted data.
    func reapplyFromPersistedData() {
        let allTokens = getPersistedAllAppsTokens()
        let exemptTokens = getPersistedExemptTokens()
        let blockTokens = allTokens.subtracting(exemptTokens)
        applyShields(blockTokens: blockTokens, exemptTokens: exemptTokens)
    }

    /// Revokes Family Controls authorization entirely.
    func revokeAuthorization() {
        AuthorizationCenter.shared.revokeAuthorization(completionHandler: { _ in })
        removeAllShields()
        authorizationStatus = .notDetermined
    }
}
