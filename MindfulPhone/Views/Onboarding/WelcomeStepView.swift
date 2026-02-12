import SwiftUI

struct WelcomeStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            VStack(spacing: 12) {
                Text("MindfulPhone")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Be intentional about every app you open.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "lock.shield",
                    title: "Everything blocked by default",
                    description: "All apps start shielded until you explain your intent."
                )
                FeatureRow(
                    icon: "bubble.left.and.text.bubble.right",
                    title: "AI-powered intentionality check",
                    description: "Tell Claude why you need an app. Good reasons get instant access."
                )
                FeatureRow(
                    icon: "timer",
                    title: "Smart time limits",
                    description: "Claude sets a duration based on your task. No rigid timers."
                )
            }
            .padding(.horizontal, 8)

            Spacer()

            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
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
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
