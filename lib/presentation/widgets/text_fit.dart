import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// 글자 크기 하한 (dp) — 0 크기 글꼴을 피하기 위한 값.
const double minFittedFontSize = 1.0;

/// 요청 글자 크기 [fontSize]에 시스템 글자 배율([textScaler])을 반영한 크기가 [fits]를 만족하도록
/// 줄인 글자 크기를 반환한다. 이미 만족하면 [fontSize] 그대로다.
///
/// - [fits]는 **배율을 반영한** 글자 크기를 받아 허용 여부를 돌려준다(크기에 대해 단조여야 한다).
/// - 반환값은 배율을 반영하기 **전** 크기다. 호출자는 같은 [textScaler]로 그려야 한다.
/// - [minFittedFontSize]로도 만족하지 않으면 [minFittedFontSize]를 반환한다(잘림·축소는 호출자 몫).
double fitFontSize(
  double fontSize, {
  required TextScaler textScaler,
  required bool Function(double scaledFontSize) fits,
}) {
  bool ok(double size) => fits(textScaler.scale(size));
  if (ok(fontSize)) return fontSize;
  if (fontSize <= minFittedFontSize || !ok(minFittedFontSize)) {
    return minFittedFontSize;
  }
  // 시스템 글자 배율이 비선형(안드로이드 14 이상)일 수 있으므로 비례 계산 대신 이분 탐색으로
  // 조건을 만족하는 가장 큰 글자 크기를 찾는다. lo는 항상 만족한다.
  var lo = minFittedFontSize;
  var hi = fontSize;
  for (var i = 0; i < 24; i++) {
    final mid = (lo + hi) / 2;
    if (ok(mid)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// [fitFontSize]와 같되 [fits]가 크기에 대해 **단조가 아니어도** 된다 (#264 R2).
///
/// 줄 상자 높이·깊이는 정수 dp로 반올림되므로, 그 값을 쓰는 조건은 반올림 경계에서 거짓 → 참으로 되돌아갈 수 있다. 그런
/// 조건에 이분 탐색([fitFontSize])을 쓰면 맞는 크기를 지나쳐 훨씬 작은 크기에서 멈춘다. 이 함수는 [fontSize]에서 [step]씩
/// 내려오며 처음 만족하는 크기를 찾고, 그 바로 위 구간만 이분 탐색으로 좁힌다 — [step]보다 좁은 구간에서만 참인 크기는
/// 놓칠 수 있다(반올림 구간은 그리는 크기로 0.5~1dp다).
double fitFontSizeScanning(
  double fontSize, {
  required TextScaler textScaler,
  required bool Function(double scaledFontSize) fits,
  double step = 0.25,
}) {
  assert(step > 0, 'step은 양수여야 한다');
  bool ok(double size) => fits(textScaler.scale(size));
  if (ok(fontSize) || fontSize <= minFittedFontSize) {
    return math.max(fontSize, minFittedFontSize);
  }
  var hi = fontSize; // 만족하지 않는 크기
  for (var size = fontSize - step; size > minFittedFontSize; size -= step) {
    if (ok(size)) {
      var lo = size;
      for (var i = 0; i < 16; i++) {
        final mid = (lo + hi) / 2;
        if (ok(mid)) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      return lo;
    }
    hi = size;
  }
  return minFittedFontSize;
}

/// [fontSize]에 배율을 반영한 한 줄 높이가 [maxHeight]를 넘지 않도록 줄인 글자 크기 ([fitFontSize] 참고).
///
/// 한 줄 높이 = `배율 반영 크기 × heightFactor`를 정수로 올림한 값
/// (`TextPainter`가 문단 높이를 정수로 올림하므로 같은 기준으로 판정한다).
double fitFontSizeToHeight(
  double fontSize, {
  required double maxHeight,
  required TextScaler textScaler,
  double heightFactor = 1.0,
}) => fitFontSize(
  fontSize,
  textScaler: textScaler,
  fits: (scaled) => (scaled * heightFactor).ceilToDouble() <= maxHeight,
);
