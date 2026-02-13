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
                .foregroundStyle(.orange)
            }

            HStack(spacing: 12) {
                TextField("Explain your reason...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

                Button {
                    onSend()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.blue)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
