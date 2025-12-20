// PHASE 3.6: PERSISTENCE AND SECURITY (Android Parity Sync)
// Version: 1.0.2 (Silicon-Locked Baseline)
// Requirement: minSdk 21+ for Rust Argon2id/XChaCha20 support.

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Preserve current project namespace
    namespace = "com.example.flutter_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        // Preserve current Application ID
        applicationId = "com.example.flutter_app"
        
        // PRINCIPAL FIX: Override flutter.minSdkVersion with 21.
        // The Rust core dependencies (Argon2id) require NDK features available in SDK 21+.
        minSdk = flutter.minSdkVersion 
        
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Preserving existing debug-sign logic for parity testing
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
