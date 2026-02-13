import SwiftUI
import FamilyControls

struct AppSelectionStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showingPicker = false

    private static let appLimit = 50

    private var appCount: Int {
        viewModel.allAppsSelection.applicationTokens.count
    }

    private var hasSelection: Bool { appCount > 0 }
    private var overLimit: Bool { appCount > Self.appLimit }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "apps.iphone")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 12) {
                Text("Block Distracting Apps")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Choose the apps you find most distracting. MindfulPhone will ask you to reflect before opening them.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            if hasSelection {
                Text("\(appCount) app\(appCount == 1 ? "" : "s") selected")
                    .font(.subheadline)
                    .foregroundStyle(overLimit ? .red : .secondary)
            }

            if overLimit {
                Text("iOS limits blocking to \(Self.appLimit) apps. Please reduce your selection.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                showingPicker = true
            } label: {
                Label(hasSelection ? "Edit Selection" : "Choose Apps", systemImage: hasSelection ? "pencil.circle" : "plus.circle")
                    .font(.headline)
            }
            .familyActivityPicker(
                isPresented: $showingPicker,
                selection: $viewModel.allAppsSelection
            )

            Spacer()

            Button {
                viewModel.advance()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasSelection || overLimit)
            .padding(.horizontal, 24)
        }
        .padding(24)
    }
}
