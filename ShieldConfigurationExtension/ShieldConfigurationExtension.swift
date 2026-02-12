import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // Side effect: save the token→name mapping so other parts of the system
        // can look up display names from opaque ApplicationTokens.
        // Both localizedDisplayName and token are optional — guard safely.
        if let name = application.localizedDisplayName, let token = application.token {
            AppGroupManager.shared.saveTokenName(name, for: token)
        }

        let appName = application.localizedDisplayName ?? "this app"

        return makeShieldConfiguration(
            subtitle: "Take a moment to reflect on whether you need \(appName) right now."
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(shielding: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        return makeShieldConfiguration(
            subtitle: "Take a moment before browsing."
        )
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(shielding: webDomain)
    }

    // MARK: - Shared Configuration Builder

    private func makeShieldConfiguration(subtitle: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor.systemBackground.withAlphaComponent(0.3),
            icon: UIImage(systemName: "brain.head.profile"),
            title: ShieldConfiguration.Label(
                text: "Mindful Pause",
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitle,
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Request Access",
                color: .white
            ),
            primaryButtonBackgroundColor: .systemBlue,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Not Now",
                color: .systemBlue
            )
        )
    }
}
