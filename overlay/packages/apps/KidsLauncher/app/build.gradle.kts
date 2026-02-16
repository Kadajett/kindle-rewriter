plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "org.kindlerewriter.kidslauncher"
    compileSdk = 34

    defaultConfig {
        applicationId = "org.kindlerewriter.kidslauncher"
        // Target API 19+ for Fire HD 7 3rd gen (Android 4.4 base)
        minSdk = 19
        targetSdk = 25  // Android 7.1 (highest ROM we'll run)
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }
}

dependencies {
    // Zero dependencies. This launcher is pure Android framework APIs.
    // No AndroidX, no Material, no third-party libs.
    // Keeps the APK tiny and compatible with old Android versions.
}
