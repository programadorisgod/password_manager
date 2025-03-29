import java.util.Properties
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localPropertiesFile = File(rootProject.projectDir, "local.properties")
val properties = Properties()

assert(localPropertiesFile.exists())
localPropertiesFile.reader().use { reader -> properties.load(reader) }

val flutterVersionCode = properties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = properties.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.example.password_manager_new"
    ndkVersion = "27.0.12077973"
    compileSdk = 34

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.password_manager_new"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 21
        targetSdk = 34
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:${rootProject.extra["kotlinVersion"]}")
    implementation("com.google.errorprone:error_prone_annotations:2.20.0")
    implementation("com.google.code.findbugs:jsr305:3.0.2")
    implementation("com.google.crypto.tink:tink-android:1.7.0")
}