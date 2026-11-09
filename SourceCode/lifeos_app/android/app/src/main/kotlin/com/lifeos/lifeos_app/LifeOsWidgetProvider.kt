package com.lifeos.lifeos_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import org.json.JSONObject

/**
 * Renders the LifeOS widget (PBI-033). The Dart side serialises a full
 * [WidgetSnapshot] — this class only lays text out and wires taps; it
 * never computes content. Guarded throughout (AC7): a bad snapshot or a
 * launcher quirk is one log line, never a crash.
 */
class LifeOsWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            try {
                appWidgetManager.updateAppWidget(
                    id,
                    render(context, appWidgetManager, id, widgetData.getString("snapshot", null)),
                )
            } catch (e: Exception) {
                Log.e(TAG, "render failed: ${e.javaClass.simpleName}")
            }
        }
    }

    /** Re-render on resize so 2×2 ↔ 4×2 swap layouts. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), HomeWidgetPlugin.getData(context))
    }

    private fun render(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        json: String?,
    ): RemoteViews {
        val minWidth =
            appWidgetManager.getAppWidgetOptions(appWidgetId)
                .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val large = minWidth >= LARGE_MIN_WIDTH_DP
        val views = RemoteViews(
            context.packageName,
            if (large) R.layout.widget_lifeos_large else R.layout.widget_lifeos_small,
        )

        val root = try {
            JSONObject(json ?: "{}")
        } catch (e: Exception) {
            JSONObject()
        }
        // After midnight the precomputed "tomorrow" variant renders, so the
        // widget is right without the app running (AC3).
        val day = root.optString("day")
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val data =
            (if (day.isNotEmpty() && today > day) root.optJSONObject("tomorrow") else null)
                ?: root.optJSONObject("today")

        if (root.optBoolean("rtl", false)) {
            views.setInt(R.id.widget_root, "setLayoutDirection", View.LAYOUT_DIRECTION_RTL)
        }

        val score = data?.optInt("score", -1) ?: -1
        setRing(views, score)
        views.setTextViewText(R.id.score_text, if (score < 0) "–" else score.toString())
        views.setTextViewText(R.id.counts_text, data?.optString("counts") ?: "")

        if (large) fillLines(context, views, data)

        // Deep links (AC4): ring → score, rows → their task, else Home.
        views.setOnClickPendingIntent(R.id.widget_root, launch(context, "lifeos://home"))
        views.setOnClickPendingIntent(R.id.ring_box, launch(context, "lifeos://score"))
        return views
    }

    private fun fillLines(context: Context, views: RemoteViews, data: JSONObject?) {
        val rows = intArrayOf(R.id.task1, R.id.task2, R.id.task3, R.id.task4)
        val tasks = data?.optJSONArray("tasks")
        for ((i, rowId) in rows.withIndex()) {
            val task = if (tasks != null && i < tasks.length()) tasks.optJSONObject(i) else null
            if (task == null) {
                views.setViewVisibility(rowId, View.GONE)
            } else {
                views.setViewVisibility(rowId, View.VISIBLE)
                views.setTextViewText(rowId, task.optString("text"))
                val taskId = task.optString("id")
                if (taskId.isNotEmpty()) {
                    views.setOnClickPendingIntent(rowId, launch(context, "lifeos://task/$taskId"))
                }
            }
        }
        setOrGone(views, R.id.more_text, data?.optString("more") ?: "")
        setOrGone(views, R.id.empty_text, data?.optString("empty") ?: "")
        setOrGone(views, R.id.payment_text, data?.optString("payment") ?: "")
        val paymentTask = data?.optString("paymentTask") ?: ""
        if (paymentTask.isNotEmpty()) {
            views.setOnClickPendingIntent(
                R.id.payment_text,
                launch(context, "lifeos://task/$paymentTask"),
            )
        }
    }

    private fun setOrGone(views: RemoteViews, id: Int, text: String) {
        if (text.isEmpty()) {
            views.setViewVisibility(id, View.GONE)
        } else {
            views.setViewVisibility(id, View.VISIBLE)
            views.setTextViewText(id, text)
        }
    }

    /** Red < 40, amber 40–69, green ≥ 70 — same as Tokens.scoreColor. */
    private fun setRing(views: RemoteViews, score: Int) {
        val shown = when {
            score < 0 -> R.id.ring_low.also { views.setProgressBar(it, 100, 0, false) }
            score < 40 -> R.id.ring_low
            score < 70 -> R.id.ring_mid
            else -> R.id.ring_high
        }
        for (ring in intArrayOf(R.id.ring_low, R.id.ring_mid, R.id.ring_high)) {
            views.setViewVisibility(ring, if (ring == shown) View.VISIBLE else View.GONE)
        }
        if (score >= 0) views.setProgressBar(shown, 100, score, false)
    }

    private fun launch(context: Context, uri: String) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))

    companion object {
        private const val TAG = "LifeOsWidget"

        /** From roughly 3 cells wide the full layout fits. */
        private const val LARGE_MIN_WIDTH_DP = 200
    }
}
