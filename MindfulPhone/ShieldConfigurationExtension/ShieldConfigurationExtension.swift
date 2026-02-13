import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // Brand colors (matching Theme.swift)
    private let brandDeepPlum = UIColor(red: 0.16, green: 0.11, blue: 0.24, alpha: 1)
    private let brandSoftPlum = UIColor(red: 0.29, green: 0.20, blue: 0.38, alpha: 1)
    private let brandWarmCream = UIColor(red: 0.99, green: 0.96, blue: 0.94, alpha: 1)
    private let brandLavender = UIColor(red: 0.72, green: 0.66, blue: 0.79, alpha: 1)

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
                text: "Take a moment to reflect on whether you need \(appName) right now.",
                color: brandSoftPlum
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Request Access",
                color: .white
            ),
            primaryButtonBackgroundColor: brandDeepPlum,
            secondaryButtonLabel: showAlwaysAllow
                ? ShieldConfiguration.Label(text: "Always Allow", color: brandLavender)
                : nil
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(shielding: application)
    }
}
