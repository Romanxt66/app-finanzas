package click.softlane.alvea

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FragmentActivity: la necesita el diálogo de huella del sistema (local_auth / BiometricPrompt)
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    // Pantalla que pidió un widget al abrir la app
                    "initialRoute" -> {
                        result.success(intent?.getStringExtra(EXTRA_ROUTE))
                        intent?.removeExtra(EXTRA_ROUTE)
                    }
                    "updateWidgets" -> {
                        AlveaWidgets.updateAll(applicationContext)
                        result.success(null)
                    }
                    "widgetCount" -> result.success(AlveaWidgets.count(applicationContext))
                    "clearWidgets" -> {
                        AlveaWidgets.clear(applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    // Con la app ya abierta, un widget pide otra pantalla
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra(EXTRA_ROUTE)?.let { route ->
            channel?.invokeMethod("open", route)
            intent.removeExtra(EXTRA_ROUTE)
        }
    }

    companion object {
        const val CHANNEL = "click.softlane.alvea/app"
        const val EXTRA_ROUTE = "route"
    }
}
