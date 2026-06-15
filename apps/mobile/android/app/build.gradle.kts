plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied AFTER the Android and Kotlin
    // plugins. It replaces the old:
    //   apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.ethersynapse.ether_synapse"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "dev.ethersynapse.ether_synapse"
        // BLE peripheral advertising requires API 21+.
        // flutter_reactive_ble scanning requires API 21+.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signed with debug keys so `flutter run --release` works without
            // a keystore configured. Replace before publishing.
            signingConfig = signingConfigs.getByName("debug")
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
