package com.example.itechnika_altcalc_fx991

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 기기 특성 조회 채널 (#24). Dart main()보다 먼저 등록되므로 앱 시작 시 바로 쓸 수 있다.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // 폴더블 판정: 접힘 정보(displayFeatures)는 화면이 붙은 뒤 비동기로 오므로,
                    // 시작 시점에 바로 알 수 있는 힌지 각도 센서 유무로 폴더블 기기를 구분한다 (API 30+).
                    "hasHingeSensor" -> result.success(
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                            packageManager.hasSystemFeature(
                                PackageManager.FEATURE_SENSOR_HINGE_ANGLE,
                            ),
                    )
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        private const val DEVICE_CHANNEL = "altcalc/device"
    }
}
