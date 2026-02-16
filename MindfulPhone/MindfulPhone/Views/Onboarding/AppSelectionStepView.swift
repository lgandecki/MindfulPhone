import SwiftUI
import FamilyControls

struct AppSelectionStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showingPicker = false
    @State private var cachedAppCount = 0
    @State private var isSaving = false

    private static let appLimit = 50

    private var hasSelection: Bool { cachedAppCount > 0 }
    private var overLimit: Bool { cachedAppCount > Self.appLimit }

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
                Text("\(cachedAppCount) app\(cachedAppCount == 1 ? "" : "s") selected")
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

            if isSaving {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Color.brandSoftPlum)
                    Text("Saving selection…")
                        .font(.subheadline)
                        .foregroundStyle(Color.brandSoftPlum.opacity(0.7))
                }
            } else {
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
            }

            Spacer()

            Button {
                guard !isSaving else { return }
                isSaving = true
                // Pre-cache the selection data on a background thread,
                // then advance. This keeps the spinner visible while
                // iOS serializes the FamilyActivitySelection.
                let selection = viewModel.allAppsSelection
                Task.detached {
                    // Force the token serialization off the main thread
                    let data = try? JSONEncoder().encode(selection)
                    await MainActor.run {
                        if let data {
                            AppGroupManager.shared.saveAllAppsSelection(data)
                        }
                        viewModel.advance()
                    }
                }
            } label: {
                Text("Continue")
            }
            .buttonStyle(BrandButtonStyle(isDisabled: !hasSelection || overLimit || isSaving))
            .disabled(!hasSelection || overLimit || isSaving)
            .padding(.horizontal, 24)
        }
        .padding(24)
        .onChange(of: showingPicker) {
            if !showingPicker {
                Task.detached {
                    let count = await MainActor.run {
                        viewModel.allAppsSelection.applicationTokens.count
                    }
                    await MainActor.run {
                        cachedAppCount = count
                    }
                }
            }
        }
    }
}
