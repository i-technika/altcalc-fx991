import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_legend.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/key_legend_view.dart';
import 'package:material_ui/material_ui.dart';

/// 키 각인 [legend]를 그린 위젯을 찾는다 (#155).
///
/// 글자만 있는 각인은 `Text`, 2차원 각인(분수·첨자·근호)은 [KeyLegendView]로 그려진다.
/// 키 정의의 각인은 상수라 같은 각인이면 같은 인스턴스다.
Finder findLegend(KeyLegend legend) => switch (legend) {
  LegendText(:final text) => find.text(text),
  _ => find.byWidgetPredicate(
    (w) => w is KeyLegendView && identical(w.legend, legend),
    description: 'KeyLegendView(${legend.plainText})',
  ),
};

/// [finder]가 가리키는 각인 위젯(`Text` 또는 [KeyLegendView])의 글자 스타일.
TextStyle legendStyleOf(WidgetTester tester, Finder finder) =>
    switch (tester.widget(finder)) {
      final Text text => text.style!,
      final KeyLegendView view => view.style,
      final other => throw StateError('각인 위젯이 아니다: $other'),
    };
