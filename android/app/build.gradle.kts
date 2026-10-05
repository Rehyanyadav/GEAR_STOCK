import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releasePropertiesFile = rootProject.file("key.properties")
val releaseProperties = Properties().apply {
    if (releasePropertiesFile.isFile) {
        releasePropertiesFile.inputStream().use { load(it) }
    }
}

fun releaseProperty(name: String): String? =
    releaseProperties.getProperty(name)?.trim()?.takeIf(String::isNotEmpty)

val resolvedApplicationId = releaseProperty("applicationId")
    ?: providers.gradleProperty("gearstockApplicationId").orNull
    ?: System.getenv("GEARSTOCK_APPLICATION_ID")
    ?: "com.sgbikedoctor.gearstock"
val releaseStoreFile = releaseProperty("storeFile")
    ?.let(rootProject::file)
val releaseStorePassword = releaseProperty("storePassword")
val releaseKeyAlias = releaseProperty("keyAlias")
val releaseKeyPassword = releaseProperty("keyPassword")
val releaseSigningConfigured = releaseStoreFile?.isFile == true &&
    releaseStorePassword != null &&
    releaseKeyAlias != null &&
    releaseKeyPassword != null
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (releaseBuildRequested) {
    require(!resolvedApplicationId.startsWith("com.example.")) {
        "Set an owner-approved applicationId in android/key.properties before building a release."
    }
    require(releaseSigningConfigured) {
        "Configure storeFile, storePassword, keyAlias, and keyPassword in the ignored android/key.properties file before building a release."
    }
}

android {
    namespace = "com.sgbikedoctor.gearstock"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    if (releaseSigningConfigured) {
        signingConfigs {
            create("gearstockRelease") {
                storeFile = checkNotNull(releaseStoreFile)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = resolvedApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("gearstockRelease")
            }
        }
    }
}

flutter {
    source = "../.."
}
