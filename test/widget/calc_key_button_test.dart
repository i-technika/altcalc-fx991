import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:material_ui/material_ui.dart';

/// 지정한 크기의 셀 하나에 위젯을 배치한다.
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

Finder _keycap(CalcKeyId id) => find.byKey(CalcKeyButton.keycapKeyOf(id));

BoxDecoration _decoration(WidgetTester tester, CalcKeyId id) {
  final container = tester.widget<AnimatedContainer>(_keycap(id));
  return container.decoration! as BoxDecoration;
}

bool _isPressed(WidgetTester tester, CalcKeyId id) =>
    _decoration(tester, id).boxShadow!.isEmpty;

const _light = 'HapticFeedbackType.lightImpact';

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
      final capRect = tester.getRect(_keycap(CalcKeyId.sin));
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

    testWidgets('showLegendBand가 false면 키캡이 셀 전체 높이를 쓴다', (tester) async {
      await tester.pumpWidget(
        _host(
          CalcKeyButton(
            keyDef: keyDefOf(CalcKeyId.cursorUp),
            showLegendBand: false,
          ),
          size: const Size(50, 50),
        ),
      );

      expect(tester.getSize(_keycap(CalcKeyId.cursorUp)).height, 50);
    });
  });

  group('카테고리 테마', () {
    testWidgets('모든 키의 키캡 배경·라벨 색이 카테고리 색과 일치한다', (tester) async {
      for (final def in allKeys) {
        await tester.pumpWidget(
          _host(CalcKeyButton(keyDef: def, onPressed: (_) {})),
        );

        expect(
          _decoration(tester, def.id).color,
          def.category.background,
          reason: '$def',
        );
        final main = tester.widget<Text>(find.text(def.mainLabel));
        expect(main.style!.color, def.category.foreground, reason: '$def');
      }
    });
  });

  group('반응형 크기', () {
    const sizes = [
      Size(28, 34),
      Size(55, 38),
      Size(160, 180),
      Size(90, 40),
      Size(10, 300),
      Size(300, 10),
    ];

    for (final size in sizes) {
      testWidgets(
        '50키 전체가 ${size.width}x${size.height} 셀·글자 배율 2.0에서 넘치지 않는다',
        (tester) async {
          for (final def in allKeys) {
            await tester.pumpWidget(
              _host(CalcKeyButton(keyDef: def), size: size, textScale: 2.0),
            );
            expect(tester.takeException(), isNull, reason: '$def @ $size');
            expect(tester.getSize(find.byType(CalcKeyButton)), size);
          }
        },
      );
    }

    testWidgets('폰 크기 셀(55x38)에서 모든 각인·메인 라벨의 렌더 높이가 5dp 이상이다', (tester) async {
      // 테스트 폰트는 글리프 폭이 1em으로 실제 폰트보다 넓어, 실기기에서는 더 크게 렌더링된다.
      for (final def in allKeys) {
        await tester.pumpWidget(
          _host(CalcKeyButton(keyDef: def), size: const Size(55, 38)),
        );
        for (final label in [def.mainLabel, def.shiftLabel, def.alphaLabel]) {
          if (label == null) continue;
          expect(
            tester.getRect(find.text(label)).height,
            greaterThanOrEqualTo(5.0),
            reason: '$def "$label"',
          );
        }
      }
    });

    testWidgets('키 크기가 커지면 라벨의 렌더 크기도 비례해 커진다', (tester) async {
      Future<double> renderedHeight(Size size) async {
        await tester.pumpWidget(
          _host(CalcKeyButton(keyDef: keyDefOf(CalcKeyId.num7)), size: size),
        );
        return tester.getRect(find.text('7')).height;
      }

      final small = await renderedHeight(const Size(40, 48));
      final large = await renderedHeight(const Size(80, 96));
      // 텍스트 줄 높이는 픽셀 단위로 반올림되므로 1dp 오차를 허용한다.
      expect(large, closeTo(small * 2, 1.0));
    });

    testWidgets('글자 크기를 주입하면 비율 계산 대신 그 값을 쓴다', (tester) async {
      await tester.pumpWidget(
        _host(
          CalcKeyButton(
            keyDef: keyDefOf(CalcKeyId.sin),
            legendFontSize: 7,
            mainLabelFontSize: 13,
          ),
        ),
      );

      expect(tester.widget<Text>(find.text('sin⁻¹')).style!.fontSize, 7);
      expect(tester.widget<Text>(find.text('sin')).style!.fontSize, 13);
    });

    testWidgets('한 축이라도 제약이 무한하면 fallbackSize를 쓴다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [CalcKeyButton(keyDef: keyDefOf(CalcKeyId.num1))],
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(CalcKeyButton)),
        CalcKeyButton.fallbackSize,
      );
    });
  });

  group('입력 및 햅틱', () {
    testWidgets('누르는 순간 lightImpact 햅틱과 함께 키 ID로 입력된다', (tester) async {
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

      final gesture = await tester.startGesture(
        tester.getCenter(_keycap(CalcKeyId.num7)),
      );
      await tester.pump();
      expect(pressed, [CalcKeyId.num7], reason: '손을 떼기 전에 입력되어야 한다');
      expect(haptics, [_light]);
      expect(_isPressed(tester, CalcKeyId.num7), isTrue);

      await gesture.up();
      await tester.pump();
      expect(pressed, [CalcKeyId.num7]);
      expect(_isPressed(tester, CalcKeyId.num7), isFalse);
    });

    testWidgets('빠르게 5번 치면 5번 입력되고 햅틱도 5번 울린다', (tester) async {
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

      for (var i = 0; i < 5; i++) {
        await tester.tap(_keycap(CalcKeyId.num7));
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(pressed.length, 5);
      expect(haptics.length, 5);
    });

    testWidgets('겹쳐 치면 누른 순서대로 입력된다 (1 누름 → 2 누름 → 2 뗌 → 1 뗌 = "12")', (
      tester,
    ) async {
      _recordHaptics(tester);
      final pressed = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(
          Row(
            children: [
              for (final id in [CalcKeyId.num1, CalcKeyId.num2])
                Expanded(
                  child: CalcKeyButton(
                    keyDef: keyDefOf(id),
                    onPressed: pressed.add,
                  ),
                ),
            ],
          ),
          size: const Size(140, 72),
        ),
      );

      final g1 = await tester.startGesture(
        tester.getCenter(_keycap(CalcKeyId.num1)),
        pointer: 1,
      );
      final g2 = await tester.startGesture(
        tester.getCenter(_keycap(CalcKeyId.num2)),
        pointer: 2,
      );
      await g2.up();
      await g1.up();
      await tester.pump();

      expect(pressed, [CalcKeyId.num1, CalcKeyId.num2]);
    });

    testWidgets('한 키에 두 손가락이 닿아도 한 번만 입력되고, 첫 손가락을 뗄 때 해제된다', (tester) async {
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
      final center = tester.getCenter(_keycap(CalcKeyId.num7));

      final g1 = await tester.startGesture(center, pointer: 1);
      final g2 = await tester.startGesture(center, pointer: 2);
      await tester.pump();
      expect(pressed, [CalcKeyId.num7]);

      await g2.up();
      await tester.pump();
      expect(_isPressed(tester, CalcKeyId.num7), isTrue);

      await g1.up();
      await tester.pump();
      expect(_isPressed(tester, CalcKeyId.num7), isFalse);
      expect(pressed, [CalcKeyId.num7]);
    });

    testWidgets('누른 채 손가락을 미끄러뜨려도 입력은 취소되지 않는다', (tester) async {
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
        tester.getCenter(_keycap(CalcKeyId.num7)),
      );
      await gesture.moveBy(const Offset(0, 300));
      await gesture.up();
      await tester.pump();

      expect(pressed, [CalcKeyId.num7]);
      expect(_isPressed(tester, CalcKeyId.num7), isFalse);
    });

    testWidgets('각인 띠 영역은 터치를 받지 않는다', (tester) async {
      final haptics = _recordHaptics(tester);
      final pressed = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(
          CalcKeyButton(
            keyDef: keyDefOf(CalcKeyId.calc),
            onPressed: pressed.add,
          ),
        ),
      );

      final topLeft = tester.getTopLeft(find.byType(CalcKeyButton));
      await tester.tapAt(topLeft + const Offset(2, 2));
      await tester.pump();

      expect(pressed, isEmpty);
      expect(haptics, isEmpty);
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
      await tester.tap(_keycap(CalcKeyId.add));
      await tester.pump();

      expect(pressed, [CalcKeyId.add]);
      expect(haptics, isEmpty);
    });
  });

  group('자동 반복', () {
    Widget repeating(List<CalcKeyId> log, {bool autoRepeat = true}) => _host(
      CalcKeyButton(
        keyDef: keyDefOf(CalcKeyId.cursorRight),
        onPressed: log.add,
        autoRepeat: autoRepeat,
      ),
    );

    testWidgets('누르고 있으면 지연 후 간격마다 반복 입력되고, 떼면 멈춘다', (tester) async {
      final haptics = _recordHaptics(tester);
      final pressed = <CalcKeyId>[];
      await tester.pumpWidget(repeating(pressed));

      final gesture = await tester.startGesture(
        tester.getCenter(_keycap(CalcKeyId.cursorRight)),
      );
      await tester.pump(
        CalcKeyButton.defaultRepeatDelay - const Duration(milliseconds: 1),
      );
      expect(pressed.length, 1);

      await tester.pump(const Duration(milliseconds: 1));
      expect(pressed.length, 2);

      await tester.pump(CalcKeyButton.defaultRepeatInterval * 3);
      expect(pressed.length, 5);
      expect(haptics.length, 1, reason: '반복 입력에는 햅틱을 내지 않는다');

      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
      expect(pressed.length, 5);
    });

    testWidgets('autoRepeat가 꺼져 있으면 오래 눌러도 한 번만 입력된다', (tester) async {
      _recordHaptics(tester);
      final pressed = <CalcKeyId>[];
      await tester.pumpWidget(repeating(pressed, autoRepeat: false));

      final gesture = await tester.startGesture(
        tester.getCenter(_keycap(CalcKeyId.cursorRight)),
      );
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();

      expect(pressed.length, 1);
    });

    testWidgets('누른 채 위젯이 제거되면 반복 타이머가 정리된다', (tester) async {
      _recordHaptics(tester);
      final pressed = <CalcKeyId>[];
      await tester.pumpWidget(repeating(pressed));

      final gesture = await tester.startGesture(
        tester.getCenter(_keycap(CalcKeyId.cursorRight)),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();

      expect(pressed.length, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('활성/비활성 전환', () {
    testWidgets('onPressed가 null이면 반응·햅틱이 없고 라벨이 흐리다', (tester) async {
      final haptics = _recordHaptics(tester);
      await tester.pumpWidget(
        _host(CalcKeyButton(keyDef: keyDefOf(CalcKeyId.add))),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(_keycap(CalcKeyId.add)),
      );
      await tester.pump();
      expect(_isPressed(tester, CalcKeyId.add), isFalse);
      await gesture.up();

      expect(haptics, isEmpty);
      final main = tester.widget<Text>(find.text('+'));
      expect(main.style!.color!.a, CalcTheme.keyDisabledLabelOpacity);
    });

    testWidgets('누른 채 비활성으로 바뀌면 눌림·반복이 즉시 해제된다', (tester) async {
      _recordHaptics(tester);
      final pressed = <CalcKeyId>[];
      Widget build(bool enabled) => _host(
        CalcKeyButton(
          keyDef: keyDefOf(CalcKeyId.del),
          onPressed: enabled ? pressed.add : null,
          autoRepeat: true,
        ),
      );

      await tester.pumpWidget(build(true));
      final gesture = await tester.startGesture(
        tester.getCenter(_keycap(CalcKeyId.del)),
      );
      await tester.pump();
      expect(_isPressed(tester, CalcKeyId.del), isTrue);

      await tester.pumpWidget(build(false));
      expect(_isPressed(tester, CalcKeyId.del), isFalse);
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();
      await tester.pump();

      expect(pressed, [CalcKeyId.del]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('비활성에서 활성으로 바뀌면 다시 입력된다', (tester) async {
      _recordHaptics(tester);
      final pressed = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(CalcKeyButton(keyDef: keyDefOf(CalcKeyId.num5))),
      );
      await tester.tap(_keycap(CalcKeyId.num5));

      await tester.pumpWidget(
        _host(
          CalcKeyButton(
            keyDef: keyDefOf(CalcKeyId.num5),
            onPressed: pressed.add,
          ),
        ),
      );
      await tester.tap(_keycap(CalcKeyId.num5));
      await tester.pump();

      expect(pressed, [CalcKeyId.num5]);
    });
  });

  group('접근성', () {
    testWidgets('버튼 시맨틱과 3단 라벨을 읽어 주고, 시맨틱 탭으로 햅틱과 함께 입력된다', (tester) async {
      final handle = tester.ensureSemantics();
      final haptics = _recordHaptics(tester);
      final pressed = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(
          CalcKeyButton(
            keyDef: keyDefOf(CalcKeyId.calc),
            onPressed: pressed.add,
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(CalcKeyButton)),
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
      expect(haptics, [_light]);
      // testWidgets는 tearDown 전에 handle 해제를 검증하므로 본문 끝에서 해제한다.
      handle.dispose();
    });

    testWidgets('비활성 키는 비활성 시맨틱이며 탭 동작이 없다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(CalcKeyButton(keyDef: keyDefOf(CalcKeyId.num4))),
      );

      expect(
        tester.getSemantics(find.byType(CalcKeyButton)),
        matchesSemantics(
          label: '4',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      handle.dispose();
    });
  });
}
