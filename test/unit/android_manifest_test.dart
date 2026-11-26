import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `AndroidManifest.xml`의 MainActivity 구성 변경 선언 검사 (#96).
///
/// 선언하지 않은 구성 변경이 나면 Android가 액티비티를 다시 만들고, `FlutterActivity`는 엔진을 새로 시작하므로
/// 입력 중이던 상태가 사라지고 몇 초간 빈 화면이 보인다. 그런 일은 기기 설정을 바꿀 때만 일어나 위젯 테스트로는 볼 수 없어
/// 선언 목록을 여기서 고정한다. 항목을 더하거나 뺄 때는 그 설정을 실제로 바꿔 보고(에뮬레이터에서 `adb shell settings put …`)
/// Flutter 엔진이 새 값을 다시 만들지 않고도 전하는지 확인한 뒤 이 목록과 매니페스트 주석을 함께 고친다.

const _manifest = 'android/app/src/main/AndroidManifest.xml';

/// MainActivity의 `android:configChanges` 값 목록
Set<String> _mainActivityConfigChanges(String manifest) {
  final activities = RegExp(
    r'<activity\b[^>]*android:name="\.MainActivity"[^>]*>',
  ).allMatches(manifest).toList();
  expect(
    activities,
    hasLength(1),
    reason: '$_manifest에 android:name=".MainActivity"인 <activity>가 하나 있어야 한다',
  );
  final attribute = RegExp(r'android:configChanges="([^"]*)"')
      .allMatches(activities.single[0]!)
      .toList();
  expect(
    attribute,
    hasLength(1),
    reason: 'MainActivity에 android:configChanges가 하나 있어야 한다',
  );
  return attribute.single[1]!.split('|').map((v) => v.trim()).toSet();
}

void main() {
  late Set<String> configChanges;

  setUpAll(() {
    configChanges = _mainActivityConfigChanges(
      File(_manifest).readAsStringSync(),
    );
  });

  test('Android 14+ "색상 대비" 변경에 액티비티를 다시 만들지 않는다 (assetsPaths, #96)', () {
    // 색상 대비를 바꾸면 시스템이 리소스 오버레이를 바꿔 CONFIG_ASSETS_PATHS만 바뀐다(API 36 에뮬레이터 logcat의
    // configDiff). 선언이 빠지면 고대비 전환 때마다 입력이 사라진다.
    expect(configChanges, contains('assetsPaths'));
  });

  test('선언 목록은 Flutter 템플릿 기본값과 assetsPaths다', () {
    expect(configChanges, {
      // Flutter 프로젝트 템플릿 기본값
      'orientation',
      'keyboardHidden',
      'keyboard',
      'screenSize',
      'smallestScreenSize',
      'locale',
      'layoutDirection',
      'fontScale',
      'screenLayout',
      'density',
      'uiMode',
      // #96 — 위 테스트 참조
      'assetsPaths',
      // fontWeightAdjustment("굵은 텍스트")는 넣지 않는다: 선언하면 액티비티는 남지만 엔진이 MediaQuery.boldText를
      // 갱신하지 않아 앱을 다시 시작할 때까지 굵게 바뀌지 않는다(API 36 에뮬레이터 확인).
    });
  });
}
