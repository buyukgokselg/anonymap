package com.example.anonymap

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pulsecity/runtime_config",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getRuntimeConfig") {
                result.success(
                    mapOf(
                        "googlePlacesApiKey" to BuildConfig.GOOGLE_PLACES_API_KEY,
                        "mapboxAccessToken" to BuildConfig.MAPBOX_ACCESS_TOKEN,
                        "backendBaseUrl" to BuildConfig.BACKEND_BASE_URL,
                    ),
                )
            } else {
                result.notImplemented()
            }
        }
    }
}
