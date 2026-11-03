package click.softlane.alvea

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Widgets del escritorio. Flutter pinta cada uno como imagen (files/widgets/<nombre>.png) con el
 * cristal, la tipografía y Alvi de la app; aquí solo se muestran y se reparten los toques.
 */
object AlveaWidgets {
    private const val PREFS = "alvea_widgets"
    private const val HIDDEN = "balance_hidden"
    const val ACTION_TOGGLE = "click.softlane.alvea.widget.TOGGLE_BALANCE"

    private val providers = listOf(
        QuickWidget::class.java,
        TodayWidget::class.java,
        BalanceWidget::class.java,
        ChargesWidget::class.java,
        GoalWidget::class.java,
    )

    private fun dir(context: Context) = File(context.filesDir, "widgets")

    fun count(context: Context): Int {
        val manager = AppWidgetManager.getInstance(context)
        return providers.sumOf { manager.getAppWidgetIds(ComponentName(context, it)).size }
    }

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for (provider in providers) {
            val kind = kindOf(provider)
            for (id in manager.getAppWidgetIds(ComponentName(context, provider))) render(context, manager, id, kind)
        }
    }

    /** Al cerrar sesión: fuera las imágenes con datos; los widgets invitan a abrir la app. */
    fun clear(context: Context) {
        dir(context).deleteRecursively()
        updateAll(context)
    }

    fun toggleBalance(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(HIDDEN, !prefs.getBoolean(HIDDEN, false)).apply()
        updateAll(context)
    }

    private fun kindOf(provider: Class<*>) = when (provider) {
        QuickWidget::class.java -> "quick"
        TodayWidget::class.java -> "today"
        BalanceWidget::class.java -> "balance"
        ChargesWidget::class.java -> "charges"
        else -> "goal"
    }

    fun render(context: Context, manager: AppWidgetManager, id: Int, kind: String) {
        val layout = when (kind) {
            "quick" -> R.layout.widget_quick
            "balance" -> R.layout.widget_balance
            else -> R.layout.widget_image
        }
        val views = RemoteViews(context.packageName, layout)
        val hidden = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(HIDDEN, false)
        val file = File(dir(context), if (kind == "balance" && hidden) "balance_hidden.png" else "$kind.png")
        val bitmap = if (file.exists()) BitmapFactory.decodeFile(file.path) else null
        if (bitmap != null) {
            views.setImageViewBitmap(R.id.widget_image, bitmap)
            views.setViewVisibility(R.id.widget_image, View.VISIBLE)
            views.setViewVisibility(R.id.widget_empty, View.GONE)
        } else if (kind != "quick") {
            // Sin imagen aún (recién puesto o sin sesión): una invitación a abrir la app
            views.setViewVisibility(R.id.widget_image, View.GONE)
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
        }
        when (kind) {
            "quick" -> {
                views.setOnClickPendingIntent(R.id.widget_left, quickAdd(context, "expense"))
                views.setOnClickPendingIntent(R.id.widget_right, quickAdd(context, "income"))
                if (bitmap == null) views.setImageViewResource(R.id.widget_image, R.drawable.widget_preview_quick)
            }
            "balance" -> {
                views.setOnClickPendingIntent(R.id.widget_left, toggle(context))
                views.setOnClickPendingIntent(R.id.widget_right, openApp(context, "/", 30))
                views.setOnClickPendingIntent(R.id.widget_empty, openApp(context, "/", 30))
            }
            "today" -> views.setOnClickPendingIntent(R.id.widget_root, openApp(context, "/", 31))
            "charges" -> views.setOnClickPendingIntent(R.id.widget_root, openApp(context, "/?cobros=${today()}", 32))
            else -> views.setOnClickPendingIntent(R.id.widget_root, openApp(context, "/goals", 33))
        }
        views.setContentDescription(R.id.widget_image, context.getString(descriptionOf(kind)))
        manager.updateAppWidget(id, views)
    }

    private fun descriptionOf(kind: String) = when (kind) {
        "quick" -> R.string.widget_quick_description
        "today" -> R.string.widget_today_description
        "balance" -> R.string.widget_balance_description
        "charges" -> R.string.widget_charges_description
        else -> R.string.widget_goal_description
    }

    private fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    private fun openApp(context: Context, route: String, code: Int): PendingIntent = PendingIntent.getActivity(
        context,
        code,
        Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            .putExtra(MainActivity.EXTRA_ROUTE, route),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun quickAdd(context: Context, type: String): PendingIntent = PendingIntent.getActivity(
        context,
        if (type == "income") 21 else 20,
        QuickAddActivity.intent(context, type),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun toggle(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        40,
        Intent(context, BalanceWidget::class.java).setAction(ACTION_TOGGLE),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
}

/** Base de los cinco widgets: se pintan con la última imagen que dejó la app. */
abstract class AlveaWidget(private val kind: String) : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) AlveaWidgets.render(context, manager, id, kind)
    }
}

class QuickWidget : AlveaWidget("quick")

class TodayWidget : AlveaWidget("today")

class ChargesWidget : AlveaWidget("charges")

class GoalWidget : AlveaWidget("goal")

class BalanceWidget : AlveaWidget("balance") {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == AlveaWidgets.ACTION_TOGGLE) AlveaWidgets.toggleBalance(context) else super.onReceive(context, intent)
    }
}
