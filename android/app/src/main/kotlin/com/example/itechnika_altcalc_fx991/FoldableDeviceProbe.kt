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
import androidx.core.util.Consumer
import androidx.window.java.layout.WindowInfoTrackerCallbackAdapter
import androidx.window.layout.FoldingFeature
import androidx.window.layout.WindowInfoTracker
import androidx.window.layout.WindowLayoutInfo
import java.util.concurrent.Executor

/**
 * 앱 시작 시점의 폴더블 기기 판정 (#24, 보강 #70). Dart `FormFactor.queryFoldableDevice`가 `altcalc/device`
 * 채널의 `isFoldableDevice`로 부른다. Dart `main()`이 이 답을 기다린 뒤 첫 화면을 띄우므로, 기다리는 동안은
 * Android 시작 화면(스플래시)이 그대로 남는다.
 *
 * 아래 신호 중 하나라도 있으면 폴더블이다.
 * 1. 힌지 각도 센서 **기능 선언** (`FEATURE_SENSOR_HINGE_ANGLE`, API 30+) — 제조사가 선언해야만 보고된다.
 * 2. 힌지 각도 **센서 자체** (`Sensor.TYPE_HINGE_ANGLE`, API 30+) — 기능은 선언하지 않고 센서만 싣는 기기 대비.
 * 3. 창 배치 정보(Jetpack WindowManager `WindowLayoutInfo`)의 **첫 값**에 접히는 부분(`FoldingFeature`)이 있음 —
 *    Samsung처럼 OEM 확장으로 접힘 정보만 주는 기기 대비. 창이 붙은 뒤에야 오므로 [layoutTimeoutMillis]까지만
 *    기다린다. Flutter `displayFeatures`도 같은 정보에서 오지만 Dart 쪽에서는 "아직 안 옴"과 "없음"을 구분하지
 *    못한다 — 여기서는 구독 뒤 첫 값이 곧 그 순간의 답이다(접힘 정보가 없는 기기도 빈 값을 한 번 보낸다).
 *
 * 1·2가 있으면 기다리지 않고 바로 답한다. 3을 기다리는 시간은 대개 창이 붙을 때까지이고, 첫 프레임은 어차피 창이
 * 붙어야 그려지므로 시작이 그만큼 늦어지지 않는다.
 *
 * 한계 (실기기 확인 전 — #70):
 * - 접은 커버 화면에서 시작하면 3은 "없음"이다(창이 접힘선에 걸치지 않는다). 1·2도 없는 기기는 폰으로 판정되고,
 *   처음 펼칠 때 접힘 정보가 오기 전 몇 프레임 동안 태블릿으로 판정될 수 있다 — Dart `DeviceOrientationLock`이
 *   접힘 정보를 한 번 보면 그 뒤로는 폴더블로 기억한다.
 * - 펼친 내부 화면이라도 분할 화면·팝업 창처럼 창이 접힘선에 걸치지 않으면 3은 "없음"이다.
 *
 * 판정마다 신호별 값과 걸린 시간을 로그(태그 [LOG_TAG])로 남긴다 — 실기기 확인 때 `adb logcat -s AltCalc`로 읽는다.
 */
