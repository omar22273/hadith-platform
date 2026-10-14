plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    signingConfigs {
        // One fixed, deliberately public keystore committed in the repository
        // (android/app/fixed-debug.keystore). Every build, on every machine, carries the same
        // certificate, so a new APK installs over the previous one (Personal and Work profile
        // included) without clearing data. Nothing is generated at build time.
        create("release") {
            storeFile = file("fixed-debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
        }
    }
    namespace = "app.hadithplatform.hadith_platform"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        multiDexEnabled = true
        // The final, official application id. (The Kotlin package above stays as the code namespace.)
        applicationId = "app.hady.platform"
        // Flutter 3.35+ refuses to build below API 24 (Android 7.0), so 24 is the floor.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // versionName comes from pubspec.yaml. versionCode grows with every CI build
        // (GITHUB_RUN_NUMBER + 100, always above the codes of earlier releases), so a new
        // build can never be rejected as a downgrade; local builds fall back to pubspec.
        val ciRunNumber = System.getenv("GITHUB_RUN_NUMBER")?.toIntOrNull()
        versionCode = if (ciRunNumber != null) 100 + ciRunNumber else flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signed exclusively with the fixed keystore above (v1, v2 and v3).
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
