package com.developerjamiu.screen_time_blocker.ui

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.developerjamiu.screen_time_blocker.databinding.ItemAppBinding
import com.developerjamiu.screen_time_blocker.model.AppInfo

/**
 * RecyclerView adapter for displaying a list of apps with checkboxes.
 */
class AppListAdapter(
    private val onAppCheckedChange: (AppInfo, Boolean) -> Unit
) : ListAdapter<AppInfo, AppListAdapter.AppViewHolder>(AppDiffCallback()) {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): AppViewHolder {
        val binding = ItemAppBinding.inflate(
            LayoutInflater.from(parent.context),
            parent,
            false
        )
        return AppViewHolder(binding)
    }

    override fun onBindViewHolder(holder: AppViewHolder, position: Int) {
        holder.bind(getItem(position))
    }

    inner class AppViewHolder(
        private val binding: ItemAppBinding
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(appInfo: AppInfo) {
            binding.apply {
                appName.text = appInfo.appName

                // Set icon
                if (appInfo.icon != null) {
                    appIcon.setImageDrawable(appInfo.icon)
                } else {
                    appIcon.setImageResource(android.R.drawable.sym_def_app_icon)
                }

                // Set checkbox state without triggering listener
                appCheckbox.setOnCheckedChangeListener(null)
                appCheckbox.isChecked = appInfo.isSelected

                // Set up checkbox listener
                appCheckbox.setOnCheckedChangeListener { _, isChecked ->
                    onAppCheckedChange(appInfo, isChecked)
                }

                // Make entire row clickable
                root.setOnClickListener {
                    appCheckbox.isChecked = !appCheckbox.isChecked
                }
            }
        }
    }

    /**
     * DiffUtil callback for efficient list updates.
     */
    class AppDiffCallback : DiffUtil.ItemCallback<AppInfo>() {
        override fun areItemsTheSame(oldItem: AppInfo, newItem: AppInfo): Boolean {
            return oldItem.packageName == newItem.packageName
        }

        override fun areContentsTheSame(oldItem: AppInfo, newItem: AppInfo): Boolean {
            return oldItem.packageName == newItem.packageName &&
                    oldItem.appName == newItem.appName &&
                    oldItem.isSelected == newItem.isSelected
        }
    }
}
