import SwiftUI
import SwiftData
import UserNotifications
import FamilyControls

struct ContentView: View {
    private static let pendingRequestMaxAgeSeconds: TimeInterval = 120

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var isOnboardingComplete = AppGroupManager.shared.isOnboardingComplete
    @State private var hasPendingRequest = AppGroupManager.shared.getPendingUnlockRequest(
        maxAge: Self.pendingRequestMaxAgeSeconds
    ) != nil
    @State private var selectedTab: AppTab = .dashboard
    @State private var showSplash = true

    enum AppTab: Hashable {
        case dashboard, chat, history, settings
    }

    var body: some View {
        ZStack {
            Group {
                if !isOnboardingComplete {
                    OnboardingContainerView {
                        isOnboardingComplete = true
                    }
                } else {
                    MainTabView(selectedTab: $selectedTab)
                }
            }

            if showSplash {
                Image("SplashImage")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .onAppear {
            refreshState()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showSplash = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refreshState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .unlockRequestNotificationTapped)) { _ in
            refreshState()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                refreshState()
            }
        }
    }

    private func refreshState() {
        // Tamper detection: check if protection was bypassed
        let manager = AppGroupManager.shared
        let blocking = BlockingService.shared

        if manager.isOnboardingComplete {
            let authStatus = AuthorizationCenter.shared.authorizationStatus
            if authStatus != .approved {
                // User revoked Family Controls authorization entirely
                handleTamperDetected()
                return
            }
            if manager.areShieldsActive && !blocking.hasActiveShields {
                // User revoked and re-enabled auth — shields are gone from the store
                handleTamperDetected()
                return
            }
        }

        let hadPendingRequest = hasPendingRequest
        hasPendingRequest = manager.getPendingUnlockRequest(
            maxAge: Self.pendingRequestMaxAgeSeconds
        ) != nil
        isOnboardingComplete = manager.isOnboardingComplete
        UnlockManager.shared.recheckExpiredUnlocks()

        // Auto-switch to Chat tab when a new pending request arrives
        if hasPendingRequest && !hadPendingRequest {
            selectedTab = .chat
        }

        if !hasPendingRequest {
            Task {
                await recoverPendingRequestFromNotificationsIfNeeded()
            }
        }
    }

    private func handleTamperDetected() {
        let manager = AppGroupManager.shared
        let email = manager.partnerEmail
        let userName = manager.userName ?? "Someone"

        NSLog("[TamperDetect] Detected! email=%@, userName=%@", email ?? "nil", userName)

        // Send notification in a detached task — completely independent of
        // view lifecycle so it survives the state reset and re-render below.
        if let email {
            NSLog("[TamperDetect] Sending protection_bypassed notification to %@", email)
            Task.detached {
                await NotifyService.shared.notify(.protectionBypassed, email: email, userName: userName)
                NSLog("[TamperDetect] Notification request completed")
            }
        } else {
            NSLog("[TamperDetect] No partner email configured, skipping notification")
        }

        // Reset all state — triggers view re-render to onboarding
        manager.isOnboardingComplete = false
        manager.areShieldsActive = false
        manager.activationDate = nil

        // Clear SwiftData history
        do {
            try modelContext.delete(model: Conversation.self)
            try modelContext.delete(model: ChatMessage.self)
            try modelContext.delete(model: UnlockRecord.self)
        } catch {
            NSLog("[ContentView] Failed to clear SwiftData on tamper: %@", error.localizedDescription)
        }

        isOnboardingComplete = false
        hasPendingRequest = false
    }

    @MainActor
    private func recoverPendingRequestFromNotificationsIfNeeded() async {
        guard AppGroupManager.shared.getPendingUnlockRequest(maxAge: Self.pendingRequestMaxAgeSeconds) == nil else {
            hasPendingRequest = true
            return
        }

        let delivered = await deliveredUnlockRequestNotifications()
        let pending = await pendingUnlockRequestNotifications()

        let deliveredCandidates = delivered.compactMap { notificationCandidate(from: $0.request) }
        let pendingCandidates = pending.compactMap(notificationCandidate(from:))
        let allCandidates = deliveredCandidates + pendingCandidates

        guard let candidate = allCandidates
            .filter({ Date().timeIntervalSince($0.timestamp) <= Self.pendingRequestMaxAgeSeconds })
            .max(by: { $0.timestamp < $1.timestamp }) else {
            return
        }

        saveExtensionDiagnosticsFromUserInfo(candidate.userInfo)

        let request = PendingUnlockRequest(tokenData: candidate.tokenData, appName: candidate.appName)
        _ = AppGroupManager.shared.savePendingUnlockRequest(request)
        AppGroupManager.shared.saveShieldActionDiagnostics([
            "recoveredFromDeliveredNotification": "YES",
            "recoveredAppName": candidate.appName
        ])
        hasPendingRequest = AppGroupManager.shared.getPendingUnlockRequest(
            maxAge: Self.pendingRequestMaxAgeSeconds
        ) != nil
        if hasPendingRequest {
            selectedTab = .chat
        }
    }

