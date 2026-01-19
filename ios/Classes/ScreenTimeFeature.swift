import Flutter
import FamilyControls
import ManagedSettings
import DeviceActivity
import SwiftUI

@available(iOS 16.0, *)
public class ScreenTimeFeature: NSObject {
    
    // MARK: - Constants
    
    private let selectionKey = "FamilyActivitySelection"
    private let scheduleIdsKey = "SavedScheduleIds"
    
    // MARK: - Properties

    private var appGroupId: String
    private let store = ManagedSettingsStore()
    private let center = DeviceActivityCenter()

    public var currentSelection = FamilyActivitySelection() {
        didSet { saveSelection() }
    }
    
    // MARK: - Initialization
    
    public init(messenger: FlutterBinaryMessenger) {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.example.app"
        let baseBundleId = bundleId.components(separatedBy: ".").prefix(3).joined(separator: ".")
        self.appGroupId = "group.\(baseBundleId)"
        
        super.init()
        
        loadSelection()
        
#if DEBUG
        print("📱 ScreenTimeBlocker: Initialized with App Group: \(appGroupId)")
#endif
    }
    
    // MARK: - Method Channel Handler
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestAuthorization": requestAuthorization(result: result)
        case "getAuthorizationStatus": getAuthorizationStatus(result: result)
        case "selectApps": showFamilyActivityPicker(result: result)
        case "getSelectionSummary": result(getSelectionSummary())
        case "startSchedule": handleStartSchedule(call: call, result: result)
        case "stopSchedule": handleStopSchedule(call: call, result: result)
        case "stopAllSchedules": stopAllSchedules(result: result)
        case "unblockUntilNextSchedule": unblockUntilNextSchedule(result: result)
        case "blockNow": blockNow(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Authorization
    
    private func requestAuthorization(result: @escaping FlutterResult) {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                await MainActor.run { result(true) }
            } catch {
                print("❌ ScreenTimeBlocker: Authorization failed: \(error)")
                await MainActor.run { result(false) }
            }
        }
    }
    
    private func getAuthorizationStatus(result: @escaping FlutterResult) {
        let status = AuthorizationCenter.shared.authorizationStatus

        // If current selection is empty, try reloading from UserDefaults
        // This handles cases where the selection wasn't loaded on init
        // (e.g., due to UserDefaults sync timing on cold launch)
        if currentSelection.applicationTokens.isEmpty &&
           currentSelection.categoryTokens.isEmpty &&
           currentSelection.webDomainTokens.isEmpty {
            loadSelection()
        }

        // Workaround: If status seems wrong but we have a saved selection,
        // the user must have approved in the past
        let hasSelection = !currentSelection.applicationTokens.isEmpty ||
                          !currentSelection.categoryTokens.isEmpty ||
                          !currentSelection.webDomainTokens.isEmpty

        if status != .approved && hasSelection {
#if DEBUG
            print("⚠️ ScreenTimeBlocker: AuthorizationCenter reports '\(status)' but we have saved selection - returning approved")
#endif
            result("approved")
            return
        }

        switch status {
        case .approved: result("approved")
        case .denied: result("denied")
        case .notDetermined: result("notDetermined")
        @unknown default:
            result("notDetermined")
        }
    }
    
    // MARK: - App Selection
    
    private func showFamilyActivityPicker(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                result(FlutterError(code: "INTERNAL_ERROR", message: "Self deallocated", details: nil))
                return
            }
            
            guard let topVC = self.getTopViewController() else {
                result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Could not find top view controller", details: nil))
                return
            }
            
            let binding = Binding(
                get: { self.currentSelection },
                set: { self.currentSelection = $0 }
            )
            
            let pickerView = FamilyActivityPickerView(selection: binding) {
                topVC.dismiss(animated: false)
                result(self.getSelectionSummary())
            }
            
            let host = UIHostingController(rootView: pickerView)
            host.modalPresentationStyle = .overFullScreen
            host.view.backgroundColor = .clear
            
            topVC.present(host, animated: false)
        }
    }
    
    private func getSelectionSummary() -> [String: Int] {
        return [
            "apps": currentSelection.applicationTokens.count,
            "categories": currentSelection.categoryTokens.count,
            "websites": currentSelection.webDomainTokens.count
        ]
    }
    
    
    // MARK: - Schedule Management
    
    private func handleStartSchedule(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let scheduleId = args["scheduleId"] as? String,
              let hour = args["hour"] as? Int,
              let minute = args["minute"] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "scheduleId, hour and minute are required", details: nil))
            return
        }
        
        startSchedule(scheduleId: scheduleId, hour: hour, minute: minute, result: result)
    }
    
    private func handleStopSchedule(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let scheduleId = args["scheduleId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "scheduleId is required", details: nil))
            return
        }
        
        stopSchedule(scheduleId: scheduleId, result: result)
    }
    
    private func startSchedule(scheduleId: String, hour: Int, minute: Int, result: @escaping FlutterResult) {
        let activityName = DeviceActivityName(rawValue: scheduleId)
        
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: hour, minute: minute),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        
        do {
            try center.startMonitoring(activityName, during: schedule)
            saveScheduleId(scheduleId)
            
#if DEBUG
            print("✅ ScreenTimeBlocker: Started schedule '\(scheduleId)' at \(hour):\(minute)")
#endif
            
            result(true)
        } catch {
            print("❌ ScreenTimeBlocker: Failed to start schedule: \(error)")
            result(false)
        }
    }
    
    private func stopSchedule(scheduleId: String, result: @escaping FlutterResult) {
        let activityName = DeviceActivityName(rawValue: scheduleId)
        center.stopMonitoring([activityName])
        removeScheduleId(scheduleId)
        
#if DEBUG
        print("✅ ScreenTimeBlocker: Stopped schedule '\(scheduleId)'")
#endif
        
        result(true)
    }
    
    private func stopAllSchedules(result: @escaping FlutterResult) {
        for scheduleId in getSavedScheduleIds() {
            let activityName = DeviceActivityName(rawValue: scheduleId)
            center.stopMonitoring([activityName])
        }
        
        clearShields()
        clearAllScheduleIds()
        
#if DEBUG
        print("✅ ScreenTimeBlocker: Stopped all schedules")
#endif
        
        result(true)
    }
    
    private func unblockUntilNextSchedule(result: @escaping FlutterResult) {
        clearShields()

#if DEBUG
        print("🔓 ScreenTimeBlocker: Apps unblocked until next schedule")
#endif

        result(true)
    }
    
    private func blockNow(result: @escaping FlutterResult) {
        applyShields()
        
#if DEBUG
        print("🔒 ScreenTimeBlocker: Apps blocked immediately")
#endif
        
        result(true)
    }
    
    // MARK: - Shield Management
    
    private func applyShields() {
        store.shield.applications = currentSelection.applicationTokens
        store.shield.applicationCategories = .specific(currentSelection.categoryTokens)
        store.shield.webDomains = currentSelection.webDomainTokens
    }
    
    private func clearShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }
    
    // MARK: - Selection Persistence
    
    private func saveSelection() {
        guard let userDefaults = UserDefaults(suiteName: appGroupId) else {
            print("❌ ScreenTimeBlocker: Cannot access App Group: \(appGroupId)")
            return
        }

        do {
            let encoded = try JSONEncoder().encode(currentSelection)
            userDefaults.set(encoded, forKey: selectionKey)

#if DEBUG
            print("✅ ScreenTimeBlocker: Selection saved")
#endif
        } catch {
            print("❌ ScreenTimeBlocker: Failed to encode selection: \(error)")
        }
    }

    private func loadSelection() {
        guard let userDefaults = UserDefaults(suiteName: appGroupId),
              let savedData = userDefaults.data(forKey: selectionKey) else {
            return
        }

        do {
            currentSelection = try JSONDecoder().decode(FamilyActivitySelection.self, from: savedData)

#if DEBUG
            print("✅ ScreenTimeBlocker: Selection loaded")
#endif
        } catch {
            print("❌ ScreenTimeBlocker: Failed to decode selection: \(error)")
        }
    }
    
    // MARK: - Schedule ID Persistence
    
    private func saveScheduleId(_ scheduleId: String) {
        guard let userDefaults = UserDefaults(suiteName: appGroupId) else { return }
        var ids = userDefaults.stringArray(forKey: scheduleIdsKey) ?? []
        if !ids.contains(scheduleId) {
            ids.append(scheduleId)
            userDefaults.set(ids, forKey: scheduleIdsKey)
        }
    }
    
    private func removeScheduleId(_ scheduleId: String) {
        guard let userDefaults = UserDefaults(suiteName: appGroupId) else { return }
        var ids = userDefaults.stringArray(forKey: scheduleIdsKey) ?? []
        ids.removeAll { $0 == scheduleId }
        userDefaults.set(ids, forKey: scheduleIdsKey)
    }
    
    private func getSavedScheduleIds() -> [String] {
        guard let userDefaults = UserDefaults(suiteName: appGroupId) else { return [] }
        return userDefaults.stringArray(forKey: scheduleIdsKey) ?? []
    }
    
    private func clearAllScheduleIds() {
        guard let userDefaults = UserDefaults(suiteName: appGroupId) else { return }
        userDefaults.removeObject(forKey: scheduleIdsKey)
    }
    
    // MARK: - Utilities
    
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            return nil
        }
        
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
    }
}
