import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/main.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:material_ui/material_ui.dart';

import '../../preview/key_preview_main.dart';
import '../support/bundled_fonts.dart';

/// 미리보기 입력 로그의 줄 높이가 실제 글꼴에서도 고정인지 지킨다 (#105).
///
/// 조작 패널의 스크롤 전환 높이는 "로그 3줄" 높이를 한 줄 높이로 계산하므로, 대체 글꼴(Math)로 그리는 `∫`가 든
/// 줄도 높이가 같아야 한다. 번들 글꼴은 한번 로드하면 파일 안에서 유지되어 다른 배치 테스트의 치수를 바꾸므로
/// `key_preview_test.dart`와 파일을 나눈다.
void main() {
  setUpAll(loadBundledFonts);

  Future<void> press(WidgetTester tester, CalcKeyId id) async {
    await tester.tap(find.byKey(CalcKeyButton.keycapKeyOf(id)));
    await tester.pump();
  }

  testWidgets('Math 대체 글꼴 글자(∫)가 든 줄도 다른 줄과 높이가 같다', (tester) async {
    tester.view.physicalSize =
        const Size(1280, 900) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        child: AltCalcApp(
          frameBuilder: (context, screen) => KeyPreviewScreen(screen: screen),
        ),
      ),
    );
    await press(tester, CalcKeyId.num7);
    await press(tester, CalcKeyId.integral);
    await press(tester, CalcKeyId.shift);
    await press(tester, CalcKeyId.integral);

    final lines = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('preview-log')),
            matching: find.byType(Text),
          ),
        )
        .toList();
    expect(lines.map((t) => t.data), [
      '3. d/dx◼  ← SHIFT + ∫◻◻◼',
      '[SHIFT 대기]',
      '2. ∫◻◻◼',
      '1. 7',
    ]);
    final heights = {
      for (final t in lines) t.data!: tester.getSize(find.byWidget(t)).height,
    };
    for (final MapEntry(:key, :value) in heights.entries) {
      expect(value, moreOrLessEquals(heights['1. 7']!), reason: key);
    }

    // 전제: strut이 없으면 ∫가 든 줄이 더 높다 — 그래야 위 검사가 strut을 지킨다.
    final integral = lines[2];
    final context = tester.element(find.byWidget(integral));
    final painter = TextPainter(
      text: TextSpan(
        text: integral.data,
        style: DefaultTextStyle.of(context).style.merge(integral.style),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    addTearDown(painter.dispose);
    expect(painter.height, greaterThan(heights['1. 7']! + 0.5));
  });
}
