package com.example.habit_tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class HabitWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { id ->
            val opts = appWidgetManager.getAppWidgetOptions(id)
            render(context, appWidgetManager, id, widgetData, opts)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        render(context, appWidgetManager, appWidgetId, prefs, newOptions)
    }

    private fun render(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        data: SharedPreferences,
        options: Bundle
    ) {
        val minW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110)
        val minH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
        val isTiny = minW < 105 && minH < 105
        val isLarge = minW >= 220 && minH >= 200

        val views = RemoteViews(context.packageName, R.layout.habit_widget).apply {
            val count = data.getString("widget_count", "0/0") ?: "0/0"
            val rawList = data.getString("widget_list", "") ?: ""
            val lines = rawList.split("\n").filter { it.isNotEmpty() }

            setTextViewText(R.id.widget_count, count)
            setTextViewTextSize(
                R.id.widget_count,
                TypedValue.COMPLEX_UNIT_SP,
                if (isTiny) 18f else if (isLarge) 34f else 24f
            )
            setViewVisibility(R.id.widget_title, if (isTiny) View.GONE else View.VISIBLE)
            setTextViewTextSize(R.id.widget_title, TypedValue.COMPLEX_UNIT_SP, if (isLarge) 15f else 11f)

            if (isTiny || lines.isEmpty()) {
                setViewVisibility(R.id.widget_list, View.GONE)
            } else {
                setViewVisibility(R.id.widget_list, View.VISIBLE)
                val maxItems = if (isLarge) 8 else if (minH >= 150) 4 else 2
                setTextViewText(R.id.widget_list, lines.take(maxItems).joinToString("\n"))
                setTextViewTextSize(R.id.widget_list, TypedValue.COMPLEX_UNIT_SP, if (isLarge) 16f else 12f)
            }

            val pi = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            setOnClickPendingIntent(R.id.widget_root, pi)
        }
        manager.updateAppWidget(widgetId, views)
    }
}
