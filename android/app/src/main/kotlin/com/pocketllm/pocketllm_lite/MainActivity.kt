package com.pocketllm.pocketllm_lite

import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "pocketllm_lite/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getFreeDiskSpace") {
                try {
                    val path = filesDir.absolutePath
                    val stat = StatFs(path)
                    val bytesAvailable = stat.availableBlocksLong * stat.blockSizeLong
                    result.success(bytesAvailable)
                } catch (e: Exception) {
                    result.error("STORAGE_ERROR", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}