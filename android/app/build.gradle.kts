import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Get AdMob App ID from properties or env or default to Test ID
val admobAppId = keystoreProperties["admobAppId"] as String?
    ?: System.getenv("ADMOB_APP_ID_ANDROID")
    ?: "ca-app-pub-3940256099942544~3347511713"

android {
    namespace = "com.pocketllm.pocketllm_lite"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.pocketllm.pocketllm_lite"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = admobAppId
    }

    signingConfigs {
        create("release") {
            keyAlias = (keystoreProperties["keyAlias"] as String?) ?: "androiddebugkey"
            keyPassword = (keystoreProperties["keyPassword"] as String?) ?: "android"
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = (keystoreProperties["storePassword"] as String?) ?: "android"
        }
    }

    buildTypes {
        release {
            // Signing config - using release keystore if available, fallback to debug for development
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            
            // Enable ProGuard/R8 for shrinking, optimization, and obfuscation
            isMinifyEnabled = true
            isShrinkResources = true
            
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}