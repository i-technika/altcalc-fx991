import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/settings_button.dart';

/// 그려진 계산기 화면이 **위아래 배치**인지 (#41).
///
/// 설정 버튼은 모든 배치에 있으므로(#41 이전에는 위아래 배치에 없었다) 버튼 유무가 아니라 위치로 판정한다.
/// 위아래 배치는 세 가지를 모두 만족한다.
/// - 키패드가 LCD 바로 아래에 있다(간격 [CalcTheme.screenLcdKeypadGap]). 접힘선 기준 위아래 배치(테이블톱)는
///   그 사이에 접힘선과 양쪽 여백이 있어 더 떨어져 있다.
/// - 설정 버튼이 LCD 위 상단 띠에 있다(보이는 버튼의 윗변이 LCD 윗변보다 위). 좌우 분할은 LCD 아래다.
/// - 설정 버튼의 오른쪽 끝이 LCD 오른쪽 끝과 같다.
bool isStackedArrangement(WidgetTester tester) {
  const tolerance = 0.01;
  final lcd = tester.getRect(find.byType(LcdDisplay));
  final keypad = tester.getRect(find.byKey(const ValueKey('calc-keypad')));
  final button = tester.getRect(find.byKey(SettingsButton.buttonKey));
  return (keypad.top - lcd.bottom - CalcTheme.screenLcdKeypadGap).abs() <=
          tolerance &&
      button.top < lcd.top &&
      (button.right - lcd.right).abs() <= tolerance;
}
