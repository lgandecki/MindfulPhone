import SwiftUI

struct APIKeyStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 12) {
                Text("Claude API Key")
                    .font(.title)
                    .fontWeight(.bold)

                Text("MindfulPhone uses Claude AI to evaluate your unlock reasons. You'll need your own API key from Anthropic.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            VStack(spacing: 12) {
                SecureField("sk-ant-...", text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 24)

                if let error = viewModel.apiKeyError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                if viewModel.apiKeyValid {
                    Label("Connected to Claude", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                if !viewModel.apiKeyValid {
                    Button {
                        Task { await viewModel.testAPIKey() }
                    } label: {
                        if viewModel.isTestingKey {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        } else {
                            Text("Test Connection")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.apiKey.isEmpty || viewModel.isTestingKey)

                    #if DEBUG
                    Button {
                        Task { await viewModel.testProxyConnection() }
                    } label: {
                        Text("Use Dev Proxy")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .disabled(viewModel.isTestingKey)
                    #endif
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
                .disabled(!viewModel.apiKeyValid)
            }
            .padding(.horizontal, 24)
        }
        .padding(24)
    }
}
