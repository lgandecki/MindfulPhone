import Foundation
import SwiftData
import Network

@MainActor
@Observable
final class ChatViewModel {
    var messages: [DisplayMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var isApproved: Bool = false
    var approvedMinutes: Int?
    var appName: String = ""
    var errorMessage: String?
    var showOfflineOption: Bool = false

    private var pendingRequest: PendingUnlockRequest?
    private var conversation: Conversation?
    private var modelContext: ModelContext?
    private let monitor = NWPathMonitor()

    struct DisplayMessage: Identifiable {
        let id: UUID
        let role: String
        let content: String
        let timestamp: Date

        var isUser: Bool { role == "user" }
        var isAssistant: Bool { role == "assistant" }
    }

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadPendingRequest()
    }

    // MARK: - Load Pending Request

    private func loadPendingRequest() {
        guard let request = AppGroupManager.shared.getPendingUnlockRequest() else {
            return
        }

        self.pendingRequest = request
        self.appName = request.appName

        // Create a new conversation in SwiftData
        let convo = Conversation(appName: request.appName)
        modelContext?.insert(convo)
        self.conversation = convo

        // Add initial greeting from assistant
        let greeting = "You'd like to open **\(request.appName)**. What do you need it for?"
        addAssistantMessage(greeting)

        // Check network availability
        checkNetworkAndShowOfflineOption()
    }

    var hasPendingRequest: Bool {
        pendingRequest != nil
    }

    // MARK: - Send Message

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        inputText = ""
        addUserMessage(text)

        Task {
            isLoading = true
            errorMessage = nil

            do {
                let history = buildUnlockHistory()
                let conversationMessages = messages
                    .filter { $0.role != "system" }
                    .map { (role: $0.role, content: $0.content) }

                let response = try await ClaudeAPIService.shared.sendMessage(
                    conversationMessages: conversationMessages,
                    appName: appName,
                    unlockHistory: history
                )

                addAssistantMessage(response.message)

                if response.isApproved, let minutes = response.approvedMinutes {
                    await handleApproval(minutes: minutes, reason: text)
                }
            } catch {
                if (error as NSError).domain == NSURLErrorDomain {
                    showOfflineOption = true
                    errorMessage = "Can't reach Claude. You can try again or use offline unlock."
                } else {
                    errorMessage = error.localizedDescription
                }
            }

            isLoading = false
        }
    }

    // MARK: - Offline Unlock

    func offlineUnlock() {
        guard pendingRequest != nil else { return }
        let reason = messages.last(where: { $0.isUser })?.content ?? "Offline unlock"
        Task {
            await handleApproval(minutes: 15, reason: reason, isOffline: true)
            addAssistantMessage("Offline mode — unlocked for 15 minutes. Be mindful!")
        }
    }

    // MARK: - Approval Handling

    private func handleApproval(minutes: Int, reason: String, isOffline: Bool = false) async {
        guard let request = pendingRequest else { return }

        isApproved = true
        approvedMinutes = minutes

        // Update conversation
        conversation?.outcome = "approved"
        conversation?.approvedDurationMinutes = minutes

        // Save unlock record
        let record = UnlockRecord(
            appName: appName,
            reason: reason,
            wasApproved: true,
            wasOffline: isOffline,
            durationMinutes: minutes,
            conversationID: conversation?.id
        )
        modelContext?.insert(record)

        // Trigger the actual unlock via UnlockManager
        await UnlockManager.shared.unlockApp(
            tokenData: request.tokenData,
            appName: appName,
            durationMinutes: minutes,
            reason: reason
        )

        // Clear the pending request
        AppGroupManager.shared.clearPendingUnlockRequest()
        pendingRequest = nil
    }

    // MARK: - Helpers

    private func addUserMessage(_ text: String) {
        let display = DisplayMessage(id: UUID(), role: "user", content: text, timestamp: Date())
        messages.append(display)

        if let convo = conversation {
            let msg = ChatMessage(role: "user", content: text, conversation: convo)
            modelContext?.insert(msg)
        }
    }

    private func addAssistantMessage(_ text: String) {
        let display = DisplayMessage(id: UUID(), role: "assistant", content: text, timestamp: Date())
        messages.append(display)

        if let convo = conversation {
            let msg = ChatMessage(role: "assistant", content: text, conversation: convo)
            modelContext?.insert(msg)
        }
    }

    private func checkNetworkAndShowOfflineOption() {
        let pathMonitor = NWPathMonitor()
        pathMonitor.pathUpdateHandler = { path in
            let isOffline = path.status != .satisfied
            Task { @MainActor [weak self] in
                self?.showOfflineOption = isOffline
            }
        }
        pathMonitor.start(queue: DispatchQueue.global(qos: .utility))

        // Stop after initial check
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            pathMonitor.cancel()
        }
    }

    private func buildUnlockHistory() -> [UnlockHistorySummary] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<UnlockRecord>(
            predicate: #Predicate { $0.wasApproved == true },
            sortBy: [SortDescriptor(\.requestedAt, order: .reverse)]
        )
        guard let records = try? context.fetch(descriptor) else { return [] }

        return records.prefix(50).map { record in
            let ago = relativeTimeString(from: record.requestedAt)
            return UnlockHistorySummary(
                appName: record.appName,
                reason: record.reason,
                timeAgo: ago
            )
        }
    }

    private func relativeTimeString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }
}
