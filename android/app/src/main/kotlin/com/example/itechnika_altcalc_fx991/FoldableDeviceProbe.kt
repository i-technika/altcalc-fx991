package com.example.itechnika_altcalc_fx991

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.annotation.VisibleForTesting
import androidx.core.util.Consumer
import androidx.window.java.layout.WindowInfoTrackerCallbackAdapter
import androidx.window.layout.FoldingFeature
import androidx.window.layout.WindowInfoTracker
import androidx.window.layout.WindowLayoutInfo
import java.util.concurrent.Executor

/**
 * 앱 시작 시점의 폴더블 기기 판정 (#24, 보강 #70, 기록·보강 #158). Dart `FormFactor.queryFoldableDevice`가 `altcalc/device`
 * 채널의 `isFoldableDevice`로 부른다. Dart `main()`이 이 답을 기다린 뒤 첫 화면을 띄우므로, 기다리는 동안은
 * Android 시작 화면(스플래시)이 그대로 남는다. 답은 [Answer] — 폴더블 여부와, 창 배치 정보 첫 값에 접히는 부분이 있었는지다.
 *
 * 아래 신호 중 하나라도 있으면 폴더블이다.
 * 1. 힌지 각도 센서 **기능 선언** (`FEATURE_SENSOR_HINGE_ANGLE`, API 30+) — 제조사가 선언해야만 보고된다.
 * 2. 힌지 각도 **센서 목록** (`Sensor.TYPE_HINGE_ANGLE`, API 30+) — 기능은 선언하지 않고 센서만 싣는 기기 대비.
 *    `getDefaultSensor`는 쓰지 않는다 — 이 종류(API 30+)의 기본 센서를 wake-up 센서로만 찾아, non-wake-up 힌지
 *    센서만 싣는 기기에서 놓친다. 목록은 wake-up 여부와 상관없이 모두 준다(`test/unit/main_activity_source_test.dart`가 지킨다).
 * 3. 창 배치 정보(Jetpack WindowManager `WindowLayoutInfo`)의 **첫 값**에 접히는 부분(`FoldingFeature`)이 있음 —
 *    Samsung처럼 OEM 확장으로 접힘 정보만 주는 기기 대비. Flutter `displayFeatures`도 같은 정보에서 오지만 Dart
 *    쪽에서는 "아직 안 옴"과 "없음"을 구분하지 못한다 — 여기서는 구독 뒤 첫 값을 그 순간의 답으로 쓴다.
 *    - 확장이 있는 기기(대부분)는 구독하자마자 확장이 지금 값을 계산해 보낸다(메인 스레드로 한 번 넘긴 뒤).
 *      확장이 없고 Sidecar만 있는 옛 기기는 창이 붙은 뒤에 온다. 어느 쪽도 없는 기기는 빈 값을 바로 보낸다.
 *    - 그래도 오지 않는 경우에 대비해 [layoutTimeoutMillis]까지만 기다린다.
 *
 * **1·2가 있어도 3의 첫 값을 기다린다** (#158). 1·2로 바로 답하면 Dart가 접힘 정보(`displayFeatures`)보다 먼저 첫
 * 화면을 그려, 펼친 내부 화면에서 시작할 때 위아래 배치가 잠깐 보인 뒤 접힘선 기준 배치로 바뀌었다(Pixel Fold
 * 에뮬레이터, Android 16 — 5번 중 4번, 첫 프레임부터 약 90~140ms). 첫 값에 접히는 부분이 있었다는 것([Answer.fold])을
 * 함께 알리면 Dart가 그 정보가 화면에 올 때까지 시작 화면을 유지한다(Dart `DeviceOrientationLock.waitForFoldFeature`).
 * 첫 값은 에뮬레이터에서 구독 뒤 20~270ms에 왔다. 그만큼 폴더블의 시작 화면이 길어진다.
 *
 * ChromeOS(`FEATURE_PC`)에서는 1·2를 쓰지 않는다 — 컨버터블 노트북이 힌지 센서를 알릴 수 있고, 폴더블로 오판하면
 * 접힘선 없는 대화면 가로 창이 계속 위아래 배치가 된다(Dart `FormFactor.arrangementOf`).
 * ChromeOS 창에는 접히는 부분이 보고되지 않으므로 3도 "없음"이다.
 *
 * 기록 (#158 — 에뮬레이터. Samsung 실기기 기록은 아직 없다):
 * - Pixel Fold(Android 16): 기능 선언·센서 모두 있음. 첫 값은 내부 화면 "접힘", 커버 화면 "없음"이었고 뒤에 바뀌지 않았다.
 * - 7.6" Fold-in·6.7" Flip 에뮬레이터(Android 14): 기능 선언 없이 **센서만** 있다 — 2가 없으면 놓친다.
 *
 * 한계:
 * - 첫 값이 이미 맞는 값이라는 가정은 Samsung OEM 확장에서 확인하지 못했다. 확장이 기기 상태를 아직 모르면 빈 값을
 *   먼저 보낼 수 있다. 그래서 답한 뒤에도 [diagnosticMillis] 동안 구독을 유지해, 앞 값과 다른 값이 오면 로그로 남긴다
 *   (판정은 바꾸지 않는다 — Dart가 화면 정보로 바로잡는다).
 * - 접은 커버 화면에서 시작하면 3은 "없음"이다(창이 접힘선에 걸치지 않는다). 1·2도 없는 기기는 폰으로 판정되고,
 *   펼칠 때 Dart `DeviceOrientationLock`이 물리 화면이 바뀐 것을 보고 폴더블로 기억한다.
 * - 펼친 내부 화면이라도 분할 화면·팝업 창처럼 창이 접힘선에 걸치지 않으면 3은 "없음"이다.
 *
 * 판정마다 신호별 값과 걸린 시간을 로그(태그 [LOG_TAG])로 남긴다 — 실기기 확인 때 `adb logcat -s AltCalc flutter`로
 * 읽는다(Dart 쪽 첫 프레임·배치 로그는 `flutter` 태그, `LayoutLog`).
 */
