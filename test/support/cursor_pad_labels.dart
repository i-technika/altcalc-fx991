import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:material_ui/material_ui.dart';

/// 커서 패드 방향 라벨 검사 도구 (테스트 공용, #65).

/// 화면에 그려진 커서 패드 [sector] 라벨(Text)
Finder cursorPadLabel(CursorPadSector sector) => find.descendant(
  of: find.byKey(CalcKeyButton.keycapKeyOf(CursorPad.defOf(sector).id)),
  matching: find.byType(Text),
);

/// 화면의 커서 패드(하나) [sectors] 라벨이 허브(둘레선 포함)에 덮이지 않고, 라벨 자리를 뺀 키캡에서도
/// 줄지 않았는지 확인한다. 실측 허브는 지름이 패드 높이의 약 1/2이라, 라벨을 반쪽 상자 가운데에 두면
/// 허브에 덮인다. 방향 구역은 데드존까지라 "자기 구역 안" 검사만으로는 이를 잡지 못한다.
void expectCursorPadLabelsClearOfHub(
  WidgetTester tester, {
  Iterable<CursorPadSector> sectors = CursorPadSector.values,
  String context = '',
}) {
  final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
  final g = CursorPadGeometry(pad.size);
  for (final sector in sectors) {
    final text = cursorPadLabel(sector);
    final label = tester.getRect(text).shift(-pad.topLeft);
    final nearest = Offset(
      g.center.dx.clamp(label.left, label.right),
      g.center.dy.clamp(label.top, label.bottom),
    );
    expect(
      (nearest - g.center).distance,
      greaterThanOrEqualTo(g.hubRadius + CalcTheme.cursorPadDividerWidth / 2),
      reason: '$context ${sector.name} 라벨 $label이 허브에 덮인다',
    );
    // FittedBox가 줄이면 그려진 높이(getRect)가 글자 상자 높이(getSize)보다 작아진다.
    expect(
      tester.getRect(text).height,
      moreOrLessEquals(tester.getSize(text).height, epsilon: 0.01),
      reason: '$context ${sector.name} 라벨이 줄었다',
    );
  }
}
