import Foundation
import SwiftData

@Model
final class Conversation {
    var id: UUID
    var appName: String
    var startedAt: Date
    var outcome: String // "pending", "approved", "denied"
    var approvedDurationMinutes: Int?

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.conversation)
    var messages: [ChatMessage] = []

    init(appName: String) {
        self.id = UUID()
        self.appName = appName
        self.startedAt = Date()
        self.outcome = "pending"
    }

    var sortedMessages: [ChatMessage] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }
}
