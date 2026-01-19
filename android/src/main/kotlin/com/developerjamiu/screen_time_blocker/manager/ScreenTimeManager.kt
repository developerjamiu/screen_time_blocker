package com.developerjamiu.screen_time_blocker.manager

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityManager
import com.developerjamiu.screen_time_blocker.model.AppInfo
import com.developerjamiu.screen_time_blocker.service.AppBlockerAccessibilityService
import com.developerjamiu.screen_time_blocker.ui.AppPickerActivity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Central manager for Screen Time blocking functionality.
 * Coordinates between permissions, app selection, and blocking services.
 */
class ScreenTimeManager(private val context: Context) {

    private val prefsManager: PreferencesManager = PreferencesManager.getInstance(context)
    private val scheduleManager: ScheduleManager = ScheduleManager.getInstance(context)

    companion object {
        private const val TAG = "ScreenTimeManager"

        const val REQUEST_CODE_APP_PICKER = 2001
        const val REQUEST_CODE_ACCESSIBILITY = 2002
        const val REQUEST_CODE_OVERLAY = 2003
        const val REQUEST_CODE_BATTERY = 2004

        @Volatile
        private var instance: ScreenTimeManager? = null

        fun getInstance(context: Context): ScreenTimeManager {
            return instance ?: synchronized(this) {
                instance ?: ScreenTimeManager(context.applicationContext).also { instance = it }
            }
        }
    }

    // ============== Authorization ==============

    /**
     * Check if all required permissions are granted.
     * On Android, this means accessibility service is enabled.
     */
    fun getAuthorizationStatus(): String {
        return if (isAccessibilityServiceEnabled()) {
            prefsManager.setAuthorizationStatus("approved")
            "approved"
        } else {
            val savedStatus = prefsManager.getAuthorizationStatus()
            if (savedStatus == "approved") {
                // Was approved but accessibility is now off
                "denied"
            } else {
                savedStatus
            }
        }
    }

    /**
     * Request authorization by opening accessibility settings.
     * Returns true if already authorized.
     */
    fun requestAuthorization(activity: Activity): Boolean {
        if (isAccessibilityServiceEnabled()) {
            prefsManager.setAuthorizationStatus("approved")
            return true
        }

        // Open accessibility settings
        openAccessibilitySettings(activity)
        prefsManager.setAuthorizationStatus("notDetermined")
        return false
    }

    /**
     * Check if the accessibility service is enabled.
     */
    fun isAccessibilityServiceEnabled(): Boolean {
        val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)

        val serviceName = "${context.packageName}/${AppBlockerAccessibilityService::class.java.canonicalName}"

