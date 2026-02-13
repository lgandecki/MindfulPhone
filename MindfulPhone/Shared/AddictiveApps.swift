import Foundation

/// Apps known to be addictive / high-distraction. These don't get the "Always Allow"
/// quick-exempt button on the shield screen. Users must go through the Claude chat flow.
enum AddictiveApps {
    static let blacklist: Set<String> = [
        // Social media
        "Instagram", "TikTok", "Facebook", "Twitter", "X",
        "Snapchat", "Threads", "Reddit", "Bluesky",
        // Video / streaming
        "YouTube", "Netflix", "Twitch", "Disney+", "Hulu",
        "HBO Max", "Max", "Prime Video", "Apple TV",
        // Dating
        "Tinder", "Bumble", "Hinge",
        // News / infinite scroll
        "News", "Google News", "Flipboard",
        // Games (common)
        "Candy Crush Saga", "Clash of Clans", "Clash Royale",
        "Roblox", "Fortnite", "PUBG MOBILE",
        // Shopping
        "Amazon", "SHEIN", "Temu", "AliExpress",
    ]

    private static let lowercased: Set<String> = {
        Set(blacklist.map { $0.lowercased() })
    }()

    static func isBlacklisted(_ appName: String) -> Bool {
        lowercased.contains(appName.lowercased())
    }
}
