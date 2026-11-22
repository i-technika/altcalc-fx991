package com.example.itechnika_altcalc_fx991

import android.content.Context
import android.database.ContentObserver
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityManager
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.EventChannel

/**
 * 시스템 접근성 "고대비 텍스트"(Android 15 이상 이름은 "텍스트 대비 최대화") 켜짐 여부를 Dart에 알린다 (#95).
 *
 * 이 설정은 시스템이 그리는 글자에 외곽선을 넣는 기능이라, 글자를 직접 그리는 Flutter 화면에는 효과가 없다.
 * Flutter 엔진은 이 설정을 `MediaQuery.highContrast`에 넣지 않으므로, 앱이 직접 읽어 고대비 팔레트를 쓴다.
 *
 * - API 36 이상: 공개 API `AccessibilityManager.isHighContrastTextEnabled`와 변경 리스너.
 * - API 35 이하: `Settings.Secure`의 `high_text_contrast_enabled`(@Readable 숨김 키)와 [ContentObserver].
 *   읽기가 막히면(SecurityException 등) 꺼진 것으로 본다.
 *
 * 구독을 시작하면 지금 값을 바로 한 번 보내고, 그 뒤에는 값이 바뀔 때만 보낸다. 모든 콜백은 메인 스레드에서 온다.
 */
class HighTextContrastStreamHandler(private val context: Context) : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    /** 마지막으로 보낸 값 — 같은 값을 거듭 보내지 않는다. 구독이 끝나면 지운다. */
    private var lastSent: Boolean? = null

    /** API 35 이하 변경 감지 */
    private var observer: ContentObserver? = null

    /** API 36 이상 변경 감지 (`AccessibilityManager.HighContrastTextStateChangeListener`) */
    private var listener: Any? = null

    private val accessibilityManager: AccessibilityManager?
        get() = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        unregister()
        sink = events
        lastSent = null
        register()
        emit(isEnabled())
    }

    override fun onCancel(arguments: Any?) {
        unregister()
        sink = null
        lastSent = null
    }

    /**
     * 지금 값을 다시 읽어 바뀌었으면 보낸다. 화면이 다시 앞에 올 때(onResume) 불러, 앱이 뒤에 있는 동안
     * 놓친 변경이 있어도 맞춘다.
     */
    fun refresh() {
        if (sink != null) emit(isEnabled())
    }

    private fun emit(enabled: Boolean) {
        if (enabled == lastSent) return
        lastSent = enabled
        sink?.success(enabled)
    }

    private fun isEnabled(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.BAKLAVA) {
            accessibilityManager?.isHighContrastTextEnabled ?: false
        } else {
            readLegacySetting()
        }

    private fun readLegacySetting(): Boolean =
        try {
            Settings.Secure.getInt(context.contentResolver, LEGACY_SETTING_KEY, 0) != 0
        } catch (error: Exception) {
            // 숨김 키라 기기에 따라 읽기가 막힐 수 있다 — 꺼진 것으로 본다.
            Log.w(TAG, "고대비 텍스트 설정 읽기 실패", error)
            false
        }

    private fun register() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.BAKLAVA) {
            registerListener()
        } else {
            val uri = Settings.Secure.getUriFor(LEGACY_SETTING_KEY)
            val contentObserver = object : ContentObserver(mainHandler) {
                override fun onChange(selfChange: Boolean) = refresh()
            }
            try {
                context.contentResolver.registerContentObserver(uri, false, contentObserver)
                observer = contentObserver
            } catch (error: Exception) {
                // 변경 감지만 못 할 뿐 onResume 다시 읽기는 남는다.
                Log.w(TAG, "고대비 텍스트 설정 변경 감지 등록 실패", error)
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.BAKLAVA)
    private fun registerListener() {
        val manager = accessibilityManager ?: return
        val stateListener = AccessibilityManager.HighContrastTextStateChangeListener { _ ->
            // 리스너가 넘기는 값 대신 다시 읽어, 보내는 값이 늘 isEnabled()와 같게 한다.
            refresh()
        }
        manager.addHighContrastTextStateChangeListener(context.mainExecutor, stateListener)
        listener = stateListener
    }

    private fun unregister() {
        observer?.let { context.contentResolver.unregisterContentObserver(it) }
        observer = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.BAKLAVA) unregisterListener()
        listener = null
    }

    @RequiresApi(Build.VERSION_CODES.BAKLAVA)
    private fun unregisterListener() {
        val stateListener =
            listener as? AccessibilityManager.HighContrastTextStateChangeListener ?: return
        accessibilityManager?.removeHighContrastTextStateChangeListener(stateListener)
    }

    companion object {
        private const val TAG = "AltCalcHighTextContrast"

        /** `Settings.Secure.ACCESSIBILITY_HIGH_TEXT_CONTRAST_ENABLED` (숨김 상수라 문자열로 쓴다) */
        private const val LEGACY_SETTING_KEY = "high_text_contrast_enabled"
    }
}
