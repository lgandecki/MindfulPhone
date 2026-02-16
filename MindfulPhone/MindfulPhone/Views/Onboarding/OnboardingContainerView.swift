import SwiftUI

struct OnboardingContainerView: View {
    @State private var viewModel = OnboardingViewModel()
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            BrandGradientBackground()

            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(OnboardingViewModel.OnboardingStep.allCases, id: \.rawValue) { step in
                        Capsule()
                            .fill(
                                step.rawValue <= viewModel.currentStep.rawValue
                                    ? Color.brandDeepPlum
                                    : Color.brandLavender.opacity(0.3)
                            )
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                // Content — only the active step is rendered so heavy views
                // like FamilyActivityPicker don't linger in memory.
                Group {
                    switch viewModel.currentStep {
                    case .welcome:
                        WelcomeStepView(onContinue: { viewModel.advance() })
                    case .authorization:
                        AuthorizationStepView(viewModel: viewModel)
                    case .appSelection:
                        AppSelectionStepView(viewModel: viewModel)
                    case .partnerSetup:
                        PartnerSetupStepView(viewModel: viewModel)
                    case .activate:
                        ActivateStepView(viewModel: viewModel, onComplete: onComplete)
                    }
                }
                .transition(.opacity)
            }
        }
    }
}
