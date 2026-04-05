pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
     id("com.google.gms.google-services") version "4.4.0" apply false
}

include(":app")

// Mapbox native SDK indirmesi: secret token (Downloads:Read). local.properties → sdk.registry.token=sk...
// veya ortam değişkeni SDK_REGISTRY_TOKEN. mapbox_maps_flutter eklentisi bunu okur.
val mapboxProps = java.util.Properties()
val mapboxLocalFile = settingsDir.resolve("local.properties")
if (mapboxLocalFile.exists()) {
    mapboxLocalFile.inputStream().use { mapboxProps.load(it) }
}
val mapboxSdkRegistryToken = mapboxProps.getProperty("sdk.registry.token")
    ?: System.getenv("SDK_REGISTRY_TOKEN")
if (!mapboxSdkRegistryToken.isNullOrBlank()) {
    gradle.beforeProject {
        extra["SDK_REGISTRY_TOKEN"] = mapboxSdkRegistryToken
    }
}
