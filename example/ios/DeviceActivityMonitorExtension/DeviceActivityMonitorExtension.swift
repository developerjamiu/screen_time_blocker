import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    
    let store = ManagedSettingsStore()
    let appGroupId = "group.com.developerjamiu.screenTimeBlockerExample"
    let selectionKey = "FamilyActivitySelection"
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        print("⏰ ScreenTimeBlocker: Interval started - blocking apps")
        
        guard let selection = loadSelection() else {
            print("❌ ScreenTimeBlocker: No apps selected to block")
            return
        }
        
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        
        print("⏰ ScreenTimeBlocker: Interval ended - unblocking apps")
        
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }
    
    private func loadSelection() -> FamilyActivitySelection? {
        guard let userDefaults = UserDefaults(suiteName: appGroupId),
              let savedData = userDefaults.data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: savedData)
        else {
            return nil
        }
        return selection
    }
}
