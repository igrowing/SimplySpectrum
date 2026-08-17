package com.igrowing.simply_spectrum

import android.os.Build
import android.os.Environment
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "simply_spectrum/platform"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setWakelock" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        runOnUiThread {
                            if (enabled) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            }
                            result.success(null)
                        }
                    }
                    "getGalleryPath" -> {
                        // On all Android versions the Pictures directory
                        // resolves to /storage/emulated/0/Pictures. The
                        // gal plugin saves into a subfolder named after
                        // the album (e.g. SimplySpectrum).
                        val picturesDir =
                            Environment.getExternalStoragePublicDirectory(
                                Environment.DIRECTORY_PICTURES
                            ).absolutePath
                        result.success(picturesDir)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
