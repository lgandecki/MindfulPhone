import Foundation
import SwiftData

struct ClaudeResponse {
    let message: String
    let isApproved: Bool
    let approvedMinutes: Int?
    let extractedAppName: String?
    let isPermanentExempt: Bool
}

final class ClaudeAPIService {
    static let shared = ClaudeAPIService()

    #if DEBUG
    // Local proxy on your Mac — update this IP if your Mac's address changes.
    // Run: cd claude-proxy && bun index.ts
    private static let proxyHost = "192.168.1.26"
    private let useProxy = true
    private let endpoint = URL(string: "http://\(proxyHost):3141/v1/messages")!
    #else
    private let useProxy = false
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    #endif

    private init() {}

    // MARK: - Network Check

    var isOnline: Bool {
        // Simple reachability check — try to resolve a known host
        let url = URL(string: "https://api.anthropic.com")!
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        // For a synchronous quick check, we rely on the actual API call failing
        return true
    }

    // MARK: - Send Message

    func sendMessage(
        conversationMessages: [(role: String, content: String)],
        appName: String,
        unlockHistory: [UnlockHistorySummary]
    ) async throws -> ClaudeResponse {
        let apiKey: String? = useProxy ? nil : KeychainService.getAPIKey()
        if !useProxy && apiKey == nil {
            throw ClaudeAPIError.noAPIKey
        }

        let systemPrompt = buildSystemPrompt(appName: appName, unlockHistory: unlockHistory)

        let messages = conversationMessages.map { msg in
            ["role": msg.role, "content": msg.content]
        }

        let body: [String: Any] = [
            "model": "claude-sonnet-4-5-20250929",
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": messages,
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        if let apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeAPIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw ClaudeAPIError.parseError
        }

        return parseResponse(text)
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(appName: String, unlockHistory: [UnlockHistorySummary]) -> String {
        var prompt = """
        You are a mindfulness guardian in the MindfulPhone app. Your role is to help the user be \
        intentional about their phone usage. The user has voluntarily set up this app to block all \
        apps by default and must explain their reason before unlocking one.

        The user wants to open: \(appName)

        Your guidelines:
        - Be warm, conversational, and non-judgmental
        - A clear, specific purpose deserves instant approval (e.g., "I need to check my flight status" → approve)
        - Vague or habitual reasons deserve gentle pushback (e.g., "I'm bored" → ask what specifically they want to do)
        - You can have a back-and-forth conversation to understand their intent
        - Consider context: time of day, how often they've requested this app recently
        - You decide the appropriate duration freely based on the task described
        - For quick tasks (checking one thing): 5-15 minutes
        - For longer tasks (reading an article, messaging friends at an event): 30-60 minutes
        - For work/productivity tasks: up to 120 minutes
        - You CAN deny access if the reason is clearly just mindless scrolling with no purpose

        RESPONSE TAGS (include at the very end of your message, all that apply):

        1. When you approve a TEMPORARY unlock:
           [APPROVED:XX] where XX is the number of minutes.

        2. When you approve a PERMANENT exemption (the user asks to never block this app again, \
        and the app is clearly essential — e.g., Phone, Messages, Maps, banking, authentication):
           [APPROVED:0][PERMANENT_EXEMPT]

        3. When the app name is "this app" (first encounter — iOS limitation), the user will tell \
        you which app they mean. Extract the name and include:
           [APP_NAME:ExactAppName]
           Use the exact app name as the user stated it (e.g., "Instagram", "Messages", "Google Maps"). \
        Include this tag in EVERY response when the app name is "this app", even if you haven't approved yet.

        Example responses:
        - "Checking your flight? Absolutely. [APP_NAME:United Airlines][APPROVED:15]"
        - "Messages is clearly essential — I'll unblock it permanently for you. [APP_NAME:Messages][APPROVED:0][PERMANENT_EXEMPT]"
        - "You want to open Instagram. What specifically do you need to do there? [APP_NAME:Instagram]"

        Do NOT include [APPROVED:XX] unless you are actually approving. \
        Do NOT grant [PERMANENT_EXEMPT] for social media, games, or entertainment apps.
        """

        if !unlockHistory.isEmpty {
            prompt += "\n\nRecent unlock history for context:\n"
            for record in unlockHistory.suffix(20) {
                prompt += "- \(record.appName): \(record.reason) (\(record.timeAgo))\n"
            }
        }

        return prompt
    }

    // MARK: - Response Parsing

    private func parseResponse(_ text: String) -> ClaudeResponse {
        var remaining = text

        // Extract [APP_NAME:xxx]
        var extractedAppName: String?
        let appNamePattern = #"\[APP_NAME:([^\]]+)\]"#
        if let regex = try? NSRegularExpression(pattern: appNamePattern),
           let match = regex.firstMatch(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)),
           let nameRange = Range(match.range(at: 1), in: remaining) {
            extractedAppName = String(remaining[nameRange])
        }
        remaining = remaining.replacingOccurrences(
            of: #"\s*\[APP_NAME:[^\]]+\]"#, with: "", options: .regularExpression
        )

        // Extract [PERMANENT_EXEMPT]
        let isPermanentExempt = remaining.contains("[PERMANENT_EXEMPT]")
        remaining = remaining.replacingOccurrences(
            of: #"\s*\[PERMANENT_EXEMPT\]"#, with: "", options: .regularExpression
        )

        // Extract [APPROVED:XX]
        let approvedPattern = #"\[APPROVED:(\d+)\]"#
        var isApproved = false
        var approvedMinutes: Int?
        if let regex = try? NSRegularExpression(pattern: approvedPattern),
           let match = regex.firstMatch(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)),
           let minutesRange = Range(match.range(at: 1), in: remaining) {
            isApproved = true
            approvedMinutes = Int(remaining[minutesRange]) ?? 15
        }
        remaining = remaining.replacingOccurrences(
            of: #"\s*\[APPROVED:\d+\]"#, with: "", options: .regularExpression
        )

        return ClaudeResponse(
            message: remaining.trimmingCharacters(in: .whitespacesAndNewlines),
            isApproved: isApproved,
            approvedMinutes: approvedMinutes,
            extractedAppName: extractedAppName,
            isPermanentExempt: isPermanentExempt
        )
    }
}

// MARK: - Supporting Types

struct UnlockHistorySummary {
    let appName: String
    let reason: String
    let timeAgo: String
}

enum ClaudeAPIError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case parseError
    case offline

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your Claude API key in Settings."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .apiError(let code, let message):
            if code == 401 {
                return "Invalid API key. Please check your key in Settings."
            }
            return "API error (\(code)): \(message)"
        case .parseError:
            return "Could not parse the response."
        case .offline:
            return "No internet connection."
        }
    }
}
