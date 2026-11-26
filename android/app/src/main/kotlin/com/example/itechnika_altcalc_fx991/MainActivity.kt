package com.example.itechnika_altcalc_fx991

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
        foldableProbe?.cancel()
        val probe = FoldableDeviceProbe(
            hingeSignals = { FoldableDeviceProbe.hingeSignalsOf(this) },
            layoutSource = foldingLayoutSource,
        )
        foldableProbe = probe
        MethodChannel(messenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // 폴더블 판정 (#70): 접힘 정보(displayFeatures)는 화면이 붙은 뒤 비동기로 오므로, 힌지 신호와
                    // 창 배치 정보 첫 값으로 시작 시점에 구분한다 — 규칙은 [FoldableDeviceProbe]. 답은 map (#158).
                    "isFoldableDevice" -> probe.query { result.success(it.toChannelValue()) }
                    else -> result.notImplemented()
                }
            }
        // 시스템 "고대비 텍스트" 켜짐 여부 (#95)
        val handler = HighTextContrastStreamHandler(applicationContext)
        highTextContrast = handler
        EventChannel(messenger, HIGH_TEXT_CONTRAST_CHANNEL).setStreamHandler(handler)
    }

    /**
     * [registerChannels]가 건 채널 처리기를 떼고 고대비 텍스트 구독·폴더블 판정을 정리한다. Dart 쪽이 구독을 끊지 않은 채
     * 엔진이 정리돼도 시스템 변경 감지 등록이 남지 않고, 답을 기다리는 폴더블 판정은 바로 답하고 창 배치 구독을 푼다.
     * 엔진이 이 액티비티보다 오래 살아도(캐시 엔진) 끝난 액티비티를 붙드는 처리기가 남지 않는다. 거듭 불러도 안전하다.
     */
    @VisibleForTesting
    internal fun unregisterChannels(messenger: BinaryMessenger) {
        MethodChannel(messenger, DEVICE_CHANNEL).setMethodCallHandler(null)
        foldableProbe?.cancel()
        foldableProbe = null
        EventChannel(messenger, HIGH_TEXT_CONTRAST_CHANNEL).setStreamHandler(null)
        highTextContrast?.onCancel(null)
        highTextContrast = null
    }

    private var highTextContrast: HighTextContrastStreamHandler? = null
    private var foldableProbe: FoldableDeviceProbe? = null

    /** 폴더블 판정에 쓰는 창 배치 정보 (테스트가 바꿔 끼운다) */
    @VisibleForTesting
    internal var foldingLayoutSource: FoldingLayoutSource = WindowLayoutFoldingSource(this)

    companion object {
        private const val DEVICE_CHANNEL = "altcalc/device"
        private const val HIGH_TEXT_CONTRAST_CHANNEL = "altcalc/accessibility/high_text_contrast"
    }
}
