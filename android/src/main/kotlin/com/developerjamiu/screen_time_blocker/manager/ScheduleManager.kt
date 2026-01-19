package com.developerjamiu.screen_time_blocker.manager

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.developerjamiu.screen_time_blocker.model.BlockingSchedule
import com.developerjamiu.screen_time_blocker.receiver.ScheduleAlarmReceiver
import java.util.Calendar

/**
 * Manages blocking schedules using AlarmManager for precise timing.
 */
class ScheduleManager(private val context: Context) {

    private val alarmManager: AlarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val prefsManager: PreferencesManager = PreferencesManager.getInstance(context)

    companion object {
        private const val TAG = "ScheduleManager"
        private const val REQUEST_CODE_BASE = 1000

        const val ACTION_START_BLOCKING = "com.developerjamiu.screen_time_blocker.ACTION_START_BLOCKING"
        const val ACTION_STOP_BLOCKING = "com.developerjamiu.screen_time_blocker.ACTION_STOP_BLOCKING"
        const val EXTRA_SCHEDULE_ID = "schedule_id"

        @Volatile
        private var instance: ScheduleManager? = null

        fun getInstance(context: Context): ScheduleManager {
            return instance ?: synchronized(this) {
                instance ?: ScheduleManager(context.applicationContext).also { instance = it }
            }
        }
    }

    /**
     * Start a new blocking schedule.
     * @param scheduleId Unique identifier for this schedule
     * @param hour Hour to start blocking (0-23)
     * @param minute Minute to start blocking (0-59)
     * @return true if schedule was set successfully
     */
    fun startSchedule(scheduleId: String, hour: Int, minute: Int): Boolean {
        return try {
            // Create and save the schedule
            val schedule = BlockingSchedule(
                id = scheduleId,
                hour = hour,
                minute = minute,
                isActive = true
            )
            prefsManager.saveSchedule(schedule)

            // Set up the alarm
            setAlarmForSchedule(schedule)

            // Check if we should start blocking immediately
            if (schedule.isCurrentlyInBlockingPeriod()) {
                prefsManager.setBlockingActive(true)
                prefsManager.setTemporarilyUnblocked(false)
            }

            Log.d(TAG, "Schedule started: $scheduleId at $hour:$minute")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start schedule: ${e.message}")
            false
        }
    }

    /**
     * Stop a specific schedule.
     */
    fun stopSchedule(scheduleId: String): Boolean {
        return try {
            // Cancel the alarm
            cancelAlarmForSchedule(scheduleId)

            // Remove from storage
            prefsManager.removeSchedule(scheduleId)

            // If no more active schedules, disable blocking
            if (prefsManager.getSchedules().isEmpty()) {
                prefsManager.setBlockingActive(false)
            }

            Log.d(TAG, "Schedule stopped: $scheduleId")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop schedule: ${e.message}")
            false
        }
    }

    /**
     * Stop all schedules and disable blocking.
     */
    fun stopAllSchedules(): Boolean {
        return try {
            // Cancel all alarms
            prefsManager.getSchedules().keys.forEach { scheduleId ->
                cancelAlarmForSchedule(scheduleId)
            }

            // Clear all schedules
            prefsManager.clearAllSchedules()

            // Disable blocking
            prefsManager.setBlockingActive(false)
            prefsManager.setTemporarilyUnblocked(false)

            Log.d(TAG, "All schedules stopped")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop all schedules: ${e.message}")
            false
        }
    }

    /**
     * Set up an alarm for a schedule.
     */
    private fun setAlarmForSchedule(schedule: BlockingSchedule) {
        val intent = Intent(context, ScheduleAlarmReceiver::class.java).apply {
            action = ACTION_START_BLOCKING
            putExtra(EXTRA_SCHEDULE_ID, schedule.id)
        }

        val requestCode = getRequestCodeForSchedule(schedule.id)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Calculate the trigger time for today or tomorrow
        val triggerTime = calculateNextTriggerTime(schedule.hour, schedule.minute)

        // Set repeating alarm (daily)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerTime,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                triggerTime,
                pendingIntent
            )
        }

        Log.d(TAG, "Alarm set for schedule ${schedule.id} at ${schedule.getFormattedStartTime()}")
    }

    /**
     * Cancel the alarm for a specific schedule.
     */
    private fun cancelAlarmForSchedule(scheduleId: String) {
        val intent = Intent(context, ScheduleAlarmReceiver::class.java).apply {
            action = ACTION_START_BLOCKING
            putExtra(EXTRA_SCHEDULE_ID, scheduleId)
        }

        val requestCode = getRequestCodeForSchedule(scheduleId)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        alarmManager.cancel(pendingIntent)
        Log.d(TAG, "Alarm cancelled for schedule $scheduleId")
    }

    /**
     * Calculate the next trigger time for a given hour and minute.
     * If the time has already passed today, schedule for tomorrow.
     */
    private fun calculateNextTriggerTime(hour: Int, minute: Int): Long {
        val now = Calendar.getInstance()
        val trigger = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        // If the time has passed today, schedule for tomorrow
        if (trigger.before(now) || trigger == now) {
            trigger.add(Calendar.DAY_OF_YEAR, 1)
        }

        return trigger.timeInMillis
    }

    /**
     * Generate a unique request code for a schedule.
     */
    private fun getRequestCodeForSchedule(scheduleId: String): Int {
        return REQUEST_CODE_BASE + scheduleId.hashCode().and(0xFFFF)
    }

    /**
     * Called when a schedule alarm fires.
     */
    fun onScheduleAlarmFired(scheduleId: String) {
        Log.d(TAG, "Schedule alarm fired: $scheduleId")

        val schedule = prefsManager.getSchedule(scheduleId)
        if (schedule != null && schedule.isActive) {
            // Enable blocking
            prefsManager.setBlockingActive(true)
            prefsManager.setTemporarilyUnblocked(false)

            // Re-schedule for tomorrow
            setAlarmForSchedule(schedule)
        }
    }

    /**
     * Check if any schedule should currently be blocking.
     */
    fun shouldCurrentlyBlock(): Boolean {
        if (prefsManager.isTemporarilyUnblocked()) {
            return false
        }

        return prefsManager.getSchedules().values.any { schedule ->
            schedule.isActive && schedule.isCurrentlyInBlockingPeriod()
        }
    }

    /**
     * Re-initialize all alarms (called after boot).
     */
    fun reinitializeAlarms() {
        prefsManager.getSchedules().values.forEach { schedule ->
            if (schedule.isActive) {
                setAlarmForSchedule(schedule)
            }
        }
        Log.d(TAG, "All alarms reinitialized")
    }
}
