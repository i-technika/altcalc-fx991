import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/layout/form_factor.dart';
import 'package:itechnika_altcalc_fx991/core/theme/high_text_contrast.dart';

/// Android `MainActivity.kt` 소스 검사 (#108) — Kotlin 단위 테스트가 구조상 볼 수 없는 것을 소스에서 본다.
///
/// 1. 플랫폼 채널 이름이 Dart 쪽과 같은지. 한쪽만 바꾸면 Dart는 `MissingPluginException`(기기 채널)을 받거나 첫 값을 기다리다 시간 초과로 꺼짐에 머물고
/// (고대비 텍스트), 양쪽의 단위 테스트는 각자 자기 이름으로 맞아 통과한다. 그래서 여기서 두 소스를 맞댄다.
///    Kotlin 쪽 테스트(`MainActivityChannelsTest`)는 Kotlin 상수가 실제로 등록되는지를 본다.
/// 2. `configureFlutterEngine`이 `super`를 부르는지. 그 호출이 플러그인(`shared_preferences` 등)을 등록하는데,
///    Kotlin 생명주기 테스트는 캐시 엔진을 써서 `super`가 바로 반환하므로(`FlutterActivity` 규칙) 빠져도 알 수 없다.

const _mainActivity =
    'android/app/src/main/kotlin/com/example/itechnika_altcalc_fx991/MainActivity.kt';
const _foldableProbe =
    'android/app/src/main/kotlin/com/example/itechnika_altcalc_fx991/FoldableDeviceProbe.kt';

/// `MainActivity.kt`의 `private const val <name> = "<값>"` 값
String _kotlinConstant(String source, String name) {
  final matches = RegExp(
    '^\\s*private const val $name = "([^"]+)"\\s*\$',
    multiLine: true,
  ).allMatches(source).toList();
  expect(
    matches,
    hasLength(1),
    reason: '$_mainActivity에 "private const val $name = \\"…\\"" 줄이 하나 있어야 한다',
  );
  return matches.single[1]!;
}

void main() {
  late String source;

  setUpAll(() {
    source = File(_mainActivity).readAsStringSync();
  });

  test('기기 특성 채널 (#24)', () {
    expect(
      FormFactor.deviceChannel.name,
      _kotlinConstant(source, 'DEVICE_CHANNEL'),
    );
  });

  test('폴더블 판정: Dart 제한 시간이 Android 쪽 창 배치 정보 기다림보다 넉넉히 길다 (#70)', () {
    // Android가 창 배치 정보를 끝까지 기다린 뒤 답해도 Dart가 먼저 시간 초과로 포기하지 않아야 한다.
    // 채널 왕복·메인 스레드 지연 몫으로 300ms 이상 여유를 둔다.
    final probe = File(_foldableProbe).readAsStringSync();
    final match = RegExp(
      r'^\s*const val LAYOUT_TIMEOUT_MILLIS = (\d+)L\s*$',
      multiLine: true,
    ).firstMatch(probe);
    expect(
      match,
      isNotNull,
      reason: '$_foldableProbe에 LAYOUT_TIMEOUT_MILLIS가 있어야 한다',
    );
    final androidWait = Duration(milliseconds: int.parse(match![1]!));
    expect(
      FormFactor.foldableQueryTimeout - androidWait,
      greaterThanOrEqualTo(const Duration(milliseconds: 300)),
    );
    // 힌지 센서는 목록으로 센다 — getDefaultSensor는 이 종류를 wake-up 센서로만 찾아 non-wake-up 센서를 놓친다.
    // (Kotlin 테스트의 Robolectric 섀도는 센서 조회를 대신 구현해 이 차이를 볼 수 없어 소스에서 본다.)
    expect(probe, contains('getSensorList(Sensor.TYPE_HINGE_ANGLE)'));
    expect(probe, isNot(contains('getDefaultSensor(')));
    // 메서드 이름도 맞댄다 — 한쪽만 바꾸면 Dart는 notImplemented(→ false)를 받아 늘 폴더블 아님이 된다
    expect(source, contains('"${FormFactor.foldableDeviceMethod}" ->'));
  });

  test('고대비 텍스트 이벤트 채널 (#95)', () {
    expect(
      SystemHighTextContrast.channel.name,
      _kotlinConstant(source, 'HIGH_TEXT_CONTRAST_CHANNEL'),
    );
  });

  test('MainActivity가 거는 채널은 위 두 개뿐이다', () {
    // 새 채널을 걸면 Dart 쪽 이름과의 대조를 여기에 더한다
    final channels = RegExp(
      r'^\s*private const val (\w+_CHANNEL) = ',
      multiLine: true,
    ).allMatches(source).map((m) => m[1]).toSet();
    expect(channels, {'DEVICE_CHANNEL', 'HIGH_TEXT_CONTRAST_CHANNEL'});
    // 상수를 거치지 않고 이름을 바로 적은 채널 생성도 막는다
    expect(
      RegExp(r'(MethodChannel|EventChannel|BasicMessageChannel)\([^,)]*,\s*"')
          .hasMatch(source),
      isFalse,
      reason: '채널 이름은 *_CHANNEL 상수로 적는다',
    );
  });

  test('configureFlutterEngine은 먼저 super를 불러 플러그인을 등록한다', () {
    final body = RegExp(
      r'override fun configureFlutterEngine\(flutterEngine: FlutterEngine\) \{\s*(\S[^\r\n]*)',
    ).firstMatch(source);
    expect(body, isNotNull, reason: 'configureFlutterEngine 재정의를 찾지 못했다');
    expect(body![1]!.trim(), 'super.configureFlutterEngine(flutterEngine)');
  });

  test('cleanUpFlutterEngine은 정리 뒤 마지막에 super를 부른다', () {
    final body = RegExp(
      r'override fun cleanUpFlutterEngine\(flutterEngine: FlutterEngine\) \{(.*?)\r?\n    \}',
      dotAll: true,
    ).firstMatch(source);
    expect(body, isNotNull, reason: 'cleanUpFlutterEngine 재정의를 찾지 못했다');
    final lines = body![1]!
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('//'))
        .toList();
    expect(lines.last, 'super.cleanUpFlutterEngine(flutterEngine)');
  });
}
