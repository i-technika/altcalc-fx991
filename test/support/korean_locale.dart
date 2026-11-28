import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';

/// 테스트 동안 기기(플랫폼) 로캘을 한국어로 둔다.
///
/// 스크린리더 문구(`CalcSemanticStrings.of`)는 기기 로캘로 언어를 고른다. 테스트 기본 로캘은 en_US라
/// 한국어 문구를 검사하는 테스트는 이 함수를 먼저 부른다. 테스트가 끝나면 원래대로 돌린다.
void useKoreanLocale(WidgetTester tester) {
  tester.platformDispatcher.localeTestValue = const Locale('ko', 'KR');
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
}