internal class FoldableDeviceProbe(
    private val hingeSignals: () -> HingeSignals,
    private val layoutSource: FoldingLayoutSource,
    private val handler: Handler = Handler(Looper.getMainLooper()),
    private val layoutTimeoutMillis: Long = LAYOUT_TIMEOUT_MILLIS,
    private val diagnosticMillis: Long = DIAGNOSTIC_MILLIS,
) {
    /** 시작 즉시 알 수 있는 힌지 신호 (위 1·2). [pc]면 둘 다 쓰지 않는다. */
    data class HingeSignals(val declared: Boolean, val sensor: Boolean, val pc: Boolean = false) {
        val foldable: Boolean get() = !pc && (declared || sensor)
    }

    /**
     * 판정 답.
     * - [foldable]: 폴더블 기기인지 (위 1·2·3 중 하나라도 있음)
     * - [fold]: 창 배치 정보 첫 값에 접히는 부분이 있었는지. 첫 값을 받지 못했으면(제한 시간 초과·구독 실패·취소) `null`.
     *   `true`면 Flutter `displayFeatures`에도 곧 접히는 부분이 온다 — Dart가 그때까지 첫 화면을 미룬다.
     */
    data class Answer(val foldable: Boolean, val fold: Boolean?) {
        /** 채널로 보내는 값 (Dart `FormFactor.queryFoldableDevice`가 읽는다) */
        fun toChannelValue(): Map<String, Any?> = mapOf(KEY_FOLDABLE to foldable, KEY_FOLD to fold)

        override fun toString(): String =
            "폴더블=$foldable, 접힘=${when (fold) { true -> "있음"; false -> "없음"; null -> "모름" }}"
    }

    private val queries = mutableListOf<Query>()

    /** 답을 기다리거나(구독 중) 답한 뒤 진단 로그를 남기는 판정 수 */
    @VisibleForTesting
    val activeCount: Int get() = queries.size

    /** 답을 기다리는 판정 수 */
    @VisibleForTesting
    val pendingCount: Int get() = queries.count { !it.answered }

    /**
     * 판정해 [reply]로 한 번 답한다. 메인 스레드에서 부른다(답도 메인 스레드에서 한다).
     * 여러 번 불러도(핫 리스타트 등) 각각 따로 답한다.
     */
    fun query(reply: (Answer) -> Unit) {
        val hinge = runCatching(hingeSignals).getOrElse { error ->
            Log.w(LOG_TAG, "힌지 신호 조회 실패", error)
            HingeSignals(declared = false, sensor = false)
        }
        val query = Query(hinge, reply)
        val unsubscribe = try {
            layoutSource.subscribe { hasFold -> handler.post { query.onLayout(hasFold) } }
        } catch (error: RuntimeException) {
            query.failSubscribe(error)
            return
        } catch (error: LinkageError) {
            // 이 호출 안에서 나는 동기 실패만 잡는다(앱에 실린 androidx.window 클래스를 못 읽는 경우 등). OEM 확장 등록은
            // 라이브러리가 나중에 메인 스레드 코루틴에서 하므로 그 실패는 여기로 오지 않는다(Flutter 엔진의 구독도 같다).
            query.failSubscribe(error)
            return
        }
        query.start(unsubscribe)
    }

    /**
     * 답을 기다리는 판정을 모두 첫 값 없이(1·2만으로) 답하고, 진단 중인 것까지 모든 구독을 푼다. 엔진
     * 정리 때 부른다 — 끝난 액티비티를 창 배치 구독이 붙들지 않게 하고, 캐시 엔진의 Dart 쪽이 제한 시간까지 기다리지
     * 않게 한다(Dart는 화면 정보로 다시 판정한다).
     */
    fun cancel() {
        for (query in queries.toList()) query.cancel()
    }

    private inner class Query(val hinge: HingeSignals, val reply: (Answer) -> Unit) {
        private val startedAt = SystemClock.uptimeMillis()
        private var unsubscribe: (() -> Unit)? = null
        private var answer: Answer? = null
        val answered: Boolean get() = answer != null

        private val timeout = Runnable { answer(null, "제한 시간 초과") }
        private val endDiagnostics = Runnable { close() }

        private val elapsed: Long get() = SystemClock.uptimeMillis() - startedAt

        /** 마지막으로 받은 창 배치 값 (아직 없으면 `null`) — 진단 로그는 이 값과 달라질 때만 남긴다 */
        private var lastLayout: Boolean? = null

        fun start(unsubscribe: () -> Unit) {
            this.unsubscribe = unsubscribe
            queries += this
            handler.postDelayed(timeout, layoutTimeoutMillis)
        }

        fun failSubscribe(error: Throwable) {
            Log.w(LOG_TAG, "창 배치 정보 구독 실패", error)
            val result = Answer(hinge.foldable, fold = null)
            log(hinge, "구독 실패", elapsed, result)
            reply(result)
        }

        fun onLayout(hasFold: Boolean) {
            if (unsubscribe == null) return // 이미 끝남
            val previous = lastLayout
            lastLayout = hasFold
            when {
                !answered -> answer(hasFold, describe(hasFold))
                // 진단: 제한 시간이 지난 뒤에야 첫 값이 왔다 (#158)
                previous == null -> Log.i(LOG_TAG, "폴더블 판정 뒤 창 배치 첫 값 접힘=${describe(hasFold)} (${elapsed}ms)")
                // 진단: 앞 값과 다른 값이 뒤에 왔다 — 첫 값을 답으로 쓰는 규칙을 다시 볼 근거 (#158)
                previous != hasFold ->
                    Log.i(LOG_TAG, "폴더블 판정 뒤 창 배치 접힘=${describe(hasFold)} (${elapsed}ms, 앞 값=${describe(previous)})")
            }
        }

        /** [fold]가 `null`이면 첫 값을 받지 못한 것이다([layout]이 까닭). */
        private fun answer(fold: Boolean?, layout: String) {
            if (answered || unsubscribe == null) return
            val result = Answer(foldable = hinge.foldable || fold == true, fold = fold)
            answer = result
            handler.removeCallbacks(timeout)
            log(hinge, layout, elapsed, result)
            reply(result)
            handler.postDelayed(endDiagnostics, diagnosticMillis)
        }

        fun cancel() {
            if (!answered) answer(null, "취소")
            close()
        }

        private fun close() {
            handler.removeCallbacks(timeout)
            handler.removeCallbacks(endDiagnostics)
            unsubscribe?.invoke()
            unsubscribe = null
            queries -= this
        }
    }

    private fun describe(hasFold: Boolean) = if (hasFold) "접힘" else "없음"

    private fun log(hinge: HingeSignals, layout: String, elapsedMillis: Long, result: Answer) {
        Log.i(
            LOG_TAG,
            "폴더블 판정: 기능 선언=${hinge.declared}, 센서=${hinge.sensor}, ChromeOS=${hinge.pc}, " +
                "창 배치 첫 값 접힘=$layout (${elapsedMillis}ms) → $result",
        )
    }

    companion object {
        /** [Answer] 채널 값의 키 — Dart `FormFactor.queryFoldableDevice`와 같아야 한다(`main_activity_source_test.dart`가 대조) */
        const val KEY_FOLDABLE = "foldable"

        /** [Answer] 채널 값의 키 */
        const val KEY_FOLD = "fold"

        /**
         * 창 배치 정보 첫 값을 기다리는 최대 시간 (ms). Dart 쪽 채널 제한 시간(`FormFactor.foldableQueryTimeout`)보다
         * 넉넉히 짧아야 한다 — `test/unit/main_activity_source_test.dart`가 대조한다.
         */
        const val LAYOUT_TIMEOUT_MILLIS = 500L

        /** 답한 뒤 진단 로그를 위해 창 배치 구독을 유지하는 시간 (ms, 구독 시작이 아니라 답한 때부터) */
        const val DIAGNOSTIC_MILLIS = 3000L

        /** 판정 로그 태그 */
        const val LOG_TAG = "AltCalc"

        /** [context]의 힌지 신호 (1·2). API 29 이하는 둘 다 없다(기능·센서 종류가 API 30에 생겼다). */
        fun hingeSignalsOf(context: Context): HingeSignals {
            val pc = context.packageManager.hasSystemFeature(PackageManager.FEATURE_PC)
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return HingeSignals(declared = false, sensor = false, pc = pc)
            val declared = context.packageManager.hasSystemFeature(PackageManager.FEATURE_SENSOR_HINGE_ANGLE)
            val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
            val sensor = sensorManager?.getSensorList(Sensor.TYPE_HINGE_ANGLE)?.isNotEmpty() == true
            return HingeSignals(declared, sensor, pc)
        }
    }
}

