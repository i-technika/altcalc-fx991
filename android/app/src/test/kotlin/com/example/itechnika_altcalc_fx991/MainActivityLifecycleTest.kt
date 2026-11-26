package com.example.itechnika_altcalc_fx991

import android.content.Context
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterJNI
import io.flutter.embedding.engine.dart.PlatformMessageHandler
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentCaptor
import org.mockito.ArgumentMatchers.any
import org.mockito.ArgumentMatchers.anyInt
import org.mockito.ArgumentMatchers.eq
import org.mockito.Mockito
import org.mockito.Mockito.atLeast
import org.mockito.Mockito.mock
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config
import java.nio.ByteBuffer

/**
 * [MainActivity]의 Flutter 생명주기 연결 (#108 R1) — `configureFlutterEngine`·`cleanUpFlutterEngine`·`onResume`이
 * 채널 등록·정리·다시 읽기를 실제로 부르는지 본다. [MainActivityChannelsTest]는 떼어 낸 등록 함수만 본다.
 *
 * Flutter 엔진(네이티브)은 JVM에서 뜨지 않으므로 Flutter 자체 테스트(`FlutterActivityTest`)와 같은 방식을 쓴다:
 * `FlutterJNI`를 Mockito 대역으로 바꾼 엔진을 [FlutterEngineCache]에 넣고, 그 캐시 엔진을 쓰는 인텐트로 액티비티를
 * 생명주기대로 돌린다. 캐시 엔진이면 Dart 실행·플러그인 자동 등록을 건너뛴다(`FlutterActivity` 규칙).
 * Dart가 보내는 메시지는 엔진이 `FlutterJNI`에 건 [PlatformMessageHandler]에 넣고, 플랫폼이 Dart로 보내는
 * 메시지·응답은 `FlutterJNI` 대역의 호출로 받는다.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [MIN_SDK, LAST_LEGACY_SDK, FIRST_PUBLIC_API_SDK])
class MainActivityLifecycleTest {
    private lateinit var context: Context
    private lateinit var jni: FlutterJNI
    private lateinit var engine: FlutterEngine
    private lateinit var controller: ActivityController<MainActivity>
    private lateinit var fromDart: PlatformMessageHandler
    private var nextReplyId = 1

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        FlutterInjector.reset()
        jni = mock(FlutterJNI::class.java)
        `when`(jni.isAttached).thenReturn(true)
        engine = FlutterEngine(context, mock(FlutterLoader::class.java), jni)
        // 엔진이 JNI에 건 메시지 처리기 — 실제 엔진에서는 네이티브 쪽이 Dart 메시지를 여기로 넘긴다
        val handler = ArgumentCaptor.forClass(PlatformMessageHandler::class.java)
        verify(jni).setPlatformMessageHandler(handler.capture())
        fromDart = handler.value
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        val intent = object : FlutterActivity.CachedEngineIntentBuilder(MainActivity::class.java, ENGINE_ID) {}
            .build(context)
        controller = Robolectric.buildActivity(MainActivity::class.java, intent)
    }

    @After
    fun tearDown() {
        FlutterEngineCache.getInstance().remove(ENGINE_ID)
        FlutterInjector.reset()
        // 인라인 모크는 Mockito가 정적 맵에 붙들고 있어, 지우지 않으면 SDK 샌드박스마다 엔진·액티비티가 쌓인다
        Mockito.framework().clearInlineMocks()
    }

    /** Dart의 `invokeMethod`처럼 엔진에 메서드 호출을 넣고, 플랫폼이 보낸 응답을 푼다 */
    private fun invokeFromDart(channel: String, method: String): Any? {
        val replyId = sendFromDart(channel, method)
        HighTextContrastSystem.idleMainLooper()
        return replyTo(replyId)
    }

    /** Dart가 보내는 것처럼 엔진에 메서드 호출을 넣고 응답 번호를 돌려준다 (응답은 [replyTo]로 본다) */
    private fun sendFromDart(channel: String, method: String): Int {
        val replyId = nextReplyId++
        val message = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(method, null))
        message.flip()
        fromDart.handleMessageFromDart(channel, message, replyId, 0)
        return replyId
    }

    /** 플랫폼이 [replyId]에 보낸 응답을 푼다. 응답이 없거나 두 번 이상이면 실패한다. */
    private fun replyTo(replyId: Int): Any? {
        val reply = ArgumentCaptor.forClass(ByteBuffer::class.java)
        verify(jni).invokePlatformMessageResponseCallback(eq(replyId), reply.capture(), anyInt())
        val buffer = reply.value.duplicate().apply { flip() }
        return StandardMethodCodec.INSTANCE.decodeEnvelope(buffer)
    }

    /** 플랫폼이 [channel]로 Dart에 보낸 이벤트를 순서대로 푼다 */
    private fun eventsSentToDart(channel: String): List<Any?> {
        val messages = ArgumentCaptor.forClass(ByteBuffer::class.java)
        val positions = ArgumentCaptor.forClass(Int::class.java)
        verify(jni, atLeast(0)).dispatchPlatformMessage(eq(channel), messages.capture(), positions.capture(), anyInt())
        return messages.allValues.zip(positions.allValues).map { (message, position) ->
            val buffer = message.duplicate().apply {
                limit(position)
                position(0)
            }
            StandardMethodCodec.INSTANCE.decodeEnvelope(buffer)
        }
    }

    @Test
    fun `configureFlutterEngine이 기기 채널을 건다 - 실제 창 배치 정보 첫 값으로 제한 시간 전에 답한다`() {
        controller.create()

        // Robolectric에는 WindowManager 확장이 없어 Jetpack WindowManager가 빈 창 배치 정보를 바로 보낸다 —
        // 실제 출처(WindowLayoutFoldingSource)가 구독·응답까지 이어지는지 본다(시계는 그대로, 제한 시간 전).
        assertEquals(false, invokeFromDart(DEVICE_CHANNEL, "isFoldableDevice"))
    }

    @Test
    fun `cleanUpFlutterEngine - 기다리는 폴더블 판정에 답하고 창 배치 구독을 푼다`() {
        val layout = FakeFoldingLayoutSource()
        controller.get().foldingLayoutSource = layout
        controller.create()
        val replyId = sendFromDart(DEVICE_CHANNEL, "isFoldableDevice")
        // 메시지를 처리기까지 보낸다(시계는 그대로 — 제한 시간은 지나지 않는다). 창 배치 정보가 아직 없어 답이 없다.
        HighTextContrastSystem.idleMainLooper()
        verify(jni, never()).invokePlatformMessageResponseCallback(eq(replyId), any(), anyInt())
        assertEquals(1, layout.activeCount)

        controller.destroy()

        assertEquals(false, replyTo(replyId))
        assertEquals(0, layout.activeCount)
    }

    @Test
    fun `configureFlutterEngine이 고대비 텍스트 채널을 건다`() {
        controller.create()

        invokeFromDart(HIGH_TEXT_CONTRAST_CHANNEL, "listen")
        assertEquals(listOf<Any?>(false), eventsSentToDart(HIGH_TEXT_CONTRAST_CHANNEL))
        assertEquals(1, HighTextContrastSystem.registrationCount(context))

        HighTextContrastSystem.set(context, true)
        HighTextContrastSystem.idleMainLooper()
        assertEquals(listOf<Any?>(false, true), eventsSentToDart(HIGH_TEXT_CONTRAST_CHANNEL))
    }

    @Test
    @Config(sdk = [MIN_SDK, LAST_LEGACY_SDK])
    fun `onResume - 뒤에 있는 동안 놓친 변경을 앞에 올 때 맞춘다`() {
        controller.create().start().resume()
        invokeFromDart(HIGH_TEXT_CONTRAST_CHANNEL, "listen")
        controller.pause().stop()

        // 변경 알림을 놓친 상황 (API 35 이하만 흉내 낼 수 있다 — API 36 리스너는 알림을 놓치지 않는다)
        HighTextContrastSystem.setLegacySetting(context, enabled = true, notify = false)
        HighTextContrastSystem.idleMainLooper()
        assertEquals(listOf<Any?>(false), eventsSentToDart(HIGH_TEXT_CONTRAST_CHANNEL))

        controller.start().resume()
        HighTextContrastSystem.idleMainLooper()
        assertEquals(listOf<Any?>(false, true), eventsSentToDart(HIGH_TEXT_CONTRAST_CHANNEL))
    }

    @Test
    fun `cleanUpFlutterEngine - Dart가 구독을 끊지 않았어도 액티비티가 끝나면 변경 감지를 푼다`() {
        controller.create().start().resume()
        invokeFromDart(HIGH_TEXT_CONTRAST_CHANNEL, "listen")
        assertEquals(1, HighTextContrastSystem.registrationCount(context))

        controller.pause().stop().destroy()

        assertEquals(0, HighTextContrastSystem.registrationCount(context))
        HighTextContrastSystem.set(context, true)
        HighTextContrastSystem.idleMainLooper()
        assertEquals(listOf<Any?>(false), eventsSentToDart(HIGH_TEXT_CONTRAST_CHANNEL))
    }

    @Test
    fun `cleanUpFlutterEngine - 캐시 엔진에 끝난 액티비티의 채널 처리기를 남기지 않는다`() {
        controller.create().start().resume().pause().stop().destroy()

        // 엔진은 캐시에 살아 있다 — 끝난 액티비티의 처리기가 남아 있으면 응답한다
        for ((channel, method) in listOf(HIGH_TEXT_CONTRAST_CHANNEL to "listen", DEVICE_CHANNEL to "isFoldableDevice")) {
            val replyId = nextReplyId++
            val message = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(method, null))
            message.flip()
            fromDart.handleMessageFromDart(channel, message, replyId, 0)
            HighTextContrastSystem.idleMainLooper()

            // 처리기가 없으면 엔진은 빈 응답(null)을 보낸다
            verify(jni).invokePlatformMessageEmptyResponseCallback(replyId)
            verify(jni, never()).invokePlatformMessageResponseCallback(eq(replyId), any(), anyInt())
        }
        assertEquals(0, HighTextContrastSystem.registrationCount(context))
    }

    private companion object {
        const val ENGINE_ID = "altcalc_test_engine"

        /** Dart `FormFactor.deviceChannel`의 이름 */
        const val DEVICE_CHANNEL = "altcalc/device"

        /** Dart `high_text_contrast.dart`의 이벤트 채널 이름 */
        const val HIGH_TEXT_CONTRAST_CHANNEL = "altcalc/accessibility/high_text_contrast"
    }
}
