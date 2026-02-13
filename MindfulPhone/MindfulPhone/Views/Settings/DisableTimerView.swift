import SwiftUI

struct DisableTimerView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Image(systemName: "exclamationmark.shield")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            VStack(spacing: 12) {
                Text("Disabling Protection")
                    .font(.title)
                    .fontWeight(.bold)

                Text("You must wait before disabling. If you leave this screen, the timer resets.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Countdown
            Text(formattedTime)
                .font(.system(size: 72, weight: .light, design: .monospaced))
                .foregroundStyle(viewModel.disableTimerCompleted ? .red : .primary)

            if viewModel.disableTimerCompleted {
                Text("Your accountability partner has been notified.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                if viewModel.disableTimerCompleted {
                    Button(role: .destructive) {
                        viewModel.confirmDisable()
                    } label: {
                        Text("Confirm Disable")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }

                Button {
                    viewModel.cancelDisableTimer()
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)
        }
        .padding(24)
        .interactiveDismissDisabled()
    }

    private var formattedTime: String {
        let minutes = viewModel.disableTimeRemaining / 60
        let seconds = viewModel.disableTimeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
