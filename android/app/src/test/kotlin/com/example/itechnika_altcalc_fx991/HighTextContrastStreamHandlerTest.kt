package com.example.itechnika_altcalc_fx991

import android.content.Context
import android.content.ContextWrapper
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * [HighTextContrastStreamHandler] (#95)의 구독·전송 규칙과 API 수준 분기 (#108).
 *
 * 클래스에 건 세 API 수준에서 모든 테스트가 한 번씩 돈다 — 옛 경로의 양 끝(앱 minSdk, API 35)과 공개 API 경로(API 36).
 * 한쪽 경로만 보는 테스트는 메서드에 `@Config(sdk = ...)`를 따로 건다.
 * 잘못된 분기를 타면 그 API 수준 프레임워크에 없는 메서드를 불러 `NoSuchMethodError`로 실패한다.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [MIN_SDK, LAST_LEGACY_SDK, FIRST_PUBLIC_API_SDK])
class HighTextContrastStreamHandlerTest {
    private lateinit var context: Context
    private lateinit var handler: HighTextContrastStreamHandler
    private val sink = RecordingSink()

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        handler = HighTextContrastStreamHandler(context)
    }

    private fun setSystem(enabled: Boolean) = HighTextContrastSystem.set(context, enabled)

    private fun idle() = HighTextContrastSystem.idleMainLooper()

    private fun registrationCount() = HighTextContrastSystem.registrationCount(context)

    // ---- 첫 값 ----

    @Test
    fun `구독하면 지금 값을 바로 보낸다 - 꺼짐`() {
        handler.onListen(null, sink)

        assertEquals(listOf<Any?>(false), sink.events)
    }

    @Test
    fun `구독하면 지금 값을 바로 보낸다 - 켜짐`() {
        setSystem(true)
        idle()

        handler.onListen(null, sink)

        assertEquals(listOf<Any?>(true), sink.events)
    }

    // ---- 변경 ----

    @Test
    fun `값이 바뀔 때마다 보낸다`() {
        handler.onListen(null, sink)

        setSystem(true)
        idle()
        assertEquals(listOf<Any?>(false, true), sink.events)

        setSystem(false)
        idle()
        assertEquals(listOf<Any?>(false, true, false), sink.events)
    }

    @Test
    fun `구독하는 동안 변경 감지를 하나만 걸어 둔다`() {
        assertEquals(0, registrationCount())

        handler.onListen(null, sink)

        assertEquals(1, registrationCount())
    }

    // ---- 같은 값 중복 전송 방지 ----

    @Test
    fun `값이 그대로면 refresh가 다시 보내지 않는다`() {
        handler.onListen(null, sink)

        handler.refresh()
        handler.refresh()

        assertEquals(listOf<Any?>(false), sink.events)
    }

    @Test
    fun `refresh가 변경 알림보다 먼저 읽어 보내면 뒤늦은 알림은 다시 보내지 않는다`() {
        handler.onListen(null, sink)

        // 시스템 값은 바뀌었고 알림은 아직 메인 루퍼에 쌓여 있다 — 이때 화면이 앞에 온다(onResume).
        setSystem(true)
        handler.refresh()
        assertEquals(listOf<Any?>(false, true), sink.events)

        idle()
        assertEquals(listOf<Any?>(false, true), sink.events)
    }

    @Test
    @Config(sdk = [MIN_SDK, LAST_LEGACY_SDK])
    fun `API 35 이하 - 값이 바뀌지 않은 변경 알림은 보내지 않는다`() {
        handler.onListen(null, sink)

        context.contentResolver.notifyChange(HighTextContrastSystem.legacyUri, null)
        idle()

        assertEquals(listOf<Any?>(false), sink.events)
    }

    // ---- refresh (onResume) ----

    @Test
    @Config(sdk = [MIN_SDK, LAST_LEGACY_SDK])
    fun `API 35 이하 - 변경 알림을 놓쳐도 refresh가 맞춘다`() {
        handler.onListen(null, sink)

        HighTextContrastSystem.setLegacySetting(context, enabled = true, notify = false)
        idle()
        assertEquals(listOf<Any?>(false), sink.events)

        handler.refresh()
        assertEquals(listOf<Any?>(false, true), sink.events)
    }

    @Test
    fun `구독 전과 구독 해제 뒤의 refresh는 아무것도 보내지 않는다`() {
        handler.refresh()

        handler.onListen(null, sink)
        handler.onCancel(null)
        setSystem(true)
        idle()
        handler.refresh()

        assertEquals(listOf<Any?>(false), sink.events)
    }

    // ---- 구독 해제·재구독 ----

    @Test
    fun `구독을 해제하면 변경 감지를 풀고 더 보내지 않는다`() {
        handler.onListen(null, sink)

        handler.onCancel(null)
        assertEquals(0, registrationCount())

        setSystem(true)
        idle()
        assertEquals(listOf<Any?>(false), sink.events)
    }

    @Test
    fun `다시 구독하면 값이 그대로여도 첫 값을 다시 보낸다`() {
        handler.onListen(null, sink)
        handler.onCancel(null)

        val second = RecordingSink()
        handler.onListen(null, second)

        assertEquals(listOf<Any?>(false), second.events)
        assertEquals(1, registrationCount())

        setSystem(true)
        idle()
        assertEquals(listOf<Any?>(false, true), second.events)
        assertEquals("해제한 구독에는 보내지 않는다", listOf<Any?>(false), sink.events)
    }

    @Test
    fun `해제 없이 다시 구독하면 앞 구독의 변경 감지를 풀고 새 구독에만 보낸다`() {
        handler.onListen(null, sink)

        val second = RecordingSink()
        handler.onListen(null, second)

        assertEquals(listOf<Any?>(false), second.events)
        assertEquals(1, registrationCount())

        setSystem(true)
        idle()
        assertEquals(listOf<Any?>(false, true), second.events)
        assertEquals(listOf<Any?>(false), sink.events)
    }

    @Test
    fun `onCancel은 구독이 없을 때와 거듭 불러도 안전하다`() {
        // 구독한 적 없음
        handler.onCancel(null)

        // Dart가 구독을 끊은 뒤 MainActivity.cleanUpFlutterEngine이 한 번 더 부른다
        handler.onListen(null, sink)
        handler.onCancel(null)
        handler.onCancel(null)
        assertEquals(0, registrationCount())

        // 그 뒤에도 다시 쓸 수 있다
        val second = RecordingSink()
        handler.onListen(null, second)
        assertEquals(listOf<Any?>(false), second.events)
        assertEquals(1, registrationCount())
    }

    // ---- API 수준 분기 ----

    @Test
    @Config(sdk = [FIRST_PUBLIC_API_SDK])
    fun `API 36 이상 - 옛 설정 키를 읽지도 지켜보지도 않는다`() {
        HighTextContrastSystem.setLegacySetting(context, enabled = true)
        idle()

        handler.onListen(null, sink)

        assertEquals(listOf<Any?>(false), sink.events)
        assertEquals(0, HighTextContrastSystem.legacyObserverCount(context))
    }

    @Test
    @Config(sdk = [FIRST_PUBLIC_API_SDK])
    fun `API 36 이상 - 접근성 관리자를 얻지 못하면 꺼진 것으로 본다`() {
        val withoutManager = object : ContextWrapper(context) {
            override fun getSystemService(name: String): Any? =
                if (name == Context.ACCESSIBILITY_SERVICE) null else super.getSystemService(name)
        }
        HighTextContrastSystem.setManagerState(context, enabled = true)
        idle()
        val handler = HighTextContrastStreamHandler(withoutManager)

        handler.onListen(null, sink)
        handler.refresh()
        handler.onCancel(null)

        assertEquals(listOf<Any?>(false), sink.events)
        assertEquals(0, registrationCount())
    }

    // ---- 실패 처리 (API 35 이하의 숨김 설정 키) ----

    @Test
    @Config(sdk = [MIN_SDK, LAST_LEGACY_SDK], shadows = [UnreadableSecureSettings::class])
    fun `API 35 이하 - 설정 읽기가 막히면 꺼진 것으로 본다`() {
        UnreadableSecureSettings.reset()

        handler.onListen(null, sink)
        handler.refresh()

        assertEquals(listOf<Any?>(false), sink.events)
        assertTrue(
            "읽기를 두 번 시도해야 한다(섀도가 걸렸는지 확인): ${UnreadableSecureSettings.readAttempts}",
            UnreadableSecureSettings.readAttempts == 2,
        )
        // 읽기만 막혔을 뿐 변경 감지는 걸려 있고, 해제도 된다
        assertEquals(1, registrationCount())
        handler.onCancel(null)
        assertEquals(0, registrationCount())
    }

    @Test
    @Config(sdk = [MIN_SDK, LAST_LEGACY_SDK])
    fun `API 35 이하 - 변경 감지 등록이 막혀도 첫 값을 보내고 refresh로 맞춘다`() {
        shadowOf(context.contentResolver).setRegisterContentProviderException(
            HighTextContrastSystem.legacyUri,
            SecurityException("등록 거부 (테스트)"),
        )
        HighTextContrastSystem.setLegacySetting(context, enabled = true)
        idle()

        handler.onListen(null, sink)
        assertEquals(listOf<Any?>(true), sink.events)
        assertEquals(0, registrationCount())

        HighTextContrastSystem.setLegacySetting(context, enabled = false)
        idle()
        assertEquals("변경 감지가 없으니 알림으로는 오지 않는다", listOf<Any?>(true), sink.events)

        handler.refresh()
        assertEquals(listOf<Any?>(true, false), sink.events)

        handler.onCancel(null)
    }
}
