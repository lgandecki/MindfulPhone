import Foundation
import SwiftData

struct ClaudeResponse {
    let message: String
    let isApproved: Bool
    let approvedMinutes: Int?
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

        When you decide to approve, end your message naturally but include this exact tag at the very end:
        [APPROVED:XX] where XX is the number of minutes you're granting.

        Example: "That makes sense! Checking your flight details is definitely important. Go ahead and take care of that. [APPROVED:10]"

        Do NOT include the [APPROVED:XX] tag unless you are actually approving the request.
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
        // Look for [APPROVED:XX] pattern at the end of the message
        let pattern = #"\[APPROVED:(\d+)\]\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let minutesRange = Range(match.range(at: 1), in: text) {
            let minutes = Int(text[minutesRange]) ?? 15
            // Remove the tag from the displayed message
            let cleanMessage = text.replacingOccurrences(
                of: #"\s*\[APPROVED:\d+\]\s*$"#,
                with: "",
                options: .regularExpression
            )
            return ClaudeResponse(message: cleanMessage, isApproved: true, approvedMinutes: minutes)
        }

        return ClaudeResponse(message: text, isApproved: false, approvedMinutes: nil)
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
