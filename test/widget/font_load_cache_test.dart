import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bundled_fonts.dart';

/// #11 메모(#16): 키패드는 라벨 폭을 글꼴로 재서 캐시하고(`_LabelWidthLimits._emWidthCache`),
/// 그 폭으로 모든 키의 통일 글자 크기를 정한다. 글꼴이 나중에 로드되면(웹 지연 로드, `FontLoader`)
/// `fontsChange` 시스템 메시지 → [PaintingBinding.systemFonts] 알림으로
/// 1. 폭 캐시가 비워지고, 2. 키패드가 다시 빌드되어 새 글꼴로 글자 크기를 다시 계산해야 한다.
///
/// 이 파일은 "번들 글꼴 로드 전" 상태가 필요하므로 다른 글꼴 테스트와 분리한다.
void main() {
  double legendFontOf(WidgetTester tester, CalcKeyId id) => tester
      .widget<CalcKeyButton>(
        find.byWidgetPredicate((w) => w is CalcKeyButton && w.keyDef.id == id),
      )
      .legendFontSize!;

  testWidgets('글꼴을 나중에 로드하면 화면의 키 글자 크기가 새 글꼴로 다시 계산된다', (tester) async {
    // 테스트 글꼴은 모든 글자가 1em 정사각형이라 각인이 번들 글꼴보다 넓다 — 가장 좁게 들어가는 각인 쌍(`·` 키
    // `Ran#`·`RanInt`)의 폭 한도가 최소 글자 크기보다 작아, 각인 글자 크기는 하한에 걸린다(#253 전에는 `MENU SETUP`). (#156부터 SHIFT·ALPHA는 원형 버튼이라 메인 라벨 폭 기준에 들지 않아, 각인 글자 크기로 본다.)
    const size = Size(360, 420);
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            height: 420,
            child: CalcKeypad(enableHaptics: false),
          ),
        ),
      ),
    );
    final before = legendFontOf(tester, CalcKeyId.shift);
    expect(
      before,
      KeypadMetrics.compute(size, TextScaler.noScaling).legendFontSize,
    );

    var notified = 0;
    void listener() => notified++;
    PaintingBinding.instance.systemFonts.addListener(listener);
    addTearDown(
      () => PaintingBinding.instance.systemFonts.removeListener(listener),
    );

    await tester.runAsync(() async {
      await loadBundledFonts();
      await pumpEventQueue();
    });
    expect(notified, greaterThan(0), reason: 'fontsChange → systemFonts 알림');
    await tester.pump();

    // 번들 각인 글꼴(Saira)은 테스트 글꼴보다 글자가 좁아 같은 각인에 더 큰 글자가 들어간다.
    // 캐시가 비워지지 않거나 키패드가 다시 빌드되지 않으면 크기가 그대로 남는다.
    final after = legendFontOf(tester, CalcKeyId.shift);
    expect(after, greaterThan(before));
    expect(
      after,
      KeypadMetrics.compute(size, TextScaler.noScaling).legendFontSize,
    );
    // 모든 키가 같은 크기로 갱신된다. 메인 라벨도 구역(함수부·숫자부 각인 종류, #156·#225)마다 새 글꼴로 다시 계산한 크기다.
    final metrics = KeypadMetrics.compute(size, TextScaler.noScaling);
    for (final b in tester.widgetList<CalcKeyButton>(
      find.byType(CalcKeyButton),
    )) {
      expect(b.legendFontSize, after, reason: b.keyDef.id.name);
      expect(
        b.mainLabelFontSize,
        metrics.mainLabelFontSizeOf(b.keyDef),
        reason: b.keyDef.id.name,
      );
    }
  });
}
