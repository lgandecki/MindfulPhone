import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOnboardingComplete = AppGroupManager.shared.isOnboardingComplete
    @State private var hasPendingRequest = AppGroupManager.shared.getPendingUnlockRequest() != nil

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
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                refreshState()
            }
        }
    }

    private func refreshState() {
        hasPendingRequest = AppGroupManager.shared.getPendingUnlockRequest() != nil
        isOnboardingComplete = AppGroupManager.shared.isOnboardingComplete
        UnlockManager.shared.recheckExpiredUnlocks()
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
                        diagnostics = AppGroupManager.shared.diagnosticInfo()
                    }
                    .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(16)
        }
        .navigationTitle("MindfulPhone")
        .onAppear {
            activeUnlocks = UnlockManager.shared.getActiveUnlocks()
            diagnostics = AppGroupManager.shared.diagnosticInfo()
        }
    }
}
