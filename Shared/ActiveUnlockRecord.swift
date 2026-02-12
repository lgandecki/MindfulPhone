import Foundation

struct ActiveUnlockRecord: Codable, Identifiable {
    let id: UUID
    let tokenData: Data
    let appName: String
    let approvedAt: Date
    let expiresAt: Date
    let durationMinutes: Int
    let reason: String
    let activityName: String

    init(
        tokenData: Data,
        appName: String,
        durationMinutes: Int,
        reason: String,
        activityName: String
    ) {
        self.id = UUID()
        self.tokenData = tokenData
        self.appName = appName
        self.approvedAt = Date()
        self.expiresAt = Date().addingTimeInterval(TimeInterval(durationMinutes * 60))
        self.durationMinutes = durationMinutes
        self.reason = reason
        self.activityName = activityName
    }
}
