plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "fr.cie6.mufasa"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Nécessaire aux notifications (flutter_local_notifications).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "fr.cie6.mufasa"
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

    // Signature fixe de MUFASA : toujours la même clé, pour que chaque nouvelle
    // version s'installe par-dessus l'ancienne. La clé vient des secrets GitHub
    // (MUFASA_KEYSTORE, MUFASA_KEY_PASSWORD) ; sans elle, clé de débogage.
    val cleMufasa = System.getenv("MUFASA_KEYSTORE_PATH")
    val mdpMufasa = System.getenv("MUFASA_KEY_PASSWORD")
    val signatureFixe = !cleMufasa.isNullOrEmpty() && !mdpMufasa.isNullOrEmpty()
    signingConfigs {
        if (signatureFixe) {
            create("mufasa") {
                storeFile = file(cleMufasa!!)
                storePassword = mdpMufasa
                keyAlias = "mufasa"
                keyPassword = mdpMufasa
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (signatureFixe) signingConfigs.getByName("mufasa")
                            else signingConfigs.getByName("debug")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
