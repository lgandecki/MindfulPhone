import SwiftUI
import FamilyControls

struct AppSelectionStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showingPicker = false

    private var hasSelection: Bool {
        !viewModel.allAppsSelection.applicationTokens.isEmpty
            || !viewModel.allAppsSelection.categoryTokens.isEmpty
    }

    private var selectionSummary: String {
        let apps = viewModel.allAppsSelection.applicationTokens.count
        let cats = viewModel.allAppsSelection.categoryTokens.count
        if apps > 0 && cats > 0 {
            return "\(apps) apps + \(cats) categories selected"
        } else if apps > 0 {
            return "\(apps) app\(apps == 1 ? "" : "s") selected"
        } else if cats > 0 {
            return "\(cats) categor\(cats == 1 ? "y" : "ies") selected (includes all apps)"
        }
        return ""
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "apps.iphone")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 12) {
                Text("Select Your Apps")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Tap the button below, then tap **Select All** at the top. This tells MindfulPhone which apps to manage.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            if hasSelection {
                Text(selectionSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                showingPicker = true
            } label: {
                Label("Choose Apps", systemImage: "plus.circle")
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
            .disabled(!hasSelection)
            .padding(.horizontal, 24)
        }
        .padding(24)
    }
}
