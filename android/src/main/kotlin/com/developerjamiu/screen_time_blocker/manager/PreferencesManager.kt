package com.developerjamiu.screen_time_blocker.manager

import android.content.Context
import android.content.SharedPreferences
import com.developerjamiu.screen_time_blocker.model.BlockingSchedule
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

/**
 * Manages persistent storage for the Screen Time Blocker plugin.
 * Stores blocked apps, schedules, and blocking state.
 */
class PreferencesManager(context: Context) {

    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val gson = Gson()

    companion object {
        private const val PREFS_NAME = "screen_time_blocker_prefs"

        // Keys
        private const val KEY_BLOCKED_APPS = "blocked_apps"
        private const val KEY_SCHEDULES = "schedules"
        private const val KEY_IS_BLOCKING_ACTIVE = "is_blocking_active"
        private const val KEY_IS_TEMPORARILY_UNBLOCKED = "is_temporarily_unblocked"
        private const val KEY_AUTHORIZATION_STATUS = "authorization_status"

        @Volatile
        private var instance: PreferencesManager? = null

        fun getInstance(context: Context): PreferencesManager {
            return instance ?: synchronized(this) {
                instance ?: PreferencesManager(context.applicationContext).also { instance = it }
            }
        }
    }

    // ============== Blocked Apps ==============

    /**
     * Save the list of blocked app package names.
     */
    fun saveBlockedApps(packageNames: Set<String>) {
        prefs.edit()
            .putStringSet(KEY_BLOCKED_APPS, packageNames)
            .apply()
    }

    /**
     * Get the list of blocked app package names.
     */
    fun getBlockedApps(): Set<String> {
        return prefs.getStringSet(KEY_BLOCKED_APPS, emptySet()) ?: emptySet()
    }

    /**
     * Add a single app to the blocked list.
     */
    fun addBlockedApp(packageName: String) {
        val current = getBlockedApps().toMutableSet()
        current.add(packageName)
        saveBlockedApps(current)
    }

    /**
     * Remove a single app from the blocked list.
     */
    fun removeBlockedApp(packageName: String) {
        val current = getBlockedApps().toMutableSet()
        current.remove(packageName)
        saveBlockedApps(current)
    }

    /**
     * Check if an app is in the blocked list.
     */
    fun isAppBlocked(packageName: String): Boolean {
        return getBlockedApps().contains(packageName)
    }

    /**
     * Clear all blocked apps.
     */
    fun clearBlockedApps() {
        prefs.edit()
            .remove(KEY_BLOCKED_APPS)
            .apply()
    }

    // ============== Schedules ==============

    /**
     * Save a blocking schedule.
     */
    fun saveSchedule(schedule: BlockingSchedule) {
        val schedules = getSchedules().toMutableMap()
        schedules[schedule.id] = schedule
        saveAllSchedules(schedules)
    }

    /**
     * Get a specific schedule by ID.
     */
    fun getSchedule(scheduleId: String): BlockingSchedule? {
        return getSchedules()[scheduleId]
    }

    /**
     * Get all schedules.
     */
    fun getSchedules(): Map<String, BlockingSchedule> {
        val json = prefs.getString(KEY_SCHEDULES, null) ?: return emptyMap()
        return try {
            val type = object : TypeToken<Map<String, BlockingSchedule>>() {}.type
            gson.fromJson(json, type) ?: emptyMap()
        } catch (e: Exception) {
            emptyMap()
        }
    }

    /**
     * Save all schedules.
     */
    private fun saveAllSchedules(schedules: Map<String, BlockingSchedule>) {
        val json = gson.toJson(schedules)
        prefs.edit()
            .putString(KEY_SCHEDULES, json)
            .apply()
    }

    /**
     * Remove a specific schedule.
     */
    fun removeSchedule(scheduleId: String) {
        val schedules = getSchedules().toMutableMap()
        schedules.remove(scheduleId)
        saveAllSchedules(schedules)
    }

    /**
     * Clear all schedules.
     */
    fun clearAllSchedules() {
        prefs.edit()
            .remove(KEY_SCHEDULES)
            .apply()
    }

    // ============== Blocking State ==============

    /**
     * Set whether blocking is currently active.
     */
    fun setBlockingActive(active: Boolean) {
        prefs.edit()
            .putBoolean(KEY_IS_BLOCKING_ACTIVE, active)
            .apply()
    }

    /**
     * Check if blocking is currently active.
     */
    fun isBlockingActive(): Boolean {
        return prefs.getBoolean(KEY_IS_BLOCKING_ACTIVE, false)
    }

    /**
     * Set whether apps are temporarily unblocked.
     */
    fun setTemporarilyUnblocked(unblocked: Boolean) {
        prefs.edit()
            .putBoolean(KEY_IS_TEMPORARILY_UNBLOCKED, unblocked)
            .apply()
    }

    /**
     * Check if apps are temporarily unblocked.
     */
    fun isTemporarilyUnblocked(): Boolean {
        return prefs.getBoolean(KEY_IS_TEMPORARILY_UNBLOCKED, false)
    }

    // ============== Authorization ==============

    /**
     * Save the authorization status.
     * @param status One of: "notDetermined", "approved", "denied"
     */
    fun setAuthorizationStatus(status: String) {
        prefs.edit()
            .putString(KEY_AUTHORIZATION_STATUS, status)
            .apply()
    }

    /**
     * Get the current authorization status.
     */
    fun getAuthorizationStatus(): String {
        return prefs.getString(KEY_AUTHORIZATION_STATUS, "notDetermined") ?: "notDetermined"
    }

    // ============== Utilities ==============

    /**
     * Clear all stored data.
     */
    fun clearAll() {
        prefs.edit().clear().apply()
    }

    /**
     * Check if the user should be actively blocking apps right now.
     * This considers both the blocking state and temporary unblock.
     */
    fun shouldBlockApps(): Boolean {
        return isBlockingActive() && !isTemporarilyUnblocked()
    }

    /**
     * Get count of blocked apps (for selection summary).
     */
    fun getBlockedAppsCount(): Int {
        return getBlockedApps().size
    }
}
