import SwiftUI
import FamilyControls

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var showingExemptPicker = false

    var body: some View {
        List {
            // MARK: - Exempt Apps
            Section {
                let count = viewModel.activitySelection.applicationTokens.count
                Button {
                    showingExemptPicker = true
                } label: {
                    HStack {
                        Label("Always-Allowed Apps", systemImage: "app.badge.checkmark")
                        Spacer()
                        Text("\(count)")
                            .foregroundStyle(.secondary)
                    }
                }
                .familyActivityPicker(
                    isPresented: $showingExemptPicker,
                    selection: $viewModel.activitySelection
                )
                .onChange(of: viewModel.activitySelection) {
                    viewModel.saveExemptApps()
                }
            } footer: {
                Text("These apps will never be blocked. Maximum ~50 apps.")
            }

            // MARK: - API Key
            Section {
                HStack {
                    Label("API Key", systemImage: "key.fill")
                    Spacer()
                    if viewModel.apiKeyValid {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                SecureField("sk-ant-...", text: $viewModel.apiKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if let error = viewModel.apiKeyError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await viewModel.updateAPIKey() }
                } label: {
                    if viewModel.isTestingKey {
                        ProgressView()
                    } else {
                        Text("Update & Test Key")
                    }
                }
                .disabled(viewModel.apiKey.isEmpty || viewModel.isTestingKey)
            } header: {
                Text("Claude API")
            } footer: {
                Text("Your key is stored securely in the iOS Keychain.")
            }

            // MARK: - Active Unlocks
            Section("Active Unlocks") {
                let active = UnlockManager.shared.getActiveUnlocks()
                if active.isEmpty {
                    Text("No apps currently unlocked")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(active) { unlock in
                        HStack {
                            Text(unlock.appName)
                            Spacer()
                            Text(unlock.expiresAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            // MARK: - Danger Zone
            Section {
                Button(role: .destructive) {
                    viewModel.showingRevokeConfirmation = true
                } label: {
                    Label("Disable MindfulPhone", systemImage: "xmark.shield")
                }
                .confirmationDialog(
                    "Disable MindfulPhone?",
                    isPresented: $viewModel.showingRevokeConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Disable & Remove All Shields", role: .destructive) {
                        viewModel.revokeAuthorization()
                    }
                } message: {
                    Text("This will remove all app shields and revoke Screen Time authorization. You'll need to go through onboarding again to re-enable.")
                }
            } header: {
                Text("Danger Zone")
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            viewModel.loadSettings()
        }
    }
}
