import SwiftUI
import SwiftData

@main
struct MindfulPhoneApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Conversation.self,
            ChatMessage.self,
            UnlockRecord.self,
        ])
        // groupContainer: .none prevents SwiftData from using the App Group
        // container (which causes sandbox permission errors). The app group
        // is for IPC with extensions only, not for SwiftData storage.
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    AccountabilityService.shared.startObserving()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
