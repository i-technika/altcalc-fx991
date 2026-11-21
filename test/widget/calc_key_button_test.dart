import 'package:flutter/gestures.dart';
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
  _shapeAndLegendTests();
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

      // 눌림 이동 여유만큼 아래를 비운다.
      expect(
        tester.getSize(_keycap(CalcKeyId.cursorUp)).height,
        50 - CalcTheme.keyPressedOffset,
      );
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

    testWidgets('제약이 무한한 축에만 fallbackSize를 쓴다', (tester) async {
      // 너비 무한(Row) + 높이 80 고정
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              height: 80,
              child: Row(
                children: [CalcKeyButton(keyDef: keyDefOf(CalcKeyId.num1))],
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(CalcKeyButton)),
        Size(CalcKeyButton.fallbackSize.width, 80),
      );

      // 너비 90 고정 + 높이 무한(Column)
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 90,
              child: Column(
                children: [CalcKeyButton(keyDef: keyDefOf(CalcKeyId.num1))],
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(CalcKeyButton)),
        Size(90, CalcKeyButton.fallbackSize.height),
      );
      expect(tester.getSize(_keycap(CalcKeyId.num1)).width, 90);
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

  group('입력 경계 조건', () {
    testWidgets('포인터가 취소되면 눌림이 풀리고 이후 다시 입력할 수 있다', (tester) async {
      _recordHaptics(tester);
      final pressed = <CalcKeyId>[];
      final repeats = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(
          CalcKeyButton(
            keyDef: keyDefOf(CalcKeyId.del),
            onPressed: pressed.add,
            onRepeat: repeats.add,
          ),
        ),
      );
      final center = tester.getCenter(_keycap(CalcKeyId.del));

      final gesture = await tester.startGesture(center);
      await tester.pump();
      await gesture.cancel();
      await tester.pump();
      expect(_isPressed(tester, CalcKeyId.del), isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(repeats, isEmpty, reason: '취소 후에는 반복하지 않는다');

      await tester.tap(_keycap(CalcKeyId.del));
      await tester.pump();
      expect(pressed, [CalcKeyId.del, CalcKeyId.del]);
    });

    testWidgets('마우스 보조 버튼과 스타일러스 지우개 끝은 입력하지 않는다', (tester) async {
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
      final center = tester.getCenter(_keycap(CalcKeyId.num7));

      for (final (kind, buttons) in [
        (PointerDeviceKind.mouse, kSecondaryMouseButton),
        (PointerDeviceKind.mouse, kMiddleMouseButton),
        (PointerDeviceKind.invertedStylus, kPrimaryButton),
      ]) {
        final g = await tester.startGesture(
          center,
          kind: kind,
          buttons: buttons,
        );
        await g.up();
        await tester.pump();
      }
      expect(pressed, isEmpty);
      expect(haptics, isEmpty);

      final g = await tester.startGesture(
        center,
        kind: PointerDeviceKind.mouse,
      );
      await g.up();
      await tester.pump();
      expect(pressed, [CalcKeyId.num7], reason: '마우스 주 버튼은 입력된다');
    });

    group('시스템 제스처 영역', () {
      Widget edgeHost(List<CalcKeyId> log) => MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 600),
            systemGestureInsets: EdgeInsets.symmetric(horizontal: 30),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 64,
              height: 72,
              child: CalcKeyButton(
                keyDef: keyDefOf(CalcKeyId.num1),
                onPressed: log.add,
              ),
            ),
          ),
        ),
      );

      testWidgets('가장자리에서 시작한 터치는 손을 뗄 때 확정된다', (tester) async {
        final haptics = _recordHaptics(tester);
        final pressed = <CalcKeyId>[];
        await tester.pumpWidget(edgeHost(pressed));

        final gesture = await tester.startGesture(const Offset(10, 300));
        await tester.pump();
        expect(pressed, isEmpty, reason: '시스템 뒤로가기일 수 있으므로 보류');
        expect(haptics, isEmpty);
        expect(_isPressed(tester, CalcKeyId.num1), isTrue);

        await gesture.up();
        await tester.pump();
        expect(pressed, [CalcKeyId.num1]);
        expect(haptics, [_light]);
      });

      testWidgets('가장자리에서 시작한 터치가 취소되거나 키 밖으로 나가면 버린다', (tester) async {
        final haptics = _recordHaptics(tester);
        final pressed = <CalcKeyId>[];
        await tester.pumpWidget(edgeHost(pressed));

        final g1 = await tester.startGesture(const Offset(10, 300));
        await g1.cancel();
        await tester.pump();

        final g2 = await tester.startGesture(const Offset(10, 300));
        await g2.moveTo(const Offset(200, 300)); // 뒤로가기 스와이프처럼 안쪽으로 이동
        await g2.up();
        await tester.pump();

        expect(pressed, isEmpty);
        expect(haptics, isEmpty);
        expect(_isPressed(tester, CalcKeyId.num1), isFalse);
      });

      testWidgets('가장자리 밖(안쪽)의 터치는 즉시 입력된다', (tester) async {
        _recordHaptics(tester);
        final pressed = <CalcKeyId>[];
        await tester.pumpWidget(edgeHost(pressed));

        final gesture = await tester.startGesture(const Offset(50, 300));
        await tester.pump();
        expect(pressed, [CalcKeyId.num1]);
        await gesture.up();
      });
    });

    testWidgets('extendHitAreaToLegend이면 각인 띠를 눌러도 입력된다', (tester) async {
      _recordHaptics(tester);
      final pressed = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(
          CalcKeyButton(
            keyDef: keyDefOf(CalcKeyId.calc),
            onPressed: pressed.add,
            extendHitAreaToLegend: true,
          ),
        ),
      );

      final topLeft = tester.getTopLeft(find.byType(CalcKeyButton));
      await tester.tapAt(topLeft + const Offset(2, 2));
      await tester.pump();
      expect(pressed, [CalcKeyId.calc]);
    });

    testWidgets('눌린 키캡도 셀 안에 그려진다', (tester) async {
      _recordHaptics(tester);
      await tester.pumpWidget(
        _host(
          CalcKeyButton(keyDef: keyDefOf(CalcKeyId.num7), onPressed: (_) {}),
        ),
      );
      final cell = tester.getRect(find.byType(CalcKeyButton));

      final gesture = await tester.startGesture(cell.center);
      await tester.pump();
      final cap = tester.getRect(_keycap(CalcKeyId.num7));
      expect(cap.bottom, lessThanOrEqualTo(cell.bottom + 0.001));
      await gesture.up();
    });

    testWidgets('누른 채 다른 키로 바뀌면 눌림·반복이 해제되어 새 ID로 반복되지 않는다', (tester) async {
      _recordHaptics(tester);
      final repeats = <CalcKeyId>[];
      Widget build(CalcKeyId id) => _host(
        CalcKeyButton(
          keyDef: keyDefOf(id),
          onPressed: (_) {},
          onRepeat: repeats.add,
        ),
      );

      await tester.pumpWidget(build(CalcKeyId.cursorRight));
      final gesture = await tester.startGesture(
        tester.getCenter(_keycap(CalcKeyId.cursorRight)),
      );
      await tester.pump();
      await tester.pumpWidget(build(CalcKeyId.cursorLeft));
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();

      expect(repeats, isEmpty);
      expect(_isPressed(tester, CalcKeyId.cursorLeft), isFalse);
    });
  });

  group('글자 배율', () {
    testWidgets('시스템 글자 배율은 1.3배까지만 반영된다 (공간이 남는 한 글자 라벨 기준)', (tester) async {
      Future<double> heightAt(double scale) async {
        await tester.pumpWidget(
          _host(
            CalcKeyButton(keyDef: keyDefOf(CalcKeyId.num7)),
            size: const Size(120, 96),
            textScale: scale,
          ),
        );
        return tester.getRect(find.text('7')).height;
      }

      final base = await heightAt(1.0);
      final at13 = await heightAt(CalcTheme.keyMaxTextScaleFactor);
      final at20 = await heightAt(2.0);
      expect(at13, greaterThan(base));
      expect(at20, closeTo(at13, 0.01));
    });
  });

  group('자동 반복', () {
    Widget repeating(
      List<CalcKeyId> presses,
      List<CalcKeyId>? repeats, {
      Duration delay = CalcKeyButton.defaultRepeatDelay,
      Duration interval = CalcKeyButton.defaultRepeatInterval,
    }) => _host(
      CalcKeyButton(
        keyDef: keyDefOf(CalcKeyId.cursorRight),
        onPressed: presses.add,
        onRepeat: repeats?.add,
        repeatDelay: delay,
        repeatInterval: interval,
      ),
    );

    Future<TestGesture> press(WidgetTester tester) =>
        tester.startGesture(tester.getCenter(_keycap(CalcKeyId.cursorRight)));

    testWidgets('누르고 있으면 지연 후 간격마다 onRepeat이 호출되고, 떼면 멈춘다', (tester) async {
      final haptics = _recordHaptics(tester);
      final presses = <CalcKeyId>[];
      final repeats = <CalcKeyId>[];
      await tester.pumpWidget(repeating(presses, repeats));

      final gesture = await press(tester);
      await tester.pump(
        CalcKeyButton.defaultRepeatDelay - const Duration(milliseconds: 1),
      );
      expect((presses.length, repeats.length), (1, 0));

      await tester.pump(const Duration(milliseconds: 1));
      expect(repeats.length, 1);

      await tester.pump(CalcKeyButton.defaultRepeatInterval * 3);
      expect(repeats.length, 4);
      expect(presses.length, 1, reason: '반복은 onPressed가 아닌 onRepeat으로만 전달된다');
      expect(haptics.length, 1, reason: '반복 입력에는 햅틱을 내지 않는다');

      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
      expect(repeats.length, 4);
    });

    testWidgets('지정한 지연·간격을 따른다 (200ms / 50ms)', (tester) async {
      _recordHaptics(tester);
      final repeats = <CalcKeyId>[];
      await tester.pumpWidget(
        repeating(
          [],
          repeats,
          delay: const Duration(milliseconds: 200),
          interval: const Duration(milliseconds: 50),
        ),
      );

      final gesture = await press(tester);
      await tester.pump(const Duration(milliseconds: 199));
      expect(repeats, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(repeats.length, 1);
      await tester.pump(const Duration(milliseconds: 150));
      expect(repeats.length, 4);
      await gesture.up();
    });

    testWidgets('onRepeat이 없으면 오래 눌러도 반복하지 않는다', (tester) async {
      _recordHaptics(tester);
      final presses = <CalcKeyId>[];
      await tester.pumpWidget(repeating(presses, null));

      final gesture = await press(tester);
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();

      expect(presses.length, 1);
    });

    testWidgets('누른 채 onRepeat이 제거되면 반복이 멈춘다', (tester) async {
      _recordHaptics(tester);
      final repeats = <CalcKeyId>[];
      await tester.pumpWidget(repeating([], repeats));

      final gesture = await press(tester);
      await tester.pump(CalcKeyButton.defaultRepeatDelay);
      expect(repeats.length, 1);

      await tester.pumpWidget(repeating([], null));
      await tester.pump(const Duration(seconds: 1));
      expect(repeats.length, 1);
      await gesture.up();
    });

    testWidgets('손가락이 키 밖으로 벗어나면 반복을 멈춘다 (첫 입력은 유지)', (tester) async {
      _recordHaptics(tester);
      final presses = <CalcKeyId>[];
      final repeats = <CalcKeyId>[];
      await tester.pumpWidget(repeating(presses, repeats));

      final gesture = await press(tester);
      await tester.pump(CalcKeyButton.defaultRepeatDelay);
      expect(repeats.length, 1);

      await gesture.moveBy(const Offset(0, 300));
      await tester.pump(const Duration(seconds: 1));
      expect(repeats.length, 1);
      expect(presses.length, 1);
      await gesture.up();
    });

    testWidgets('누른 채 onRepeat을 뺐다가 다시 넣어도 그 누름에서는 반복이 재개되지 않는다', (
      tester,
    ) async {
      _recordHaptics(tester);
      final repeats = <CalcKeyId>[];
      await tester.pumpWidget(repeating([], repeats));

      final gesture = await press(tester);
      await tester.pump(CalcKeyButton.defaultRepeatDelay); // 주기 반복 시작
      expect(repeats.length, 1);

      await tester.pumpWidget(repeating([], null));
      await tester.pumpWidget(repeating([], repeats));
      await tester.pump(const Duration(seconds: 1));
      expect(repeats.length, 1, reason: '지연·간격·콜백 변경은 다음 누름부터 적용된다');
      await gesture.up();
    });

    // 아래 두 테스트는 시간을 흘려보내지 않고 끝난다. 타이머가 정리되지 않으면
    // testWidgets의 종료 검증("A Timer is still pending")이 실패한다.
    testWidgets('누른 채 위젯이 제거되면 반복 타이머가 즉시 정리된다', (tester) async {
      _recordHaptics(tester);
      await tester.pumpWidget(repeating([], []));

      final gesture = await press(tester);
      await tester.pumpWidget(const SizedBox());
      await gesture.up();
      expect(tester.takeException(), isNull);
    });

    testWidgets('반복 중 위젯이 제거되면 주기 타이머도 정리된다', (tester) async {
      _recordHaptics(tester);
      await tester.pumpWidget(repeating([], []));

      final gesture = await press(tester);
      await tester.pump(CalcKeyButton.defaultRepeatDelay); // 주기 타이머로 전환
      await tester.pumpWidget(const SizedBox());
      await gesture.up();
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

    testWidgets('누른 채 비활성으로 바뀌면 눌림·반복 타이머가 즉시 해제된다', (tester) async {
      _recordHaptics(tester);
      final presses = <CalcKeyId>[];
      Widget build(bool enabled) => _host(
        CalcKeyButton(
          keyDef: keyDefOf(CalcKeyId.del),
          onPressed: enabled ? presses.add : null,
          onRepeat: (_) {},
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
      await gesture.up();
      await tester.pump();

      // 시간을 흘리지 않고 종료 — 타이머가 남아 있으면 종료 검증에서 실패한다.
      expect(presses, [CalcKeyId.del]);
    });

    testWidgets('비활성 전환으로 버려진 반복 타이머가 다음 누름의 반복을 앞당기지 않는다', (tester) async {
      _recordHaptics(tester);
      final repeats = <CalcKeyId>[];
      Widget build(bool enabled) => _host(
        CalcKeyButton(
          keyDef: keyDefOf(CalcKeyId.del),
          onPressed: enabled ? (_) {} : null,
          onRepeat: repeats.add,
        ),
      );
      Offset center() => tester.getCenter(_keycap(CalcKeyId.del));

      await tester.pumpWidget(build(true));
      final g1 = await tester.startGesture(center(), pointer: 1);
      await tester.pumpWidget(build(false)); // t=0에 시작한 타이머는 정리되어야 한다
      await g1.up();
      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 300));

      final g2 = await tester.startGesture(center(), pointer: 2); // t=300
      await tester.pump(
        const Duration(milliseconds: 250),
      ); // t=550 (첫 타이머 예정 시각 지남)
      expect(repeats, isEmpty, reason: '두 번째 누름의 반복은 t=800부터');
      await tester.pump(const Duration(milliseconds: 250)); // t=800
      expect(repeats.length, 1);
      await g2.up();
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

void _shapeAndLegendTests() {
  /// 왼쪽 위 → 오른쪽 위 → 아래 가운데 삼각형 (커서 패드 ▲ 부채꼴과 같은 모양)
  Path triangle(Size s) => Path()
    ..addPolygon([
      Offset.zero,
      Offset(s.width, 0),
      Offset(s.width / 2, s.height),
    ], true);

  group('키 모양 (shape)', () {
    testWidgets('모양 밖을 누르면 입력되지 않고, 안을 누르면 입력된다', (tester) async {
      final pressed = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(
          CalcKeyButton(
            keyDef: keyDefOf(CalcKeyId.cursorUp),
            showLegendBand: false,
            enableHaptics: false,
            shape: triangle,
            onPressed: pressed.add,
          ),
          size: const Size(100, 60),
        ),
      );
      final box = tester.getRect(find.byType(CalcKeyButton));
      await tester.tapAt(box.topLeft + const Offset(5, 50)); // 왼쪽 아래 모서리: 삼각형 밖
      expect(pressed, isEmpty);
      await tester.tapAt(box.topLeft + const Offset(50, 10));
      expect(pressed, [CalcKeyId.cursorUp]);
    });

    testWidgets('누른 채 모양 밖으로 나가면 (상자 안이어도) 반복이 멈춘다', (tester) async {
      final repeats = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(
          CalcKeyButton(
            keyDef: keyDefOf(CalcKeyId.cursorUp),
            showLegendBand: false,
            enableHaptics: false,
            shape: triangle,
            onPressed: (_) {},
            onRepeat: repeats.add,
          ),
          size: const Size(100, 60),
        ),
      );
      final box = tester.getRect(find.byType(CalcKeyButton));
      final g = await tester.startGesture(box.topLeft + const Offset(50, 10));
      await tester.pump(CalcKeyButton.defaultRepeatDelay);
      expect(repeats, hasLength(1));
      await g.moveTo(box.topLeft + const Offset(8, 50)); // 상자 안, 삼각형 밖
      await tester.pump(CalcKeyButton.defaultRepeatInterval * 5);
      expect(repeats, hasLength(1));
      await g.up();
    });
  });

  group('각인 배분', () {
    testWidgets('긴 각인 옆의 한 글자 각인은 줄어들지 않는다', (tester) async {
      await tester.pumpWidget(
        _host(
          CalcKeyButton(keyDef: keyDefOf(CalcKeyId.sdToggle)),
          size: const Size(55, 38),
        ),
      );
      final y = find.text('Y');
      expect(
        tester.getRect(y).height,
        moreOrLessEquals(tester.getSize(y).height, epsilon: 0.01),
      );
      // 긴 각인은 남은 폭 안에 들어가도록 줄어든다 (띠 밖으로 넘치지 않는다).
      final band = tester.getRect(find.byType(CalcKeyButton));
      final long = tester.getRect(find.text('a b/c⇔d/c'));
      expect(long.left, greaterThanOrEqualTo(band.left - 0.01));
      expect(long.right, lessThan(tester.getRect(y).left));
      expect(tester.takeException(), isNull);
    });

    testWidgets('둘 다 긴 각인 쌍은 글자 수 비례로 나눠 함께 줄어든다', (tester) async {
      await tester.pumpWidget(
        _host(
          CalcKeyButton(keyDef: keyDefOf(CalcKeyId.dot)), // Ran# / RanInt
          size: const Size(55, 38),
        ),
      );
      double scaleOf(String text) {
        final f = find.text(text);
        return tester.getRect(f).height / tester.getSize(f).height;
      }

      expect(
        scaleOf('Ran#'),
        moreOrLessEquals(scaleOf('RanInt'), epsilon: 0.02),
      );
    });
  });
}
