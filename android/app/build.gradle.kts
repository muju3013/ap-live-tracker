import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --------------------------------------------------
// Release signing configuration
// Reads passwords and keystore path from:
// android/key.properties
// --------------------------------------------------
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.muju3013.aplivetracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // IMPORTANT:
        // Before publishing widely / Play Store, consider replacing
        // Permanent unique Application ID.
        applicationId = "com.muju3013.aplivetracker"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        // Version comes from pubspec.yaml
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // --------------------------------------------------
    // Production release signing
    // --------------------------------------------------
    signingConfigs {
        create("release") {
            if (!keystorePropertiesFile.exists()) {
                throw GradleException(
                    "android/key.properties was not found. " +
                    "Release signing cannot be configured."
                )
            }

            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storePassword = keystoreProperties["storePassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
        }
    }

    buildTypes {
        release {
            // IMPORTANT:
            // Release APK now uses your private production signing key,
            // NOT Flutter's debug key.
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