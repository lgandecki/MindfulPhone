import Foundation

struct PendingUnlockRequest: Codable, Identifiable {
    let id: UUID
    let tokenData: Data
    let appName: String
    let timestamp: Date

    init(tokenData: Data, appName: String) {
        self.id = UUID()
        self.tokenData = tokenData
        self.appName = appName
        self.timestamp = Date()
    }
}
