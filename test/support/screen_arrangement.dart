import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';

/// 그려진 계산기 화면이 **위아래 배치**인지 (#41).
///
/// 위아래 배치는 세 가지를 모두 만족한다.
/// - 키패드가 실물 배열이다. 가로형(#142)은 넓은 배열이다.
/// - 키패드가 LCD 바로 아래에 있다(간격 [CalcTheme.screenLcdKeypadGap]). 접힘선 기준 위아래 배치(테이블톱)는
///   그 사이에 접힘선과 양쪽 여백이 있어 더 떨어져 있다.
/// - LCD와 키패드의 좌우 끝이 같다(둘 다 본체 폭, #141).
bool isStackedArrangement(WidgetTester tester) =>
    drawnArrangementOf(tester) == DrawnArrangement.stacked;

/// 화면에 그려진 LCD·키패드 위치로 본 배치 종류
enum DrawnArrangement {
  /// 위아래 배치 — [isStackedArrangement]
  stacked,

  /// 가로형 (#142) — 넓은 배열 키패드가 활성 LCD 바로 아래(간격 [CalcTheme.screenLcdKeypadGap])에 있다
  landscape,

  /// LCD와 키패드가 좌우로 나란히 놓임 (세로 접힘선 기준 배치)
  sideBySide,

  /// 위 LCD·아래 키패드이지만 사이가 간격보다 넓음 (가로 접힘선 기준 테이블톱 배치)
  tabletop,

  /// 위 어느 것에도 맞지 않음 (배치가 깨졌다)
  unknown,
}

/// 그려진 계산기 화면의 배치 종류 (#41 R1). 위아래 배치는 [isStackedArrangement]의 세 조건을 모두 만족할 때다.
/// - 가로형: 키패드가 넓은 배열이고 LCD 바로 아래(간격)에 있다(활성 LCD는 기록 영역이 있으면 블록 폭이다).
/// - 좌우: LCD와 키패드가 가로로 겹치지 않고, LCD 윗변이 키패드 윗변 이하다(세로 접힘선 양쪽 — LCD는 본체 윗변부터, #190).
/// - 테이블톱: 키패드가 LCD 아래에 간격보다 더 떨어져 있다(사이에 접힘선과 양쪽 여백).
DrawnArrangement drawnArrangementOf(WidgetTester tester) {
  const tolerance = 0.01;
  final lcd = tester.getRect(find.byType(LcdDisplay));
  final keypad = tester.getRect(find.byKey(const ValueKey('calc-keypad')));
  final wide =
      tester.widget<CalcKeypad>(find.byType(CalcKeypad)).arrangement ==
      KeypadArrangement.wide;
  final gap = keypad.top - lcd.bottom;
  final besideGap = (gap - CalcTheme.screenLcdKeypadGap).abs() <= tolerance;
  if (wide && besideGap) return DrawnArrangement.landscape;
  if (!wide &&
      besideGap &&
      (keypad.left - lcd.left).abs() <= tolerance &&
      (keypad.right - lcd.right).abs() <= tolerance) {
    return DrawnArrangement.stacked;
  }
  if ((keypad.left >= lcd.right - tolerance ||
          keypad.right <= lcd.left + tolerance) &&
      lcd.top <= keypad.top + tolerance) {
    return DrawnArrangement.sideBySide;
  }
  if (gap > CalcTheme.screenLcdKeypadGap + tolerance) {
    return DrawnArrangement.tabletop;
  }
  return DrawnArrangement.unknown;
}
