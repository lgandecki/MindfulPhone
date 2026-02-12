import SwiftUI

struct OnboardingContainerView: View {
    @State private var viewModel = OnboardingViewModel()
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(OnboardingViewModel.OnboardingStep.allCases, id: \.rawValue) { step in
                    Capsule()
                        .fill(step.rawValue <= viewModel.currentStep.rawValue ? Color.blue : Color.secondary.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            // Content
            TabView(selection: $viewModel.currentStep) {
                WelcomeStepView(onContinue: { viewModel.advance() })
                    .tag(OnboardingViewModel.OnboardingStep.welcome)

                AuthorizationStepView(viewModel: viewModel)
                    .tag(OnboardingViewModel.OnboardingStep.authorization)

                ExemptAppsStepView(viewModel: viewModel)
                    .tag(OnboardingViewModel.OnboardingStep.exemptApps)

                APIKeyStepView(viewModel: viewModel)
                    .tag(OnboardingViewModel.OnboardingStep.apiKey)

                ActivateStepView(viewModel: viewModel, onComplete: onComplete)
                    .tag(OnboardingViewModel.OnboardingStep.activate)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: viewModel.currentStep)
        }
    }
}
