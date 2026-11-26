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
// 인라인 모크를 만드는 Mockito 에이전트. JVM에 실행 중 붙는 방식(자기 부착)은 앞으로의 JDK에서 기본으로 막히므로
// 테스트 JVM을 띄울 때 -javaagent로 붙인다 (Mockito 공식 권장 설정).
val mockitoVersion = "5.24.0"
val mockitoAgent: Configuration by configurations.creating

dependencies {
    // 시작 시 폴더블 판정의 창 배치 정보 (#70, FoldableDeviceProbe). Flutter 엔진이 displayFeatures에 쓰는 것과 같은
    // 라이브러리라 Flutter 임베딩이 이미 싣는다 — 앱 코드가 직접 쓰므로 명시한다. 버전은 임베딩 POM의 값과 맞춘다
    // (Gradle은 둘 중 높은 버전을 고른다).
    implementation("androidx.window:window-java:1.2.0")
    mockitoAgent("org.mockito:mockito-core:$mockitoVersion") { isTransitive = false }
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.18.1")
    // Flutter 엔진의 네이티브 연결(FlutterJNI)을 대역으로 바꿔 MainActivity 생명주기를 돌린다 (MainActivityLifecycleTest)
    testImplementation("org.mockito:mockito-core:$mockitoVersion")
}

// Robolectric은 API 36 프레임워크를 Java 21 이상에서만 돌린다(Robolectric 4.18 `DefaultSdkProvider`의 SDK별 요구 Java 버전).
// 낮은 JVM이면 Robolectric도 API 36 테스트마다 "Failed to create a Robolectric sandbox"로 실패시키지만, 여기서는 테스트를
// 시작하기 전에 한 번, 무엇을 하면 되는지 적은 문구로 멈춘다. Robolectric을 올릴 때 그쪽 요구 버전과 이 값을 함께 확인한다.
// CI 잡의 Java 버전은 이 값 이상이어야 한다 (test/unit/ci_android_unit_test_test.dart가 대조한다).
val minTestJavaVersion = 21
tasks.withType<Test>().configureEach {
    // 실패·건너뜀은 테스트별로, 전체 결과는 마지막에 한 줄로 콘솔에 남긴다 — CI 로그만으로 원인과 실행 개수를 볼 수 있게
    // (HTML 보고서는 CI에 남지 않는다)
    testLogging {
        events("failed", "skipped")
        exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
    }
    afterSuite(
        KotlinClosure2<TestDescriptor, TestResult, Unit>({ suite, result ->
            if (suite.parent == null) {
                println(
                    "Android 단위 테스트: ${result.resultType} — 실행 ${result.testCount}, 성공 ${result.successfulTestCount}, " +
                        "실패 ${result.failedTestCount}, 건너뜀 ${result.skippedTestCount}",
                )
            }
        }),
    )
    // Configuration 대신 경로 Provider를 잡는다 (구성 캐시 직렬화)
    val agentPath = mockitoAgent.elements.map { it.single().asFile.absolutePath }
    jvmArgumentProviders.add(CommandLineArgumentProvider { listOf("-javaagent:${agentPath.get()}") })
    // doFirst가 스크립트 객체를 잡지 않게 지역 값으로 옮긴다 (구성 캐시 직렬화)
    val required = minTestJavaVersion
    val launcherVersion = javaLauncher.map { it.metadata.languageVersion.asInt() }
    doFirst {
        val version = launcherVersion.get()
        check(version >= required) {
            "Android 단위 테스트는 Java $required 이상에서 돌린다 (지금 Java $version). " +
                "Robolectric이 API 36 프레임워크에 Java ${required}을 요구한다 — JAVA_HOME을 바꿀 것 (#108, README \"Android 단위 테스트\")"
        }
    }
}
