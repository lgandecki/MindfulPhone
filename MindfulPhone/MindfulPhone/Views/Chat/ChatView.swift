import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ChatViewModel()
    @Namespace private var bottomID

    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(message: message)
                        }

                        if viewModel.isLoading {
                            typingIndicator
                        }

                        if viewModel.isApproved {
                            approvalBanner
                        }

                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .background(Color.brandWarmCream.opacity(0.5))
                .onChange(of: viewModel.messages.count) {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.isLoading) {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            // Input
            if !viewModel.isApproved {
                ChatInputView(
                    text: $viewModel.inputText,
                    isLoading: viewModel.isLoading,
                    showOfflineOption: viewModel.showOfflineOption,
                    onSend: { viewModel.sendMessage() },
                    onOfflineUnlock: { viewModel.offlineUnlock() }
                )
            }
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
        }
    }

    // MARK: - Subviews

    private var chatHeader: some View {
        VStack(spacing: 4) {
            if !viewModel.appName.isEmpty {
                Text("Unlock Request")
                    .font(.subheadline)
                    .foregroundStyle(Color.brandSoftPlum.opacity(0.7))
                Text(viewModel.appName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.brandDeepPlum)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.brandWarmCream.opacity(0.95))
    }

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.brandLavender)
                    .frame(width: 8, height: 8)
                    .opacity(0.4)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: viewModel.isLoading
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.brandLavender.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var approvalBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.brandSoftPlum)

            Text("Unlocked for \(viewModel.approvedMinutes ?? 0) minutes")
                .font(.headline)
                .foregroundStyle(Color.brandDeepPlum)

            Text("Switch to \(viewModel.appName) to use it now.")
                .font(.subheadline)
                .foregroundStyle(Color.brandSoftPlum.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.brandLavender.opacity(0.15), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.brandLavender.opacity(0.3), lineWidth: 1)
        )
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
