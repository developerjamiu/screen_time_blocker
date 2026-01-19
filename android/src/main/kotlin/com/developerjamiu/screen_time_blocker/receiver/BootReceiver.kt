package com.developerjamiu.screen_time_blocker.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.developerjamiu.screen_time_blocker.manager.ScheduleManager

/**
 * Broadcast receiver that reinitializes alarms when the device boots.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
            intent.action == "com.htc.intent.action.QUICKBOOT_POWERON"
        ) {
            Log.d(TAG, "Boot completed, reinitializing alarms")

            // Reinitialize all schedule alarms
            val scheduleManager = ScheduleManager.getInstance(context)
            scheduleManager.reinitializeAlarms()
        }
    }
}
