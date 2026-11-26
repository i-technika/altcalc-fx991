package com.example.itechnika_altcalc_fx991

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.window.layout.WindowLayoutInfo
import androidx.window.testing.layout.FoldingFeature
import androidx.window.testing.layout.WindowLayoutInfoPublisherRule
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLog
import org.robolectric.shadows.ShadowSensor
import java.time.Duration

/**
 * 시작 시 폴더블 판정 (#70) — [FoldableDeviceProbe]의 신호 조합·기다림·정리 규칙과 실제 창 배치 정보 출처의 연결.
 * 판정 규칙은 창 배치 정보를 [FakeFoldingLayoutSource]로 흉내 내고, 기다림은 Robolectric 메인 루퍼 시계로 돌린다.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [FIRST_PUBLIC_API_SDK])
class FoldableDeviceProbeTest {
    /** Jetpack WindowManager가 내보내는 창 배치 정보를 테스트가 정한다 ([WindowLayoutFoldingSource] 검사용) */
    @get:Rule
    val publisher = WindowLayoutInfoPublisherRule()

    private val layout = FakeFoldingLayoutSource()
    private val replies = mutableListOf<FoldableDeviceProbe.Answer>()

    private fun probe(declared: Boolean = false, sensor: Boolean = false, pc: Boolean = false) = FoldableDeviceProbe(
        hingeSignals = { FoldableDeviceProbe.HingeSignals(declared, sensor, pc) },
        layoutSource = layout,
        handler = Handler(Looper.getMainLooper()),
    )

    private fun answer(foldable: Boolean, fold: Boolean?) = FoldableDeviceProbe.Answer(foldable, fold)

    private fun idle() = shadowOf(Looper.getMainLooper()).idle()

    private fun idleFor(millis: Long) = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(millis))

    private fun logs(): List<String> = ShadowLog.getLogsForTag(FoldableDeviceProbe.LOG_TAG).map { it.msg }

    // ---- 판정 규칙 ----

    @Test
    fun `힌지 기능 선언이나 센서가 있어도 창 배치 정보 첫 값을 기다려 접힘과 함께 답한다 (#158)`() {
        for ((declared, sensor) in listOf(true to false, false to true, true to true)) {
            for (hasFold in listOf(true, false)) {
                replies.clear()
                probe(declared, sensor).query { replies += it }
                assertTrue("첫 값 전에는 답하지 않는다", replies.isEmpty())

                layout.emit(hasFold)
                idle()

                assertEquals("declared=$declared sensor=$sensor fold=$hasFold", listOf(answer(true, hasFold)), replies)
            }
        }
    }

    @Test
    fun `힌지 신호가 있는데 창 배치 정보가 오지 않으면 제한 시간에 폴더블로, 접힘은 모름으로 답한다`() {
        probe(sensor = true).query { replies += it }

        idleFor(FoldableDeviceProbe.LAYOUT_TIMEOUT_MILLIS - 1)
        assertTrue(replies.isEmpty())
        idleFor(1)

        assertEquals(listOf(answer(true, null)), replies)
    }

    @Test
    fun `힌지 신호가 있는데 창 배치 정보 구독이 실패하면 바로 폴더블로, 접힘은 모름으로 답한다`() {
        layout.failure = IllegalStateException("구독 실패 (테스트)")
        val probe = probe(declared = true)
        probe.query { replies += it }

        assertEquals(listOf(answer(true, null)), replies)
        assertEquals(0, probe.activeCount)
    }

    @Test
    fun `cancel - 힌지 신호가 있으면 기다리던 판정에 폴더블로 답한다`() {
        val probe = probe(declared = true)
        probe.query { replies += it }

        probe.cancel()

        assertEquals(listOf(answer(true, null)), replies)
        assertEquals(0, layout.activeCount)
    }

    @Test
    fun `ChromeOS에서는 힌지 신호를 쓰지 않고 창 배치 정보로 판정한다`() {
        probe(declared = true, sensor = true, pc = true).query { replies += it }
        assertTrue(replies.isEmpty())

        layout.emit(false)
        idle()

        assertEquals(listOf(answer(false, false)), replies)
    }

    @Test
    fun `힌지 신호가 없으면 창 배치 정보 첫 값에 접히는 부분이 있는지로 답한다`() {
        for (hasFold in listOf(true, false)) {
            replies.clear()
            probe().query { replies += it }
            assertTrue("첫 값 전에는 답하지 않는다", replies.isEmpty())

            layout.emit(hasFold)
            idle()

            assertEquals(listOf(answer(hasFold, hasFold)), replies)
        }
    }

    @Test
    fun `판정 로그에 신호별 값과 결과를 남긴다`() {
        probe(sensor = true).query { replies += it }
        layout.emit(true)
        idle()

        assertTrue(
            logs().toString(),
            logs().any {
                it.startsWith("폴더블 판정: 기능 선언=false, 센서=true, ChromeOS=false, 창 배치 첫 값 접힘=접힘 (") &&
                    it.endsWith("→ 폴더블=true, 접힘=있음")
            },
        )
    }

    @Test
    fun `채널 값 - 폴더블 여부와 첫 값 접힘(모르면 null)을 map으로 보낸다`() {
        assertEquals(
            mapOf(FoldableDeviceProbe.KEY_FOLDABLE to true, FoldableDeviceProbe.KEY_FOLD to null),
            answer(true, null).toChannelValue(),
        )
        assertEquals(
            mapOf(FoldableDeviceProbe.KEY_FOLDABLE to false, FoldableDeviceProbe.KEY_FOLD to false),
            answer(false, false).toChannelValue(),
        )
    }

    @Test
    fun `답한 뒤 진단 시간 동안 구독을 유지하고, 지나면 푼다`() {
        val probe = probe()
        probe.query { replies += it }
        layout.emit(false)
        idle()
        assertEquals(0, probe.pendingCount)
        assertEquals("진단용으로 구독 유지", 1, layout.activeCount)

        idleFor(FoldableDeviceProbe.DIAGNOSTIC_MILLIS - 1)
        assertEquals(1, layout.activeCount)
        idleFor(1)

        assertEquals(0, layout.activeCount)
        assertEquals(0, probe.activeCount)
    }

    @Test
    fun `첫 값만 답이다 - 뒤에 앞 값과 다른 값이 올 때만 로그로 남긴다`() {
        probe(declared = true).query { replies += it }

        layout.emit(false)
        layout.emit(false)
        layout.emit(true)
        layout.emit(true)
        idle()

        assertEquals("힌지 신호로 폴더블, 접힘은 첫 값", listOf(answer(true, false)), replies)
        val later = logs().filter { it.startsWith("폴더블 판정 뒤") }
        // 힌지 신호가 있어도 답(폴더블=true)이 아니라 앞 창 배치 값과 비교한다 — 같은 값이 이어지면 남기지 않는다
        assertEquals("바뀐 때만 한 번: $later", 1, later.size)
        assertTrue(later.single(), later.single().startsWith("폴더블 판정 뒤 창 배치 접힘=접힘 ("))
        assertTrue(later.single(), later.single().endsWith("앞 값=없음)"))
    }

    @Test
    fun `구독하는 동안 바로 값이 와도 구독을 마친 뒤 답한다`() {
        layout.emitOnSubscribe = true
        probe().query { replies += it }
        assertTrue("구독 함수 안에서는 답하지 않는다", replies.isEmpty())

        idle()
        assertEquals(listOf(answer(true, true)), replies)
        idleFor(FoldableDeviceProbe.DIAGNOSTIC_MILLIS)
        assertEquals(0, layout.activeCount)
    }

    @Test
    fun `창 배치 정보가 오지 않으면 제한 시간에 폴더블 아님, 접힘 모름으로 답한다`() {
        val probe = probe()
        probe.query { replies += it }

        idleFor(FoldableDeviceProbe.LAYOUT_TIMEOUT_MILLIS - 1)
        assertTrue("제한 시간 전에는 답하지 않는다", replies.isEmpty())

        idleFor(1)
        assertEquals(listOf(answer(false, null)), replies)
        assertEquals(0, probe.pendingCount)

        // 늦게 온 첫 값은 답을 바꾸지 않는다(진단 로그만)
        layout.emit(true)
        idle()
        assertEquals(listOf(answer(false, null)), replies)
        assertTrue(logs().toString(), logs().any { it.startsWith("폴더블 판정 뒤 창 배치 첫 값 접힘=접힘") })
        idleFor(FoldableDeviceProbe.DIAGNOSTIC_MILLIS)
        assertEquals(0, layout.activeCount)
    }

    @Test
    fun `답한 뒤에는 제한 시간이 지나도 다시 답하지 않는다`() {
        probe().query { replies += it }
        layout.emit(true)
        idle()

        idleFor(FoldableDeviceProbe.LAYOUT_TIMEOUT_MILLIS * 2)

        assertEquals(listOf(answer(true, true)), replies)
    }

    @Test
    fun `창 배치 정보 구독이 실패하면 기다리지 않고 답한다 - 링크 오류도 잡는다`() {
        for (error in listOf<Throwable>(IllegalStateException("구독 실패 (테스트)"), NoClassDefFoundError("확장 없음 (테스트)"))) {
            replies.clear()
            layout.failure = error
            val probe = probe()
            probe.query { replies += it }

            assertEquals(error.toString(), listOf(answer(false, null)), replies)
            assertEquals(0, probe.activeCount)
        }
    }

    @Test
    fun `힌지 신호 조회가 실패하면 창 배치 정보로 판정한다`() {
        FoldableDeviceProbe(
            hingeSignals = { throw SecurityException("조회 거부 (테스트)") },
            layoutSource = layout,
            handler = Handler(Looper.getMainLooper()),
        ).query { replies += it }

        layout.emit(true)
        idle()

        assertEquals(listOf(answer(true, true)), replies)
    }

    @Test
    fun `여러 번 부르면 각각 따로 구독하고 답한다`() {
        val probe = probe()
        val first = mutableListOf<FoldableDeviceProbe.Answer>()
        val second = mutableListOf<FoldableDeviceProbe.Answer>()
        probe.query { first += it }
        probe.query { second += it }
        assertEquals(2, layout.activeCount)

        layout.emit(true)
        idle()

        assertEquals(listOf(answer(true, true)), first)
        assertEquals(listOf(answer(true, true)), second)
    }

    @Test
    fun `cancel - 기다리는 판정에 답하고 구독을 풀며, 뒤에 오는 값과 제한 시간은 무시한다`() {
        val probe = probe()
        probe.query { replies += it }

        probe.cancel()

        assertEquals(listOf(answer(false, null)), replies)
        assertEquals(0, layout.activeCount)
        assertEquals(0, probe.activeCount)
        layout.emit(true)
        idleFor(FoldableDeviceProbe.LAYOUT_TIMEOUT_MILLIS * 2)
        assertEquals(listOf(answer(false, null)), replies)
        // 거듭 불러도 안전하다
        probe.cancel()
        assertEquals(listOf(answer(false, null)), replies)
    }

    @Test
    fun `cancel - 답한 뒤 진단 중인 구독도 푼다`() {
        val probe = probe()
        probe.query { replies += it }
        layout.emit(true)
        idle()
        assertEquals(1, layout.activeCount)

        probe.cancel()

        assertEquals("다시 답하지 않는다", listOf(answer(true, true)), replies)
        assertEquals(0, layout.activeCount)
        assertEquals(0, probe.activeCount)
    }

    // ---- 실제 창 배치 정보 출처 (WindowLayoutFoldingSource) ----

    @Test
    fun `실제 출처 - 창 배치 정보의 FoldingFeature 유무를 그대로 알리고, 구독을 풀면 더 알리지 않는다`() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val seen = mutableListOf<Boolean>()
        val unsubscribe = WindowLayoutFoldingSource(activity).subscribe { seen += it }
        idle()

        publisher.overrideWindowLayoutInfo(WindowLayoutInfo(listOf(FoldingFeature(activity))))
        idle()
        publisher.overrideWindowLayoutInfo(WindowLayoutInfo(emptyList()))
        idle()
        assertEquals(listOf(true, false), seen)

        unsubscribe()
        publisher.overrideWindowLayoutInfo(WindowLayoutInfo(listOf(FoldingFeature(activity))))
        idle()
        assertEquals(listOf(true, false), seen)
    }

    @Test
    fun `실제 출처로 판정하면 힌지 신호가 있어도 첫 값을 기다려 답하고 로그에 창 배치 값이 남는다`() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        FoldableDeviceProbe(
            hingeSignals = { FoldableDeviceProbe.HingeSignals(declared = true, sensor = false) },
            layoutSource = WindowLayoutFoldingSource(activity),
            handler = Handler(Looper.getMainLooper()),
        ).query { replies += it }
        idle()

        publisher.overrideWindowLayoutInfo(WindowLayoutInfo(listOf(FoldingFeature(activity))))
        idle()

        assertEquals(listOf(answer(true, true)), replies)
        assertTrue(logs().toString(), logs().any { it.contains("창 배치 첫 값 접힘=접힘") })
    }

    // ---- 힌지 신호 (실제 시스템 값) ----

    private val context: Context get() = RuntimeEnvironment.getApplication()

    private fun declareHingeFeature() =
        shadowOf(context.packageManager).setSystemFeature(PackageManager.FEATURE_SENSOR_HINGE_ANGLE, true)

    private fun addHingeSensor(wakeUp: Boolean = false) {
        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensor = ShadowSensor.newInstance(Sensor.TYPE_HINGE_ANGLE)
        shadowOf(sensor).setWakeUpFlag(wakeUp)
        shadowOf(sensorManager).addSensor(sensor)
    }

    private fun signals(declared: Boolean, sensor: Boolean) = FoldableDeviceProbe.HingeSignals(declared, sensor)

    @Test
    @Config(sdk = [Build.VERSION_CODES.R, FIRST_PUBLIC_API_SDK])
    fun `hingeSignalsOf - API 30 이상은 기능 선언과 센서를 따로 읽는다`() {
        assertEquals(signals(declared = false, sensor = false), FoldableDeviceProbe.hingeSignalsOf(context))

        addHingeSensor()
        assertEquals(signals(declared = false, sensor = true), FoldableDeviceProbe.hingeSignalsOf(context))

        declareHingeFeature()
        assertEquals(signals(declared = true, sensor = true), FoldableDeviceProbe.hingeSignalsOf(context))
    }

    @Test
    @Config(sdk = [Build.VERSION_CODES.R, FIRST_PUBLIC_API_SDK])
    fun `hingeSignalsOf - wake-up 힌지 센서만 있어도 센서로 본다`() {
        // 실제 프레임워크의 getDefaultSensor는 API 36부터 이 종류를 wake-up 센서로만 찾는다 — 목록을 쓰므로 둘 다 센다.
        // (Robolectric 섀도가 센서 목록을 대신 구현하므로 프레임워크 분기 자체는 여기서 볼 수 없다.)
        addHingeSensor(wakeUp = true)
        assertEquals(signals(declared = false, sensor = true), FoldableDeviceProbe.hingeSignalsOf(context))
    }

    @Test
    @Config(sdk = [Build.VERSION_CODES.R])
    fun `hingeSignalsOf - 기능 선언만 있어도 읽는다`() {
        declareHingeFeature()
        assertEquals(signals(declared = true, sensor = false), FoldableDeviceProbe.hingeSignalsOf(context))
    }

    @Test
    @Config(sdk = [MIN_SDK, Build.VERSION_CODES.Q])
    fun `hingeSignalsOf - API 29 이하는 기능 선언이 있어도 둘 다 없다`() {
        declareHingeFeature()
        assertEquals(signals(declared = false, sensor = false), FoldableDeviceProbe.hingeSignalsOf(context))
    }

    @Test
    @Config(sdk = [MIN_SDK, FIRST_PUBLIC_API_SDK])
    fun `hingeSignalsOf - ChromeOS(FEATURE_PC)를 함께 알려 힌지 신호를 쓰지 않게 한다`() {
        shadowOf(context.packageManager).setSystemFeature(PackageManager.FEATURE_PC, true)
        declareHingeFeature()

        val hinge = FoldableDeviceProbe.hingeSignalsOf(context)

        assertTrue(hinge.pc)
        assertFalse(hinge.foldable)
    }
}

/** 창 배치 정보를 흉내 내는 [FoldingLayoutSource]. [emit]으로 지금 구독한 모두에게 값을 보낸다. */
internal class FakeFoldingLayoutSource : FoldingLayoutSource {
    private val listeners = mutableListOf<(Boolean) -> Unit>()

    /** 지금까지 구독한 횟수 */
    var subscribeCount = 0
        private set

    /** 지금 구독 중인 수 */
    val activeCount: Int get() = listeners.size

    /** true면 구독하는 즉시(구독 함수 안에서) 접힘 있음을 보낸다 */
    var emitOnSubscribe = false

    /** 있으면 구독할 때 이 오류를 던진다 */
    var failure: Throwable? = null

    override fun subscribe(onLayout: (hasFold: Boolean) -> Unit): () -> Unit {
        failure?.let { throw it }
        subscribeCount++
        listeners += onLayout
        if (emitOnSubscribe) onLayout(true)
        return { listeners -= onLayout }
    }

    fun emit(hasFold: Boolean) {
        for (listener in listeners.toList()) listener(hasFold)
    }
}
