import SwiftUI

// MARK: - Brand Colors

extension Color {
    static let brandLavender = Color(red: 0.72, green: 0.66, blue: 0.79)    // #B8A9C9
    static let brandPeach = Color(red: 0.96, green: 0.76, blue: 0.63)       // #F4C1A0
    static let brandDeepPlum = Color(red: 0.16, green: 0.11, blue: 0.24)    // #2A1B3D
    static let brandSoftPlum = Color(red: 0.29, green: 0.20, blue: 0.38)    // #4A3460
    static let brandWarmCream = Color(red: 0.99, green: 0.96, blue: 0.94)   // #FDF6F0
    static let brandGoldenGlow = Color(red: 0.91, green: 0.78, blue: 0.48)  // #E8C87A
}

// MARK: - Brand Gradient Background

struct BrandGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.brandLavender.opacity(0.5), Color.brandPeach.opacity(0.4), Color.brandWarmCream],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Brand Button Style

struct BrandButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.brandSoftPlum, Color.brandDeepPlum],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .opacity(isDisabled ? 0.4 : (configuration.isPressed ? 0.8 : 1.0))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Brand Secondary Button Style

struct BrandSecondaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.brandSoftPlum.opacity(0.1))
            .foregroundStyle(Color.brandSoftPlum)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.brandLavender.opacity(0.4), lineWidth: 1)
            )
            .opacity(isDisabled ? 0.4 : (configuration.isPressed ? 0.7 : 1.0))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
