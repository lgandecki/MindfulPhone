import SwiftUI

struct AuthorizationStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "faceid")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 12) {
                Text("Authorization Required")
                    .font(.title)
                    .fontWeight(.bold)

                Text("MindfulPhone uses Screen Time's Family Controls to manage app access. You'll authorize with Face ID or Touch ID.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            if viewModel.isAuthorized {
                Label("Authorized", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            Spacer()

            VStack(spacing: 12) {
                if !viewModel.isAuthorized {
                    Button {
                        Task {
                            await viewModel.requestAuthorization()
                        }
                    } label: {
                        Text("Authorize with Face ID")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    viewModel.advance()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isAuthorized)
            }
            .padding(.horizontal, 24)
        }
        .padding(24)
    }
}
