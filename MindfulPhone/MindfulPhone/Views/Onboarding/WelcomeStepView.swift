import SwiftUI

struct WelcomeStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image("AppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: Color.brandDeepPlum.opacity(0.15), radius: 20, y: 10)

            VStack(spacing: 8) {
                Text("MindfulPhone")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brandDeepPlum)

                Text("Be intentional about every app you open.")
                    .font(.title3)
                    .foregroundStyle(Color.brandSoftPlum.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "sparkles",
                    title: "A conversation, not a countdown",
                    description: "Tell Claude AI why you need an app. Good reasons get instant access."
                )
                FeatureRow(
                    icon: "brain.head.profile",
                    title: "Context-aware decisions",
                    description: "Claude considers the time of day, your history, and your intent."
                )
                FeatureRow(
                    icon: "clock.arrow.circlepath",
                    title: "Smart time limits",
                    description: "Duration fits the task — 5 min for a quick check, an hour for real work."
                )
            }
            .padding(.horizontal, 8)

            Spacer()

            Button(action: onContinue) {
                Text("Get Started")
            }
            .buttonStyle(BrandButtonStyle())
            .padding(.horizontal, 24)
        }
        .padding(24)
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.brandSoftPlum)
                .frame(width: 32, height: 32)
                .background(Color.brandLavender.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.brandDeepPlum)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.brandSoftPlum.opacity(0.6))
            }
        }
    }
}
