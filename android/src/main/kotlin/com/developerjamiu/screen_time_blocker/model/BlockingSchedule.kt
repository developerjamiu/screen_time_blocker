package com.developerjamiu.screen_time_blocker.model

/**
 * Represents a blocking schedule with start time.
 * Blocking continues from start time until 23:59 or until manually stopped.
 */
data class BlockingSchedule(
    val id: String,
    val hour: Int,
    val minute: Int,
    val isActive: Boolean = true,
    val createdAt: Long = System.currentTimeMillis()
) {
    /**
     * Get the start time as minutes since midnight.
     */
    fun getStartTimeMinutes(): Int {
        return hour * 60 + minute
    }

    /**
     * Check if the current time is within the blocking period.
     * Blocking runs from start time until 23:59.
     */
    fun isCurrentlyInBlockingPeriod(): Boolean {
        if (!isActive) return false

        val now = java.util.Calendar.getInstance()
        val currentHour = now.get(java.util.Calendar.HOUR_OF_DAY)
        val currentMinute = now.get(java.util.Calendar.MINUTE)
        val currentTimeMinutes = currentHour * 60 + currentMinute
        val startTimeMinutes = getStartTimeMinutes()

        // Blocking from start time until 23:59
        return currentTimeMinutes >= startTimeMinutes
    }

    /**
     * Format the start time as HH:MM string.
     */
    fun getFormattedStartTime(): String {
        return String.format("%02d:%02d", hour, minute)
    }
}
