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
        val is1x1 = minW < 115 && minH < 115
        val isWide = minW >= 210
        val isTall = minH >= 150

        val views = RemoteViews(context.packageName, R.layout.habit_widget).apply {
            val count = data.getString("widget_count", "0/0") ?: "0/0"
            val dPct = data.getString("widget_daily", "0%") ?: "0%"
            val wPct = data.getString("widget_weekly", "0%") ?: "0%"
            val mPct = data.getString("widget_monthly", "0%") ?: "0%"

            setTextViewText(R.id.widget_count, count)
            setTextViewTextSize(
                R.id.widget_count,
                TypedValue.COMPLEX_UNIT_SP,
                if (is1x1) 18f else if (isWide && isTall) 32f else 24f
            )

            setViewVisibility(R.id.widget_title, if (is1x1) View.GONE else View.VISIBLE)
            setTextViewTextSize(R.id.widget_title, TypedValue.COMPLEX_UNIT_SP, if (isWide) 14f else 11f)

            if (is1x1) {
                setViewVisibility(R.id.widget_stats, View.GONE)
            } else {
                setViewVisibility(R.id.widget_stats, View.VISIBLE)
                val summary = if (isWide && isTall) {
                    "Daily: $dPct\nWeekly: $wPct\nMonthly: $mPct"
                } else if (isWide) {
                    "D $dPct  ·  W $wPct  ·  M $mPct"
                } else {
                    "D $dPct · W $wPct"
                }
                setTextViewText(R.id.widget_stats, summary)
                setTextViewTextSize(
                    R.id.widget_stats,
                    TypedValue.COMPLEX_UNIT_SP,
                    if (isWide && isTall) 15f else 12f
                )
            }

            val pi = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            setOnClickPendingIntent(R.id.widget_root, pi)
        }
        manager.updateAppWidget(widgetId, views)
    }
}
