import SwiftUI
import SwiftData
import UserNotifications

struct ContentView: View {
    private static let pendingRequestMaxAgeSeconds: TimeInterval = 120

    @Environment(\.scenePhase) private var scenePhase
    @State private var isOnboardingComplete = AppGroupManager.shared.isOnboardingComplete
    @State private var hasPendingRequest = AppGroupManager.shared.getPendingUnlockRequest(
        maxAge: Self.pendingRequestMaxAgeSeconds
    ) != nil

    var body: some View {
        Group {
            if !isOnboardingComplete {
                OnboardingContainerView {
                    isOnboardingComplete = true
                }
            } else if hasPendingRequest {
                NavigationStack {
                    ChatView()
                }
            } else {
                MainTabView()
            }
        }
        .onAppear {
            refreshState()
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
        hasPendingRequest = AppGroupManager.shared.getPendingUnlockRequest(
            maxAge: Self.pendingRequestMaxAgeSeconds
        ) != nil
        isOnboardingComplete = AppGroupManager.shared.isOnboardingComplete
        UnlockManager.shared.recheckExpiredUnlocks()

        if !hasPendingRequest {
            Task {
                await recoverPendingRequestFromNotificationsIfNeeded()
            }
        }
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
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "gauge.open.with.lines.needle.33percent") {
                NavigationStack {
                    DashboardView()
                }
            }

            Tab("History", systemImage: "clock") {
                NavigationStack {
                    HistoryListView()
                }
            }

            Tab("Settings", systemImage: "gear") {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @State private var activeUnlocks: [ActiveUnlockRecord] = []
    @State private var diagnostics: [String: String] = [:]
    @State private var extensionLogs: [String] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status card
                VStack(spacing: 12) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)

                    Text("MindfulPhone Active")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("All apps are shielded. Open any blocked app to start an unlock request.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

                // Active Unlocks
                if !activeUnlocks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Unlocks")
                            .font(.headline)

                        ForEach(activeUnlocks) { unlock in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(unlock.appName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(unlock.reason)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Expires")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(unlock.expiresAt, style: .relative)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.orange)
                                }
                            }
                            .padding(12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                // Quick stats link
                NavigationLink {
                    StatsView()
                } label: {
                    HStack {
                        Label("View Stats", systemImage: "chart.bar")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .foregroundStyle(.primary)

                // Debug diagnostics (temporary)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Debug Info")
                        .font(.headline)
                        .foregroundStyle(.red)

                    ForEach(diagnostics.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(alignment: .top) {
                            Text(key + ":")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .frame(width: 120, alignment: .leading)
                            Text(value)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Refresh") {
                        refreshDiagnostics()
                    }
                    .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                if !extensionLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extension Logs")
                            .font(.headline)
                            .foregroundStyle(.orange)

                        ForEach(Array(extensionLogs.indices), id: \.self) { index in
                            Text(extensionLogs[index])
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button("Clear Logs") {
                            AppGroupManager.shared.clearExtensionLogs()
                            refreshDiagnostics()
                        }
                        .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(16)
        }
        .navigationTitle("MindfulPhone")
        .onAppear {
            activeUnlocks = UnlockManager.shared.getActiveUnlocks()
            refreshDiagnostics()
        }
    }

    private func refreshDiagnostics() {
        diagnostics = AppGroupManager.shared.diagnosticInfo()
        extensionLogs = AppGroupManager.shared.getExtensionLogs(limit: 25)

        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                diagnostics["notificationAuthorization"] = notificationStatusText(settings.authorizationStatus)
            }
        }
    }

    private func notificationStatusText(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }
}
