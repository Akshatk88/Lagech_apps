import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")

    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")

    // Firebase Google Services plugin
    id("com.google.gms.google-services")
}

android {
    namespace = "com.lagech.restaurent"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.lagech.restaurent"

        minSdk = if (flutter.minSdkVersion < 21) {
            21
        } else {
            flutter.minSdkVersion
        }

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")

            storeFile = keystoreProperties.getProperty("storeFile")?.let { path ->
                val f = file(path)
                if (f.exists()) f else rootProject.file(path)
            }

            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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

    // Core library desugaring
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.0.4"
    )

    // =========================================================
    // FIREBASE
    // =========================================================

    // Firebase BoM
    // Firebase dependencies ki versions yahan separately nahi deni hain.
    implementation(
        platform("com.google.firebase:firebase-bom:34.19.0")
    )

    // Firebase Cloud Messaging
    // NewOrderMessagingService ke liye required
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

    // NotificationCompat ke liye
    implementation(
        "androidx.core:core-ktx:1.13.1"
    )
}