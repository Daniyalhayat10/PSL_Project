plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.psl.psl_urdu_detector"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

   kotlinOptions {
    jvmTarget = "17"
}

    defaultConfig {
        applicationId = "com.psl.psl_urdu_detector"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes { 
release {
    isMinifyEnabled = false
    isShrinkResources = false      
    signingConfig = signingConfigs.getByName("debug")
}
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Force TFLite 2.14+ so FULLY_CONNECTED op v12 is supported.
    implementation("org.tensorflow:tensorflow-lite:2.14.0")
    implementation("org.tensorflow:tensorflow-lite-gpu:2.14.0")

    // MediaPipe Tasks Vision — provides the full hand-landmark pipeline
    // (palm detection + crop + landmark). Exclude its bundled TFLite to
    // avoid conflicts with the version we already force above.
    implementation("com.google.mediapipe:tasks-vision:0.10.14") {
        exclude(group = "org.tensorflow")
    }
}
