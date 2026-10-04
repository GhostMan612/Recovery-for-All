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

// Did THIS invocation ask for a release variant? Checked from the requested
// task names rather than assumed, so a debug build is never blocked by an
// absent keystore (release keys are gitignored, so a fresh clone legitimately
// has none and must still be able to build debug).
val RELEASE_VARIANT_REQUESTED: Boolean =
    gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }

// Captured here because the buildTypes/buildType lambdas have their own
// receivers; relying on `logger` resolving through that chain is exactly the
// kind of thing that compiles on one Gradle version and not the next.
val gradleLogger = logger

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
            // A release bundle must NEVER silently fall back to the debug key.
            //
            // This previously read `if (storeFile?.exists()) release else debug`,
            // which looks defensive and is actually a trap: a debug-signed AAB
            // builds cleanly, `jarsigner -verify` reports `jar verified.`, and
            // the resulting Play upload fails with an opaque signature error.
            // Every step between the mistake and finding out is green. So the
            // fallback is kept for debug builds (where it is correct and
            // unreachable) and made FATAL for a release build, where it is
            // never what anyone meant.
            val keystorePresent = releaseSig.storeFile?.exists() == true
            val keystorePath = releaseSig.storeFile?.path
                ?: "(storeFile unset — android/key.properties missing or has no storeFile)"
            if (!keystorePresent) {
                if (RELEASE_VARIANT_REQUESTED) {
                    throw GradleException(
                        "REFUSING TO SIGN A RELEASE WITH THE DEBUG KEY.\n" +
                        "  android/key.properties points at a keystore that does not exist:\n" +
                        "  $keystorePath\n" +
                        "  The upload key (upload-keystore.jks) is gitignored and never committed.\n" +
                        "  Restore it to the repo root, fix storeFile in key.properties, or build\n" +
                        "  a debug APK instead. Not negotiable — a debug-signed release looks\n" +
                        "  exactly like a good one until Play rejects it.\n" +
                        "  See AGENTS.md §5 Build Boundary."
                    )
                }
                gradleLogger.warn(
                    "Release keystore not found ($keystorePath). Debug builds are unaffected; " +
                        "a RELEASE build would now fail rather than be debug-signed."
                )
            }
            signingConfig = if (keystorePresent) releaseSig else signingConfigs.getByName("debug")
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