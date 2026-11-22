package com.example.itechnika_altcalc_fx991

import android.os.Build
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * 테스트가 도는 API 수준이 앱 설정과 어긋나지 않게 지킨다 (#108).
 * Flutter가 minSdk·targetSdk 기본값을 올리면 여기서 실패하므로, [MIN_SDK] 등 테스트 대상 API 수준을 함께 고친다.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [FIRST_PUBLIC_API_SDK])
class AndroidTestSetupTest {
    private val appInfo get() = RuntimeEnvironment.getApplication().applicationInfo

    @Test
    fun `옛 경로 테스트의 최저 API 수준은 앱 minSdk와 같다`() {
        assertEquals(MIN_SDK, appInfo.minSdkVersion)
    }

    @Test
    fun `고대비 텍스트 분기 경계는 API 35와 36 사이다`() {
        assertEquals(35, LAST_LEGACY_SDK)
        assertEquals(LAST_LEGACY_SDK + 1, FIRST_PUBLIC_API_SDK)
    }

    @Test
    fun `공개 API 경로 테스트는 앱 targetSdk 이하에서 돈다`() {
        // targetSdk보다 높은 API 수준에서는 Robolectric이 호환 동작을 흉내 내 실제 기기와 다를 수 있다.
        assertTrue(
            "targetSdk=${appInfo.targetSdkVersion}",
            FIRST_PUBLIC_API_SDK <= appInfo.targetSdkVersion,
        )
    }

    @Test
    fun `Robolectric이 요청한 API 수준의 프레임워크로 돈다`() {
        assertEquals(FIRST_PUBLIC_API_SDK, Build.VERSION.SDK_INT)
    }
}
