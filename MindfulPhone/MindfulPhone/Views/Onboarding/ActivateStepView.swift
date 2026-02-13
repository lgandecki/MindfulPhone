import FamilyControls
import SwiftUI

struct ActivateStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    private var hasPartner: Bool {
        !viewModel.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.partnerEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "shield.checkered")
                .font(.system(size: 56))
                .foregroundStyle(Color.brandSoftPlum)
                .frame(width: 88, height: 88)
                .background(Color.brandLavender.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 22))

            VStack(spacing: 12) {
                Text("Ready to Activate")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brandDeepPlum)

                Text("Once activated, your selected apps will be blocked. To open one, you'll have a quick conversation with Claude AI about why you need it.")
                    .font(.body)
                    .foregroundStyle(Color.brandSoftPlum.opacity(0.7))
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
                ChecklistRow(
                    text: "Accountability partner \(hasPartner ? "added" : "(optional)")",
                    isDone: hasPartner
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
                        .tint(.white)
                } else {
                    Text("Activate MindfulPhone")
                }
            }
            .buttonStyle(BrandButtonStyle(isDisabled: viewModel.isActivating))
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
                .foregroundStyle(isDone ? .green : Color.brandLavender)
            Text(text)
                .foregroundStyle(isDone ? Color.brandDeepPlum : Color.brandSoftPlum.opacity(0.5))
        }
    }
}
