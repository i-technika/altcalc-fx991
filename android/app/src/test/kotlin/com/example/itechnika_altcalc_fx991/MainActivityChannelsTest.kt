package com.example.itechnika_altcalc_fx991

import android.content.pm.PackageManager
import android.os.Build
import android.os.Looper
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.time.Duration

/**
 * [MainActivity]가 거는 플랫폼 채널 (#108) — `altcalc/device`(#24)와 고대비 텍스트 이벤트 채널(#95).
 *
 * 액티비티를 만들기만 하고(onCreate 전) 채널 등록 부분만 가짜 메신저로 불러 채널 동작을 자세히 본다.
 * 생명주기 훅이 이 등록·정리를 실제로 부르는지는 [MainActivityLifecycleTest]가 본다.
 * 채널 이름은 여기에 따로 적어 Kotlin 상수가 바뀌면 실패하게 하고, Dart 쪽 이름과의 일치는
 * Dart 테스트 `test/unit/main_activity_source_test.dart`가 `MainActivity.kt`를 읽어 대조한다.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [MIN_SDK, LAST_LEGACY_SDK, FIRST_PUBLIC_API_SDK])
class MainActivityChannelsTest {
    private lateinit var activity: MainActivity
    private val messenger = FakeBinaryMessenger()
    private val layout = FakeFoldingLayoutSource()

    @Before
    fun setUp() {
        // get()은 컨텍스트만 붙인 액티비티를 준다 — onCreate를 부르면 Flutter 엔진(네이티브)을 띄우려 한다.
        activity = Robolectric.buildActivity(MainActivity::class.java).get()
        activity.foldingLayoutSource = layout
        activity.registerChannels(messenger)
    }

    private fun isFoldableDevice(): List<MethodReply> = messenger.startMethod(DEVICE_CHANNEL, "isFoldableDevice")

    /** `isFoldableDevice` 응답 (#158 — 폴더블 여부와 창 배치 첫 값의 접힘) */
    private fun reply(foldable: Boolean, fold: Boolean?): MethodReply =
        MethodReply.Success(mapOf("foldable" to foldable, "fold" to fold))

    private fun declareHingeSensor() =
        shadowOf(activity.packageManager).setSystemFeature(PackageManager.FEATURE_SENSOR_HINGE_ANGLE, true)

    // ---- altcalc/device ----
    // 판정 규칙의 자세한 경우는 FoldableDeviceProbeTest가 본다. 여기서는 채널·메서드 이름과 액티비티의 실제 신호 연결을 본다.

    @Test
    @Config(sdk = [Build.VERSION_CODES.R, FIRST_PUBLIC_API_SDK])
    fun `isFoldableDevice - API 30 이상은 힌지 기능 선언이 있으면 접힘이 없어도 폴더블`() {
        declareHingeSensor()
        val replies = isFoldableDevice()
        // 창 배치 정보 첫 값을 기다려 접힘과 함께 답한다 (#158)
        assertTrue(replies.isEmpty())

        layout.emit(false)
        HighTextContrastSystem.idleMainLooper()

        assertEquals(listOf(reply(foldable = true, fold = false)), replies)
    }

    @Test
    fun `isFoldableDevice - 힌지 신호가 없으면 창 배치 정보 첫 값으로 답한다`() {
        val replies = isFoldableDevice()
        assertTrue(replies.isEmpty())

        layout.emit(true)
        HighTextContrastSystem.idleMainLooper()

        assertEquals(listOf(reply(foldable = true, fold = true)), replies)
    }

    @Test
    @Config(sdk = [MIN_SDK, Build.VERSION_CODES.Q])
    fun `isFoldableDevice - API 29 이하는 기능 선언이 있어도 창 배치 정보로 판정한다`() {
        declareHingeSensor()
        val replies = isFoldableDevice()

        layout.emit(false)
        HighTextContrastSystem.idleMainLooper()

        assertEquals(listOf(reply(foldable = false, fold = false)), replies)
    }

    @Test
    fun `isFoldableDevice - 창 배치 정보가 오지 않으면 제한 시간에 폴더블 아님, 접힘 모름(null)`() {
        val replies = isFoldableDevice()

        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(FoldableDeviceProbe.LAYOUT_TIMEOUT_MILLIS))
        assertEquals(listOf(reply(foldable = false, fold = null)), replies)

        // 답한 뒤 진단 시간이 지나면 구독을 푼다
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(FoldableDeviceProbe.DIAGNOSTIC_MILLIS))
        assertEquals(0, layout.activeCount)
    }

    @Test
    fun `엔진 정리 - 기다리는 폴더블 판정에 답하고 창 배치 구독을 푼다`() {
        val replies = isFoldableDevice()
        assertEquals(1, layout.activeCount)

        activity.unregisterChannels(messenger)

        assertEquals(listOf(reply(foldable = false, fold = null)), replies)
        assertEquals(0, layout.activeCount)
    }

    @Test
    fun `다시 등록하면 앞 등록의 기다리는 폴더블 판정을 정리한다`() {
        val replies = isFoldableDevice()

        activity.registerChannels(messenger)

        assertEquals(listOf(reply(foldable = false, fold = null)), replies)
        assertEquals(0, layout.activeCount)
    }

    @Test
    fun `isInMultiWindowMode - 액티비티의 여러 창 모드 여부를 그때그때 답한다 (#137)`() {
        assertEquals(MethodReply.Success(false), messenger.invokeMethod(DEVICE_CHANNEL, "isInMultiWindowMode"))

        // 분할 화면에 들어감 — 등록 때 값을 기억하지 않고 물을 때마다 읽는다
        shadowOf(activity).setInMultiWindowMode(true)
        assertEquals(MethodReply.Success(true), messenger.invokeMethod(DEVICE_CHANNEL, "isInMultiWindowMode"))

        shadowOf(activity).setInMultiWindowMode(false)
        assertEquals(MethodReply.Success(false), messenger.invokeMethod(DEVICE_CHANNEL, "isInMultiWindowMode"))
    }

    @Test
    fun `기기 채널은 모르는 메서드에 notImplemented로 답한다`() {
        assertEquals(MethodReply.NotImplemented, messenger.invokeMethod(DEVICE_CHANNEL, "noSuchMethod"))
    }

    // ---- altcalc/accessibility/high_text_contrast ----

    @Test
    fun `고대비 텍스트 채널 - 구독하면 지금 값을 보내고 바뀌면 새 값을 보낸다`() {
        assertEquals(MethodReply.Success(null), messenger.invokeMethod(HIGH_TEXT_CONTRAST_CHANNEL, "listen"))
        assertEquals(listOf<Any?>(false), messenger.sentEvents(HIGH_TEXT_CONTRAST_CHANNEL))

        HighTextContrastSystem.set(activity, true)
        HighTextContrastSystem.idleMainLooper()
        assertEquals(listOf<Any?>(false, true), messenger.sentEvents(HIGH_TEXT_CONTRAST_CHANNEL))

        assertEquals(MethodReply.Success(null), messenger.invokeMethod(HIGH_TEXT_CONTRAST_CHANNEL, "cancel"))
        assertEquals(0, HighTextContrastSystem.registrationCount(activity))
    }

    @Test
    fun `엔진 정리 - Dart가 구독을 끊지 않았어도 변경 감지를 풀고 두 채널 처리기를 모두 뗀다`() {
        messenger.invokeMethod(HIGH_TEXT_CONTRAST_CHANNEL, "listen")
        assertEquals(1, HighTextContrastSystem.registrationCount(activity))

        activity.unregisterChannels(messenger)

        assertEquals(0, HighTextContrastSystem.registrationCount(activity))
        assertTrue("채널 처리기를 모두 뗀다: ${messenger.channels}", messenger.channels.isEmpty())
        HighTextContrastSystem.set(activity, true)
        HighTextContrastSystem.idleMainLooper()
        assertEquals(listOf<Any?>(false), messenger.sentEvents(HIGH_TEXT_CONTRAST_CHANNEL))
    }

    @Test
    fun `엔진 정리 - Dart가 먼저 구독을 끊었거나 거듭 정리해도 안전하다`() {
        messenger.invokeMethod(HIGH_TEXT_CONTRAST_CHANNEL, "listen")
        messenger.invokeMethod(HIGH_TEXT_CONTRAST_CHANNEL, "cancel")

        // 처리기의 onCancel이 Dart의 cancel에 이어 한 번 더 불린다
        activity.unregisterChannels(messenger)
        activity.unregisterChannels(messenger)

        assertEquals(0, HighTextContrastSystem.registrationCount(activity))
    }

    @Test
    fun `고대비 텍스트 채널 - 다시 listen하면(핫 리스타트) 앞 구독을 풀고 첫 값을 다시 보낸다`() {
        // EventChannel은 구독 중에 listen이 다시 오면 처리기의 onCancel 뒤 onListen을 부른다
        messenger.invokeMethod(HIGH_TEXT_CONTRAST_CHANNEL, "listen")
        messenger.invokeMethod(HIGH_TEXT_CONTRAST_CHANNEL, "listen")

        assertEquals(listOf<Any?>(false, false), messenger.sentEvents(HIGH_TEXT_CONTRAST_CHANNEL))
        assertEquals(1, HighTextContrastSystem.registrationCount(activity))
    }

    @Test
    fun `엔진 정리 뒤 다시 등록하면 새로 구독할 수 있다`() {
        messenger.invokeMethod(HIGH_TEXT_CONTRAST_CHANNEL, "listen")
        activity.unregisterChannels(messenger)

        activity.registerChannels(messenger)
        messenger.invokeMethod(HIGH_TEXT_CONTRAST_CHANNEL, "listen")

        assertEquals(listOf<Any?>(false, false), messenger.sentEvents(HIGH_TEXT_CONTRAST_CHANNEL))
        assertEquals(1, HighTextContrastSystem.registrationCount(activity))
    }

    @Test
    fun `등록한 채널 이름`() {
        assertEquals(setOf(DEVICE_CHANNEL, HIGH_TEXT_CONTRAST_CHANNEL), messenger.channels)
        assertTrue(messenger.sentEvents(HIGH_TEXT_CONTRAST_CHANNEL).isEmpty())
    }

    private companion object {
        /** Dart `FormFactor.deviceChannel`의 이름 */
        const val DEVICE_CHANNEL = "altcalc/device"

        /** Dart `high_text_contrast.dart`의 이벤트 채널 이름 */
        const val HIGH_TEXT_CONTRAST_CHANNEL = "altcalc/accessibility/high_text_contrast"
    }
}
