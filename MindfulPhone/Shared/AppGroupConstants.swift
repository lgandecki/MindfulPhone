import Foundation

enum AppGroupConstants {
    static let suiteName = "group.net.lgandecki.mindfulphone.shared"

    // MARK: - UserDefaults Keys

    /// Dictionary mapping Base64-encoded ApplicationToken → display name
    static let tokenNameMapKey = "tokenNameMap"

    /// JSON-encoded PendingUnlockRequest
    static let pendingUnlockRequestKey = "pendingUnlockRequest"

    /// JSON-encoded [ActiveUnlockRecord]
    static let activeUnlocksKey = "activeUnlocks"

    /// JSON-encoded FamilyActivitySelection data for exempt apps
    static let exemptSelectionKey = "exemptSelection"

    /// Bool: whether onboarding has been completed
    static let onboardingCompleteKey = "onboardingComplete"

    /// Bool: whether shields are currently active
    static let shieldsActiveKey = "shieldsActive"

    /// JSON-encoded diagnostics emitted by ShieldActionExtension
    static let shieldActionDiagnosticsKey = "shieldActionDiagnostics"
}
