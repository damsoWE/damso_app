import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 릴리스 서명 정보. android/key.properties(저장소에 올리지 않음)에서 읽는다.
// 키: storePassword, keyPassword, keyAlias, storeFile
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "io.github.damsowe.damso_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.github.damsowe.damso_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // 디버그 키로 서명하지 않는다. key.properties 가 없으면 아래 검사에서 릴리스 빌드를 중단한다.
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

// 릴리스 태스크(assembleRelease, bundleRelease 등)가 요청됐는데 서명 키가 없으면 빌드를 거부한다.
// 디버그 빌드는 key.properties 없이도 동작한다.
if (!keystorePropertiesFile.exists() &&
    gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
) {
    throw GradleException(
        "릴리스 서명 키가 없습니다. android/key.properties 를 만든 뒤 다시 빌드하세요 " +
            "(storePassword, keyPassword, keyAlias, storeFile). 디버그 키로는 릴리스를 서명하지 않습니다. " +
            "/ android/key.properties is missing; release builds are never signed with the debug key."
    )
}

flutter {
    source = "../.."
}
