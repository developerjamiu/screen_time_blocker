package com.developerjamiu.screen_time_blocker.service

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.developerjamiu.screen_time_blocker.manager.PreferencesManager
import com.developerjamiu.screen_time_blocker.manager.ScreenTimeManager

/**
 * Accessibility Service that monitors foreground app changes and triggers blocking overlay.
 *
 * This service:
 * 1. Listens for window state changes (app switches)
 * 2. Checks if the foreground app should be blocked
 * 3. Launches the blocking overlay if needed
 */
class AppBlockerAccessibilityService : AccessibilityService() {

    private lateinit var prefsManager: PreferencesManager
    private lateinit var screenTimeManager: ScreenTimeManager

    private var lastBlockedPackage: String? = null
    private var lastBlockTime: Long = 0

    companion object {
        private const val TAG = "AppBlockerService"
        private const val BLOCK_COOLDOWN_MS = 1000L // Prevent rapid re-blocking

        // Packages that should never be blocked
        private val SYSTEM_PACKAGES = setOf(
            "com.android.systemui",
            "com.android.launcher",
            "com.android.launcher3",
            "com.google.android.apps.nexuslauncher",
            "com.sec.android.app.launcher", // Samsung
            "com.miui.home", // Xiaomi
            "com.huawei.android.launcher", // Huawei
            "com.oppo.launcher", // Oppo
            "com.android.settings",
            "com.google.android.packageinstaller",
            "com.android.packageinstaller",
            "com.google.android.permissioncontroller"
        )

        @Volatile
        var isRunning = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        prefsManager = PreferencesManager.getInstance(this)
        screenTimeManager = ScreenTimeManager.getInstance(this)
        Log.d(TAG, "Accessibility service created")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isRunning = true

        // Configure the service
        serviceInfo = serviceInfo?.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 100
        }

        Log.d(TAG, "Accessibility service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        // Only process window state changes
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            return
        }

        val packageName = event.packageName?.toString() ?: return

        // Skip system packages and our own app
        if (shouldSkipPackage(packageName)) {
            return
        }

        // Check if we should block this app
        if (shouldBlockApp(packageName)) {
            showBlockingOverlay(packageName)
        }
    }

    /**
     * Check if a package should be skipped entirely.
     */
    private fun shouldSkipPackage(packageName: String): Boolean {
        // Skip our own app
        if (packageName == applicationContext.packageName) {
            return true
        }

        // Skip system packages
        if (SYSTEM_PACKAGES.contains(packageName)) {
            return true
        }

        // Skip blocking overlay service
        if (packageName.contains("BlockingOverlay")) {
            return true
        }

        return false
    }

    /**
     * Check if we should block this app.
     */
    private fun shouldBlockApp(packageName: String): Boolean {
        // Check cooldown to prevent rapid re-blocking
        val now = System.currentTimeMillis()
        if (packageName == lastBlockedPackage && now - lastBlockTime < BLOCK_COOLDOWN_MS) {
            return false
        }

        return screenTimeManager.shouldBlockApp(packageName)
    }

    /**
     * Check if the app has overlay permission.
     */
    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    /**
     * Show the blocking overlay for a package.
     */
    private fun showBlockingOverlay(packageName: String) {
        // Check overlay permission first
        if (!hasOverlayPermission()) {
            Log.w(TAG, "Cannot show overlay - permission not granted")
            // Instead of showing overlay, just go to home screen
            goToHome()
            return
        }

        Log.d(TAG, "Blocking app: $packageName")

        lastBlockedPackage = packageName
        lastBlockTime = System.currentTimeMillis()

        val intent = Intent(this, BlockingOverlayService::class.java).apply {
            putExtra(BlockingOverlayService.EXTRA_BLOCKED_PACKAGE, packageName)
            putExtra(BlockingOverlayService.EXTRA_APP_NAME, screenTimeManager.getAppName(packageName))
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    /**
     * Navigate to home screen when we can't show overlay.
     */
    private fun goToHome() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility service interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        Log.d(TAG, "Accessibility service destroyed")
    }

    /**
     * Clear the last blocked state (called when user dismisses overlay).
     */
    fun clearLastBlocked() {
        lastBlockedPackage = null
        lastBlockTime = 0
    }
}
