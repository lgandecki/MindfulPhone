import SwiftUI

struct AuthorizationStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "faceid")
                .font(.system(size: 56))
                .foregroundStyle(Color.brandSoftPlum)
                .frame(width: 88, height: 88)
                .background(Color.brandLavender.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 22))

            VStack(spacing: 12) {
                Text("Authorization Required")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brandDeepPlum)

                Text("MindfulPhone uses Screen Time to manage app access. You'll authorize with Face ID or Touch ID.")
                    .font(.body)
                    .foregroundStyle(Color.brandSoftPlum.opacity(0.7))
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
                    }
                    .buttonStyle(BrandButtonStyle())
                }

                Button {
                    viewModel.advance()
                } label: {
                    Text("Continue")
                }
                .buttonStyle(BrandSecondaryButtonStyle(isDisabled: !viewModel.isAuthorized))
                .disabled(!viewModel.isAuthorized)
            }
            .padding(.horizontal, 24)
        }
        .padding(24)
    }
}
