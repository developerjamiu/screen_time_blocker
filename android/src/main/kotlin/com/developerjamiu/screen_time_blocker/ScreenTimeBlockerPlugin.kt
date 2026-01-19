package com.developerjamiu.screen_time_blocker

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Base64
import android.util.Log
import com.developerjamiu.screen_time_blocker.manager.PreferencesManager
import com.developerjamiu.screen_time_blocker.manager.ScheduleManager
import com.developerjamiu.screen_time_blocker.manager.ScreenTimeManager
import com.developerjamiu.screen_time_blocker.ui.AppPickerActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.io.ByteArrayOutputStream

/**
 * ScreenTimeBlockerPlugin - Flutter plugin for Android app blocking.
 *
 * This plugin provides:
 * - Authorization management (accessibility service)
 * - App selection via native picker or Flutter-based picker
 * - Schedule-based app blocking
 * - Immediate block/unblock functionality
 */
class ScreenTimeBlockerPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var pendingResult: Result? = null

    private lateinit var screenTimeManager: ScreenTimeManager
    private lateinit var prefsManager: PreferencesManager
    private lateinit var scheduleManager: ScheduleManager

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    companion object {
        private const val TAG = "ScreenTimeBlockerPlugin"
        private const val CHANNEL_NAME = "com.developerjamiu.screen_time_blocker"
    }

    // ============== FlutterPlugin ==============

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)

        // Initialize managers
        screenTimeManager = ScreenTimeManager.getInstance(context)
        prefsManager = PreferencesManager.getInstance(context)
        scheduleManager = ScheduleManager.getInstance(context)

        Log.d(TAG, "Plugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
        Log.d(TAG, "Plugin detached from engine")
    }

    // ============== ActivityAware ==============

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
        Log.d(TAG, "Attached to activity")
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // ============== MethodCallHandler ==============

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d(TAG, "Method called: ${call.method}")

        when (call.method) {
            "requestAuthorization" -> handleRequestAuthorization(result)
            "getAuthorizationStatus" -> handleGetAuthorizationStatus(result)
            "requestOverlayPermission" -> handleRequestOverlayPermission(result)
            "hasOverlayPermission" -> handleHasOverlayPermission(result)
            "selectApps" -> handleSelectApps(result)
            "getSelectionSummary" -> handleGetSelectionSummary(result)
            "getInstalledApps" -> handleGetInstalledApps(result)
            "setSelectedApps" -> handleSetSelectedApps(call, result)
            "startSchedule" -> handleStartSchedule(call, result)
            "stopSchedule" -> handleStopSchedule(call, result)
            "stopAllSchedules" -> handleStopAllSchedules(result)
            "unblockUntilNextSchedule" -> handleUnblockUntilNextSchedule(result)
            "blockNow" -> handleBlockNow(result)
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            else -> result.notImplemented()
        }
    }

    // ============== Authorization ==============

    private fun handleRequestAuthorization(result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "No activity available", null)
            return
        }

        // Check if already authorized
        if (screenTimeManager.isAccessibilityServiceEnabled()) {
            prefsManager.setAuthorizationStatus("approved")
            result.success(true)
            return
        }

        // Open accessibility settings
        screenTimeManager.openAccessibilitySettings(currentActivity)

        // Note: We return false immediately because we can't know if user enabled it
        // The app should check authorization status when it resumes
        result.success(false)
    }

    private fun handleGetAuthorizationStatus(result: Result) {
        val status = screenTimeManager.getAuthorizationStatus()
        result.success(status)
    }

    private fun handleRequestOverlayPermission(result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "No activity available", null)
            return
        }

        if (screenTimeManager.hasOverlayPermission()) {
            result.success(true)
            return
        }

        screenTimeManager.requestOverlayPermission(currentActivity)
        result.success(false)
    }

    private fun handleHasOverlayPermission(result: Result) {
        result.success(screenTimeManager.hasOverlayPermission())
    }

    // ============== App Selection ==============

    private fun handleSelectApps(result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "No activity available", null)
            return
        }

        pendingResult = result
        screenTimeManager.openAppPicker(currentActivity)
    }

    private fun handleGetSelectionSummary(result: Result) {
        val summary = screenTimeManager.getSelectionSummary()
        result.success(summary)
    }

    private fun handleGetInstalledApps(result: Result) {
        scope.launch {
            try {
                val apps = screenTimeManager.getBlockableApps()
                val appsList = apps.map { appInfo ->
                    mapOf(
                        "packageName" to appInfo.packageName,
                        "appName" to appInfo.appName,
                        "isSelected" to appInfo.isSelected,
                        "icon" to (appInfo.icon?.let { drawableToBase64(it) } ?: "")
                    )
                }
                result.success(appsList)
            } catch (e: Exception) {
                Log.e(TAG, "Error getting installed apps", e)
                result.error("GET_APPS_ERROR", e.message, null)
            }
        }
    }

    private fun handleSetSelectedApps(call: MethodCall, result: Result) {
        val packageNames = call.argument<List<String>>("packageNames")
        if (packageNames == null) {
            result.error("INVALID_ARGUMENTS", "packageNames is required", null)
            return
        }

        screenTimeManager.saveBlockedApps(packageNames.toSet())
        result.success(true)
    }

    private fun drawableToBase64(drawable: Drawable): String {
        val bitmap = drawableToBitmap(drawable)
        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
        val byteArray = outputStream.toByteArray()
        return Base64.encodeToString(byteArray, Base64.NO_WRAP)
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable) {
            if (drawable.bitmap != null) {
                return drawable.bitmap
            }
        }

        val bitmap = if (drawable.intrinsicWidth <= 0 || drawable.intrinsicHeight <= 0) {
            Bitmap.createBitmap(48, 48, Bitmap.Config.ARGB_8888)
        } else {
            Bitmap.createBitmap(
                drawable.intrinsicWidth.coerceAtMost(96),
                drawable.intrinsicHeight.coerceAtMost(96),
                Bitmap.Config.ARGB_8888
            )
        }

        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    // ============== Schedule Management ==============

    private fun handleStartSchedule(call: MethodCall, result: Result) {
        val scheduleId = call.argument<String>("scheduleId")
        val hour = call.argument<Int>("hour")
        val minute = call.argument<Int>("minute")

        if (scheduleId == null || hour == null || minute == null) {
            result.error("INVALID_ARGUMENTS", "scheduleId, hour, and minute are required", null)
            return
        }

        if (hour < 0 || hour > 23) {
            result.error("INVALID_ARGUMENTS", "hour must be between 0 and 23", null)
            return
        }

        if (minute < 0 || minute > 59) {
            result.error("INVALID_ARGUMENTS", "minute must be between 0 and 59", null)
            return
        }

        val success = screenTimeManager.startSchedule(scheduleId, hour, minute)
        result.success(success)
    }

    private fun handleStopSchedule(call: MethodCall, result: Result) {
        val scheduleId = call.argument<String>("scheduleId")

        if (scheduleId == null) {
            result.error("INVALID_ARGUMENTS", "scheduleId is required", null)
            return
        }

        val success = screenTimeManager.stopSchedule(scheduleId)
        result.success(success)
    }

    private fun handleStopAllSchedules(result: Result) {
        val success = screenTimeManager.stopAllSchedules()
        result.success(success)
    }

    // ============== Blocking Control ==============

    private fun handleUnblockUntilNextSchedule(result: Result) {
        val success = screenTimeManager.unblockUntilNextSchedule()
        result.success(success)
    }

    private fun handleBlockNow(result: Result) {
        val success = screenTimeManager.blockNow()
        result.success(success)
    }

    // ============== Activity Result ==============

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        Log.d(TAG, "Activity result: requestCode=$requestCode, resultCode=$resultCode")

        when (requestCode) {
            ScreenTimeManager.REQUEST_CODE_APP_PICKER -> {
                // App picker closed, return the selection summary
                val summary = screenTimeManager.getSelectionSummary()
                pendingResult?.success(summary)
                pendingResult = null
                return true
            }
            ScreenTimeManager.REQUEST_CODE_ACCESSIBILITY -> {
                // Accessibility settings closed, check if enabled
                val isEnabled = screenTimeManager.isAccessibilityServiceEnabled()
                if (isEnabled) {
                    prefsManager.setAuthorizationStatus("approved")
                }
                // We already returned from requestAuthorization, so just log
                Log.d(TAG, "Accessibility service enabled: $isEnabled")
                return true
            }
            ScreenTimeManager.REQUEST_CODE_OVERLAY -> {
                val hasPermission = screenTimeManager.hasOverlayPermission()
                Log.d(TAG, "Overlay permission granted: $hasPermission")
                return true
            }
            ScreenTimeManager.REQUEST_CODE_BATTERY -> {
                val isDisabled = screenTimeManager.isBatteryOptimizationDisabled()
                Log.d(TAG, "Battery optimization disabled: $isDisabled")
                return true
            }
        }

        return false
    }
}
