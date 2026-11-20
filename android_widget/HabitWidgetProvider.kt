package com.example.habit_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.database.sqlite.SQLiteDatabase
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class HabitWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { id ->
            render(context, appWidgetManager, id, widgetData, appWidgetManager.getAppWidgetOptions(id))
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
        val is4x2 = minW >= 220

        var done = data.getInt("widget_done", 0)
        var total = data.getInt("widget_total", 0)
        val items = mutableListOf<Triple<Int, Boolean, String>>()

        try {
            val dbFile = context.getDatabasePath("habits_v2.db")
            if (dbFile.exists()) {
                val db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)
                val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
                val doneIds = mutableSetOf<Int>()
                db.rawQuery("SELECT habit_id FROM logs WHERE date = ?", arrayOf(today)).use { c ->
                    while (c.moveToNext()) doneIds.add(c.getInt(0))
                }
                total = 0
                done = 0
                db.rawQuery("SELECT id, title FROM habits ORDER BY id DESC", null).use { c ->
                    while (c.moveToNext()) {
                        val id = c.getInt(0)
                        val title = c.getString(1)
                        val isDone = doneIds.contains(id)
                        total++
                        if (isDone) done++
                        if (items.size < 4) items.add(Triple(id, isDone, title))
                    }
                }
                db.close()
            }
        } catch (_: Exception) {}

        val pct = if (total == 0) 0 else (done * 100) / total
        val views = RemoteViews(context.packageName, R.layout.habit_widget).apply {
            setTextViewText(R.id.widget_count, "$done/$total")
            setProgressBar(R.id.widget_ring, 100, pct, false)
            setViewVisibility(R.id.widget_daily, if (is1x1) View.GONE else View.VISIBLE)
            setTextViewText(R.id.widget_daily, "Daily $pct%")
            setViewVisibility(R.id.widget_list_col, if (is4x2 && items.isNotEmpty()) View.VISIBLE else View.GONE)

            val rowIds = intArrayOf(R.id.widget_item_0, R.id.widget_item_1, R.id.widget_item_2, R.id.widget_item_3)
            for (i in 0 until 4) {
                if (i < items.size && is4x2) {
                    val (hid, isDone, title) = items[i]
                    setViewVisibility(rowIds[i], View.VISIBLE)
                    setTextViewText(rowIds[i], "${if (isDone) "✓" else "○"}  $title")
                    val toggleIntent = Intent(context, HabitToggleReceiver::class.java).apply {
                        putExtra("habit_id", hid)
                    }
                    val pi = PendingIntent.getBroadcast(
                        context,
                        hid,
                        toggleIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    setOnClickPendingIntent(rowIds[i], pi)
                } else {
                    setViewVisibility(rowIds[i], View.GONE)
                }
            }

            val openPi = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            setOnClickPendingIntent(R.id.widget_ring_col, openPi)
        }
        manager.updateAppWidget(widgetId, views)
    }
}
