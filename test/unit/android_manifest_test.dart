import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `AndroidManifest.xml`의 MainActivity 구성 변경 선언 검사 (#96).
///
/// 선언하지 않은 구성 변경이 나면 Android가 액티비티를 다시 만들고, `FlutterActivity`는 엔진을 새로 시작하므로
/// 입력 중이던 상태가 사라지고 몇 초간 빈 화면이 보인다. 그런 일은 기기 설정을 바꿀 때만 일어나 위젯 테스트로는 볼 수 없어
/// 원문 매니페스트의 선언 목록을 여기서 고정한다(병합·컴파일된 값은 Android 단위 테스트 `MainActivityConfigChangesTest`가 본다).
///
/// 목록의 기준은 Flutter 프로젝트 템플릿(`flutter create`가 만드는 매니페스트)의 기본값에 이 앱이 더한 항목이다.
/// 항목을 더하거나 뺄 때는 그 설정을 실제로 바꿔 보고(에뮬레이터에서 `adb shell settings put …`, logcat에 `relaunch`가
/// 없는지) Flutter 엔진이 다시 만들지 않고도 새 값을 전하는지 확인한 뒤 이 목록과 매니페스트 주석을 함께 고친다.

const _manifest = 'android/app/src/main/AndroidManifest.xml';

/// MainActivity의 `android:configChanges` 값 목록. 주석은 걷어 내고 본다(주석 처리한 옛 선언을 세지 않게).
Set<String> _mainActivityConfigChanges(String manifest) {
  final source = manifest.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  final activities = RegExp(
    r'<activity\b[^>]*android:name\s*=\s*"\.MainActivity"[^>]*>',
  ).allMatches(source).toList();
  expect(
    activities,
    hasLength(1),
    reason:
        '$_manifest에 android:name=".MainActivity"인 <activity>가 하나 있어야 한다 (큰따옴표·상대 이름 기준)',
  );
  final attribute = RegExp(r'android:configChanges\s*=\s*"([^"]*)"')
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
  test('MainActivity configChanges는 Flutter 템플릿 기본값에 assetsPaths를 더한 것이다', () {
    final configChanges = _mainActivityConfigChanges(
      File(_manifest).readAsStringSync(),
    );
    expect(configChanges, {
      // Flutter 프로젝트 템플릿 기본값 — 지우면 회전·글자 크기 변경 등에도 다시 만들어진다
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
      // #96 — Android 14+ "색상 대비"를 바꾸면 리소스 오버레이가 바뀌어 CONFIG_ASSETS_PATHS만 바뀐다
      // (API 36 에뮬레이터 logcat의 configDiff). 빠지면 고대비 전환 때마다 입력이 사라진다.
      'assetsPaths',
      // fontWeightAdjustment("굵은 텍스트")는 넣지 않는다: 선언하면 엔진이 MediaQuery.boldText를 갱신하지 않는다.
      // 그래서 지금은 굵은 텍스트를 바꾸면 다시 만들어진다 — #148.
    });
  });
}
