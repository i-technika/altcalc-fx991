package com.example.itechnika_altcalc_fx991

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Looper
import android.provider.Settings
import android.util.ArrayMap
import android.view.accessibility.AccessibilityManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.util.ReflectionHelpers
import org.robolectric.util.ReflectionHelpers.ClassParameter
import java.nio.ByteBuffer

// Android 단위 테스트(#108)가 함께 쓰는 도구.

/** 앱 minSdk (Flutter 기본값) — 옛 경로가 최저 지원 기기에 없는 API를 부르지 않는지 본다. 값은 [AndroidTestSetupTest]가 앱 설정과 대조한다. */
internal const val MIN_SDK = Build.VERSION_CODES.N

/** `Settings.Secure` 숨김 키로 고대비 텍스트를 읽는 마지막 API 수준 */
internal const val LAST_LEGACY_SDK = Build.VERSION_CODES.VANILLA_ICE_CREAM

/** 공개 API `AccessibilityManager.isHighContrastTextEnabled`가 생긴 API 수준 */
internal const val FIRST_PUBLIC_API_SDK = Build.VERSION_CODES.BAKLAVA

/** 받은 이벤트를 순서대로 적어 두는 [EventChannel.EventSink] */
internal class RecordingSink : EventChannel.EventSink {
    val events = mutableListOf<Any?>()

    override fun success(event: Any?) {
        events += event
    }

    override fun error(errorCode: String?, errorMessage: String?, errorDetails: Any?) =
        throw AssertionError("오류 이벤트를 보내면 안 된다: $errorCode $errorMessage")

    override fun endOfStream() = throw AssertionError("스트림을 끝내면 안 된다")
}

/**
 * 시스템 "고대비 텍스트" 설정을 흉내 낸다. 지금 도는 API 수준에서 실제 시스템이 값을 두는 곳을 바꾼다.
 *
 * - API 35 이하: `Settings.Secure`의 `high_text_contrast_enabled` (Robolectric이 메모리에 두고, 값이 바뀌면 관찰자에게 알린다).
 * - API 36 이상: [AccessibilityManager]의 상태 플래그. Robolectric에 이 값을 바꾸는 공개 수단이 없어, 시스템 서비스가
 *   상태를 밀어 넣을 때 타는 숨김 메서드 `setStateLocked`를 리플렉션으로 부른다 — 그 뒤는 실제 프레임워크 코드가 돈다
 *   (`isHighContrastTextEnabled` 값 갱신, 등록된 리스너에 실행기로 알림). 이름은 Robolectric이 싣는 프레임워크 jar의
 *   것이므로, Robolectric 버전을 올려 이름이 바뀌면 여기서 `NoSuchMethodException` 등으로 드러난다.
 *
 * 어느 쪽이든 변경 알림은 메인 루퍼에 쌓이고 [idleMainLooper]를 불러야 전달된다(Robolectric 기본 PAUSED 루퍼).
 */
internal object HighTextContrastSystem {
    /** `HighTextContrastStreamHandler`가 읽는 숨김 설정 키 */
    const val LEGACY_KEY = "high_text_contrast_enabled"

    val legacyUri: Uri get() = Settings.Secure.getUriFor(LEGACY_KEY)

    /** 지금 API 수준의 시스템 값을 바꾼다 */
    fun set(context: Context, enabled: Boolean) {
        if (Build.VERSION.SDK_INT >= FIRST_PUBLIC_API_SDK) {
            setManagerState(context, enabled)
        } else {
            setLegacySetting(context, enabled)
        }
    }

    /** 옛 설정 키를 바꾼다. [notify]가 false면 관찰자에게 알리지 않는다(변경 알림을 놓친 상황). */
    fun setLegacySetting(context: Context, enabled: Boolean, notify: Boolean = true) {
        val resolver: ContentResolver? = if (notify) context.contentResolver else null
        Settings.Secure.putInt(resolver, LEGACY_KEY, if (enabled) 1 else 0)
    }

    /** API 36 이상: 접근성 관리자의 고대비 텍스트 상태를 바꾼다 */
    fun setManagerState(context: Context, enabled: Boolean) {
        val flag = ReflectionHelpers.getStaticField<Int>(
            AccessibilityManager::class.java,
            "STATE_FLAG_HIGH_TEXT_CONTRAST_ENABLED",
        )
        ReflectionHelpers.callInstanceMethod<Any?>(
            manager(context),
            "setStateLocked",
            ClassParameter.from(Int::class.javaPrimitiveType, if (enabled) flag else 0),
        )
    }

