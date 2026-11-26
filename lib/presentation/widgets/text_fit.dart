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

/// [fontSize]에 배율을 반영한 한 줄 높이가 [maxHeight]를 넘지 않도록 줄인 글자 크기 ([fitFontSize] 참고).
///
/// 한 줄 높이 = `배율 반영 크기 × heightFactor`를 정수로 올림한 값
/// (`TextPainter`가 문단 높이를 정수로 올림하므로 같은 기준으로 판정한다).
///
/// [inkHeightFactor]가 있으면 `배율 반영 크기 × inkHeightFactor`(올림하지 않는다)도 [maxHeight]를 넘지 않아야 한다.
/// 2차원 각인(#155)처럼 잉크가 한 줄 상자보다 높은 그림의 높이다 — 그 높이는 글리프 잉크로 정해지고
/// 정수로 올림되지 않으므로, 한 줄 높이와 따로 판정한다(같이 올림하면 띠 높이의 소수부 때문에 불필요하게 줄어든다).
double fitFontSizeToHeight(
  double fontSize, {
  required double maxHeight,
  required TextScaler textScaler,
  double heightFactor = 1.0,
  double? inkHeightFactor,
}) => fitFontSize(
  fontSize,
  textScaler: textScaler,
  fits: (scaled) =>
      (scaled * heightFactor).ceilToDouble() <= maxHeight &&
      (inkHeightFactor == null || scaled * inkHeightFactor <= maxHeight),
);
