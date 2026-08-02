import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningProperties = Properties()
val releaseSigningPropertiesFile = rootProject.file("key.properties")
if (releaseSigningPropertiesFile.isFile) {
    FileInputStream(releaseSigningPropertiesFile).use {
        releaseSigningProperties.load(it)
    }
}

fun releaseSigningValue(environmentName: String, propertyName: String): String? =
    System.getenv(environmentName)?.takeIf { it.isNotBlank() }
        ?: releaseSigningProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }

val releaseStorePath = releaseSigningValue("MLMD_KEYSTORE_PATH", "storeFile")
val releaseStorePassword = releaseSigningValue("MLMD_KEYSTORE_PASSWORD", "storePassword")
val releaseKeyAlias = releaseSigningValue("MLMD_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = releaseSigningValue("MLMD_KEY_PASSWORD", "keyPassword")
val releaseStoreFile = releaseStorePath?.let { rootProject.file(it) }
val hasReleaseSigning = releaseStoreFile?.isFile == true &&
    releaseStorePassword != null && releaseKeyAlias != null && releaseKeyPassword != null
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

android {
    namespace = "com.example.mlmd"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.mlmd"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseStoreFile!!
                storePassword = releaseStorePassword!!
                keyAlias = releaseKeyAlias!!
                keyPassword = releaseKeyPassword!!
            }
        }
    }

    buildTypes {
        getByName("release") {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            } else if (releaseBuildRequested) {
                throw GradleException(
                    "Release signing is not configured. Set MLMD_KEYSTORE_PATH, " +
                        "MLMD_KEYSTORE_PASSWORD, MLMD_KEY_ALIAS, and MLMD_KEY_PASSWORD " +
                        "or provide android/key.properties. Debug keys are never used for release builds.",
                )
            }
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
