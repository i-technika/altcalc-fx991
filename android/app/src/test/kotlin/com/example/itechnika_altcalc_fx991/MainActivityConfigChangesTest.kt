package com.example.itechnika_altcalc_fx991

import android.content.ComponentName
import android.content.pm.ActivityInfo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * 병합된 매니페스트가 실제로 MainActivity에 주는 `configChanges` 값을 검사한다 (#96).
 * `test/unit/android_manifest_test.dart`는 원문 매니페스트의 목록을 고정하고, 여기서는 빌드 도구가 병합·컴파일한
 * 정수값에 그 비트가 실제로 들어갔는지 본다(다른 매니페스트가 `tools:replace`로 덮어써도 여기서 걸린다).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [FIRST_PUBLIC_API_SDK])
class MainActivityConfigChangesTest {
    private val configChanges: Int
        get() {
            val app = RuntimeEnvironment.getApplication()
            return app.packageManager
                .getActivityInfo(ComponentName(app, MainActivity::class.java), 0)
                .configChanges
        }

    @Test
    fun `색상 대비 변경(assets paths)에 액티비티를 다시 만들지 않는다`() {
        // 빠지면 Android 14+ "색상 대비"를 바꿀 때마다 엔진이 새로 시작해 입력이 사라진다
        assertTrue(
            "configChanges=0x${Integer.toHexString(configChanges)}",
            configChanges and ActivityInfo.CONFIG_ASSETS_PATHS != 0,
        )
    }

    @Test
    fun `굵은 텍스트 변경은 선언하지 않는다`() {
        // 선언하면 엔진이 MediaQuery.boldText를 갱신하지 않는다 — 매니페스트 주석, #148 참조
        assertEquals(0, configChanges and ActivityInfo.CONFIG_FONT_WEIGHT_ADJUSTMENT)
    }
}
