import SwiftUI

struct ChatBubbleView: View {
    let message: ChatViewModel.DisplayMessage

    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
            }

            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(message.isUser
                              ? AnyShapeStyle(
                                  LinearGradient(
                                      colors: [Color.brandAccent, Color.brandAccentDeep],
                                      startPoint: .topLeading,
                                      endPoint: .bottomTrailing
                                  )
                              )
                              : AnyShapeStyle(Color.brandLavender.opacity(0.25)))
                }
                .foregroundStyle(message.isUser ? .white : Color.brandDeepPlum)

            if message.isAssistant {
                Spacer(minLength: 60)
            }
        }
    }
}
