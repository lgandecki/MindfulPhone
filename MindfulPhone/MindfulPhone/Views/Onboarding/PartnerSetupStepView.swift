import SwiftUI

struct PartnerSetupStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var skipCountdown = 5
    @State private var skipVisible = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 20)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.brandSoftPlum)
                    .frame(width: 88, height: 88)
                    .background(Color.brandLavender.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                VStack(spacing: 8) {
                    Text("Accountability Partner")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.brandDeepPlum)

                    Text("Add someone you trust. They'll be notified if you bypass or disable protection.")
                        .font(.subheadline)
                        .foregroundStyle(Color.brandSoftPlum.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal)

                VStack(spacing: 0) {
                    TextField("Your first name", text: $viewModel.userName)
                        .textContentType(.givenName)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    Divider()
                        .padding(.leading, 16)

                    TextField("Partner's email", text: $viewModel.partnerEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .background(Color.brandLavender.opacity(0.1), in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandLavender.opacity(0.2), lineWidth: 1))
                .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    Button {
                        viewModel.advance()
                    } label: {
                        Text("Continue")
                    }
                    .buttonStyle(BrandButtonStyle(isDisabled: !canContinue))
                    .disabled(!canContinue)

                    if skipVisible {
                        Button {
                            viewModel.advance()
                        } label: {
                            Text("Skip for now")
                                .font(.subheadline)
                                .foregroundStyle(Color.brandSoftPlum.opacity(0.5))
                        }
                        .transition(.opacity)
                    } else {
                        Button {} label: {
                            Text("Skip for now (\(skipCountdown))")
                                .font(.subheadline)
                                .foregroundStyle(Color.brandLavender.opacity(0.4))
                        }
                        .disabled(true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .task {
            for _ in 0..<5 {
                try? await Task.sleep(for: .seconds(1))
                skipCountdown -= 1
            }
            withAnimation {
                skipVisible = true
            }
        }
    }

    private var canContinue: Bool {
        let name = viewModel.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = viewModel.partnerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && !email.isEmpty
    }
}
