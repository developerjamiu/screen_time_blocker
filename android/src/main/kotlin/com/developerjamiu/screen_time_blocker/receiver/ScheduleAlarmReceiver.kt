package com.developerjamiu.screen_time_blocker.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.developerjamiu.screen_time_blocker.manager.ScheduleManager

/**
 * Broadcast receiver that handles schedule alarm events.
 */
class ScheduleAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ScheduleAlarmReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        val scheduleId = intent.getStringExtra(ScheduleManager.EXTRA_SCHEDULE_ID)

        Log.d(TAG, "Received alarm: action=$action, scheduleId=$scheduleId")

        when (action) {
            ScheduleManager.ACTION_START_BLOCKING -> {
                if (scheduleId != null) {
                    val scheduleManager = ScheduleManager.getInstance(context)
                    scheduleManager.onScheduleAlarmFired(scheduleId)
                }
            }
            ScheduleManager.ACTION_STOP_BLOCKING -> {
                // This could be used for automatic end-of-day stopping
                // Currently, blocking runs until 23:59 or manual stop
            }
        }
    }
}
