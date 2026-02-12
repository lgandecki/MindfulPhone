import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // Do not write to app-group files/defaults from this extension.
        // The managed-settings-shield-configuration sandbox rejects those writes.
        AppGroupManager.shared.appendExtensionLog(
            source: "ShieldConfig",
            message: "configuration hasName=\(application.localizedDisplayName == nil ? "NO" : "YES") hasToken=\(application.token == nil ? "NO" : "YES")",
            persistToSharedFile: false
        )

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
