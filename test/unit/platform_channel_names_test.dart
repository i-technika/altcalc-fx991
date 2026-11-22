import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/layout/form_factor.dart';
import 'package:itechnika_altcalc_fx991/core/theme/high_text_contrast.dart';

/// Dart가 쓰는 플랫폼 채널 이름이 Android `MainActivity.kt`가 거는 이름과 같은지 본다 (#108).
///
/// 한쪽만 바꾸면 Dart는 `MissingPluginException`(기기 채널)을 받거나 첫 값을 기다리다 시간 초과로 꺼짐에 머물고
/// (고대비 텍스트), 양쪽의 단위 테스트는 각자 자기 이름으로 맞아 통과한다. 그래서 여기서 두 소스를 맞댄다.
/// Kotlin 쪽 테스트(`MainActivityChannelsTest`)는 Kotlin 상수가 실제로 등록되는지를 본다.

const _mainActivity =
    'android/app/src/main/kotlin/com/example/itechnika_altcalc_fx991/MainActivity.kt';

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
      RegExp(r'(MethodChannel|EventChannel)\([^,)]*,\s*"').hasMatch(source),
      isFalse,
      reason: '채널 이름은 *_CHANNEL 상수로 적는다',
    );
  });
}