internal class FoldableDeviceProbe(
    private val hingeSignals: () -> HingeSignals,
    private val layoutSource: FoldingLayoutSource,
    private val handler: Handler = Handler(Looper.getMainLooper()),
    private val layoutTimeoutMillis: Long = LAYOUT_TIMEOUT_MILLIS,
) {
    /** 시작 즉시 알 수 있는 힌지 신호 (위 1·2) */
    data class HingeSignals(val declared: Boolean, val sensor: Boolean) {
        val any: Boolean get() = declared || sensor
    }

    private val pending = mutableListOf<Query>()

    /** 답을 기다리는 판정 수 (테스트용) */
    val pendingCount: Int get() = pending.size

    /**
     * 판정해 [reply]로 한 번 답한다. 메인 스레드에서 부른다(답도 메인 스레드에서 한다).
     * 여러 번 불러도(핫 리스타트 등) 각각 따로 답한다.
     */
    fun query(reply: (Boolean) -> Unit) {
        val hinge = runCatching(hingeSignals).getOrElse { error ->
            Log.w(LOG_TAG, "힌지 신호 조회 실패", error)
            HingeSignals(declared = false, sensor = false)
        }
        if (hinge.any) {
            log(hinge, layout = "기다리지 않음", elapsedMillis = 0, result = true)
            reply(true)
            return
        }
        val query = Query(hinge, reply)
        pending += query
        val unsubscribe = try {
            layoutSource.subscribe { hasFold -> handler.post { query.finish(hasFold, if (hasFold) "접힘" else "없음") } }
        } catch (error: RuntimeException) {
            Log.w(LOG_TAG, "창 배치 정보 구독 실패", error)
            query.finish(false, "구독 실패")
            return
        }
        query.attach(unsubscribe)
        if (!query.done) handler.postDelayed(query.timeout, layoutTimeoutMillis)
    }

    /**
     * 답을 기다리는 판정을 모두 "폴더블 아님"(1·2가 없었으므로)으로 답하고 구독을 푼다. 엔진 정리 때 부른다 —
     * 끝난 액티비티를 창 배치 구독이 붙들지 않게 하고, 캐시 엔진의 Dart 쪽이 제한 시간까지 기다리지 않게 한다.
     */
    fun cancel() {
        for (query in pending.toList()) query.finish(false, "취소")
    }

    private inner class Query(val hinge: HingeSignals, val reply: (Boolean) -> Unit) {
        private val startedAt = SystemClock.uptimeMillis()
        private var unsubscribe: (() -> Unit)? = null
        var done = false
            private set

        val timeout = Runnable { finish(false, "제한 시간 초과") }

        /** 구독을 붙인다. 구독 중 이미 끝났으면(동기 응답 등) 바로 푼다. */
        fun attach(unsubscribe: () -> Unit) {
            if (done) unsubscribe() else this.unsubscribe = unsubscribe
        }

        fun finish(hasFold: Boolean, layout: String) {
            if (done) return
            done = true
            pending -= this
            handler.removeCallbacks(timeout)
            unsubscribe?.invoke()
            unsubscribe = null
            log(hinge, layout, SystemClock.uptimeMillis() - startedAt, hasFold)
            reply(hasFold)
        }
    }

    private fun log(hinge: HingeSignals, layout: String, elapsedMillis: Long, result: Boolean) {
        Log.i(
            LOG_TAG,
            "폴더블 판정: 기능 선언=${hinge.declared}, 센서=${hinge.sensor}, 창 배치 접힘=$layout " +
                "(${elapsedMillis}ms) → $result",
        )
    }

    companion object {
        /**
         * 창 배치 정보 첫 값을 기다리는 최대 시간 (ms). Dart 쪽 채널 제한 시간(`FormFactor.foldableQueryTimeout`)보다
         * 넉넉히 짧아야 한다 — `test/unit/main_activity_source_test.dart`가 대조한다.
         */
        const val LAYOUT_TIMEOUT_MILLIS = 500L

        /** 판정 로그 태그 */
        const val LOG_TAG = "AltCalc"

        /** [context]의 힌지 신호 (1·2). API 29 이하는 둘 다 없다(기능·센서 종류가 API 30에 생겼다). */
        fun hingeSignalsOf(context: Context): HingeSignals {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return HingeSignals(declared = false, sensor = false)
            val declared = context.packageManager.hasSystemFeature(PackageManager.FEATURE_SENSOR_HINGE_ANGLE)
            val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
            val sensor = sensorManager?.getDefaultSensor(Sensor.TYPE_HINGE_ANGLE) != null
            return HingeSignals(declared, sensor)
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
