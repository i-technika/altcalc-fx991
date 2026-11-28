import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';

/// 그려진 계산기 화면이 **위아래 배치**인지 (#41).
///
/// 위아래 배치는 세 가지를 모두 만족한다.
/// - 키패드가 실물 배열이다. 가로형(#142)·책 자세(#285)는 넓은 배열이다.
/// - 키패드가 LCD 바로 아래에 있다(간격 [CalcTheme.screenLcdKeypadGap]). 가로 접힘선 기준 배치는
///   그 사이에 접힘선과 양쪽 여백이 있어 더 떨어져 있다.
/// - LCD와 키패드의 좌우 끝이 같다(둘 다 본체 폭, #141).
bool isStackedArrangement(WidgetTester tester) =>
    drawnArrangementOf(tester) == DrawnArrangement.stacked;

/// 화면에 그려진 LCD·키패드 위치로 본 배치 종류
enum DrawnArrangement {
  /// 위아래 배치 — [isStackedArrangement]
  stacked,

  /// 가로형 (#142) — 넓은 배열 키패드가 LCD 바로 아래(간격 [CalcTheme.screenLcdKeypadGap])에 있다
  landscape,

  /// 책 자세 (세로 접힘선 기준 배치, #143·#285) — 가로형처럼 넓은 배열 키패드가 LCD 바로 아래에 있고, 두 블록 사이에
  /// 접힘선이 있다(키패드에 블록 사이 최소 간격 `CalcKeypad.minSectionGap`을 준다)
  sideBySide,

  /// 위 LCD·아래 키패드이지만 사이가 간격보다 넓음 (가로 접힘선 기준 배치 — 사이에 접힘선)
  tabletop,

  /// 위 어느 것에도 맞지 않음 (배치가 깨졌다)
  unknown,
}

/// 그려진 계산기 화면의 배치 종류 (#41 R1). 위아래 배치는 [isStackedArrangement]의 세 조건을 모두 만족할 때다.
/// - 가로형: 키패드가 넓은 배열이고 LCD 바로 아래(간격)에 있다.
/// - 책 자세: 가로형과 같은 모양이고 키패드가 블록 사이 최소 간격(접힘선)을 받았다(#285). 물리 힌지면 LCD가 숫자부 쪽
///   패널에만 있어 키패드보다 좁다.
/// - 테이블톱: 키패드가 LCD 아래에 간격보다 더 떨어져 있다(사이에 접힘선과 양쪽 여백).
DrawnArrangement drawnArrangementOf(WidgetTester tester) {
  const tolerance = 0.01;
  final lcd = tester.getRect(find.byType(LcdDisplay));
  final keypad = tester.getRect(find.byKey(const ValueKey('calc-keypad')));
  final keypadWidget = tester.widget<CalcKeypad>(find.byType(CalcKeypad));
  final wide = keypadWidget.arrangement == KeypadArrangement.wide;
  final gap = keypad.top - lcd.bottom;
  final besideGap = (gap - CalcTheme.screenLcdKeypadGap).abs() <= tolerance;
  if (wide && besideGap) {
    return keypadWidget.minSectionGap > 0
        ? DrawnArrangement.sideBySide
        : DrawnArrangement.landscape;
  }
  if (!wide &&
      besideGap &&
      (keypad.left - lcd.left).abs() <= tolerance &&
      (keypad.right - lcd.right).abs() <= tolerance) {
    return DrawnArrangement.stacked;
  }
  if (gap > CalcTheme.screenLcdKeypadGap + tolerance) {
    return DrawnArrangement.tabletop;
  }
  return DrawnArrangement.unknown;
}
