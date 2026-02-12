import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID
    var role: String // "user", "assistant", "system"
    var content: String
    var timestamp: Date
    var conversation: Conversation?

    init(role: String, content: String, conversation: Conversation? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.conversation = conversation
    }
}
