package com.example.habit_tracker

import android.app.NotificationManager
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class HabitToggleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val habitId = intent.getIntExtra("habit_id", -1)
        if (habitId == -1) return
        try {
            val dbFile = context.getDatabasePath("habits_v2.db")
            if (dbFile.exists()) {
                val db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READWRITE)
                val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
                db.execSQL("INSERT OR IGNORE INTO logs(habit_id, date) VALUES(?, ?)", arrayOf("$habitId", today))
                db.close()
            }
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(habitId)
            val upd = Intent(context, HabitWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                val ids = AppWidgetManager.getInstance(context)
                    .getAppWidgetIds(ComponentName(context, HabitWidgetProvider::class.java))
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(upd)
        } catch (_: Exception) {}
    }
}
