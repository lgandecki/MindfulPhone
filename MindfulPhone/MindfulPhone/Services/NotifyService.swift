import Foundation
import OSLog

enum NotificationType: String {
    case protectionBypassed = "protection_bypassed"
    case protectionDisabled = "protection_disabled"
    case consideringDisable = "considering_disable"
    case appRemoved = "app_removed"
}

final class NotifyService {
    static let shared = NotifyService()

    private let endpoint = URL(string: "https://mindfulphone-claude-proxy.gozdak.workers.dev/v1/notify")!
    private let logger = Logger(subsystem: "pro.lgandecki.MindfulPhone", category: "NotifyService")

    /// Shared secret injected via Secrets.xcconfig → Info.plist at build time.
    private let appSecret: String? = {
        guard let secret = Bundle.main.infoDictionary?["AppSharedSecret"] as? String,
              !secret.isEmpty,
              !secret.contains("$") else {
            return nil
        }
        return secret
    }()

    private init() {}

    /// Fire-and-forget notification to the accountability partner.
    /// Callers capture `email` and `userName` from AppGroupManager on the main thread
    /// and pass them directly, avoiding MainActor isolation issues.
    func notify(_ type: NotificationType, email: String, userName: String) async {
        NSLog("[NotifyService] notify called: type=%@, email=%@, userName=%@", type.rawValue, email, userName)
        guard let appSecret else {
            NSLog("[NotifyService] ABORT: APP_SHARED_SECRET not configured")
            return
        }

        let body: [String: String] = [
            "to": email,
            "userName": userName,
            "type": type.rawValue,
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            logger.error("Failed to encode notify payload")
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(appSecret)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        request.timeoutInterval = 15

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.info("Notify \(type.rawValue, privacy: .public) → \(status)")
        } catch {
            logger.error("Notify \(type.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
