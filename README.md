# Screen Time Blocker

A Flutter plugin for blocking apps using iOS Screen Time API (Family Controls, ManagedSettings, DeviceActivity).

## Platform Support

| Platform | Status       | Minimum Version |
| -------- | ------------ | --------------- |
| iOS      | ✅ Supported | iOS 16.0+       |
| Android  | 🚧 Planned   | -               |
| macOS    | ❌           | -               |
| Web      | ❌           | -               |
| Windows  | ❌           | -               |
| Linux    | ❌           | -               |

## Features

- ✅ Request Screen Time authorization
- ✅ Native Family Activity Picker for selecting apps/categories
- ✅ Multiple simultaneous blocking schedules
- ✅ Immediate blocking without schedule
- ✅ Temporary unblock functionality
- ✅ Persistent selection across app restarts

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  screen_time_blocker:
    path: ../screen_time_blocker # or publish to pub.dev
```

## iOS Setup (Required)

This plugin requires significant iOS configuration. Follow each step carefully.

### 1. Apple Developer Account Requirements

You need a **paid Apple Developer account** with the **Family Controls** capability enabled.

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list)
2. Select your App ID (or create one)
3. Enable **Family Controls** capability
4. Regenerate your provisioning profiles

### 2. Update Minimum iOS Version

In `ios/Podfile`, set the minimum iOS version:

```ruby
platform :ios, '16.0'
```

### 3. Configure App Groups

The plugin uses App Groups to share data between your app and the extensions.

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Runner** project → **Runner** target
3. Go to **Signing & Capabilities**
4. Click **+ Capability** → Add **App Groups**
5. Create a new App Group: `group.<your.bundle.identifier>`
   - Example: `group.com.yourcompany.yourapp`

### 4. Add Family Controls Capability

1. Still in **Signing & Capabilities**
2. Click **+ Capability** → Add **Family Controls**

### 5. Create App Extensions

You must create three app extensions. For each extension:

#### 5a. Device Activity Monitor Extension

1. **File → New → Target...**
2. Search for **Device Activity Monitor Extension**
3. Name: `DeviceActivityMonitor`
4. Bundle ID: `<your.bundle.identifier>.DeviceActivityMonitor`
5. Click **Finish** → **Don't Activate**

Replace the generated Swift file with:

```swift
import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    let store = ManagedSettingsStore()
    // ⚠️ UPDATE THIS to match your App Group
    let appGroupId = "group.com.yourcompany.yourapp"
    let selectionKey = "FamilyActivitySelection"

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard let selection = loadSelection() else { return }

        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    private func loadSelection() -> FamilyActivitySelection? {
        guard let userDefaults = UserDefaults(suiteName: appGroupId),
              let savedData = userDefaults.data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: savedData)
        else { return nil }
        return selection
    }
}
```

**Required:** Update `appGroupId` to match your App Group.

Configure entitlements:

- Add **Family Controls** capability
- Add **App Groups** with same group ID

---

#### 5b. Shield Configuration Extension

This extension controls the appearance of the block screen. **Customize it to match your app's branding.**

1. **File → New → Target...**
2. Search for **Shield Configuration Extension**
3. Name: `ShieldConfiguration`
4. Bundle ID: `<your.bundle.identifier>.ShieldConfiguration`

Replace the generated Swift file with:

```swift
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
        // ⚠️ CUSTOMIZE these values to match your app
        return ShieldConfiguration(
            backgroundColor: .systemBackground,
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(
                text: "App Blocked",
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Complete your task to unlock \(itemName ?? "this app").",
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Go to App",
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
```

**Customization options:**
| Property | Description |
| ----------------------------- | ------------------------------------------------------------- |
| `backgroundColor` | Background color of the shield screen |
| `icon` | SF Symbol or custom UIImage |
| `title` | Main heading text and color |
| `subtitle` | Secondary text (use `{appName}` placeholder via `itemName`) |
| `primaryButtonLabel` | Primary action button text |
| `primaryButtonBackgroundColor`| Primary button background |
| `secondaryButtonLabel` | Secondary button text (set to `nil` to hide) |

Configure entitlements:

- Add **Family Controls** capability
- Add **App Groups** with same group ID

---

#### 5c. Shield Action Extension

This extension handles user interactions with the shield screen buttons.

1. **File → New → Target...**
2. Search for **Shield Action Extension**
3. Name: `ShieldAction`
4. Bundle ID: `<your.bundle.identifier>.ShieldAction`

Replace the generated Swift file with:

```swift
import ManagedSettings

class ShieldActionExtension: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            // User tapped primary button - close shield and let them try again
            completionHandler(.close)
        case .secondaryButtonPressed:
            // User tapped secondary button - defer (keep shield visible)
            completionHandler(.defer)
        @unknown default:
            completionHandler(.close)
        }
    }
}
```

**Response options:**
| Response | Description |
| -------- | ----------- |
| `.close` | Dismisses the shield screen |
| `.defer` | Keeps the shield visible |

**Advanced:** To open your app when the button is pressed, you can post a local notification from this extension that deep-links to your app.

Configure entitlements:

- Add **Family Controls** capability
- Add **App Groups** with same group ID

---

### 6. Fix Build Phase Order

After adding extensions, you may encounter a build cycle error. To fix:

1. Select **Runner** target → **Build Phases**
2. Drag **Embed Foundation Extensions** above **Thin Binary** and **[CP] Embed Pods Frameworks**

### 7. Update App Group in Plugin

The plugin auto-derives the App Group from your bundle ID using this pattern:

```
group.<first-three-segments-of-bundle-id>
```

For example:

- Bundle ID: `com.yourcompany.yourapp` → App Group: `group.com.yourcompany.yourapp`
- Bundle ID: `com.yourcompany.yourapp.dev` → App Group: `group.com.yourcompany.yourapp`

Ensure your App Group matches this pattern, or the plugin won't be able to share data with extensions.

## Usage

### Basic Example

```dart
import 'package:screen_time_blocker/screen_time_blocker.dart';

