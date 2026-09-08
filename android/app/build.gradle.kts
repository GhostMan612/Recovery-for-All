import java.util.Properties
import java.io.FileInputStream

// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// Read keystore properties before the android block for release signing
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase activates ONLY when you drop your google-services.json in —
// the repo stays buildable without any Google Cloud configuration.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}


android {
    namespace = "com.recoveryforall"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Matches the Firebase app registration (com.recoveryforall —
        // Android package segments cannot contain underscores).
        applicationId = "com.recoveryforall"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile") as String?
            if (!storeFilePath.isNullOrBlank()) {
                storeFile = file(storeFilePath)
                keyAlias = keystoreProperties.getProperty("keyAlias") as String?
                keyPassword = keystoreProperties.getProperty("keyPassword") as String?
                storePassword = keystoreProperties.getProperty("storePassword") as String?
            }
        }
    }

    buildTypes {
        getByName("release") {
            val releaseSig = signingConfigs.getByName("release")
            signingConfig = if (releaseSig.storeFile?.exists() == true) releaseSig else signingConfigs.getByName("debug")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

// 16 KB page-size compliance (Play policy for targetSdk 35+): force the
// ML Kit / CameraX artifacts whose bundled .so files are 16 KB-aligned.
// Pins come from mobile_scanner 3.5.7 (barcode-scanning:17.2.0 ships a 4 KB
// libbarhopper_v3.so; camera-core:1.3.x ships a 4 KB
// libimage_processing_util_jni.so). Minor-bump only — no Dart API change.
configurations.all {
    resolutionStrategy {
        force("com.google.mlkit:barcode-scanning:17.3.0")
        force("com.google.android.gms:play-services-mlkit-barcode-scanning:18.3.1")
        force("androidx.camera:camera-core:1.4.2")
        force("androidx.camera:camera-camera2:1.4.2")
        force("androidx.camera:camera-lifecycle:1.4.2")
    }
}