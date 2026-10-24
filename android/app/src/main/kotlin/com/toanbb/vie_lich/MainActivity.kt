package com.toanbb.vie_lich

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.toanbb.vie_lich/media_store"

    override fun onCreate(savedInstanceState: Bundle?) {
        // 👇 Gọi TRƯỚC super.onCreate() theo khuyến nghị của Android
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveSound" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    if (sourcePath == null) {
                        result.error("INVALID_ARGS", "sourcePath is null", null)
                        return@setMethodCallHandler
                    }
                    val uri = MediaStoreHelper.saveToMediaStore(this, sourcePath)
                    if (uri != null) {
                        result.success(uri)
                    } else {
                        result.error("SAVE_FAILED", "Không lưu được file", null)
                    }
                }
                "deleteSound" -> {
                    val deleted = MediaStoreHelper.deleteFromMediaStore(this)
                    result.success(deleted)
                }
                "existsSound" -> {
                    val exists = MediaStoreHelper.existsInMediaStore(this)
                    result.success(exists)
                }
                else -> result.notImplemented()
            }
        }
    }
}