plugins {
    id("com.android.application")
    id("kotlin-android")

    // Firebase Google Services plugin
    id("com.google.gms.google-services")

    // Flutter Gradle Plugin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.lagech.delivery"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.lagech.delivery"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with debug keys for now
            signingConfig = signingConfigs.getByName("debug")

            // =====================================================
            // RELEASE BUILD SPEED
            // =====================================================
            // R8 / ProGuard OFF
            // This avoids minifyReleaseWithR8 and makes APK build
            // significantly faster.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

flutter {
    source = "../.."
}

dependencies {

    // =========================================================
    // CORE LIBRARY DESUGARING
    // =========================================================

    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )

    // =========================================================
    // FIREBASE
    // =========================================================

    implementation(
        platform("com.google.firebase:firebase-bom:34.19.0")
    )

    // Firebase Cloud Messaging
    implementation(
        "com.google.firebase:firebase-messaging"
    )

    // Firebase Analytics
    implementation(
        "com.google.firebase:firebase-analytics"
    )

    // =========================================================
    // ANDROIDX
    // =========================================================

    implementation(
        "androidx.core:core-ktx:1.13.1"
    )
}