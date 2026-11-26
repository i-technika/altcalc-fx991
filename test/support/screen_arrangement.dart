import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/settings_button.dart';

/// 그려진 계산기 화면이 **위아래 배치**인지 (#41).
///
/// 설정 버튼은 모든 배치에 있으므로(#41 이전에는 위아래 배치에 없었다) 버튼 유무가 아니라 위치로 판정한다.
/// 위아래 배치는 네 가지를 모두 만족한다.
/// - 키패드가 실물 배열이다. 가로형(#142)은 넓은 배열이다.
/// - 키패드가 LCD 바로 아래에 있다(간격 [CalcTheme.screenLcdKeypadGap]). 접힘선 기준 위아래 배치(테이블톱)는
///   그 사이에 접힘선과 양쪽 여백이 있어 더 떨어져 있다.
/// - 설정 버튼이 LCD 위 상단 띠에 있다(보이는 버튼의 윗변이 LCD 윗변보다 위). 세로 접힘선 기준 배치는 LCD 아래다.
/// - 설정 버튼의 오른쪽 끝이 LCD 오른쪽 끝과 같다.
bool isStackedArrangement(WidgetTester tester) =>
    drawnArrangementOf(tester) == DrawnArrangement.stacked;

/// 화면에 그려진 LCD·키패드·설정 버튼 위치로 본 배치 종류
enum DrawnArrangement {
  /// 위아래 배치 — [isStackedArrangement]
  stacked,

  /// 가로형 (#142) — 넓은 배열 키패드가 LCD 바로 아래(간격 [CalcTheme.screenLcdKeypadGap])에 있고, 설정 버튼이 LCD 위
  /// 상단 띠에 있다
  landscape,

  /// LCD와 키패드가 좌우로 나란히 놓임 (세로 접힘선 기준 배치)
  sideBySide,

  /// 위 LCD·아래 키패드이지만 사이가 간격보다 넓음 (가로 접힘선 기준 테이블톱 배치)
  tabletop,

  /// 위 어느 것에도 맞지 않음 (배치가 깨졌다)
  unknown,
}

/// 그려진 계산기 화면의 배치 종류 (#41 R1). 위아래 배치는 [isStackedArrangement]의 네 조건을 모두 만족할 때다.
/// - 가로형: 키패드가 넓은 배열이고 위아래 배치의 나머지 조건 중 간격·설정 버튼 높이를 만족한다(버튼 오른쪽 끝은
///   왼손잡이·기록 영역이 있으면 LCD 오른쪽 끝과 다르다).
/// - 좌우: LCD와 키패드가 가로로 겹치지 않고, 윗변이 같다(세로 접힘선은 키패드 윗변에 LCD를 맞춘다).
/// - 테이블톱: 키패드가 LCD 아래에 간격보다 더 떨어져 있다(사이에 접힘선과 양쪽 여백). 설정 버튼 위치는 보지 않는다 —
///   위 절반 모서리로 간 버튼은 손잡이에 따라 LCD 오른쪽 끝과 맞을 수 있다.
DrawnArrangement drawnArrangementOf(WidgetTester tester) {
  const tolerance = 0.01;
  final lcd = tester.getRect(find.byType(LcdDisplay));
  final keypad = tester.getRect(find.byKey(const ValueKey('calc-keypad')));
  final button = tester.getRect(find.byKey(SettingsButton.buttonKey));
  final wide =
      tester.widget<CalcKeypad>(find.byType(CalcKeypad)).arrangement ==
      KeypadArrangement.wide;
  final gap = keypad.top - lcd.bottom;
  final besideGap = (gap - CalcTheme.screenLcdKeypadGap).abs() <= tolerance;
  if (wide && besideGap && button.top < lcd.top) {
    return DrawnArrangement.landscape;
  }
  if (!wide &&
      besideGap &&
      button.top < lcd.top &&
      (button.right - lcd.right).abs() <= tolerance) {
    return DrawnArrangement.stacked;
  }
  if ((keypad.left >= lcd.right - tolerance ||
          keypad.right <= lcd.left + tolerance) &&
      (keypad.top - lcd.top).abs() <= tolerance) {
    return DrawnArrangement.sideBySide;
  }
  if (gap > CalcTheme.screenLcdKeypadGap + tolerance) {
    return DrawnArrangement.tabletop;
  }
  return DrawnArrangement.unknown;
}
