import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:material_ui/material_ui.dart';

/// 지정한 크기의 셀 하나에 버튼을 배치한다.
Widget _host(
  Widget child, {
  Size size = const Size(64, 72),
  double textScale = 1.0,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        backgroundColor: CalcTheme.bodyBackground,
        body: Center(
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    ),
  );
}

/// 플랫폼 채널로 나가는 햅틱 호출을 기록한다.
List<String> _recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

BoxDecoration _keycapDecoration(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find.byKey(CalcKeyButton.keycapKey),
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  group('3단 라벨 레이아웃', () {
    testWidgets('메인·SHIFT·ALPHA 라벨을 모두 표시한다 (CALC / SOLVE / =)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(CalcKeyButton(keyDef: keyDefOf(CalcKeyId.calc))),
      );

      expect(find.text('CALC'), findsOneWidget);
      expect(find.text('SOLVE'), findsOneWidget);
      expect(find.text('='), findsOneWidget);
    });

    testWidgets('SHIFT 각인은 좌측 금색, ALPHA 각인은 우측 빨간색이며 키캡보다 위에 있다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(CalcKeyButton(keyDef: keyDefOf(CalcKeyId.sin))),
      );

      final shift = tester.widget<Text>(find.text('sin⁻¹'));
      final alpha = tester.widget<Text>(find.text('D'));
      expect(shift.style!.color, CalcTheme.shiftLabel);
      expect(alpha.style!.color, CalcTheme.alphaLabel);

      final shiftRect = tester.getRect(find.text('sin⁻¹'));
      final alphaRect = tester.getRect(find.text('D'));
      final capRect = tester.getRect(find.byKey(CalcKeyButton.keycapKey));
      expect(shiftRect.center.dx, lessThan(alphaRect.center.dx));
      expect(shiftRect.bottom, lessThanOrEqualTo(capRect.top + 0.01));
      expect(alphaRect.bottom, lessThanOrEqualTo(capRect.top + 0.01));
    });

    testWidgets('각인이 없는 키는 메인 라벨만 표시한다', (tester) async {
      await tester.pumpWidget(
        _host(CalcKeyButton(keyDef: keyDefOf(CalcKeyId.num4))),
      );

      expect(find.byType(Text), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });
  });

  group('카테고리 테마', () {
    testWidgets('모든 키의 키캡 배경·라벨 색이 카테고리 색과 일치한다', (tester) async {
      for (final def in allKeys) {
        await tester.pumpWidget(
          _host(CalcKeyButton(keyDef: def, onPressed: (_) {})),
        );

        expect(
          _keycapDecoration(tester).color,
          def.category.background,
          reason: '$def',
        );
        final main = tester.widget<Text>(find.text(def.mainLabel));
        expect(main.style!.color, def.category.foreground, reason: '$def');
      }
    });
  });

  group('반응형 크기', () {
    const sizes = [Size(28, 34), Size(64, 72), Size(160, 180), Size(90, 40)];

    for (final size in sizes) {
      testWidgets('50키 전체가 ${size.width}x${size.height} 셀에서 넘치지 않는다', (
        tester,
      ) async {
        for (final def in allKeys) {
          await tester.pumpWidget(
            _host(CalcKeyButton(keyDef: def), size: size, textScale: 2.0),
          );
          // RenderFlex 오버플로 등 레이아웃 예외가 없어야 한다.
          expect(tester.takeException(), isNull, reason: '$def @ $size');
          expect(
            tester.getSize(find.byType(CalcKeyButton)),
            size,
            reason: '$def @ $size',
          );
        }
      });
    }

    testWidgets('키 크기가 커지면 메인 라벨 글자도 커진다', (tester) async {
      double mainFontSize(Size size) {
        final text = tester.widget<Text>(find.text('7'));
        return text.style!.fontSize!;
      }

      await tester.pumpWidget(
        _host(
          CalcKeyButton(keyDef: keyDefOf(CalcKeyId.num7)),
          size: const Size(40, 48),
        ),
      );
      final small = mainFontSize(const Size(40, 48));

      await tester.pumpWidget(
        _host(
          CalcKeyButton(keyDef: keyDefOf(CalcKeyId.num7)),
          size: const Size(80, 96),
        ),
      );
      final large = mainFontSize(const Size(80, 96));

      expect(large, closeTo(small * 2, 0.001));
    });
  });

  group('입력 및 햅틱', () {
    testWidgets('탭하면 lightImpact 햅틱 1회 후 키 ID로 콜백한다', (tester) async {
      final haptics = _recordHaptics(tester);
      final pressed = <CalcKeyId>[];

      await tester.pumpWidget(
        _host(
          CalcKeyButton(
            keyDef: keyDefOf(CalcKeyId.num7),
            onPressed: pressed.add,
          ),
        ),
      );
      await tester.tap(find.byType(CalcKeyButton));
      await tester.pump();

      expect(pressed, [CalcKeyId.num7]);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
    });

    testWidgets('누르고 있는 동안 눌림 표시, 떼면 원래대로 돌아간다', (tester) async {
      _recordHaptics(tester);
      final def = keyDefOf(CalcKeyId.num7);
      await tester.pumpWidget(
        _host(CalcKeyButton(keyDef: def, onPressed: (_) {})),
      );

      final idle = _keycapDecoration(tester);
      expect(idle.boxShadow, isNotEmpty);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CalcKeyButton)),
      );
      await tester.pump();
      final down = _keycapDecoration(tester);
      expect(down.boxShadow, isEmpty);
      expect(down.color, isNot(idle.color));

      await gesture.up();
      await tester.pump();
      expect(_keycapDecoration(tester).color, idle.color);
    });

    testWidgets('키 밖으로 끌어낸 뒤 떼면 입력이 취소된다', (tester) async {
      _recordHaptics(tester);
      final pressed = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(
          CalcKeyButton(
            keyDef: keyDefOf(CalcKeyId.num7),
            onPressed: pressed.add,
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CalcKeyButton)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(0, 300));
      await gesture.up();
      await tester.pump();

      expect(pressed, isEmpty);
      expect(
        _keycapDecoration(tester).color,
        keyDefOf(CalcKeyId.num7).category.background,
      );
    });

    testWidgets('enableHaptics가 false면 햅틱 없이 입력만 전달한다', (tester) async {
      final haptics = _recordHaptics(tester);
      final pressed = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(
          CalcKeyButton(
            keyDef: keyDefOf(CalcKeyId.add),
            onPressed: pressed.add,
            enableHaptics: false,
          ),
        ),
      );
      await tester.tap(find.byType(CalcKeyButton));
      await tester.pump();

      expect(pressed, [CalcKeyId.add]);
      expect(haptics, isEmpty);
    });

    testWidgets('onPressed가 null이면 반응·햅틱이 없다', (tester) async {
      final haptics = _recordHaptics(tester);
      await tester.pumpWidget(
        _host(CalcKeyButton(keyDef: keyDefOf(CalcKeyId.add))),
      );
      final idle = _keycapDecoration(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CalcKeyButton)),
      );
      await tester.pump();
      expect(_keycapDecoration(tester).color, idle.color);
      await gesture.up();
      await tester.pump();

      expect(haptics, isEmpty);
      // 비활성 키는 라벨을 흐리게 표시한다.
      final main = tester.widget<Text>(find.text('+'));
      expect(main.style!.color!.a, lessThan(1.0));
    });
  });

  group('접근성', () {
    testWidgets('버튼 시맨틱과 3단 라벨을 읽어 주고, 시맨틱 탭으로 입력된다', (tester) async {
      final handle = tester.ensureSemantics();
      _recordHaptics(tester);
      final pressed = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(
          CalcKeyButton(
            keyDef: keyDefOf(CalcKeyId.calc),
            onPressed: pressed.add,
          ),
        ),
      );

      final finder = find.byType(CalcKeyButton);
      expect(
        tester.getSemantics(finder),
        matchesSemantics(
          label: 'CALC, SHIFT SOLVE, ALPHA =',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(
        find.semantics.byLabel('CALC, SHIFT SOLVE, ALPHA ='),
      );
      await tester.pump();
      expect(pressed, [CalcKeyId.calc]);
      handle.dispose();
    });
  });
}
