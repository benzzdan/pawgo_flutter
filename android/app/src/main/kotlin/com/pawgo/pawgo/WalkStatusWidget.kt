package com.pawgo.pawgo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews

/**
 * Android Home Screen AppWidget that displays the current walk status.
 *
 * Data is pushed from Flutter via the `home_widget` plugin, which stores
 * key-value pairs in SharedPreferences. This provider reads those values
 * and updates the RemoteViews layout.
 */
class WalkStatusWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        private const val PREFS_NAME = "HomeWidgetPreferences"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs: SharedPreferences =
                context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            val walkerName = prefs.getString("walkerName", "") ?: ""
            val stage = prefs.getString("stage", "No active walk") ?: "No active walk"
            val elapsedMinutes = prefs.getInt("elapsedMinutes", 0)

            val views = RemoteViews(context.packageName, R.layout.walk_status_widget)

            if (walkerName.isNotEmpty()) {
                views.setTextViewText(R.id.widget_walker_name, walkerName)
                views.setTextViewText(R.id.widget_elapsed, "${elapsedMinutes} min")
            } else {
                views.setTextViewText(R.id.widget_walker_name, "")
                views.setTextViewText(R.id.widget_elapsed, "")
            }

            views.setTextViewText(R.id.widget_stage, stage)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
