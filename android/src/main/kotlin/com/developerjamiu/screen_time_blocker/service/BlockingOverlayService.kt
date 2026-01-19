package com.developerjamiu.screen_time_blocker.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import androidx.core.app.NotificationCompat
import com.developerjamiu.screen_time_blocker.R

/**
 * Service that displays the blocking overlay when a blocked app is opened.
 * This is a foreground service to ensure it stays running.
 */
class BlockingOverlayService : Service() {

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var isOverlayShowing = false

    companion object {
        private const val TAG = "BlockingOverlayService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "blocking_overlay_channel"

        const val EXTRA_BLOCKED_PACKAGE = "blocked_package"
        const val EXTRA_APP_NAME = "app_name"
        const val ACTION_DISMISS = "com.developerjamiu.screen_time_blocker.DISMISS_OVERLAY"
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        Log.d(TAG, "Blocking overlay service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_DISMISS -> {
                hideOverlay()
                stopSelf()
                return START_NOT_STICKY
            }
        }

        val blockedPackage = intent?.getStringExtra(EXTRA_BLOCKED_PACKAGE)
        val appName = intent?.getStringExtra(EXTRA_APP_NAME) ?: blockedPackage ?: "App"

        // Start as foreground service
        startForeground(NOTIFICATION_ID, createNotification(appName))

        // Show the overlay
        showOverlay(appName, blockedPackage)

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /**
     * Create the notification channel for Android O+.
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                getString(R.string.notification_channel_name),
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = getString(R.string.notification_channel_description)
                setShowBadge(false)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * Create the foreground service notification.
     */
    private fun createNotification(appName: String): Notification {
        val dismissIntent = Intent(this, BlockingOverlayService::class.java).apply {
            action = ACTION_DISMISS
        }
        val dismissPendingIntent = PendingIntent.getService(
            this,
            0,
            dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.blocking_title))
            .setContentText("$appName is blocked")
            .setSmallIcon(R.drawable.ic_lock)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .addAction(R.drawable.ic_close, "Dismiss", dismissPendingIntent)
            .build()
    }

    /**
     * Show the blocking overlay.
     */
    private fun showOverlay(appName: String, blockedPackage: String?) {
        if (isOverlayShowing) {
            updateOverlay(appName)
            return
        }

        try {
            val layoutParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER
            }

            val inflater = getSystemService(LAYOUT_INFLATER_SERVICE) as LayoutInflater
            overlayView = inflater.inflate(R.layout.overlay_blocking, null)

            // Set up the UI
            overlayView?.apply {
                findViewById<TextView>(R.id.blockedAppName)?.text = appName

                findViewById<Button>(R.id.closeButton)?.setOnClickListener {
                    goToHome()
                    hideOverlay()
                    stopSelf()
                }

                findViewById<Button>(R.id.openAppButton)?.setOnClickListener {
                    openMainApp()
                    hideOverlay()
                    stopSelf()
                }
            }

            windowManager?.addView(overlayView, layoutParams)
            isOverlayShowing = true

            Log.d(TAG, "Blocking overlay shown for: $appName")

        } catch (e: Exception) {
            Log.e(TAG, "Failed to show overlay: ${e.message}")
        }
    }

    /**
     * Update the overlay with new app info.
     */
    private fun updateOverlay(appName: String) {
        overlayView?.findViewById<TextView>(R.id.blockedAppName)?.text = appName
    }

    /**
     * Hide the blocking overlay.
     */
    private fun hideOverlay() {
        try {
            if (overlayView != null && isOverlayShowing) {
                windowManager?.removeView(overlayView)
                overlayView = null
                isOverlayShowing = false
                Log.d(TAG, "Blocking overlay hidden")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to hide overlay: ${e.message}")
        }
    }

    /**
     * Go to home screen.
     */
    private fun goToHome() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
    }

    /**
     * Open the main Flutter app.
     */
    private fun openMainApp() {
        // Get the main activity from the host app
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        if (launchIntent != null) {
            launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            startActivity(launchIntent)
        } else {
            goToHome()
        }
    }

    override fun onDestroy() {
        hideOverlay()
        super.onDestroy()
        Log.d(TAG, "Blocking overlay service destroyed")
    }
}
