import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/layout/layout_log.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/key_legend_view.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/round_key_face.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/screen_coordinate_root.dart';
import 'package:material_ui/material_ui.dart';

import '../support/key_legends.dart';
import '../support/korean_locale.dart';

/// 지정한 크기의 셀 하나에 위젯을 배치한다.
Widget _host(
  Widget child, {
  Size size = const Size(64, 72),
  double textScale = 1.0,
  bool highContrast = false,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        highContrast: highContrast,
      ),
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

/// 실제로 그려지고 있는 키캡 장식 (AnimatedContainer의 목표값이 아니라 애니메이션 현재값)
BoxDecoration _renderedDecoration(WidgetTester tester, CalcKeyId id) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: _keycap(id), matching: find.byType(DecoratedBox)).first,
  );
  return box.decoration as BoxDecoration;
}

final _normalBorder = Border.all(
  color: CalcTheme.keyBorder,
  width: CalcTheme.keyBorderWidth,
);
final _pressedBorder = Border.all(
  color: CalcTheme.keyPressedBorder,
  width: CalcTheme.keyBorderWidth,
);

bool _isPressed(WidgetTester tester, CalcKeyId id) =>
    _decoration(tester, id).boxShadow!.isEmpty;

const _light = 'HapticFeedbackType.lightImpact';

