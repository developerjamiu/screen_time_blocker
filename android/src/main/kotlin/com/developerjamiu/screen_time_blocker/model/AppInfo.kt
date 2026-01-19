package com.developerjamiu.screen_time_blocker.model

import android.graphics.drawable.Drawable

/**
 * Represents an installed app with its metadata.
 */
data class AppInfo(
    val packageName: String,
    val appName: String,
    val icon: Drawable?,
    var isSelected: Boolean = false
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as AppInfo
        return packageName == other.packageName
    }

    override fun hashCode(): Int {
        return packageName.hashCode()
    }
}
