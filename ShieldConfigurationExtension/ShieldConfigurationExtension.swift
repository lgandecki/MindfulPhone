import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

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

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor.systemBackground.withAlphaComponent(0.3),
            icon: UIImage(systemName: "brain.head.profile"),
            title: ShieldConfiguration.Label(
                text: "\(appName) is blocked",
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Take a moment to reflect on whether you need \(appName) right now.",
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Request Access",
                color: .white
            ),
            primaryButtonBackgroundColor: .systemBlue,
            secondaryButtonLabel: showAlwaysAllow
                ? ShieldConfiguration.Label(text: "Always Allow", color: .systemGreen)
                : nil
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(shielding: application)
    }
}
