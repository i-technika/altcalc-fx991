import 'package:material_ui/material_ui.dart';

/// 글자 크기 하한 (dp) — 0 크기 글꼴을 피하기 위한 값.
const double minFittedFontSize = 1.0;

/// 요청 글자 크기 [fontSize]에 시스템 글자 배율([textScaler])을 반영한 한 줄 높이가
/// [maxHeight]를 넘지 않도록 줄인 글자 크기를 반환한다. 이미 들어가면 [fontSize] 그대로다.
///
/// - 한 줄 높이 = `textScaler.scale(크기) × heightFactor`를 정수로 올림한 값
///   (`TextPainter`가 문단 높이를 정수로 올림하므로 같은 기준으로 판정한다).
/// - 반환값은 배율을 반영하기 **전** 크기다. 호출자는 같은 [textScaler]로 그려야 한다.
/// - [minFittedFontSize]로도 들어가지 않으면 [minFittedFontSize]를 반환한다(잘림은 호출자 몫).
double fitFontSizeToHeight(
  double fontSize, {
  required double maxHeight,
  required TextScaler textScaler,
  double heightFactor = 1.0,
}) {
  bool fits(double size) =>
      (textScaler.scale(size) * heightFactor).ceilToDouble() <= maxHeight;
  if (fits(fontSize)) return fontSize;
  if (fontSize <= minFittedFontSize || !fits(minFittedFontSize)) {
    return minFittedFontSize;
  }
  // 시스템 글자 배율이 비선형(안드로이드 14 이상)일 수 있으므로 비례 계산 대신 이분 탐색으로
  // 높이에 들어가는 가장 큰 글자 크기를 찾는다. lo는 항상 들어간다.
  var lo = minFittedFontSize;
  var hi = fontSize;
  for (var i = 0; i < 24; i++) {
    final mid = (lo + hi) / 2;
    if (fits(mid)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}