        return enabledServices.any { serviceInfo ->
            serviceInfo.resolveInfo.serviceInfo.let { info ->
                "${info.packageName}/${info.name}" == serviceName
            }
        }
    }

    /**
     * Open accessibility settings.
     */
    fun openAccessibilitySettings(activity: Activity) {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        activity.startActivityForResult(intent, REQUEST_CODE_ACCESSIBILITY)
    }

    /**
     * Check if overlay permission is granted.
     */
    fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    /**
     * Request overlay permission.
     */
    fun requestOverlayPermission(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${context.packageName}")
            )
            activity.startActivityForResult(intent, REQUEST_CODE_OVERLAY)
        }
    }

    /**
     * Check if battery optimization is disabled for this app.
     */
    fun isBatteryOptimizationDisabled(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            return pm.isIgnoringBatteryOptimizations(context.packageName)
        }
        return true
    }

    /**
     * Request to disable battery optimization.
     */
    fun requestDisableBatteryOptimization(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${context.packageName}")
            }
            activity.startActivityForResult(intent, REQUEST_CODE_BATTERY)
        }
    }

    // ============== App Selection ==============

    /**
     * Open the app picker activity.
     */
    fun openAppPicker(activity: Activity) {
        val intent = Intent(activity, AppPickerActivity::class.java)
        activity.startActivityForResult(intent, REQUEST_CODE_APP_PICKER)
    }

    /**
     * Get list of installed apps that can be blocked.
     * Filters out system apps and the blocking app itself.
     */
    suspend fun getBlockableApps(): List<AppInfo> = withContext(Dispatchers.IO) {
        val pm = context.packageManager
        val blockedApps = prefsManager.getBlockedApps()

        val installedApps = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.getInstalledApplications(0)
        }

        installedApps
            .filter { appInfo ->
                // Filter criteria:
                // 1. Has a launcher intent (is a launchable app)
                // 2. Not our own app
                // 3. Not a system app (unless updated)
                val launchIntent = pm.getLaunchIntentForPackage(appInfo.packageName)
                val isLaunchable = launchIntent != null
                val isNotSelf = appInfo.packageName != context.packageName
                val isUserApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) == 0 ||
                        (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0

                isLaunchable && isNotSelf && (isUserApp || isSystemAppAllowedToBlock(appInfo.packageName))
            }
            .map { appInfo ->
                AppInfo(
                    packageName = appInfo.packageName,
                    appName = pm.getApplicationLabel(appInfo).toString(),
                    icon = try {
                        pm.getApplicationIcon(appInfo.packageName)
                    } catch (e: Exception) {
                        null
                    },
                    isSelected = blockedApps.contains(appInfo.packageName)
                )
            }
            .sortedBy { it.appName.lowercase() }
    }

    /**
     * Some system apps should be blockable (like browsers, social media pre-installs).
     */
    private fun isSystemAppAllowedToBlock(packageName: String): Boolean {
        val allowedSystemApps = setOf(
            "com.android.chrome",
            "com.sec.android.app.sbrowser", // Samsung Internet
            "com.opera.browser",
            "org.mozilla.firefox",
            "com.facebook.katana",
            "com.instagram.android",
            "com.twitter.android",
            "com.zhiliaoapp.musically", // TikTok
            "com.snapchat.android",
            "com.whatsapp",
            "com.google.android.youtube"
        )
        return allowedSystemApps.contains(packageName)
    }

    /**
     * Save the selected apps to block.
     */
    fun saveBlockedApps(packageNames: Set<String>) {
        prefsManager.saveBlockedApps(packageNames)
        Log.d(TAG, "Saved ${packageNames.size} blocked apps")
    }

    /**
     * Get the current selection summary.
     */
    fun getSelectionSummary(): Map<String, Int> {
        return mapOf(
            "apps" to prefsManager.getBlockedAppsCount(),
            "categories" to 0, // Android doesn't support category blocking
            "websites" to 0    // Android doesn't support website blocking via this API
        )
    }

    // ============== Blocking Control ==============

    /**
     * Start a blocking schedule.
     */
    fun startSchedule(scheduleId: String, hour: Int, minute: Int): Boolean {
        return scheduleManager.startSchedule(scheduleId, hour, minute)
    }

    /**
     * Stop a specific schedule.
     */
    fun stopSchedule(scheduleId: String): Boolean {
        return scheduleManager.stopSchedule(scheduleId)
    }

    /**
     * Stop all schedules.
     */
    fun stopAllSchedules(): Boolean {
        return scheduleManager.stopAllSchedules()
    }

    /**
     * Temporarily unblock apps until the next schedule.
     */
    fun unblockUntilNextSchedule(): Boolean {
        prefsManager.setTemporarilyUnblocked(true)
        Log.d(TAG, "Apps temporarily unblocked")
        return true
    }

    /**
     * Block apps immediately.
     */
    fun blockNow(): Boolean {
        prefsManager.setBlockingActive(true)
        prefsManager.setTemporarilyUnblocked(false)
        Log.d(TAG, "Blocking activated immediately")
        return true
    }

    /**
     * Check if an app should currently be blocked.
     */
    fun shouldBlockApp(packageName: String): Boolean {
        // Check if blocking is active
        if (!prefsManager.shouldBlockApps()) {
            return false
        }

        // Check if this specific app is in the blocked list
        if (!prefsManager.isAppBlocked(packageName)) {
            return false
        }

        // Check if any schedule is currently active
        return scheduleManager.shouldCurrentlyBlock() || prefsManager.isBlockingActive()
    }

    /**
     * Get the app name for a package.
     */
    fun getAppName(packageName: String): String {
        return try {
            val pm = context.packageManager
            val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getApplicationInfo(packageName, PackageManager.ApplicationInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                pm.getApplicationInfo(packageName, 0)
            }
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }
}
