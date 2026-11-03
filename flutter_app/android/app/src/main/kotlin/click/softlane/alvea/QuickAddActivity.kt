package click.softlane.alvea

import android.content.Intent
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Recuadro rápido: anota un gasto o ingreso encima de lo que haya en pantalla, sin abrir la app.
 * Fondo transparente y su propia entrada de Dart (`quickAddMain` en lib/main.dart).
 */
class QuickAddActivity : FlutterFragmentActivity() {
    override fun getDartEntrypointFunctionName(): String = "quickAddMain"

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MainActivity.CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "quickAddType" -> result.success(intent?.getStringExtra(EXTRA_TYPE) ?: "expense")
                "finish" -> {
                    result.success(null)
                    finishAndRemoveTask()
                }
                "openApp" -> {
                    result.success(null)
                    startActivity(
                        Intent(this, MainActivity::class.java)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                            .putExtra(MainActivity.EXTRA_ROUTE, call.arguments as? String ?: "/"),
                    )
                    finishAndRemoveTask()
                }
                "updateWidgets" -> {
                    AlveaWidgets.updateAll(applicationContext)
                    result.success(null)
                }
                "widgetCount" -> result.success(AlveaWidgets.count(applicationContext))
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        const val EXTRA_TYPE = "type"

        fun intent(context: android.content.Context, type: String): Intent =
            Intent(context, QuickAddActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                .putExtra(EXTRA_TYPE, type)
    }
}
