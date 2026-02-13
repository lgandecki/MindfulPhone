import SwiftUI
import FamilyControls

struct SettingsView: View {
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
                        Spacer()
                        Text("\(count) apps")
                            .foregroundStyle(.secondary)
                    }
                }
                .familyActivityPicker(
                    isPresented: $showingExemptPicker,
                    selection: $viewModel.allAppsSelection
                )
                .onChange(of: viewModel.allAppsSelection) {
                    viewModel.saveUpdatedAppList()
                }
            } footer: {
                Text("Add newly installed apps to MindfulPhone's managed list.")
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
