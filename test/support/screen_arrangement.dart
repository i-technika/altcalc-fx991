import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/history_panel.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';

/// 그려진 계산기 화면이 **위아래 배치**인지 (#41).
///
/// 위아래 배치는 네 가지를 모두 만족한다.
/// - 키패드가 실물 배열이다. 가로형(#142)은 넓은 배열이다.
/// - 키패드가 LCD 바로 아래에 있다(간격 [CalcTheme.screenLcdKeypadGap]). 가로 접힘선 기준 배치는
///   그 사이에 접힘선과 양쪽 여백이 있어 더 떨어져 있다.
/// - LCD와 키패드의 좌우 끝이 같다(둘 다 본체 폭, #141).
/// - 계산 기록 영역이 옆에 보이지 않는다. 책 자세(세로 접힘선, #143)는 손 쪽 패널이 세로형이고 옆 패널이 기록이다.
bool isStackedArrangement(WidgetTester tester) =>
    drawnArrangementOf(tester) == DrawnArrangement.stacked;

/// 화면에 그려진 LCD·키패드 위치로 본 배치 종류
enum DrawnArrangement {
  /// 위아래 배치 — [isStackedArrangement]
  stacked,

  /// 가로형 (#142) — 넓은 배열 키패드가 활성 LCD 바로 아래(간격 [CalcTheme.screenLcdKeypadGap])에 있다
  landscape,

  /// 책 자세 (세로 접힘선 기준 배치, #143) — 손 쪽 패널에 LCD·키패드(세로형), 그 옆 패널에 계산 기록
  sideBySide,

  /// 위 LCD·아래 키패드이지만 사이가 간격보다 넓음 (가로 접힘선 기준 배치 — 사이에 접힘선)
  tabletop,

  /// 위 어느 것에도 맞지 않음 (배치가 깨졌다)
  unknown,
}

/// 그려진 계산기 화면의 배치 종류 (#41 R1). 위아래 배치는 [isStackedArrangement]의 네 조건을 모두 만족할 때다.
/// - 가로형: 키패드가 넓은 배열이고 LCD 바로 아래(간격)에 있다(활성 LCD는 기록 영역이 있으면 블록 폭이다).
/// - 책 자세: 세로형처럼 LCD 바로 아래 같은 폭의 실물 배열 키패드가 있고, 계산 기록 영역이 그 옆(가로로 겹치지 않음)에
///   있다(#143).
/// - 테이블톱: 키패드가 LCD 아래에 간격보다 더 떨어져 있다(사이에 접힘선과 양쪽 여백).
DrawnArrangement drawnArrangementOf(WidgetTester tester) {
  const tolerance = 0.01;
  final lcd = tester.getRect(find.byType(LcdDisplay));
  final keypad = tester.getRect(find.byKey(const ValueKey('calc-keypad')));
  final wide =
      tester.widget<CalcKeypad>(find.byType(CalcKeypad)).arrangement ==
      KeypadArrangement.wide;
  // 보이지 않는(기록 영역이 없는 배치) 기록 영역은 Offstage라 찾지 않는다.
  final historyFinder = find.byType(HistoryPanel);
  final history = historyFinder.evaluate().isEmpty
      ? null
      : tester.getRect(historyFinder);
  final gap = keypad.top - lcd.bottom;
  final besideGap = (gap - CalcTheme.screenLcdKeypadGap).abs() <= tolerance;
  if (wide && besideGap) return DrawnArrangement.landscape;
  if (!wide &&
      besideGap &&
      (keypad.left - lcd.left).abs() <= tolerance &&
      (keypad.right - lcd.right).abs() <= tolerance) {
    final historyBeside =
        history != null &&
        (history.right <= keypad.left + tolerance ||
            history.left >= keypad.right - tolerance);
    return historyBeside
        ? DrawnArrangement.sideBySide
        : DrawnArrangement.stacked;
  }
  if (gap > CalcTheme.screenLcdKeypadGap + tolerance) {
    return DrawnArrangement.tabletop;
  }
  return DrawnArrangement.unknown;
}
