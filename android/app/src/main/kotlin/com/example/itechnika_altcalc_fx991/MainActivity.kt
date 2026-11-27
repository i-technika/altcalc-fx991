package com.example.itechnika_altcalc_fx991

import android.graphics.Point
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
     * 여러 창 모드에 들어가고 나올 때 Dart에 알린다 (#137 R1). Dart(`DeviceOrientationLock`)는 화면 정보가 바뀔 때도
     * [isInMultiWindowMode]를 묻지만, 그 시점에 값이 아직 바뀌지 않았거나(분할 화면 회전 중 7ms 동안 false 관찰) 창
     * 크기가 그대로인 채 모드만 바뀌면 놓친다. 이 알림을 받으면 다시 묻고 방향 정책을 다시 정한다.
     * 한 인자 판(API 24)을 재정의한다 — API 26 이상에서도 두 인자 판의 기본 구현이 이것을 부른다(minSdk 24라 두 인자
     * 판만 재정의하면 API 24·25에서 알림이 없다).
     */
    @Deprecated("Deprecated in Java")
    @Suppress("DEPRECATION")
    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean) {
        super.onMultiWindowModeChanged(isInMultiWindowMode)
        // 전체 화면으로 돌아오면 Dart를 기다리지 않고 전체 화면에서 쓰던 방향 고정을 바로 되돌린다 (#137 R1) — Dart는 이
        // 알림을 받고 다시 묻고 요청하느라 메인 스레드를 두 번 오가는데, 그동안 가로로 든 폰에서는 전체 화면이 가로로
        // 그려졌다(에뮬레이터에서 0.6~1.2초). Dart가 곧 같은 값을 다시 요청한다.
        // 기억한 화면과 다른 화면으로 나오면(분할 화면 중 폴더블을 접거나 폈다) 되돌리지 않고 Dart를 기다린다 (#137 R2) —
        // 커버 화면의 세로 고정을 펼친 내부 화면에 걸면 한 번 돌았다가 Dart의 네 방향 요청으로 다시 돈다.
        if (!isInMultiWindowMode) {
            val orientation = fullScreenOrientation
            if (orientation != null && fullScreenDisplay == displayShortSide()) {
                super.setRequestedOrientation(orientation)
            }
        }
        deviceChannel?.invokeMethod(MULTI_WINDOW_MODE_CHANGED, isInMultiWindowMode)
    }

    /**
     * 전체 화면에서 마지막으로 요청한 방향 (#137 R1, 없으면 `null`). Dart의 방향 요청(`SystemChrome.setPreferredOrientations`)은
     * Flutter 엔진의 `PlatformPlugin`이 이 메서드(`Activity.setRequestedOrientation`)로 보낸다 — 에뮬레이터에서 분할 화면
     * 중 `dumpsys activity activities`의 `requestedOrientation`이 Dart 요청대로 바뀌는 것과, 이 값으로 되돌려 나올 때 가로
     * 전체 화면 배치가 사라진 것으로 확인했다. 여러 창 모드에서 푼 요청(네 방향)은 기억하지 않는다.
     */
    @VisibleForTesting
    internal var fullScreenOrientation: Int? = null
        private set

    /**
     * [fullScreenOrientation]을 기억할 때의 물리 화면 (짧은 변 px — 폴더블 커버·내부 화면을 가른다, #137 R2). 창 크기에 따라
     * 바뀌는 구성 값(`smallestScreenWidthDp`)은 쓰지 않는다 — 여러 창 모드에서 나오는 알림 때는 아직 분할 창의 값이라
     * 에뮬레이터에서 늘 달라 되돌리지 못했다.
     */
    private var fullScreenDisplay: Int? = null

    /** 이 액티비티가 놓인 물리 화면의 짧은 변 (px, 회전과 무관) */
    @Suppress("DEPRECATION")
    private fun displayShortSide(): Int {
        val size = Point()
        windowManager.defaultDisplay.getRealSize(size)
        return minOf(size.x, size.y)
    }

    override fun setRequestedOrientation(requestedOrientation: Int) {
        if (!isInMultiWindowMode) {
            fullScreenOrientation = requestedOrientation
            fullScreenDisplay = displayShortSide()
        }
        super.setRequestedOrientation(requestedOrientation)
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
        val channel = MethodChannel(messenger, DEVICE_CHANNEL)
        deviceChannel = channel
        channel
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // 폴더블 판정 (#70): 접힘 정보(displayFeatures)는 화면이 붙은 뒤 비동기로 오므로, 힌지 신호와
                    // 창 배치 정보 첫 값으로 시작 시점에 구분한다 — 규칙은 [FoldableDeviceProbe]. 답은 map (#158).
                    "isFoldableDevice" -> probe.query { result.success(it.toChannelValue()) }
                    // 여러 창 모드(분할 화면·자유 형식 창·팝업 창)인지 (#137). Android는 이 모드에서 방향을 고정한 앱의
                    // 창 모양이 요청 방향과 다르면 창 안에 레터박스로 줄여 그린다 — Dart(`DeviceOrientationLock`)가 이
                    // 답으로 방향 고정을 풀어 창 전체를 쓴다. 화면 정보가 바뀔 때마다 묻는다(API 24 = minSdk부터 있다).
                    "isInMultiWindowMode" -> result.success(isInMultiWindowMode)
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
        deviceChannel = null
        foldableProbe?.cancel()
        foldableProbe = null
        EventChannel(messenger, HIGH_TEXT_CONTRAST_CHANNEL).setStreamHandler(null)
        highTextContrast?.onCancel(null)
        highTextContrast = null
    }

    private var highTextContrast: HighTextContrastStreamHandler? = null

    /** Dart로 여러 창 모드 변경을 알리는 기기 채널 ([registerChannels]가 건 것, 없으면 `null`) */
    private var deviceChannel: MethodChannel? = null
    private var foldableProbe: FoldableDeviceProbe? = null

    /** 폴더블 판정에 쓰는 창 배치 정보 (테스트가 바꿔 끼운다) */
    @VisibleForTesting
    internal var foldingLayoutSource: FoldingLayoutSource = WindowLayoutFoldingSource(this)

    companion object {
        private const val DEVICE_CHANNEL = "altcalc/device"

        /** 여러 창 모드 변경 알림 — Dart `FormFactor.multiWindowModeChangedMethod`와 같아야 한다 (#137 R1) */
        private const val MULTI_WINDOW_MODE_CHANGED = "multiWindowModeChanged"
        private const val HIGH_TEXT_CONTRAST_CHANNEL = "altcalc/accessibility/high_text_contrast"
    }
}