final blocker = ScreenTimeBlocker();

// Check if platform is supported
if (!blocker.isSupported) {
  print('Screen Time not supported on this platform');
  return;
}

// Request authorization
final granted = await blocker.requestAuthorization();
if (!granted) {
  print('Authorization denied');
  return;
}

// Let user select apps to block
final selection = await blocker.selectAppsToBlock();
print('Selected ${selection.total} items');

// Start multiple blocking schedules
await blocker.startSchedule(scheduleId: 'morning', hour: 9, minute: 0);
await blocker.startSchedule(scheduleId: 'afternoon', hour: 14, minute: 0);
await blocker.startSchedule(scheduleId: 'evening', hour: 20, minute: 0);

// When user completes their task, unblock for today
await blocker.unblockForToday();

// Stop a specific schedule
await blocker.stopSchedule('morning');

// Stop all schedules
await blocker.stopAllSchedules();
```

### Immediate Blocking

```dart
// Block apps immediately without waiting for schedule
await blocker.blockNow();

// Unblock for the rest of today
await blocker.unblockForToday();
```

### API Reference

#### `ScreenTimeBlocker`

| Method                                    | Description                                     |
| ----------------------------------------- | ----------------------------------------------- |
| `isSupported`                             | Returns `true` if platform supports Screen Time |
| `requestAuthorization()`                  | Requests Family Controls permission             |
| `getAuthorizationStatus()`                | Returns current authorization status            |
| `selectAppsToBlock()`                     | Opens native picker, returns selection summary  |
| `getSelectionSummary()`                   | Gets current selection without opening picker   |
| `startSchedule(scheduleId, hour, minute)` | Starts a named daily blocking schedule          |
| `stopSchedule(scheduleId)`                | Stops a specific schedule by ID                 |
| `stopAllSchedules()`                      | Stops all schedules and removes all blocks      |
| `unblockForToday()`                       | Temporarily unblocks until next scheduled time  |
| `blockNow()`                              | Blocks selected apps immediately                |

#### `AuthorizationStatus`

```dart
enum AuthorizationStatus {
  notDetermined,  // User hasn't been asked yet
  approved,       // User granted permission
  denied,         // User denied permission
}
```

#### `SelectionSummary`

```dart
class SelectionSummary {
  final int apps;        // Individual apps selected
  final int categories;  // App categories selected
  final int webDomains;  // Web domains selected

  int get total;         // Total items selected
  bool get isEmpty;
  bool get isNotEmpty;
}
```

## Troubleshooting

### "Authorization failed"

- Ensure Family Controls capability is enabled in Apple Developer Portal
- Regenerate provisioning profiles after enabling the capability

### "Apps don't block"

- Verify App Group ID matches across main app and all extensions
- Check that DeviceActivityMonitor extension is properly signed
- Ensure extensions have Family Controls entitlement

### "Shield screen doesn't appear"

- Verify ShieldConfiguration extension is included in the build
- Check extension's bundle ID is correct

### "Selection not persisted"

- App Group mismatch between main app and extensions
- Check console logs for App Group errors

### Build cycle error

- Reorder Build Phases as described in setup step 6

### Only one schedule works

- Each schedule needs a unique `scheduleId`
- Use descriptive IDs like `'morning'`, `'afternoon'`, `'evening'`

## License

MIT License - see LICENSE file
