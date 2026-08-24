package com.pocketllm.pocketllm_lite

import android.app.ActivityManager
import android.content.Context
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.os.StatFs
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val storageChannel = "pocketllm_lite/storage"
    private val deviceChannel = "pocketllm_lite/device"
    private val ocrChannel = "pocketllm_lite/ocr"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storageChannel).setMethodCallHandler { call, result ->
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannel).setMethodCallHandler { call, result ->
            if (call.method != "getProfile") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val memory = ActivityManager.MemoryInfo()
                activityManager.getMemoryInfo(memory)
                val stat = StatFs(filesDir.absolutePath)
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                val thermal = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    when (powerManager.currentThermalStatus) {
                        PowerManager.THERMAL_STATUS_NONE -> "none"
                        PowerManager.THERMAL_STATUS_LIGHT -> "light"
                        PowerManager.THERMAL_STATUS_MODERATE -> "moderate"
                        PowerManager.THERMAL_STATUS_SEVERE -> "severe"
                        PowerManager.THERMAL_STATUS_CRITICAL -> "critical"
                        PowerManager.THERMAL_STATUS_EMERGENCY -> "emergency"
                        PowerManager.THERMAL_STATUS_SHUTDOWN -> "shutdown"
                        else -> "unknown"
                    }
                } else null
                result.success(
                    mapOf(
                        "totalRamBytes" to memory.totalMem,
                        "availableRamBytes" to memory.availMem,
                        "cpuArchitecture" to Build.SUPPORTED_ABIS.joinToString(","),
                        "cpuCores" to Runtime.getRuntime().availableProcessors(),
                        "availableStorageBytes" to stat.availableBytes,
                        "thermalState" to thermal,
                        "batteryLevel" to batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY),
                        // Android does not expose a dependable cross-device accelerator probe.
                        "hasGpuAcceleration" to null,
                    )
                )
            } catch (e: Exception) {
                result.error("DEVICE_PROFILE_ERROR", e.localizedMessage, null)
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ocrChannel).setMethodCallHandler { call, result ->
            if (call.method != "recognizeText") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val imagePath = call.argument<String>("path")
            if (imagePath.isNullOrBlank()) {
                result.error("OCR_INPUT_ERROR", "An image path is required", null)
                return@setMethodCallHandler
            }
            try {
                val image = InputImage.fromFilePath(this, android.net.Uri.fromFile(java.io.File(imagePath)))
                val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                recognizer.process(image)
                    .addOnSuccessListener { recognized ->
                        result.success(mapOf("text" to recognized.text, "confidence" to null))
                        recognizer.close()
                    }
                    .addOnFailureListener { error ->
                        result.error("OCR_PROCESSING_ERROR", error.localizedMessage, null)
                        recognizer.close()
                    }
            } catch (error: Exception) {
                result.error("OCR_INPUT_ERROR", error.localizedMessage, null)
            }
        }
    }
}