/** 창 배치 정보에서 접히는 부분 유무를 받는 곳. [subscribe]는 구독을 푸는 함수를 돌려준다. */
internal fun interface FoldingLayoutSource {
    /** 창 배치 정보가 올 때마다 [onLayout]을 부른다(접히는 부분이 있으면 true). 어느 스레드에서 불러도 된다. */
    fun subscribe(onLayout: (hasFold: Boolean) -> Unit): () -> Unit
}

/** [activity] 창의 Jetpack WindowManager 창 배치 정보 (Flutter 엔진이 `displayFeatures`를 만드는 것과 같은 출처) */
internal class WindowLayoutFoldingSource(private val activity: Activity) : FoldingLayoutSource {
    override fun subscribe(onLayout: (hasFold: Boolean) -> Unit): () -> Unit {
        val tracker = WindowInfoTrackerCallbackAdapter(WindowInfoTracker.getOrCreate(activity))
        val consumer = Consumer<WindowLayoutInfo> { info ->
            onLayout(info.displayFeatures.any { it is FoldingFeature })
        }
        // 직접 실행 — 받은 쪽([FoldableDeviceProbe])이 메인 스레드로 넘긴다
        tracker.addWindowLayoutInfoListener(activity, Executor { it.run() }, consumer)
        return { tracker.removeWindowLayoutInfoListener(consumer) }
    }
}
