import SwiftUI
import UIKit

// MARK: - Brand Colors (Adaptive Light/Dark)

extension Color {
    static let brandLavender = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.42, green: 0.36, blue: 0.52, alpha: 1) // #6B5C85 — dimmed on dark
            : UIColor(red: 0.72, green: 0.66, blue: 0.79, alpha: 1) // #B8A9C9
    })

    static let brandPeach = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.55, green: 0.37, blue: 0.24, alpha: 1) // #8C5E3D — muted on dark
            : UIColor(red: 0.96, green: 0.76, blue: 0.63, alpha: 1) // #F4C1A0
    })

    static let brandDeepPlum = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.93, green: 0.90, blue: 0.96, alpha: 1) // #EDE6F5 — light text on dark
            : UIColor(red: 0.16, green: 0.11, blue: 0.24, alpha: 1) // #2A1B3D
    })

    static let brandSoftPlum = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.70, green: 0.62, blue: 0.82, alpha: 1) // #B39ED1 — readable on dark
            : UIColor(red: 0.29, green: 0.20, blue: 0.38, alpha: 1) // #4A3460
    })

    static let brandWarmCream = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.06, blue: 0.12, alpha: 1) // #140F1E — very dark plum bg
            : UIColor(red: 0.99, green: 0.96, blue: 0.94, alpha: 1) // #FDF6F0
    })

    static let brandGoldenGlow = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.83, green: 0.66, blue: 0.29, alpha: 1) // #D4A84A — richer gold
            : UIColor(red: 0.91, green: 0.78, blue: 0.48, alpha: 1) // #E8C87A
    })

    /// Card/surface background — white in light, slightly elevated dark plum in dark.
    static let brandCardBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.09, blue: 0.19, alpha: 1) // #1E1730
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)   // #FFFFFF
    })

    /// Plum accent for buttons, user bubbles, decorative fills — stays plum in both modes.
    /// Slightly brighter on dark backgrounds so it pops.
    static let brandAccent = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.38, green: 0.28, blue: 0.52, alpha: 1) // #604785
            : UIColor(red: 0.29, green: 0.20, blue: 0.38, alpha: 1) // #4A3460
    })

    static let brandAccentDeep = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.25, green: 0.17, blue: 0.38, alpha: 1) // #402B60
            : UIColor(red: 0.16, green: 0.11, blue: 0.24, alpha: 1) // #2A1B3D
    })
}

// MARK: - Brand Gradient Background

struct BrandGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [Color.brandLavender.opacity(0.15), Color.brandPeach.opacity(0.08), Color.brandWarmCream],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [Color.brandLavender.opacity(0.5), Color.brandPeach.opacity(0.4), Color.brandWarmCream],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
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
                    colors: [Color.brandAccent, Color.brandAccentDeep],
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
            .background(Color.brandAccent.opacity(0.12))
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
