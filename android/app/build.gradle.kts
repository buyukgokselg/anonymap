import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use(::load)
    }
}

val keystoreProperties = Properties().apply {
    val keystoreFile = rootProject.file("key.properties")
    if (keystoreFile.exists()) {
        keystoreFile.inputStream().use(::load)
    }
}

fun escapeForGradle(value: String): String =
    value.replace("\\", "\\\\").replace("\"", "\\\"")

val googlePlacesApiKey =
    providers.environmentVariable("GOOGLE_PLACES_API_KEY").orNull
        ?: localProperties.getProperty("google.places.api.key", "")
val mapboxAccessToken =
    providers.environmentVariable("MAPBOX_ACCESS_TOKEN").orNull
        ?: localProperties.getProperty("mapbox.access.token", "")
val backendBaseUrl =
    providers.environmentVariable("BACKEND_BASE_URL").orNull
        ?: localProperties.getProperty("backend.base.url", "")
val hasReleaseKeystore =
    keystoreProperties.getProperty("storeFile")?.isNotBlank() == true &&
        keystoreProperties.getProperty("storePassword")?.isNotBlank() == true &&
        keystoreProperties.getProperty("keyAlias")?.isNotBlank() == true &&
        keystoreProperties.getProperty("keyPassword")?.isNotBlank() == true

android {
    namespace = "com.example.anonymap"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.anonymap"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["mapboxAccessToken"] = mapboxAccessToken
        buildConfigField(
            "String",
            "GOOGLE_PLACES_API_KEY",
            "\"${escapeForGradle(googlePlacesApiKey)}\"",
        )
        buildConfigField(
            "String",
            "MAPBOX_ACCESS_TOKEN",
            "\"${escapeForGradle(mapboxAccessToken)}\"",
        )
        buildConfigField(
            "String",
            "BACKEND_BASE_URL",
            "\"${escapeForGradle(backendBaseUrl)}\"",
        )
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseKeystore) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
