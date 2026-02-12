import SwiftUI
import FamilyControls

struct ExemptAppsStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showingPicker = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 12) {
                Text("Always-Allowed Apps")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Choose apps that should never be blocked — like Phone, Messages, or Maps. You can change this later in Settings.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            let count = viewModel.activitySelection.applicationTokens.count
            if count > 0 {
                Text("\(count) app\(count == 1 ? "" : "s") selected")
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
                selection: $viewModel.activitySelection
            )

            if count > 45 {
                Text("Note: There's a limit of ~50 exempt apps. You have \(count) selected.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    viewModel.saveExemptApps()
                    viewModel.advance()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.advance()
                } label: {
                    Text("Skip — block everything")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
        }
        .padding(24)
    }
}