    /** 시스템에 걸려 있는 변경 감지 등록 수 (API 35 이하: ContentObserver, API 36 이상: 상태 변경 리스너) */
    fun registrationCount(context: Context): Int =
        if (Build.VERSION.SDK_INT >= FIRST_PUBLIC_API_SDK) {
            ReflectionHelpers.getField<ArrayMap<*, *>>(
                manager(context),
                "mHighContrastTextStateChangeListeners",
            ).size
        } else {
            legacyObserverCount(context)
        }

    /** 옛 설정 키에 걸린 ContentObserver 수 */
    fun legacyObserverCount(context: Context): Int =
        shadowOf(context.contentResolver).getContentObservers(legacyUri).size

    /** 쌓인 변경 알림을 전달한다 */
    fun idleMainLooper() = shadowOf(Looper.getMainLooper()).idle()

    private fun manager(context: Context): AccessibilityManager =
        context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
}

/**
 * `Settings.Secure.getInt` 읽기가 막힌 기기를 흉내 내는 섀도 — 숨김 키는 기기에 따라 [SecurityException]으로 막힐 수 있다.
 * `@Config(shadows = [UnreadableSecureSettings::class])`로 건다. 섀도가 걸리지 않으면 테스트가 헛되이 통과하므로
 * [readAttempts]로 실제로 불렸는지 확인한다.
 */
@Implements(Settings.Secure::class)
internal class UnreadableSecureSettings {
    companion object {
        /** 읽기를 시도한 횟수 */
        @JvmStatic
        var readAttempts = 0
            private set

        @JvmStatic
        @Implementation
        fun getInt(resolver: ContentResolver?, name: String?, def: Int): Int {
            readAttempts++
            throw SecurityException("$name 읽기 거부 (테스트)")
        }

        /** 섀도의 정적 상태는 같은 샌드박스의 테스트 사이에 남으므로, 쓰는 테스트가 먼저 지운다 */
        @JvmStatic
        fun reset() {
            readAttempts = 0
        }
    }
}

/**
 * Flutter 엔진 대신 쓰는 [BinaryMessenger]. 채널이 건 처리기를 이름별로 들고 있다가 Dart가 보내는 것처럼
 * 메시지를 넣어 주고([invokeMethod]), 플랫폼이 Dart로 보낸 메시지를 적어 둔다([sentEvents]).
 * 실제 채널 클래스(`MethodChannel`·`EventChannel`)와 표준 코덱을 그대로 거치므로 채널 이름·메서드 이름·응답 형식을 함께 본다.
 */
internal class FakeBinaryMessenger : BinaryMessenger {
    private val handlers = mutableMapOf<String, BinaryMessenger.BinaryMessageHandler>()
    private val sent = mutableListOf<Pair<String, ByteBuffer?>>()

    /** 처리기가 걸려 있는 채널 이름 */
    val channels: Set<String> get() = handlers.keys

    override fun send(channel: String, message: ByteBuffer?) = send(channel, message, null)

    override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {
        sent += channel to message
    }

    override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
        if (handler == null) handlers.remove(channel) else handlers[channel] = handler
    }

    /** Dart의 `invokeMethod`처럼 [channel]에 메서드 호출을 넣고 응답을 돌려준다 */
    fun invokeMethod(channel: String, method: String, arguments: Any? = null): MethodReply {
        val handler = handlers[channel] ?: throw AssertionError("채널 $channel 에 처리기가 없다")
        // 코덱은 다 쓴 위치의 버퍼를 돌려주고, 엔진은 읽을 위치로 되돌려 건넨다.
        val message = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(method, arguments))
        message.flip()
        val replies = mutableListOf<ByteBuffer?>()
        handler.onMessage(message) { replies += it }
        if (replies.size != 1) throw AssertionError("응답은 정확히 한 번이어야 한다: ${replies.size}번")
        val reply = replies.single() ?: return MethodReply.NotImplemented
        reply.flip()
        return MethodReply.Success(StandardMethodCodec.INSTANCE.decodeEnvelope(reply))
    }

    /** 플랫폼이 [channel]로 보낸 이벤트(성공 봉투)를 순서대로 푼다 */
    fun sentEvents(channel: String): List<Any?> =
        sent.filter { it.first == channel }.map { (_, message) ->
            val buffer = message ?: throw AssertionError("스트림 끝(null)을 보내면 안 된다")
            StandardMethodCodec.INSTANCE.decodeEnvelope(buffer.duplicate().apply { flip() })
        }
}

/** [FakeBinaryMessenger.invokeMethod]의 응답 */
internal sealed interface MethodReply {
    data class Success(val value: Any?) : MethodReply

    /** 처리기가 `notImplemented()`로 답했다 */
    data object NotImplemented : MethodReply
}
