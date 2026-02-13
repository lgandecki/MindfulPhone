import FamilyControls
import SwiftUI

struct ActivateStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "shield.checkered")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 12) {
                Text("Ready to Activate")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Once activated, your selected apps will be blocked. To open one, you'll have a quick conversation with Claude AI about why you need it.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                ChecklistRow(
                    text: "Screen Time authorized",
                    isDone: viewModel.isAuthorized
                )
                ChecklistRow(
                    text: "Distracting apps selected",
                    isDone: !viewModel.allAppsSelection.applicationTokens.isEmpty
                )
            }

            Spacer()

            Button {
                Task {
                    await viewModel.activate()
                    onComplete()
                }
            } label: {
                if viewModel.isActivating {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else {
                    Text("Activate MindfulPhone")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isActivating)
            .padding(.horizontal, 24)
        }
        .padding(24)
    }
}

private struct ChecklistRow: View {
    let text: String
    let isDone: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isDone ? .green : .secondary)
            Text(text)
                .foregroundStyle(isDone ? .primary : .secondary)
        }
    }
}