    private func saveExtensionDiagnosticsFromUserInfo(_ userInfo: [AnyHashable: Any]) {
        var diagnostics: [String: String] = [:]

        if let value = userInfo["saveSuccess"] as? Bool {
            diagnostics["notif.saveSuccess"] = value ? "YES" : "NO"
        }
        if let value = userInfo["saveWroteFile"] as? Bool {
            diagnostics["notif.saveWroteFile"] = value ? "YES" : "NO"
        }
        if let value = userInfo["saveWroteSharedDefaults"] as? Bool {
            diagnostics["notif.saveWroteSharedDefaults"] = value ? "YES" : "NO"
        }
        if let value = userInfo["saveSharedContainerAvailable"] as? Bool {
            diagnostics["notif.saveSharedContainerAvailable"] = value ? "YES" : "NO"
        }
        if let value = userInfo["saveSharedDefaultsAvailable"] as? Bool {
            diagnostics["notif.saveSharedDefaultsAvailable"] = value ? "YES" : "NO"
        }

        if !diagnostics.isEmpty {
            AppGroupManager.shared.saveShieldActionDiagnostics(diagnostics)
        }
    }

    private func deliveredUnlockRequestNotifications() async -> [UNNotification] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
                continuation.resume(
                    returning: notifications.filter {
                        $0.request.content.categoryIdentifier == "UNLOCK_REQUEST"
                    }
                )
            }
        }
    }

    private func pendingUnlockRequestNotifications() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                continuation.resume(
                    returning: requests.filter {
                        $0.content.categoryIdentifier == "UNLOCK_REQUEST"
                    }
                )
            }
        }
    }

    private func notificationCandidate(from request: UNNotificationRequest) -> (appName: String, tokenData: Data, timestamp: Date, userInfo: [AnyHashable: Any])? {
        let userInfo = request.content.userInfo
        guard let appName = userInfo["appName"] as? String,
              let tokenDataBase64 = userInfo["tokenDataBase64"] as? String,
              let tokenData = Data(base64Encoded: tokenDataBase64) else {
            return nil
        }

        if let rawTimestamp = userInfo["requestTimestamp"] as? TimeInterval {
            return (appName, tokenData, Date(timeIntervalSince1970: rawTimestamp), userInfo)
        }
        if let rawTimestamp = userInfo["requestTimestamp"] as? NSNumber {
            return (appName, tokenData, Date(timeIntervalSince1970: rawTimestamp.doubleValue), userInfo)
        }
        return (appName, tokenData, Date(), userInfo)
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Binding var selectedTab: ContentView.AppTab

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "gauge.open.with.lines.needle.33percent", value: .dashboard) {
                NavigationStack {
                    DashboardView()
                }
            }

            Tab("Chat", systemImage: "bubble.left.and.bubble.right", value: .chat) {
                NavigationStack {
                    ChatView()
                }
            }

            Tab("History", systemImage: "clock", value: .history) {
                NavigationStack {
                    HistoryListView()
                }
            }

            Tab("Settings", systemImage: "gear", value: .settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(Color.brandAccent)
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @State private var activeUnlocks: [ActiveUnlockRecord] = []

    private var streakText: String {
        guard let activation = AppGroupManager.shared.activationDate else {
            return "MindfulPhone Active"
        }
        let days = Calendar.current.dateComponents([.day], from: activation, to: Date()).day ?? 0
        return "Protected for \(days) \(days == 1 ? "day" : "days")"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status card
                VStack(spacing: 12) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.brandSoftPlum)

                    Text(streakText)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.brandDeepPlum)

                    Text("All apps are shielded. Open any blocked app to start an unlock request.")
                        .font(.subheadline)
                        .foregroundStyle(Color.brandSoftPlum.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color.brandCardBackground, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.brandLavender.opacity(0.2), radius: 12, y: 4)

                // Active Unlocks
                if !activeUnlocks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Unlocks")
                            .font(.headline)
                            .foregroundStyle(Color.brandDeepPlum)

                        ForEach(activeUnlocks) { unlock in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(unlock.appName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.brandDeepPlum)
                                    Text(unlock.reason)
                                        .font(.caption)
                                        .foregroundStyle(Color.brandSoftPlum.opacity(0.6))
                                        .lineLimit(1)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Expires")
                                        .font(.caption2)
                                        .foregroundStyle(Color.brandSoftPlum.opacity(0.5))
                                    Text(unlock.expiresAt, style: .relative)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.brandGoldenGlow)
                                }
                            }
                            .padding(12)
                            .background(Color.brandCardBackground, in: RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.brandLavender.opacity(0.1), radius: 6, y: 2)
                        }
                    }
                }

                // Quick stats link
                NavigationLink {
                    StatsView()
                } label: {
                    HStack {
                        Label("View Stats", systemImage: "chart.bar")
                            .foregroundStyle(Color.brandDeepPlum)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.brandLavender)
                    }
                    .padding(16)
                    .background(Color.brandCardBackground, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.brandLavender.opacity(0.1), radius: 6, y: 2)
                }

            }
            .padding(16)
        }
        .background(Color.brandWarmCream)
        .navigationTitle("MindfulPhone")
        .onAppear {
            activeUnlocks = UnlockManager.shared.getActiveUnlocks()
        }
    }
}
