import SwiftUI
import FamilyControls

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = SettingsViewModel()
    @State private var showingExemptPicker = false

    var body: some View {
        List {
            // MARK: - App List
            Section {
                let count = viewModel.allAppsSelection.applicationTokens.count
                Button {
                    showingExemptPicker = true
                } label: {
                    HStack {
                        Label("Update App List", systemImage: "apps.iphone")
                            .foregroundStyle(Color.brandDeepPlum)
                        Spacer()
                        Text("\(count) apps")
                            .foregroundStyle(Color.brandSoftPlum.opacity(0.6))
                    }
                }
                .familyActivityPicker(
                    isPresented: $showingExemptPicker,
                    selection: $viewModel.allAppsSelection
                )
                .onChange(of: viewModel.allAppsSelection) {
                    viewModel.handleAppSelectionChange()
                }
            } footer: {
                Text("Add newly installed apps to MindfulPhone's managed list.")
            }

            // MARK: - Accountability Partner
            Section {
                TextField("Your first name", text: $viewModel.userName)
                    .textContentType(.givenName)
                    .onChange(of: viewModel.userName) {
                        AppGroupManager.shared.userName = viewModel.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? nil
                            : viewModel.userName.trimmingCharacters(in: .whitespacesAndNewlines)
                    }

                TextField("Partner's email", text: $viewModel.partnerEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: viewModel.partnerEmail) {
                        AppGroupManager.shared.partnerEmail = viewModel.partnerEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? nil
                            : viewModel.partnerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
            } header: {
                Text("Accountability Partner")
            } footer: {
                Text("Your partner will be notified if you bypass or disable protection.")
            }

            // MARK: - Active Unlocks
            Section("Active Unlocks") {
                let active = UnlockManager.shared.getActiveUnlocks()
                if active.isEmpty {
                    Text("No apps currently unlocked")
                        .foregroundStyle(Color.brandSoftPlum.opacity(0.5))
                } else {
                    ForEach(active) { unlock in
                        HStack {
                            Text(unlock.appName)
                                .foregroundStyle(Color.brandDeepPlum)
                            Spacer()
                            Text(unlock.expiresAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(Color.brandGoldenGlow)
                        }
                    }
                }
            }

            // MARK: - Danger Zone
            Section {
                Button(role: .destructive) {
                    viewModel.startDisableTimer()
                } label: {
                    Label("Disable MindfulPhone", systemImage: "xmark.shield")
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("Starts a 5-minute countdown. Your accountability partner will be notified.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.brandWarmCream)
        .navigationTitle("Settings")
        .onAppear {
            viewModel.loadSettings()
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active {
                viewModel.resetDisableTimerIfBackgrounded()
            }
        }
        .fullScreenCover(isPresented: $viewModel.showingDisableTimer) {
            DisableTimerView(viewModel: viewModel)
        }
        .alert(
            "Can't Remove Apps",
            isPresented: $viewModel.showingRemovalRejected
        ) {
            Button("Start 5-Minute Timer") {
                viewModel.startRemovalTimer()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removing apps from the blocked list requires a 5-minute waiting period. Your accountability partner will be notified.")
        }
        .sheet(isPresented: $viewModel.showingRemovalTimer) {
            RemovalTimerView(viewModel: viewModel)
        }
    }
}

// MARK: - Removal Timer View

private struct RemovalTimerView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.brandGoldenGlow)

            VStack(spacing: 12) {
                Text("Removal Timer")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brandDeepPlum)

                Text("Wait for the timer to complete, then try removing apps again.")
                    .font(.body)
                    .foregroundStyle(Color.brandSoftPlum.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Text(formattedTime)
                .font(.system(size: 56, weight: .light, design: .monospaced))
                .foregroundStyle(Color.brandDeepPlum)

            Spacer()

            Button {
                viewModel.cancelRemovalTimer()
            } label: {
                Text("Cancel")
            }
            .buttonStyle(BrandSecondaryButtonStyle())
            .padding(.horizontal, 24)
        }
        .padding(24)
        .background(Color.brandWarmCream.ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    private var formattedTime: String {
        let minutes = viewModel.removalTimeRemaining / 60
        let seconds = viewModel.removalTimeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
