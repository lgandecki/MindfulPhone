import Foundation
import SwiftData

@Model
final class UnlockRecord {
    var id: UUID
    var appName: String
    var requestedAt: Date
    var approvedAt: Date?
    var expiresAt: Date?
    var durationMinutes: Int?
    var reason: String
    var wasApproved: Bool
    var wasOffline: Bool
    var conversationID: UUID?

    init(
        appName: String,
        reason: String,
        wasApproved: Bool,
        wasOffline: Bool = false,
        durationMinutes: Int? = nil,
        conversationID: UUID? = nil
    ) {
        self.id = UUID()
        self.appName = appName
        self.requestedAt = Date()
        self.reason = reason
        self.wasApproved = wasApproved
        self.wasOffline = wasOffline
        self.durationMinutes = durationMinutes
        self.conversationID = conversationID

        if wasApproved {
            self.approvedAt = Date()
            if let minutes = durationMinutes {
                self.expiresAt = Date().addingTimeInterval(TimeInterval(minutes * 60))
            }
        }
    }
}
