plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.itechnika_altcalc_fx991"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.itechnika_altcalc_fx991"
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    testOptions {
        unitTests {
            // Robolectric이 병합된 AndroidManifest(MainActivity 선언 등)와 리소스를 읽게 한다 (#108)
            isIncludeAndroidResources = true
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

// Kotlin 플랫폼 코드의 JVM 단위 테스트 (#108) — 실행 방법은 README "Android 단위 테스트".
// Robolectric이 API 수준별 Android 프레임워크(android-all jar)를 JVM에서 돌려, 기기 없이 API 분기를 검사한다.
dependencies {
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.18.1")
}

// Robolectric은 API 36 프레임워크를 Java 21 이상에서만 돌린다(Robolectric `DefaultSdkProvider`의 SDK별 요구 Java 버전).
// 낮은 JVM으로는 API 36 분기 테스트가 돌지 못하므로, 테스트를 시작하기 전에 분명한 문구로 멈춘다.
// CI 잡의 Java 버전은 이 값 이상이어야 한다 (test/unit/ci_android_unit_test_test.dart가 대조한다).
val minTestJavaVersion = 21
tasks.withType<Test>().configureEach {
    // 실패한 테스트의 이름·단언 문구·스택을 콘솔에 남긴다 — CI 로그만으로 원인을 볼 수 있게 (HTML 보고서는 CI에 남지 않는다)
    testLogging {
        events("failed")
        exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
    }
    val launcherVersion = javaLauncher.map { it.metadata.languageVersion.asInt() }
    doFirst {
        val version = launcherVersion.get()
        check(version >= minTestJavaVersion) {
            "Android 단위 테스트는 Java $minTestJavaVersion 이상에서 돌린다 (지금 Java $version) — " +
                "Robolectric의 API 36 프레임워크가 Java $minTestJavaVersion 을 요구한다 (#108, README \"Android 단위 테스트\")"
        }
    }
}
