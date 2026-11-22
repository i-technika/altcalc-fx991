package com.example.itechnika_altcalc_fx991

import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.VisibleForTesting
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerChannels(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        unregisterChannels(flutterEngine.dartExecutor.binaryMessenger)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onResume() {
        super.onResume()
        // 앱이 뒤에 있는 동안 바뀐 설정을 놓쳤어도 다시 앞에 올 때 맞춘다.
        highTextContrast?.refresh()
    }

    /**
     * 플랫폼 채널을 [messenger]에 건다. Flutter 엔진 없이 JVM 단위 테스트에서 부를 수 있게
     * [configureFlutterEngine]에서 떼어 두었다 (#108).
     */
    @VisibleForTesting
    internal fun registerChannels(messenger: BinaryMessenger) {
        // 기기 특성 조회 채널 (#24). Dart main()보다 먼저 등록되므로 앱 시작 시 바로 쓸 수 있다.
        MethodChannel(messenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // 폴더블 판정: 접힘 정보(displayFeatures)는 화면이 붙은 뒤 비동기로 오므로,
                    // 시작 시점에 바로 알 수 있는 힌지 각도 센서 유무로 폴더블 기기를 구분한다 (API 30+).
                    "hasHingeSensor" -> result.success(
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                            packageManager.hasSystemFeature(
                                PackageManager.FEATURE_SENSOR_HINGE_ANGLE,
                            ),
                    )
                    else -> result.notImplemented()
                }
            }
        // 시스템 "고대비 텍스트" 켜짐 여부 (#95)
        val handler = HighTextContrastStreamHandler(applicationContext)
        highTextContrast = handler
        EventChannel(messenger, HIGH_TEXT_CONTRAST_CHANNEL).setStreamHandler(handler)
    }

    /**
     * [registerChannels]가 건 고대비 텍스트 구독을 정리한다. Dart 쪽이 구독을 끊지 않은 채 엔진이 정리돼도
     * 시스템 변경 감지 등록이 남지 않게 한다. 거듭 불러도 안전하다.
     */
    @VisibleForTesting
    internal fun unregisterChannels(messenger: BinaryMessenger) {
        EventChannel(messenger, HIGH_TEXT_CONTRAST_CHANNEL).setStreamHandler(null)
        highTextContrast?.onCancel(null)
        highTextContrast = null
    }

    private var highTextContrast: HighTextContrastStreamHandler? = null

    companion object {
        private const val DEVICE_CHANNEL = "altcalc/device"
        private const val HIGH_TEXT_CONTRAST_CHANNEL = "altcalc/accessibility/high_text_contrast"
    }
}
