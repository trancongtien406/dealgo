import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (DEC-PROD-053): android/key.properties (git-ignored) holds
// storeFile/storePassword/keyAlias/keyPassword. Without it a release build fails
// instead of silently shipping debug-signed artifacts.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseKeystore = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !keystoreProperties.getProperty(it).isNullOrBlank() }
// Local R8 check only: `-PdealgoDebugSignRelease=true` (or ORG_GRADLE_PROJECT_dealgoDebugSignRelease=true)
// signs a release build with the debug key when key.properties is missing. Never upload that build.
val debugSignRelease = !hasReleaseKeystore &&
    (project.findProperty("dealgoDebugSignRelease") as String?) == "true"

android {
    namespace = "com.nguyenngoctien.dealgo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nguyenngoctien.dealgo"
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
        // Unified app-link / passkey domain (DEC-PROD-058); override with -PdealgoAppLinkHost=…
        manifestPlaceholders["appLinkHost"] =
            (project.findProperty("dealgoAppLinkHost") as String?) ?: "dealgo.laptrinhapp.com"
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when {
                hasReleaseKeystore -> signingConfigs.getByName("release")
                debugSignRelease -> signingConfigs.getByName("debug")
                else -> null
            }
            // R8 keep rules for CallKit / LiveKit-WebRTC / Firebase / own channels.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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

gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any { it.project == project && it.name.contains("Release") }
    if (buildsRelease && debugSignRelease) {
        logger.warn("DealGo: release build signed with the DEBUG key (local R8 check). Do not upload it.")
    }
    if (buildsRelease && !hasReleaseKeystore && !debugSignRelease) {
        throw GradleException(
            "Release signing is not configured: create android/key.properties " +
                "(see android/key.properties.example). DEC-PROD-053.",
        )
    }
}
