package com.developerjamiu.screen_time_blocker.ui

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.developerjamiu.screen_time_blocker.databinding.ActivityAppPickerBinding
import com.developerjamiu.screen_time_blocker.manager.ScreenTimeManager
import com.developerjamiu.screen_time_blocker.model.AppInfo
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Activity for selecting apps to block.
 * Displays a list of installed apps with checkboxes.
 */
class AppPickerActivity : AppCompatActivity() {

    private lateinit var binding: ActivityAppPickerBinding
    private lateinit var screenTimeManager: ScreenTimeManager
    private lateinit var adapter: AppListAdapter

    private var allApps: List<AppInfo> = emptyList()
    private var filteredApps: List<AppInfo> = emptyList()

    companion object {
        const val RESULT_APPS_SELECTED = "apps_selected"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityAppPickerBinding.inflate(layoutInflater)
        setContentView(binding.root)

        screenTimeManager = ScreenTimeManager.getInstance(this)

        setupToolbar()
        setupRecyclerView()
        setupSearch()
        setupButtons()
        loadApps()
    }

    private fun setupToolbar() {
        binding.toolbar.setNavigationOnClickListener {
            setResult(Activity.RESULT_CANCELED)
            finish()
        }
    }

    private fun setupRecyclerView() {
        adapter = AppListAdapter { appInfo, isChecked ->
            appInfo.isSelected = isChecked
            updateSelectedCount()
        }

        binding.appRecyclerView.apply {
            layoutManager = LinearLayoutManager(this@AppPickerActivity)
            adapter = this@AppPickerActivity.adapter
        }
    }

    private fun setupSearch() {
        binding.searchEditText.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                filterApps(s?.toString() ?: "")
            }
        })
    }

    private fun setupButtons() {
        binding.cancelButton.setOnClickListener {
            setResult(Activity.RESULT_CANCELED)
            finish()
        }

        binding.saveButton.setOnClickListener {
            saveSelection()
        }
    }

    private fun loadApps() {
        binding.loadingProgress.visibility = View.VISIBLE
        binding.appRecyclerView.visibility = View.GONE

        lifecycleScope.launch {
            try {
                allApps = screenTimeManager.getBlockableApps()
                filteredApps = allApps

                withContext(Dispatchers.Main) {
                    binding.loadingProgress.visibility = View.GONE
                    binding.appRecyclerView.visibility = View.VISIBLE
                    adapter.submitList(filteredApps)
                    updateSelectedCount()
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    binding.loadingProgress.visibility = View.GONE
                    // Show error message
                }
            }
        }
    }

    private fun filterApps(query: String) {
        filteredApps = if (query.isEmpty()) {
            allApps
        } else {
            allApps.filter { app ->
                app.appName.contains(query, ignoreCase = true) ||
                        app.packageName.contains(query, ignoreCase = true)
            }
        }
        adapter.submitList(filteredApps)
    }

    private fun updateSelectedCount() {
        val selectedCount = allApps.count { it.isSelected }
        binding.selectedCountText.text = getString(
            com.developerjamiu.screen_time_blocker.R.string.app_picker_selected_count,
            selectedCount
        )
    }

    private fun saveSelection() {
        val selectedPackages = allApps
            .filter { it.isSelected }
            .map { it.packageName }
            .toSet()

        screenTimeManager.saveBlockedApps(selectedPackages)

        val resultIntent = Intent().apply {
            putExtra(RESULT_APPS_SELECTED, selectedPackages.size)
        }
        setResult(Activity.RESULT_OK, resultIntent)
        finish()
    }
}
