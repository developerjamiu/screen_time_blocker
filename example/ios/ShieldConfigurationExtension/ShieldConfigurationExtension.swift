import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        return createShieldConfiguration(for: application.localizedDisplayName)
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        return createShieldConfiguration(for: application.localizedDisplayName)
    }
    
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        return createShieldConfiguration(for: webDomain.domain)
    }
    
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        return createShieldConfiguration(for: webDomain.domain)
    }
    
    private func createShieldConfiguration(for itemName: String?) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundColor: UIColor.systemBackground,
            
            icon: UIImage(systemName: "lock.fill"),
            
            title: ShieldConfiguration.Label(
                text: "App Blocked",
                color: .label
            ),
            
            subtitle: ShieldConfiguration.Label(
                text: "Complete your daily task to unlock \(itemName ?? "this app").",
                color: .secondaryLabel
            ),
            
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Open App",
                color: .white
            ),
            primaryButtonBackgroundColor: .systemBlue,
            
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Close",
                color: .systemBlue
            )
        )
    }
}
