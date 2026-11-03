import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de publicación (Google Play): android/key.properties apunta al keystore. No se sube al
// repositorio; la CI lo crea a partir de los secrets ANDROID_* (ver ../ANDROID.md). Sin él, la
// versión release se firma con la clave de depuración: sirve para instalar y probar, no para Play.
val keystoreProperties =
    Properties().apply {
        val file = rootProject.file("key.properties")
        if (file.exists()) file.inputStream().use { load(it) }
    }
val hasReleaseKey = !keystoreProperties.isEmpty

android {
    namespace = "click.softlane.alvea"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identificador en Google Play: no se puede cambiar después de publicar la app
        applicationId = "click.softlane.alvea"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // versionCode/versionName salen de pubspec.yaml (la CI usa el número de ejecución como build)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Tema AppCompat del arranque: el diálogo de huella (local_auth) lo necesita en Android 8 o anterior
    implementation("androidx.appcompat:appcompat:1.7.0")
}

flutter {
    source = "../.."
}
