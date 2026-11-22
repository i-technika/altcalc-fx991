package com.example.itechnika_altcalc_fx991

import android.content.pm.PackageManager
import android.os.Build
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * [MainActivity]가 거는 플랫폼 채널 (#108) — `altcalc/device`(#24)와 고대비 텍스트 이벤트 채널(#95).
 *
 * Flutter 엔진은 JVM에서 뜨지 않으므로 액티비티를 만들기만 하고(onCreate 전) 채널 등록 부분만 가짜 메신저로 부른다.
 * 채널·메서드 이름은 Dart 쪽(`FormFactor.deviceChannel`, `high_text_contrast.dart`)과 맞춘 값을 여기에 따로 적어,
 * Kotlin 쪽 이름이 바뀌면 실패하게 한다.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [LAST_LEGACY_SDK, FIRST_PUBLIC_API_SDK])
class MainActivityChannelsTest {
    private lateinit var activity: MainActivity
    private val messenger = FakeBinaryMessenger()

    @Before
    fun setUp() {
        // get()은 컨텍스트만 붙인 액티비티를 준다 — onCreate를 부르면 Flutter 엔진(네이티브)을 띄우려 한다.
        activity = Robolectric.buildActivity(MainActivity::class.java).get()
        activity.registerChannels(messenger)
    }

    private fun hasHingeSensor(): MethodReply = messenger.invokeMethod(DEVICE_CHANNEL, "hasHingeSensor")

    private fun declareHingeSensor(declared: Boolean) =
        shadowOf(activity.packageManager).setSystemFeature(PackageManager.FEATURE_SENSOR_HINGE_ANGLE, declared)

    // ---- altcalc/device ----

    @Test
    @Config(sdk = [Build.VERSION_CODES.R, FIRST_PUBLIC_API_SDK])
    fun `hasHingeSensor - API 30 이상은 힌지 각도 센서 기능 선언을 따른다`() {
        assertEquals("선언 정보 없음", MethodReply.Success(false), hasHingeSensor())

        declareHingeSensor(true)
        assertEquals(MethodReply.Success(true), hasHingeSensor())

        declareHingeSensor(false)
        assertEquals(MethodReply.Success(false), hasHingeSensor())
    }

    @Test
    @Config(sdk = [Build.VERSION_CODES.Q])
    fun `hasHingeSensor - API 29 이하는 기능 선언이 있어도 false`() {
        declareHingeSensor(true)

        assertEquals(MethodReply.Success(false), hasHingeSensor())
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
    fun `엔진 정리 - Dart가 구독을 끊지 않았어도 변경 감지를 풀고 채널 처리기를 뗀다`() {
        messenger.invokeMethod(HIGH_TEXT_CONTRAST_CHANNEL, "listen")
        assertEquals(1, HighTextContrastSystem.registrationCount(activity))

        activity.unregisterChannels(messenger)

        assertEquals(0, HighTextContrastSystem.registrationCount(activity))
        assertFalse(HIGH_TEXT_CONTRAST_CHANNEL in messenger.channels)
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
