import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // Brand colors — adaptive for light/dark mode (matching Theme.swift)
    private let brandDeepPlum = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.93, green: 0.90, blue: 0.96, alpha: 1) // light text on dark
            : UIColor(red: 0.16, green: 0.11, blue: 0.24, alpha: 1) // #2A1B3D
    }
    private let brandSoftPlum = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.70, green: 0.62, blue: 0.82, alpha: 1) // #B39ED1
            : UIColor(red: 0.29, green: 0.20, blue: 0.38, alpha: 1) // #4A3460
    }
    private let brandWarmCream = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.06, blue: 0.12, alpha: 1) // #140F1E
            : UIColor(red: 0.99, green: 0.96, blue: 0.94, alpha: 1) // #FDF6F0
    }
    private let brandLavender = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.42, green: 0.36, blue: 0.52, alpha: 1) // #6B5C85
            : UIColor(red: 0.72, green: 0.66, blue: 0.79, alpha: 1) // #B8A9C9
    }

    // Non-swapping accent for button backgrounds — stays plum in both modes
    private let brandAccentDeep = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.25, green: 0.17, blue: 0.38, alpha: 1) // #402B60
            : UIColor(red: 0.16, green: 0.11, blue: 0.24, alpha: 1) // #2A1B3D
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let appName = application.localizedDisplayName ?? "this app"

        // Decide whether to show "Always Allow" secondary button
        let showAlwaysAllow: Bool
        if let displayName = application.localizedDisplayName,
           AddictiveApps.isBlacklisted(displayName) {
            // Known addictive app — no quick exempt
            showAlwaysAllow = false
        } else if let token = application.token,
                  AppGroupManager.shared.getTokenName(for: token) != nil {
            // User already went through chat for this app (chose not to exempt)
            showAlwaysAllow = false
        } else {
            // First encounter, not blacklisted — offer quick exempt
            showAlwaysAllow = true
        }

        let icon = UIImage(named: "MascotIcon")

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: brandWarmCream,
            icon: icon,
            title: ShieldConfiguration.Label(
                text: "\(appName) is blocked",
                color: brandDeepPlum
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Take a moment to reflect on whether you need this app right now.",
                color: brandSoftPlum
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Request Access",
                color: .white
            ),
            primaryButtonBackgroundColor: brandAccentDeep,
            secondaryButtonLabel: showAlwaysAllow
                ? ShieldConfiguration.Label(text: "Always Allow", color: brandLavender)
                : nil
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(shielding: application)
    }
}
