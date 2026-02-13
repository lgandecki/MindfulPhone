import SwiftUI
import FamilyControls

struct AppSelectionStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showingPicker = false

    private static let appLimit = 50

    private var appCount: Int {
        viewModel.allAppsSelection.applicationTokens.count
    }

    private var hasSelection: Bool { appCount > 0 }
    private var overLimit: Bool { appCount > Self.appLimit }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "apps.iphone")
                .font(.system(size: 56))
                .foregroundStyle(Color.brandSoftPlum)
                .frame(width: 88, height: 88)
                .background(Color.brandLavender.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 22))

            VStack(spacing: 12) {
                Text("Block Distracting Apps")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brandDeepPlum)

                Text("Choose the apps you find most distracting. MindfulPhone will ask you to reflect before opening them.")
                    .font(.body)
                    .foregroundStyle(Color.brandSoftPlum.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            if hasSelection {
                Text("\(appCount) app\(appCount == 1 ? "" : "s") selected")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(overLimit ? .red : Color.brandSoftPlum)
            }

            if overLimit {
                Text("iOS limits blocking to \(Self.appLimit) apps. Please reduce your selection.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                showingPicker = true
            } label: {
                Label(hasSelection ? "Edit Selection" : "Choose Apps", systemImage: hasSelection ? "pencil.circle" : "plus.circle")
                    .font(.headline)
                    .foregroundStyle(Color.brandSoftPlum)
            }
            .familyActivityPicker(
                isPresented: $showingPicker,
                selection: $viewModel.allAppsSelection
            )

            Spacer()

            Button {
                viewModel.advance()
            } label: {
                Text("Continue")
            }
            .buttonStyle(BrandButtonStyle(isDisabled: !hasSelection || overLimit))
            .disabled(!hasSelection || overLimit)
            .padding(.horizontal, 24)
        }
        .padding(24)
    }
}