void main() {
  _shapeAndLegendTests();
  _appearanceTests();
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

      final sinShift = findLegend(keyDefOf(CalcKeyId.sin).shiftLegend!);
      expect(legendStyleOf(tester, sinShift).color, CalcTheme.shiftLabel);
      expect(
        tester.widget<Text>(find.text('D')).style!.color,
        CalcTheme.alphaLabel,
      );

      final shiftRect = legendSlotRect(tester, sinShift);
      final alphaRect = legendSlotRect(tester, find.text('D'));
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
        // 원형 버튼(#190)은 키캡 대신 `RoundKeyFace`로 그린다 — 아래 "원형 버튼 키" 그룹이 따로 검사한다.
        if (def.face == KeyFace.roundButton) continue;
        await tester.pumpWidget(
          _host(CalcKeyButton(keyDef: def, onPressed: (_) {})),
        );

        expect(
          _decoration(tester, def.id).color,
          def.category.background,
          reason: '$def',
        );
        expect(
          legendStyleOf(tester, findLegend(def.mainLegend)).color,
          def.category.foreground,
          reason: '$def',
        );
      }
    });
  });

  group('눌림 색 (#22)', () {
    testWidgets('모든 키: 누르는 즉시 눌림 색·테두리로 그려지고, 떼면 애니메이션 뒤 원래대로 돌아온다', (
      tester,
    ) async {
      for (final def in allKeys) {
        // 원형 버튼(#190)은 키캡 대신 `RoundKeyFace`로 그린다 — 아래 "원형 버튼 키" 그룹이 따로 검사한다.
        if (def.face == KeyFace.roundButton) continue;
        await tester.pumpWidget(
          _host(CalcKeyButton(keyDef: def, onPressed: (_) {})),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(_keycap(def.id)),
        );
        // 다음 한 프레임에 이미 목표 색이다 (누를 때는 애니메이션하지 않는다).
        await tester.pump();
        var drawn = _renderedDecoration(tester, def.id);
        expect(drawn.color, def.category.pressedBackground, reason: '$def');
        expect(drawn.border, _pressedBorder, reason: '$def');

        // 뗄 때는 애니메이션한다: 중간 시점에는 눌림 색도 평소 색도 아니다.
        await gesture.up();
        await tester.pump();
        await tester.pump(CalcTheme.keyPressAnimationDuration ~/ 2);
        drawn = _renderedDecoration(tester, def.id);
        expect(
          drawn.color,
          isNot(def.category.pressedBackground),
          reason: '$def',
        );
        expect(drawn.color, isNot(def.category.background), reason: '$def');

        await tester.pump(CalcTheme.keyPressAnimationDuration);
        drawn = _renderedDecoration(tester, def.id);
        expect(drawn.color, def.category.background, reason: '$def');
        expect(drawn.border, _normalBorder, reason: '$def');
      }
    });

    testWidgets('비활성 키는 눌러도 눌림 색이 되지 않는다', (tester) async {
      final def = keyDefOf(CalcKeyId.sin);
      await tester.pumpWidget(_host(CalcKeyButton(keyDef: def)));
      final gesture = await tester.startGesture(
        tester.getCenter(_keycap(def.id)),
      );
      await tester.pump();
      final drawn = _renderedDecoration(tester, def.id);
      expect(drawn.color, def.category.background);
      expect(drawn.border, _normalBorder);
      await gesture.up();
    });
  });

  group('고대비 모드 (#54)', () {
    const palette = CalcPalette.highContrast;

    testWidgets('모든 키: 평소 키캡·라벨·테두리·각인이 고대비 팔레트 색이다', (tester) async {
      for (final def in allKeys) {
        // 원형 버튼(#190)은 키캡 대신 `RoundKeyFace`로 그린다 — 아래 "원형 버튼 키" 그룹이 따로 검사한다.
        if (def.face == KeyFace.roundButton) continue;
        await tester.pumpWidget(
          _host(
            CalcKeyButton(keyDef: def, onPressed: (_) {}),
            highContrast: true,
          ),
        );
        final decoration = _decoration(tester, def.id);
        expect(
          decoration.color,
          palette.keyBackground(def.category),
          reason: '$def',
        );
        expect(
          decoration.border,
          Border.all(color: palette.keyBorder, width: CalcTheme.keyBorderWidth),
          reason: '$def',
        );
        expect(
          legendStyleOf(tester, findLegend(def.mainLegend)).color,
          palette.keyForeground(def.category),
          reason: '$def',
        );
        if (def.shiftLegend case final shift?) {
          expect(
            legendStyleOf(tester, findLegend(shift)).color,
            palette.shiftLabel,
            reason: '$def',
          );
        }
        if (def.alphaLegend case final alpha?) {
          expect(
            legendStyleOf(tester, findLegend(alpha)).color,
            palette.alphaLabel,
            reason: '$def',
          );
        }
      }
    });

    testWidgets(
      '모든 키: 누르면 즉시 눌림 색(흰 라벨 키는 반전)이 되고, 떼면 배경·라벨이 함께 애니메이션 뒤 돌아온다',
      (tester) async {
        for (final def in allKeys) {
          // 원형 버튼(#190)은 키캡 대신 `RoundKeyFace`로 그린다 — 아래 "원형 버튼 키" 그룹이 따로 검사한다.
          if (def.face == KeyFace.roundButton) continue;
          final category = def.category;
          await tester.pumpWidget(
            _host(
              CalcKeyButton(keyDef: def, onPressed: (_) {}),
              highContrast: true,
            ),
          );
          final gesture = await tester.startGesture(
            tester.getCenter(_keycap(def.id)),
          );
          await tester.pump();
          var drawn = _renderedDecoration(tester, def.id);
          expect(
            drawn.color,
            palette.keyPressedBackground(category),
            reason: '$def',
          );
          expect(
            drawn.border,
            Border.all(
              color: palette.keyPressedBorder,
              width: CalcTheme.keyBorderWidth,
            ),
            reason: '$def',
          );
          expect(
            legendStyleOf(tester, findLegend(def.mainLegend)).color,
            palette.keyPressedForeground(category),
            reason: '$def',
          );

          Color? label() =>
              legendStyleOf(tester, findLegend(def.mainLegend)).color;

          await gesture.up();
          await tester.pump();
          await tester.pump(CalcTheme.keyPressAnimationDuration ~/ 2);
          // 중간 시점: 배경은 눌림 색도 평소 색도 아니다. 반전 키는 라벨도 함께 옮겨 가는 중이라,
          // 흰 배경(눌림)에 흰 라벨(평소)인 프레임이 없다.
          drawn = _renderedDecoration(tester, def.id);
          expect(
            drawn.color,
            isNot(palette.keyPressedBackground(category)),
            reason: '$def',
          );
          expect(drawn.color, isNot(palette.keyBackground(category)));
          if (palette.invertsOnPress(category)) {
            expect(label(), isNot(palette.keyForeground(category)));
            expect(label(), isNot(palette.keyPressedForeground(category)));
          } else {
            expect(label(), palette.keyForeground(category), reason: '$def');
          }

          await tester.pump(CalcTheme.keyPressAnimationDuration);
          drawn = _renderedDecoration(tester, def.id);
          expect(drawn.color, palette.keyBackground(category), reason: '$def');
          expect(label(), palette.keyForeground(category), reason: '$def');
        }
      },
    );

    testWidgets('비활성 키 라벨은 고대비 모드에서도 활성 라벨보다 키캡 대비가 낮다 (흐리게 보인다)', (
      tester,
    ) async {
      double contrast(Color a, Color b) {
        final la = a.computeLuminance();
        final lb = b.computeLuminance();
        return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
      }

      for (final def in allKeys) {
        // 원형 버튼(#190)은 키캡 대신 `RoundKeyFace`로 그린다 — 아래 "원형 버튼 키" 그룹이 따로 검사한다.
        if (def.face == KeyFace.roundButton) continue;
        final background = palette.keyBackground(def.category);
        Future<double> labelContrast({required bool enabled}) async {
          await tester.pumpWidget(
            _host(
              CalcKeyButton(keyDef: def, onPressed: enabled ? (_) {} : null),
              highContrast: true,
            ),
          );
          // 같은 키가 활성 ↔ 비활성으로 바뀌면 라벨 색도 뗄 때와 같은 시간 동안 옮겨 간다.
          await tester.pump(CalcTheme.keyPressAnimationDuration);
          final color = legendStyleOf(
            tester,
            findLegend(def.mainLegend),
          ).color!;
          return contrast(Color.alphaBlend(color, background), background);
        }

        final enabled = await labelContrast(enabled: true);
        final disabled = await labelContrast(enabled: false);
        expect(disabled, lessThan(enabled), reason: '$def');
        expect(disabled, greaterThan(1.0), reason: '$def');
      }
    });
  });

  group('원형 버튼 키 (#190)', () {
    final on = keyDefOf(settingsKey);
    RoundKeyFace face(WidgetTester tester) =>
        tester.widget<RoundKeyFace>(find.byType(RoundKeyFace));
    RoundKeyFacePainter painter(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(RoundKeyFace),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as RoundKeyFacePainter;

    testWidgets('버튼 면에는 글자가 없고, 메인 각인(SETTING)은 각인 띠 가운데에 본체 인쇄 색으로 그린다', (
      tester,
    ) async {
      for (final highContrast in [false, true]) {
        await tester.pumpWidget(
          _host(
            CalcKeyButton(keyDef: on, onPressed: (_) {}),
            highContrast: highContrast,
          ),
        );
        final reason = 'highContrast=$highContrast';
        expect(
          find.descendant(of: _keycap(on.id), matching: find.byType(Text)),
          findsNothing,
          reason: reason,
        );
        expect(
          find.descendant(
            of: _keycap(on.id),
            matching: find.byType(RoundKeyFace),
          ),
          findsOneWidget,
        );
        final label = findLegend(on.mainLegend);
        expect(
          legendStyleOf(tester, label).color,
          highContrast ? CalcTheme.bodyPrintHighContrast : CalcTheme.bodyPrint,
          reason: reason,
        );
        final cap = tester.getRect(_keycap(on.id));
        final text = legendSlotRect(tester, label);
        expect(text.bottom, lessThanOrEqualTo(cap.top + 0.01), reason: reason);
        expect(
          text.center.dx,
          moreOrLessEquals(cap.center.dx, epsilon: 0.5),
          reason: reason,
        );
        // 평소 고리 바깥 경계는 키캡 테두리 색이다 (고대비 팔레트를 따른다)
        expect(
          painter(tester).edge,
          highContrast
              ? CalcPalette.highContrast.keyBorder
              : CalcPalette.standard.keyBorder,
          reason: reason,
        );
      }
    });

    test('고리는 키캡 자리의 짧은 변을 지름으로 가운데에, 원판은 그 안에 그린다', () {
      for (final size in const [Size(64, 72), Size(120, 40), Size(30, 90)]) {
        final bezel = RoundKeyFacePainter.bezelOf(size);
        expect(bezel.width, moreOrLessEquals(size.shortestSide));
        expect(bezel.height, moreOrLessEquals(size.shortestSide));
        expect(bezel.center, size.center(Offset.zero));
        final disc = RoundKeyFacePainter.discOf(size);
        expect(disc.center, bezel.center);
        expect(
          disc.width,
          moreOrLessEquals(bezel.width * CalcTheme.roundKeyDiscRatio),
        );
        expect(bezel.contains(disc.topLeft), isTrue);
      }
      expect(RoundKeyFacePainter.bezelOf(Size.zero).isEmpty, isTrue);
    });

    testWidgets('누르면 즉시 눌림 원판·눌림 테두리로 그려지고 아래로 내려가며, 떼면 돌아온다', (tester) async {
      await tester.pumpWidget(
        _host(CalcKeyButton(keyDef: on, onPressed: (_) {})),
      );
      final cap = tester.getRect(_keycap(on.id));
      final restTop = tester.getRect(find.byType(RoundKeyFace)).top;
      expect(restTop, moreOrLessEquals(cap.top));
      expect(face(tester).pressed, isFalse);
      final gesture = await tester.startGesture(cap.center);
      await tester.pump();
      expect(face(tester).pressed, isTrue);
      expect(painter(tester).edge, CalcTheme.keyPressedBorder);
      expect(
        tester.getRect(find.byType(RoundKeyFace)).top,
        moreOrLessEquals(restTop + CalcTheme.keyPressedOffset),
      );
      await gesture.up();
      await tester.pump();
      expect(face(tester).pressed, isFalse);
      expect(painter(tester).edge, CalcTheme.keyBorder);
    });

    // #156부터 SHIFT·ALPHA·MENU도 원형 버튼이다 — 키캡만 받던 #156 전과 달리 각인 띠까지 셀 전체가 터치 영역이다
    // (터치 영역이 넓어지기만 한다. 셀 밖·키 사이 간격은 그대로 터치 영역이 아니다).
    for (final id in [
      CalcKeyId.shift,
      CalcKeyId.alpha,
      CalcKeyId.menu,
      settingsKey,
    ]) {
      testWidgets('${id.name}: 그린 버튼이 작아도 셀 전체(각인 띠 포함)가 터치 영역이다', (
        tester,
      ) async {
        final def = keyDefOf(id);
        final pressed = <CalcKeyId>[];
        const cell = Size(64, 72);
        await tester.pumpWidget(
          _host(
            CalcKeyButton(keyDef: def, onPressed: pressed.add),
            size: cell,
          ),
        );
        final box = tester.getRect(find.byType(CalcKeyButton));
        expect(box.size, cell);
        final bezel = RoundKeyFacePainter.bezelOf(
          tester.getSize(_keycap(def.id)),
        );
        expect(bezel.width, lessThan(cell.width));
        // 네 모서리 (각인 띠의 위 모서리, 원 밖의 아래 모서리) — 모두 그린 원 밖이다
        for (final p in [
          box.topLeft + const Offset(1, 1),
          box.topRight + const Offset(-1, 1),
          box.bottomLeft + const Offset(1, -1),
          box.bottomRight + const Offset(-1, -1),
        ]) {
          await tester.tapAt(p);
          await tester.pump();
        }
        expect(pressed, List.filled(4, def.id));
        // 셀 바깥은 터치 영역이 아니다
        await tester.tapAt(box.topLeft - const Offset(1, 1));
        await tester.pump();
        expect(pressed, hasLength(4));
      });
    }

    testWidgets('비활성이면 원판을 흐리게 그리고, 눌러도 입력되지 않는다', (tester) async {
      await tester.pumpWidget(_host(CalcKeyButton(keyDef: on)));
      expect(face(tester).enabled, isFalse);
      expect(painter(tester).enabled, isFalse);
      final gesture = await tester.startGesture(
        tester.getCenter(_keycap(on.id)),
      );
      await tester.pump();
      expect(face(tester).pressed, isFalse);
      await gesture.up();
    });

    testWidgets(
      '키보드: focusable이면 포커스를 받아 Enter·Space로 누르고 햅틱을 낸다. 비활성이면 포커스를 받지 않는다',
      (tester) async {
        final haptics = _recordHaptics(tester);
        final pressed = <CalcKeyId>[];
        await tester.pumpWidget(
          _host(
            CalcKeyButton(keyDef: on, onPressed: pressed.add, focusable: true),
          ),
        );
        final node = Focus.of(tester.element(_keycap(on.id)));
        node.requestFocus();
        await tester.pump();
        expect(node.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(pressed, [on.id, on.id]);
        expect(haptics, [_light, _light]);

        // 비활성: 포커스를 받지 않는다(가지고 있던 포커스도 잃는다)
        await tester.pumpWidget(
          _host(CalcKeyButton(keyDef: on, focusable: true)),
        );
        await tester.pump();
        final disabled = Focus.of(tester.element(_keycap(on.id)));
        expect(disabled.canRequestFocus, isFalse);
        expect(disabled.hasFocus, isFalse);
      },
    );

    testWidgets('키보드: focusable이 아닌 키는 Tab으로 포커스를 받지 않는다 (원형 버튼·키캡 모두)', (
      tester,
    ) async {
      for (final def in [on, keyDefOf(CalcKeyId.sin)]) {
        await tester.pumpWidget(
          _host(CalcKeyButton(keyDef: def, onPressed: (_) {})),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus?.context;
        final inKey =
            focused != null &&
            find
                .descendant(
                  of: find.byType(CalcKeyButton),
                  matching: find.byElementPredicate(
                    (e) => identical(e, focused),
                  ),
                )
                .evaluate()
                .isNotEmpty;
        expect(inKey, isFalse, reason: def.id.name);
      }
    });

    testWidgets('스크린리더: focusable 키는 포커스를 받을 수 있고 지금 포커스가 있는지 알린다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(CalcKeyButton(keyDef: on, onPressed: (_) {}, focusable: true)),
      );
      final button = find.byType(CalcKeyButton);
      expect(
        tester.getSemantics(button),
        isSemantics(isButton: true, isFocusable: true, isFocused: false),
      );
      Focus.of(tester.element(_keycap(on.id))).requestFocus();
      await tester.pump();
      expect(
        tester.getSemantics(button),
        isSemantics(isButton: true, isFocusable: true, isFocused: true),
      );
      handle.dispose();
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
        for (final legend in [
          def.mainLegend,
          def.shiftLegend,
          def.alphaLegend,
        ]) {
          if (legend == null) continue;
          expect(
            tester.getRect(findLegend(legend)).height,
            greaterThanOrEqualTo(5.0),
            reason: '$def "${legend.plainText}"',
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

      // 두 크기 모두 글자 크기 상한(#141) 아래다(키캡 높이 × 비율: 약 7.3·14.5dp).
      final small = await renderedHeight(const Size(20, 24));
      final large = await renderedHeight(const Size(40, 48));
      // 텍스트 줄 높이는 픽셀 단위로 반올림되므로 1dp 오차를 허용한다.
      expect(large, closeTo(small * 2, 1.0));
    });

    testWidgets('키가 아주 커져도 라벨 글자는 상한에서 멈춘다 (#141)', (tester) async {
      for (final size in const [Size(80, 96), Size(200, 240)]) {
        await tester.pumpWidget(
          _host(CalcKeyButton(keyDef: keyDefOf(CalcKeyId.num7)), size: size),
        );
        expect(
          tester.widget<Text>(find.text('7')).style?.fontSize,
          CalcTheme.keyMainLabelMaxFontSize,
          reason: '$size',
        );
      }
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

      final sin = keyDefOf(CalcKeyId.sin);
      expect(legendStyleOf(tester, findLegend(sin.shiftLegend!)).fontSize, 7);
      expect(legendStyleOf(tester, findLegend(sin.mainLegend)).fontSize, 13);
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

      testWidgets(
        '진단 로그 (#118): 누름 하나는 첫 줄 뒤 끝 줄 하나로 끝난다 — 뗌, 이미 입력한 누름의 취소, 누른 채 키가 사라진 해제',
        (tester) async {
          final lines = <String>[];
          LayoutLog.enable(sink: lines.add, frameTimings: false);
          addTearDown(LayoutLog.disable);
          final pressed = <CalcKeyId>[];
          await tester.pumpWidget(edgeHost(pressed));

          // 제스처 영역 밖(키 가운데 x=32)에서 누르고 뗀다
          await tester.tapAt(const Offset(32, 300));
          await tester.pump();
          expect(pressed, [CalcKeyId.num1]);

          // 제스처 영역 밖에서 누른 뒤 취소 — 입력은 이미 됐다
          final inside = await tester.startGesture(const Offset(32, 300));
          await inside.cancel();
          await tester.pump();
          expect(pressed, [CalcKeyId.num1, CalcKeyId.num1]);

          // 가장자리(x=10)에서 누른 채 키가 사라진다 — 보류한 누름은 입력되지 않는다
          final edge = await tester.startGesture(const Offset(10, 300));
          await tester.pump();
          await tester.pumpWidget(const SizedBox());
          await edge.up();
          expect(pressed, [CalcKeyId.num1, CalcKeyId.num1]);

          expect(lines.map((l) => l.split(' @').first).toList(), [
            'AltCalc 키 입력(누를 때): num1 (32,300)',
            'AltCalc 키 뗌(이미 입력): num1 (32,300)',
            'AltCalc 키 입력(누를 때): num1 (32,300)',
            'AltCalc 키 취소(이미 입력): num1 (32,300)',
            'AltCalc 키 보류(제스처 영역): num1 (10,300)',
            'AltCalc 키 해제(보류 버림): num1',
          ]);
        },
      );

      testWidgets(
        '진단 로그 (#118): 누른 채 비활성이 되거나 다른 키로 바뀌면 누르던 키의 해제 줄을 남기고, 로그를 끈 뒤에는 줄이 늘지 않는다',
        (tester) async {
          final lines = <String>[];
          LayoutLog.enable(sink: lines.add, frameTimings: false);
          addTearDown(LayoutLog.disable);
          Widget host(
            ValueChanged<CalcKeyId>? onPressed, {
            CalcKeyId id = CalcKeyId.num1,
          }) => MaterialApp(
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
                    keyDef: keyDefOf(id),
                    onPressed: onPressed,
                  ),
                ),
              ),
            ),
          );
          final pressed = <CalcKeyId>[];
          await tester.pumpWidget(host(pressed.add));
          final g = await tester.startGesture(const Offset(10, 300));
          await tester.pump();
          await tester.pumpWidget(host(null));
          await g.up();
          await tester.pump();
          expect(pressed, isEmpty);

          // 영역 밖에서 누른 채 같은 자리의 키가 다른 키(num2)로 바뀐다 — 해제 줄은 누르던 키(num1) 이름이다
          await tester.pumpWidget(host(pressed.add));
          final g2 = await tester.startGesture(const Offset(32, 300));
          await tester.pump();
          await tester.pumpWidget(host(pressed.add, id: CalcKeyId.num2));
          await g2.up();
          await tester.pump();
          expect(pressed, [CalcKeyId.num1]);

          expect(lines.map((l) => l.split(' @').first).toList(), [
            'AltCalc 키 보류(제스처 영역): num1 (10,300)',
            'AltCalc 키 해제(보류 버림): num1',
            'AltCalc 키 입력(누를 때): num1 (32,300)',
            'AltCalc 키 해제(이미 입력): num1',
          ]);

          LayoutLog.disable();
          await tester.pumpWidget(host(pressed.add));
          await tester.tapAt(const Offset(10, 300));
          await tester.tapAt(const Offset(32, 300));
          await tester.pump();
          expect(pressed, [CalcKeyId.num1, CalcKeyId.num1, CalcKeyId.num1]);
          expect(lines, hasLength(4), reason: '꺼진 뒤에는 줄이 늘지 않는다');
        },
      );

      testWidgets('가장자리 밖(안쪽)의 터치는 즉시 입력된다', (tester) async {
        _recordHaptics(tester);
        final pressed = <CalcKeyId>[];
        await tester.pumpWidget(edgeHost(pressed));

        final gesture = await tester.startGesture(const Offset(50, 300));
        await tester.pump();
        expect(pressed, [CalcKeyId.num1]);
        await gesture.up();
      });

      // 화면을 흉내 내는 곳(개발용 미리보기)처럼, 400×400 화면을 전역 (300, 100)에 절반 크기로 그린다.
      // 판정은 전역 좌표가 아니라 ScreenCoordinateRoot 기준 화면 좌표로 해야 한다(#50).
      // 키는 네 가장자리 가운데와 화면 가운데에 하나씩 두고, 위쪽 키도 셀 끝까지 눌리도록 각인 띠까지 터치 영역으로 한다.
      const screenOrigin = Offset(300, 100);
      const screenScale = 0.5;
      const screenSize = Size(400, 400);
      Offset toGlobal(Offset screen) => screenOrigin + screen * screenScale;

      Widget simulatedScreenHost(
        List<CalcKeyId> log, {
        EdgeInsets rootInset = EdgeInsets.zero,
        Size mediaQuerySize = screenSize,
      }) {
        final screen = Stack(
          children: [
            for (final (id, alignment) in [
              (CalcKeyId.num1, Alignment.centerLeft),
              (CalcKeyId.num2, Alignment.center),
              (CalcKeyId.num3, Alignment.centerRight),
              (CalcKeyId.num4, Alignment.topCenter),
              (CalcKeyId.num5, Alignment.bottomCenter),
            ])
              Align(
                alignment: alignment,
                child: SizedBox(
                  width: 64,
                  height: 72,
                  child: CalcKeyButton(
                    keyDef: keyDefOf(id),
                    onPressed: log.add,
                    extendHitAreaToLegend: true,
                  ),
                ),
              ),
          ],
        );
        return MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.only(
                left: screenOrigin.dx,
                top: screenOrigin.dy,
              ),
              child: SizedBox.fromSize(
                size: screenSize * screenScale,
                child: FittedBox(
                  child: SizedBox.fromSize(
                    size: screenSize,
                    child: Padding(
                      padding: rootInset,
                      child: ScreenCoordinateRoot(
                        data: MediaQueryData(
                          size: mediaQuerySize,
                          systemGestureInsets: const EdgeInsets.all(30),
                        ),
                        child: screen,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      /// 전역 좌표 [at]을 누르고, (누른 순간 입력되었는지, 손을 뗀 뒤 입력된 키 이름)을 돌려준다.
      /// (레코드 안의 List는 `==`로 비교되지 않으므로 이름을 문자열로 잇는다.)
      Future<(bool, String)> pressAtGlobal(
        WidgetTester tester,
        List<CalcKeyId> log,
        Offset at,
      ) async {
        log.clear();
        final g = await tester.startGesture(at);
        await tester.pump();
        final immediate = log.isNotEmpty;
        await g.up();
        await tester.pump();
        return (immediate, log.map((id) => id.name).join(','));
      }

      testWidgets('밀리고 축소된 화면에서도 화면 기준 네 가장자리로 판정한다', (tester) async {
        _recordHaptics(tester);
        final pressed = <CalcKeyId>[];
        await tester.pumpWidget(simulatedScreenHost(pressed));
        // 전제: 화면이 전역 (300, 100)에 절반 크기로 그려졌다.
        expect(
          tester.getRect(find.byType(CalcKeyButton).first),
          Rect.fromLTWH(screenOrigin.dx, 100 + 164 * screenScale, 32, 36),
        );
        Future<(bool, String)> pressAt(Offset screen) =>
            pressAtGlobal(tester, pressed, toGlobal(screen));

        // 각 가장자리(인셋 30 안쪽)에서 시작한 터치는 보류된다. 전역 좌표로 비교하면 모두 영역 밖이다
        // (예: 왼쪽 x=10 → 전역 305, 아래 y=390 → 전역 295 < 600-30).
        expect(await pressAt(const Offset(10, 200)), (false, 'num1'));
        expect(await pressAt(const Offset(390, 200)), (false, 'num3'));
        expect(await pressAt(const Offset(200, 10)), (false, 'num4'));
        expect(await pressAt(const Offset(200, 390)), (false, 'num5'));
        // 경계 안쪽(인셋 30 밖)과 가운데 키는 즉시 입력된다.
        expect(await pressAt(const Offset(50, 200)), (true, 'num1'));
        expect(await pressAt(const Offset(350, 200)), (true, 'num3'));
        expect(await pressAt(const Offset(200, 50)), (true, 'num4'));
        expect(await pressAt(const Offset(200, 350)), (true, 'num5'));
        expect(await pressAt(const Offset(200, 200)), (true, 'num2'));
      });

      testWidgets(
        'ScreenCoordinateRoot가 받은 크기가 MediaQuery 크기와 다르면 레이아웃할 때 알린다',
        (tester) async {
          await tester.pumpWidget(
            simulatedScreenHost(
              <CalcKeyId>[],
              rootInset: const EdgeInsets.all(20),
            ),
          );
          final error = tester.takeException();
          expect(error, isA<FlutterError>());
          expect('$error', contains('ScreenCoordinateRoot'));
        },
      );

      testWidgets('제약은 그대로이고 data.size만 바뀌어도 다시 확인한다', (tester) async {
        final pressed = <CalcKeyId>[];
        await tester.pumpWidget(simulatedScreenHost(pressed));
        expect(tester.takeException(), isNull, reason: '처음에는 크기가 맞다');

        // 받는 크기(400×400)는 그대로 두고 MediaQuery 크기만 바꾼다.
        await tester.pumpWidget(
          simulatedScreenHost(pressed, mediaQuerySize: const Size(400, 390)),
        );
        final error = tester.takeException();
        expect(error, isA<FlutterError>());
        expect('$error', contains('ScreenCoordinateRoot'));
      });

      testWidgets(
        '루트 없이 키 위쪽에서 MediaQuery.size를 영역 기준으로 덮어쓰면 오류를 보고하고 입력은 처리한다',
        (tester) async {
          // #24·#25에서 분할 영역마다 size를 덮어쓰는 실수를 잡는다(배치 계약).
          _recordHaptics(tester);
          final pressed = <CalcKeyId>[];
          await tester.pumpWidget(
            MaterialApp(
              home: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 400,
                  height: 600,
                  child: MediaQuery(
                    data: const MediaQueryData(
                      size: Size(400, 600), // 테스트 View는 800×600
                      systemGestureInsets: EdgeInsets.symmetric(horizontal: 30),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 64,
                        height: 72,
                        child: CalcKeyButton(
                          keyDef: keyDefOf(CalcKeyId.num1),
                          onPressed: pressed.add,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final g = await tester.startGesture(const Offset(200, 300));
          final error = tester.takeException();
          expect(error, isA<FlutterError>());
          expect('$error', contains('MediaQuery.size'));
          await g.up();
          await tester.pump();
          expect(pressed, [CalcKeyId.num1], reason: '보고만 하고 입력 처리는 계속한다');
        },
      );

      testWidgets('루트 없는 실제 앱 경로: 화면 안 좌우 분할에서도 기기 가장자리 기준으로 판정한다', (
        tester,
      ) async {
        // #24·#25의 LCD | 키패드 분할처럼 키가 화면 오른쪽 절반에 있어도, MediaQuery를 영역 기준으로
        // 덮어쓰지 않으면 전역 좌표 = 화면 좌표이므로 판정이 맞는다.
        _recordHaptics(tester);
        final pressed = <CalcKeyId>[];
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(800, 600),
                systemGestureInsets: EdgeInsets.symmetric(horizontal: 30),
              ),
              child: Row(
                children: [
                  const Expanded(child: SizedBox.expand()),
                  Expanded(
                    child: Stack(
                      children: [
                        for (final (id, alignment) in [
                          (CalcKeyId.num1, Alignment.centerLeft),
                          (CalcKeyId.num3, Alignment.centerRight),
                        ])
                          Align(
                            alignment: alignment,
                            child: SizedBox(
                              width: 64,
                              height: 72,
                              child: CalcKeyButton(
                                keyDef: keyDefOf(id),
                                onPressed: pressed.add,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        expect(tester.getRect(find.byType(CalcKeyButton).first).left, 400);

        // 오른쪽 영역의 왼쪽 끝 키(전역 x=405)는 화면 가운데라 즉시, 화면 오른쪽 끝 키(x=795)는 보류된다.
        expect(await pressAtGlobal(tester, pressed, const Offset(405, 300)), (
          true,
          'num1',
        ));
        expect(await pressAtGlobal(tester, pressed, const Offset(795, 300)), (
          false,
          'num3',
        ));
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
    testWidgets(
      '버튼 시맨틱과 3단 기능(라벨: 메인, 힌트: 시프트·알파)을 읽어 주고, 시맨틱 탭으로 햅틱과 함께 입력된다',
      (tester) async {
        final handle = tester.ensureSemantics();
        useKoreanLocale(tester);
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
            label: '변수 대입 계산',
            hint: '시프트 방정식 풀기, 알파 등호 입력',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );

        tester.semantics.tap(find.semantics.byLabel('변수 대입 계산'));
        await tester.pump();
        expect(pressed, [CalcKeyId.calc]);
        expect(haptics, [_light]);
        // testWidgets는 tearDown 전에 handle 해제를 검증하므로 본문 끝에서 해제한다.
        handle.dispose();
      },
    );

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
  /// 왼쪽 위 → 오른쪽 위 → 아래 가운데 삼각형 (사각형이 아닌 키 모양 예시)
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

  group('터치 모양 (hitShape·hitOutset, #64)', () {
    // 버튼 상자 120×80, 그림 상자는 사방 10dp 안쪽(100×60)의 삼각형,
    // 터치 영역은 버튼 상자의 왼쪽 3/4 (그림 밖까지 넓고, 오른쪽 끝은 좁다)
    const outer = Size(120, 80);
    const outset = EdgeInsets.all(10);
    Path leftThreeQuarters(Size s) =>
        Path()..addRect(Rect.fromLTWH(0, 0, s.width * 0.75, s.height));

    Widget button({
      ValueChanged<CalcKeyId>? onPressed,
      ValueChanged<CalcKeyId>? onRepeat,
    }) => _host(
      CalcKeyButton(
        keyDef: keyDefOf(CalcKeyId.cursorUp),
        showLegendBand: false,
        enableHaptics: false,
        shape: triangle,
        hitShape: leftThreeQuarters,
        hitOutset: outset,
        onPressed: onPressed ?? (_) {},
        onRepeat: onRepeat,
      ),
      size: outer,
    );

    testWidgets('그림은 여백 안쪽 상자에 그대로 그린다', (tester) async {
      await tester.pumpWidget(button());
      final box = tester.getRect(find.byType(CalcKeyButton));
      expect(box.size, outer);
      final keycap = tester.getRect(_keycap(CalcKeyId.cursorUp));
      expect(keycap.topLeft, box.topLeft + const Offset(10, 10));
      expect(keycap.width, 100);
    });

    testWidgets('그림 밖이라도 터치 모양 안이면 입력되고, 버튼 상자 안이라도 터치 모양 밖이면 무시된다', (
      tester,
    ) async {
      final pressed = <CalcKeyId>[];
      await tester.pumpWidget(button(onPressed: pressed.add));
      final box = tester.getRect(find.byType(CalcKeyButton));
      for (final (p, expected) in [
        (const Offset(5, 75), true), // 그림 상자 밖(여백)
        (const Offset(15, 65), true), // 그림 상자 안, 삼각형 밖
        (const Offset(50, 25), true), // 삼각형 안
        (const Offset(100, 30), false), // 삼각형 안이지만 터치 모양 밖 (x > 90)
        (const Offset(115, 75), false), // 여백, 터치 모양 밖
      ]) {
        pressed.clear();
        await tester.tapAt(box.topLeft + p);
        await tester.pump();
        expect(pressed.isNotEmpty, expected, reason: '$p');
      }
    });

    testWidgets('누른 채 터치 모양 안(그림 밖)으로 움직이면 반복이 이어지고, 밖으로 나가면 멈춘다', (
      tester,
    ) async {
      final repeats = <CalcKeyId>[];
      await tester.pumpWidget(button(onRepeat: repeats.add));
      final box = tester.getRect(find.byType(CalcKeyButton));
      final g = await tester.startGesture(box.topLeft + const Offset(50, 25));
      await tester.pump(CalcKeyButton.defaultRepeatDelay);
      expect(repeats, hasLength(1));
      await g.moveTo(box.topLeft + const Offset(5, 75)); // 그림 밖, 터치 모양 안
      await tester.pump(CalcKeyButton.defaultRepeatInterval * 3);
      expect(repeats, hasLength(4));
      await g.moveTo(box.topLeft + const Offset(100, 30)); // 터치 모양 밖
      await tester.pump(CalcKeyButton.defaultRepeatInterval * 5);
      expect(repeats, hasLength(4));
      await g.up();
    });

    testWidgets('여백이 버튼 상자보다 크면 키는 그리지 않고 터치 영역만 남는다', (tester) async {
      final pressed = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(
          CalcKeyButton(
            keyDef: keyDefOf(CalcKeyId.sin),
            enableHaptics: false,
            hitShape: leftThreeQuarters,
            hitOutset: const EdgeInsets.all(60),
            onPressed: pressed.add,
          ),
          size: outer,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(_keycap(CalcKeyId.sin), findsNothing);
      final box = tester.getRect(find.byType(CalcKeyButton));
      await tester.tapAt(box.topLeft + const Offset(20, 40));
      expect(pressed, [CalcKeyId.sin]);
    });

    testWidgets('hitOutset이 음수면 디버그 assert로 알린다', (tester) async {
      await tester.pumpWidget(
        _host(
          CalcKeyButton(
            keyDef: keyDefOf(CalcKeyId.cursorUp),
            hitShape: leftThreeQuarters,
            hitOutset: const EdgeInsets.only(left: -1),
            onPressed: (_) {},
          ),
          size: outer,
        ),
      );
      final error = tester.takeException();
      expect(error, isA<AssertionError>());
      expect('$error', contains('음수'));
    });

    testWidgets('hitShape와 extendHitAreaToLegend를 함께 주면 디버그 assert로 알린다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CalcKeyButton(
            keyDef: keyDefOf(CalcKeyId.sin),
            hitShape: leftThreeQuarters,
            extendHitAreaToLegend: true,
            onPressed: (_) {},
          ),
          size: outer,
        ),
      );
      final error = tester.takeException();
      expect(error, isA<AssertionError>());
      expect('$error', contains('extendHitAreaToLegend'));
    });

    testWidgets('hitShape 없이 hitOutset만 주면 디버그 assert로 알린다', (tester) async {
      await tester.pumpWidget(
        _host(
          CalcKeyButton(
            keyDef: keyDefOf(CalcKeyId.cursorUp),
            hitOutset: outset,
            onPressed: (_) {},
          ),
          size: outer,
        ),
      );
      expect(tester.takeException(), isA<AssertionError>());
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
      final y = find.text('y');
      expect(
        tester.getRect(y).height,
        moreOrLessEquals(tester.getSize(y).height, epsilon: 0.01),
      );
      // 긴 각인은 남은 폭 안에 들어가도록 줄어든다 (띠 밖으로 넘치지 않는다).
      final band = tester.getRect(find.byType(CalcKeyButton));
      final long = tester.getRect(
        findLegend(keyDefOf(CalcKeyId.sdToggle).shiftLegend!),
      );
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

  group('라벨 여백 (labelInsets, #65)', () {
    const box = Size(120, 80);

    Rect labelOf(WidgetTester tester) => tester.getRect(
      find.descendant(
        of: _keycap(CalcKeyId.cursorUp),
        matching: find.byType(Text),
      ),
    );

    Widget button(EdgeInsets labelInsets) => _host(
      CalcKeyButton(
        keyDef: keyDefOf(CalcKeyId.cursorUp),
        showLegendBand: false,
        enableHaptics: false,
        labelInsets: labelInsets,
        onPressed: (_) {},
      ),
      size: box,
    );

    testWidgets('라벨은 키캡에서 여백을 뺀 나머지의 가운데에 놓이고, 키캡 크기는 그대로다', (tester) async {
      await tester.pumpWidget(button(EdgeInsets.zero));
      final keycap = tester.getRect(_keycap(CalcKeyId.cursorUp));
      final centered = labelOf(tester);

      await tester.pumpWidget(button(const EdgeInsets.only(bottom: 30)));
      expect(tester.getRect(_keycap(CalcKeyId.cursorUp)), keycap);
      final shifted = labelOf(tester);
      // 아래 30dp를 빼면 라벨 중심이 다음 프레임 없이 바로 15dp 올라간다(키캡 여백과 달리 애니메이션하지 않는다).
      // 크기는 그대로다(남은 자리에 들어간다).
      expect(shifted.size, centered.size);
      expect(shifted.center.dx, moreOrLessEquals(centered.center.dx));
      expect(shifted.center.dy, moreOrLessEquals(centered.center.dy - 15));
    });

    testWidgets('왼쪽 여백은 라벨을 오른쪽으로 옮긴다', (tester) async {
      await tester.pumpWidget(button(EdgeInsets.zero));
      final centered = labelOf(tester);
      await tester.pumpWidget(button(const EdgeInsets.only(left: 40)));
      final shifted = labelOf(tester);
      expect(shifted.size, centered.size);
      expect(shifted.center.dx, moreOrLessEquals(centered.center.dx + 20));
      expect(shifted.center.dy, moreOrLessEquals(centered.center.dy));
    });

    testWidgets('남은 자리가 라벨보다 작으면 줄여 그린다', (tester) async {
      await tester.pumpWidget(button(EdgeInsets.zero));
      final full = labelOf(tester);
      // 남은 높이를 라벨 높이의 절반으로 만든다.
      final keycap = tester.getRect(_keycap(CalcKeyId.cursorUp));
      final cut = keycap.height - full.height / 2;
      await tester.pumpWidget(button(EdgeInsets.only(bottom: cut)));
      final shrunk = labelOf(tester);
      expect(shrunk.height, lessThan(full.height * 0.6));
      expect(shrunk.bottom, lessThanOrEqualTo(keycap.bottom - cut + 0.01));
    });

    testWidgets('labelInsets가 음수면 디버그 assert로 알린다', (tester) async {
      await tester.pumpWidget(button(const EdgeInsets.only(top: -1)));
      final error = tester.takeException();
      expect(error, isA<AssertionError>());
      expect('$error', contains('음수'));
    });
  });
}

/// 실물 외관 (#156) — 원형 버튼 넷, 키캡 입체감, 모서리 반경, 변수 이탤릭, 키별 그리기 층.
void _appearanceTests() {
  group('실물 외관 (#156)', () {
    KeycapSheenPainter? sheenOf(WidgetTester tester, CalcKeyId id) {
      final paints = tester.widgetList<CustomPaint>(
        find.descendant(of: _keycap(id), matching: find.byType(CustomPaint)),
      );
      for (final p in paints) {
        if (p.painter case final KeycapSheenPainter sheen) return sheen;
      }
      return null;
    }

    testWidgets(
      'SHIFT·ALPHA·MENU·ON은 원형 버튼이고, 이름은 버튼 위 본체에 SHIFT 금색·ALPHA 자홍색·나머지 흰색으로 인쇄한다',
      (tester) async {
        for (final highContrast in [false, true]) {
          final palette = highContrast
              ? CalcPalette.highContrast
              : CalcPalette.standard;
          for (final (id, color) in [
            (CalcKeyId.shift, palette.shiftLabel),
            (CalcKeyId.alpha, palette.alphaLabel),
            (CalcKeyId.menu, palette.bodyPrint),
            (CalcKeyId.on, palette.bodyPrint),
          ]) {
            final def = keyDefOf(id);
            expect(def.face, KeyFace.roundButton, reason: id.name);
            await tester.pumpWidget(
              _host(
                CalcKeyButton(keyDef: def, onPressed: (_) {}),
                highContrast: highContrast,
              ),
            );
            final reason = '${id.name} highContrast=$highContrast';
            expect(
              find.descendant(
                of: _keycap(id),
                matching: find.byType(RoundKeyFace),
              ),
              findsOneWidget,
              reason: reason,
            );
            expect(
              find.descendant(of: _keycap(id), matching: find.byType(Text)),
              findsNothing,
              reason: reason,
            );
            expect(
              legendStyleOf(tester, findLegend(def.mainLegend)).color,
              color,
              reason: reason,
            );
          }
        }
        // 실물 MENU 버튼 위 `MENU SETUP` — SETUP은 SHIFT 각인 색
        await tester.pumpWidget(
          _host(CalcKeyButton(keyDef: keyDefOf(CalcKeyId.menu))),
        );
        expect(
          legendStyleOf(tester, find.text('SETUP')).color,
          CalcTheme.shiftLabel,
        );
      },
    );

    testWidgets('일반 모드 키캡: 윗면 광택·옆면·그림자를 그리고, 눌리면 옆면·그림자가 사라진다', (
      tester,
    ) async {
      for (final (id, dark) in [
        (CalcKeyId.sin, true),
        (CalcKeyId.del, true),
        (CalcKeyId.num7, false),
        (CalcKeyId.add, false),
      ]) {
        final def = keyDefOf(id);
        await tester.pumpWidget(
          _host(CalcKeyButton(keyDef: def, onPressed: (_) {})),
        );
        final sheen = sheenOf(tester, id);
        expect(sheen, isNotNull, reason: id.name);
        expect(sheen!.dark, dark, reason: id.name);
        // 광택은 글자 자리(가운데)를 비운다
        expect(sheen.colors[1].a, 0);
        expect(sheen.colors[2].a, 0);
        final shadows = _decoration(tester, id).boxShadow!;
        expect(shadows, hasLength(2), reason: id.name);
        // 둘째가 옆면 — 번지지 않고, 옆면 깊이만큼 아래에, 키캡 색을 어둡게 한 색
        expect(shadows[1].blurRadius, 0);
        expect(shadows[1].offset, const Offset(0, CalcTheme.keyCapSideDepth));
        expect(
          shadows[1].color,
          Color.alphaBlend(CalcTheme.keyCapSide, def.category.background),
        );
        expect(shadows[0].color, CalcTheme.keyShadow);

        final gesture = await tester.startGesture(
          tester.getCenter(_keycap(id)),
        );
        await tester.pump();
        expect(_decoration(tester, id).boxShadow, isEmpty, reason: id.name);
        await gesture.up();
        await tester.pump(CalcTheme.keyPressAnimationDuration);
      }
    });

    testWidgets('고대비 키캡: 광택·옆면을 그리지 않고 그림자만 남긴다 (글자 뒤 색이 평평하다)', (
      tester,
    ) async {
      for (final id in [CalcKeyId.sin, CalcKeyId.num7, CalcKeyId.ac]) {
        await tester.pumpWidget(
          _host(
            CalcKeyButton(keyDef: keyDefOf(id), onPressed: (_) {}),
            highContrast: true,
          ),
        );
        expect(sheenOf(tester, id), isNull, reason: id.name);
        final shadows = _decoration(tester, id).boxShadow!;
        expect(shadows, hasLength(1), reason: id.name);
        expect(shadows.single.color, CalcTheme.keyShadow);
      }
    });

    testWidgets('키캡 모서리 반경은 숫자부가 덜 둥글고, 키캡 높이에 비례하되 상한에서 멈춘다', (tester) async {
      expect(
        keyCapCornerRadius(KeyCategory.function, 40),
        moreOrLessEquals(40 * CalcTheme.keyCapCornerRadiusRatio),
      );
      expect(
        keyCapCornerRadius(KeyCategory.number, 40),
        moreOrLessEquals(40 * CalcTheme.keyCapNumberCornerRadiusRatio),
      );
      for (final c in [
        KeyCategory.operator,
        KeyCategory.equals,
        KeyCategory.ac,
        KeyCategory.del,
      ]) {
        expect(
          keyCapCornerRadius(c, 40),
          keyCapCornerRadius(KeyCategory.number, 40),
          reason: c.name,
        );
      }
      expect(
        keyCapCornerRadius(KeyCategory.function, 1000),
        CalcTheme.keyCapMaxCornerRadius,
      );
      expect(keyCapCornerRadius(KeyCategory.number, 0), 0);
      // 화면의 키캡도 그 반경으로 그린다
      await tester.pumpWidget(
        _host(CalcKeyButton(keyDef: keyDefOf(CalcKeyId.sin))),
      );
      final radius = _decoration(tester, CalcKeyId.sin).borderRadius!;
      final capHeight = tester.getSize(_keycap(CalcKeyId.sin)).height;
      expect(
        (radius as BorderRadius).topLeft.x,
        moreOrLessEquals(keyCapCornerRadius(KeyCategory.function, capHeight)),
      );
    });

    testWidgets('변수 글자만 이탤릭 세리프로 그린다 — x 키·x!의 x (각인 글꼴은 그대로)', (tester) async {
      const style = TextStyle(fontSize: 10, color: Color(0xFFFFFFFF));
      final xBang = keyLabelSpan('x!', style);
      expect(xBang.children, hasLength(2));
      final italic = xBang.children![0] as TextSpan;
      expect(italic.text, 'x');
      expect(italic.style!.fontFamily, CalcTheme.keyVariableFontFamily);
      expect(italic.style!.fontStyle, FontStyle.italic);
      expect((xBang.children![1] as TextSpan).style, isNull);
      // ⇔는 수학 글꼴 조각이다 (#156 R2)
      final sd = keyLabelSpan('S⇔D', style);
      expect(sd.children, hasLength(3));
      expect(
        (sd.children![1] as TextSpan).style!.fontFamily,
        CalcTheme.mathFontFamily,
      );
      // 바꾸는 글자가 없으면 글자열 하나다
      final plain = keyLabelSpan('Rec', style);
      expect(plain.children, isNull);
      expect(plain.text, 'Rec');

      await tester.pumpWidget(
        _host(CalcKeyButton(keyDef: keyDefOf(CalcKeyId.variableX))),
      );
      final text = tester.widget<Text>(
        find.descendant(
          of: _keycap(CalcKeyId.variableX),
          matching: find.byType(Text),
        ),
      );
      final span = text.textSpan! as TextSpan;
      expect(
        (span.children!.single as TextSpan).style!.fontStyle,
        FontStyle.italic,
      );
      // 각인 위젯 찾기(find.text)·스타일 읽기는 그대로 된다
      expect(findLegend(const LegendText('x')), findsWidgets);
      expect(text.style!.fontFamily, CalcTheme.keyFontFamily);
    });

    testWidgets('광택은 키캡 테두리 안쪽 상자에 그리고, 반경은 바깥 반경 − 테두리다 (#156 R1·R2)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(CalcKeyButton(keyDef: keyDefOf(CalcKeyId.sin))),
      );
      final paint = find.descendant(
        of: _keycap(CalcKeyId.sin),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is KeycapSheenPainter,
        ),
      );
      final cap = tester.getSize(_keycap(CalcKeyId.sin));
      expect(
        tester.getSize(paint),
        Size(
          cap.width - 2 * CalcTheme.keyBorderWidth,
          cap.height - 2 * CalcTheme.keyBorderWidth,
        ),
      );
      final sheen = sheenOf(tester, CalcKeyId.sin)!;
      final outer =
          (_decoration(tester, CalcKeyId.sin).borderRadius! as BorderRadius)
              .topLeft
              .x;
      expect(sheen.cornerRadius, outer);
    });

    testWidgets('키마다 따로 그리는 층이다 — 누른 키만 다시 그린다', (tester) async {
      await tester.pumpWidget(
        _host(CalcKeyButton(keyDef: keyDefOf(CalcKeyId.sin))),
      );
      expect(
        find.descendant(
          of: find.byType(CalcKeyButton),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });
  });
}
