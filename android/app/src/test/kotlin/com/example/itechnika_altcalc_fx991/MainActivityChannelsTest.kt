package com.example.itechnika_altcalc_fx991

import android.content.pm.ActivityInfo
import android.content.res.Configuration
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
import io.flutter.plugin.common.MethodCall
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
    @Suppress("DEPRECATION")
    fun `여러 창 모드가 바뀌면 기기 채널로 Dart에 알린다 (#137 R1)`() {
        activity.onMultiWindowModeChanged(true)
        activity.onMultiWindowModeChanged(false)
        assertEquals(
            listOf(MethodCall("multiWindowModeChanged", true), MethodCall("multiWindowModeChanged", false))
                .map { it.method to it.arguments },
            messenger.sentMethodCalls(DEVICE_CHANNEL).map { it.method to it.arguments },
        )

        // 채널을 뗀 뒤에는 보내지 않는다(끝난 엔진에 보내지 않는다)
        activity.unregisterChannels(messenger)
        activity.onMultiWindowModeChanged(true)
        assertEquals(2, messenger.sentMethodCalls(DEVICE_CHANNEL).size)
    }

    @Test
    @Suppress("DEPRECATION")
    fun `전체 화면으로 돌아오면 전체 화면에서 쓰던 방향 고정을 바로 되돌린다 (#137 R1)`() {
        val portrait = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        val fullUser = ActivityInfo.SCREEN_ORIENTATION_FULL_USER
        activity.requestedOrientation = portrait
        assertEquals(portrait, activity.fullScreenOrientation)

        // 분할 화면에서 Dart가 고정을 풀어도 전체 화면 값은 그대로 기억한다
        shadowOf(activity).setInMultiWindowMode(true)
        activity.onMultiWindowModeChanged(true)
        activity.requestedOrientation = fullUser
        assertEquals(fullUser, activity.requestedOrientation)
        assertEquals(portrait, activity.fullScreenOrientation)

        // 나오면 Dart를 기다리지 않고 되돌린다
        shadowOf(activity).setInMultiWindowMode(false)
        activity.onMultiWindowModeChanged(false)
        assertEquals(portrait, activity.requestedOrientation)
    }

    @Test
    @Config(sdk = [Build.VERSION_CODES.O, LAST_LEGACY_SDK, FIRST_PUBLIC_API_SDK])
    fun `API 26 이상 - 시스템이 부르는 두 인자 판도 한 인자 판을 거쳐 알리고 되돌린다 (#137 R2)`() {
        activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        shadowOf(activity).setInMultiWindowMode(true)
        activity.onMultiWindowModeChanged(true, Configuration(activity.resources.configuration))
        activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_FULL_USER
        shadowOf(activity).setInMultiWindowMode(false)
        activity.onMultiWindowModeChanged(false, Configuration(activity.resources.configuration))
        assertEquals(
            listOf(true, false),
            messenger.sentMethodCalls(DEVICE_CHANNEL).map { it.arguments },
        )
        assertEquals(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT, activity.requestedOrientation)
    }

    @Test
    @Suppress("DEPRECATION")
    fun `기억한 화면과 다른 화면으로 나오면(폴더블 접기·펴기) 되돌리지 않고 Dart를 기다린다 (#137 R2)`() {
        activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        shadowOf(activity).setInMultiWindowMode(true)
        activity.onMultiWindowModeChanged(true)
        activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_FULL_USER
        // 분할 화면 중 펼쳤다 — 물리 화면의 짧은 변이 커버 화면과 다르다
        @Suppress("DEPRECATION")
        val display = shadowOf(activity.windowManager.defaultDisplay)
        display.setRealWidth(1812)
        display.setRealHeight(2176)
        shadowOf(activity).setInMultiWindowMode(false)
        activity.onMultiWindowModeChanged(false)
        assertEquals(ActivityInfo.SCREEN_ORIENTATION_FULL_USER, activity.requestedOrientation)
    }

    @Test
    @Suppress("DEPRECATION")
    fun `전체 화면에서 요청한 적이 없으면 여러 창 모드에서 나와도 방향을 건드리지 않는다`() {
        val before = activity.requestedOrientation
        shadowOf(activity).setInMultiWindowMode(true)
        activity.onMultiWindowModeChanged(true)
        shadowOf(activity).setInMultiWindowMode(false)
        activity.onMultiWindowModeChanged(false)
        assertEquals(before, activity.requestedOrientation)
        assertEquals(null, activity.fullScreenOrientation)
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
