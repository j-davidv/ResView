package org.resview.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.Normalizer
import java.io.File
import android.os.StatFs
import android.content.Intent
import android.provider.Settings

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        val messenger = engine.dartExecutor.binaryMessenger
        engine.platformViewsController.registry.registerViewFactory("org.resview/source_view", SourceViewFactory(messenger))
        MethodChannel(messenger, "org.resview/private", io.flutter.plugin.common.StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue()).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "normalizeNfc" -> result.success(Normalizer.normalize(call.arguments as String, Normalizer.Form.NFC))
                    "normalizeNfcBatch" -> result.success((call.arguments as List<*>).map { Normalizer.normalize(it as String, Normalizer.Form.NFC) })
                    "availableBytes" -> {
                        val path = File(call.arguments as String).canonicalFile
                        val owned = File(applicationInfo.dataDir).canonicalFile
                        require(path.path.startsWith(owned.path + File.separator))
                        result.success(StatFs(path.path).availableBytes)
                    }
                    "notificationSettings" -> {
                        runOnUiThread {
                            try {
                                val intent = if (android.os.Build.VERSION.SDK_INT >= 26)
                                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.parse("package:$packageName"))
                                startActivity(intent)
                                result.success(null)
                            } catch (_: Exception) { result.error("SETTINGS_UNAVAILABLE", "Open notification settings in Android Settings", null) }
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("PRIVATE_OPERATION_FAILED", "Device operation could not be completed", null)
            }
        }
    }
}
