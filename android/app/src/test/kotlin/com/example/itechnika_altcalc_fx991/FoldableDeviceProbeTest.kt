package com.example.itechnika_altcalc_fx991

import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowSensor
import java.time.Duration

/**
 * 시작 시 폴더블 판정 (#70) — [FoldableDeviceProbe]의 신호 조합·기다림·정리 규칙.
 * 창 배치 정보는 [FakeFoldingLayoutSource]로 흉내 내고, 기다림은 Robolectric 메인 루퍼 시계로 돌린다.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [FIRST_PUBLIC_API_SDK])
class FoldableDeviceProbeTest {
    private val layout = FakeFoldingLayoutSource()
    private val replies = mutableListOf<Boolean>()

    private fun probe(declared: Boolean = false, sensor: Boolean = false) = FoldableDeviceProbe(
        hingeSignals = { FoldableDeviceProbe.HingeSignals(declared, sensor) },
        layoutSource = layout,
        handler = Handler(Looper.getMainLooper()),
    )

    private fun idle() = shadowOf(Looper.getMainLooper()).idle()

    private fun idleFor(millis: Long) = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(millis))

    @Test
    fun `힌지 기능 선언이나 센서가 있으면 창 배치 정보를 기다리지 않고 바로 true`() {
        for ((declared, sensor) in listOf(true to false, false to true, true to true)) {
            replies.clear()
            probe(declared, sensor).query { replies += it }
            assertEquals("declared=$declared sensor=$sensor", listOf(true), replies)
        }
        assertEquals("구독하지 않는다", 0, layout.subscribeCount)
    }

    @Test
    fun `힌지 신호가 없으면 창 배치 정보 첫 값에 접히는 부분이 있는지로 답하고 구독을 푼다`() {
        for (hasFold in listOf(true, false)) {
            replies.clear()
            probe().query { replies += it }
            assertTrue("첫 값 전에는 답하지 않는다", replies.isEmpty())

            layout.emit(hasFold)
            idle()

            assertEquals(listOf(hasFold), replies)
            assertEquals(0, layout.activeCount)
        }
    }

    @Test
    fun `첫 값만 답이다 - 뒤에 오는 값은 무시하고 한 번만 답한다`() {
        val probe = probe()
        probe.query { replies += it }

        layout.emit(false)
        layout.emit(true)
        idle()

        assertEquals(listOf(false), replies)
        assertEquals(0, probe.pendingCount)
    }

    @Test
    fun `구독하는 동안 바로 값이 와도 답하고 구독을 푼다`() {
        layout.emitOnSubscribe = true
        probe().query { replies += it }
        idle()

        assertEquals(listOf(true), replies)
        assertEquals(0, layout.activeCount)
    }

    @Test
    fun `창 배치 정보가 오지 않으면 제한 시간에 false로 답하고 구독을 푼다`() {
        val probe = probe()
        probe.query { replies += it }

        idleFor(FoldableDeviceProbe.LAYOUT_TIMEOUT_MILLIS - 1)
        assertTrue("제한 시간 전에는 답하지 않는다", replies.isEmpty())

        idleFor(1)
        assertEquals(listOf(false), replies)
        assertEquals(0, layout.activeCount)
        assertEquals(0, probe.pendingCount)

        // 늦게 온 값은 무시한다
        layout.emit(true)
        idle()
        assertEquals(listOf(false), replies)
    }

    @Test
    fun `답한 뒤에는 제한 시간이 지나도 다시 답하지 않는다`() {
        probe().query { replies += it }
        layout.emit(true)
        idle()

        idleFor(FoldableDeviceProbe.LAYOUT_TIMEOUT_MILLIS * 2)

        assertEquals(listOf(true), replies)
    }

    @Test
    fun `창 배치 정보 구독이 실패하면 기다리지 않고 false`() {
        layout.failOnSubscribe = true
        probe().query { replies += it }

        assertEquals(listOf(false), replies)
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

        assertEquals(listOf(true), replies)
    }

    @Test
    fun `여러 번 부르면 각각 따로 구독하고 답한다`() {
        val probe = probe()
        val first = mutableListOf<Boolean>()
        val second = mutableListOf<Boolean>()
        probe.query { first += it }
        probe.query { second += it }
        assertEquals(2, layout.activeCount)

        layout.emit(true)
        idle()

        assertEquals(listOf(true), first)
        assertEquals(listOf(true), second)
        assertEquals(0, layout.activeCount)
    }

    @Test
    fun `cancel - 기다리는 판정에 false로 답하고 구독을 풀며, 뒤에 오는 값과 제한 시간은 무시한다`() {
        val probe = probe()
        probe.query { replies += it }

        probe.cancel()

        assertEquals(listOf(false), replies)
        assertEquals(0, layout.activeCount)
        layout.emit(true)
        idleFor(FoldableDeviceProbe.LAYOUT_TIMEOUT_MILLIS * 2)
        assertEquals(listOf(false), replies)
        // 거듭 불러도 안전하다
        probe.cancel()
        assertEquals(listOf(false), replies)
    }

    // ---- 힌지 신호 (실제 시스템 값) ----

    private val context: Context get() = RuntimeEnvironment.getApplication()

    private fun declareHingeFeature() =
        shadowOf(context.packageManager).setSystemFeature(PackageManager.FEATURE_SENSOR_HINGE_ANGLE, true)

    private fun addHingeSensor() {
        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        shadowOf(sensorManager).addSensor(ShadowSensor.newInstance(Sensor.TYPE_HINGE_ANGLE))
    }

    @Test
    @Config(sdk = [Build.VERSION_CODES.R, FIRST_PUBLIC_API_SDK])
    fun `hingeSignalsOf - API 30 이상은 기능 선언과 센서를 따로 읽는다`() {
        assertEquals(FoldableDeviceProbe.HingeSignals(declared = false, sensor = false), FoldableDeviceProbe.hingeSignalsOf(context))

        addHingeSensor()
        assertEquals(FoldableDeviceProbe.HingeSignals(declared = false, sensor = true), FoldableDeviceProbe.hingeSignalsOf(context))

        declareHingeFeature()
        assertEquals(FoldableDeviceProbe.HingeSignals(declared = true, sensor = true), FoldableDeviceProbe.hingeSignalsOf(context))
    }

    @Test
    @Config(sdk = [Build.VERSION_CODES.R])
    fun `hingeSignalsOf - 기능 선언만 있어도 읽는다`() {
        declareHingeFeature()
        assertEquals(FoldableDeviceProbe.HingeSignals(declared = true, sensor = false), FoldableDeviceProbe.hingeSignalsOf(context))
    }

    @Test
    @Config(sdk = [MIN_SDK, Build.VERSION_CODES.Q])
    fun `hingeSignalsOf - API 29 이하는 기능 선언이 있어도 둘 다 없다`() {
        declareHingeFeature()
        assertEquals(FoldableDeviceProbe.HingeSignals(declared = false, sensor = false), FoldableDeviceProbe.hingeSignalsOf(context))
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

    /** true면 구독이 실패한다 */
    var failOnSubscribe = false

    override fun subscribe(onLayout: (hasFold: Boolean) -> Unit): () -> Unit {
        if (failOnSubscribe) throw IllegalStateException("구독 실패 (테스트)")
        subscribeCount++
        listeners += onLayout
        if (emitOnSubscribe) onLayout(true)
        return { listeners -= onLayout }
    }

    fun emit(hasFold: Boolean) {
        for (listener in listeners.toList()) listener(hasFold)
    }
}
