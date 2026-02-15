import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let showOfflineOption: Bool
    let onSend: () -> Void
    let onOfflineUnlock: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if showOfflineOption {
                Button("Unlock Offline (15 min)") {
                    onOfflineUnlock()
                }
                .font(.footnote)
                .foregroundStyle(Color.brandGoldenGlow)
            }

            HStack(spacing: 12) {
                TextField("Explain your reason...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.brandLavender.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.brandLavender.opacity(0.25), lineWidth: 1)
                    )

                Button {
                    onSend()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.brandSoftPlum)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.brandWarmCream.opacity(0.95))
    }
}
