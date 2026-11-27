import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/calc_state.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/calc_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/handedness_dialog.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/history_panel.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/round_key_face.dart';
import 'package:material_ui/material_ui.dart';

import '../support/korean_locale.dart';
import '../support/screen_arrangement.dart';

/// 설정 키 (#190): ON 키를 누르면 설정이 열리고, 상단 띠 장식·설정 버튼(#41)은 없다.
/// 대화상자 위치(접힘선·좁은 하위 화면, #25·#94·#125·#129)는 `screen_layout_test`가 본다.

final _lcd = find.byType(LcdDisplay);
final _keypad = find.byKey(const ValueKey('calc-keypad'));
final _onKey = find.byKey(CalcKeyButton.keycapKeyOf(settingsKey));
final _dialog = find.byType(HandednessDialog);
final _surface = find
    .descendant(of: find.byType(AlertDialog), matching: find.byType(Material))
    .first;

/// [size] 창·[padding] 인셋으로 [CalculatorScreen]을 띄운다. 같은 테스트에서 [container]를 넘겨 다시 부르면
/// 창만 바꿔 다시 그린다.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required Size size,
  EdgeInsets padding = EdgeInsets.zero,
  List<DisplayFeature> displayFeatures = const [],
  ProviderContainer? container,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  tester.view.displayFeatures = displayFeatures;
  addTearDown(tester.view.resetDisplayFeatures);
  if (container == null) {
    container = ProviderContainer();
    addTearDown(container.dispose);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: padding,
            viewPadding: padding,
            displayFeatures: displayFeatures,
          ),
          child: const CalculatorScreen(),
        ),
      ),
    ),
  );
  return container;
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(_onKey);
  await tester.pumpAndSettle();
  expect(_dialog, findsOneWidget);
}

/// 지금 키보드 포커스가 [finder] 안에 있는지
bool _focusIn(Finder finder) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  return find
      .descendant(
        of: finder,
        matching: find.byElementPredicate((e) => identical(e, focused)),
      )
      .evaluate()
      .isNotEmpty;
}

final _onButton = find.byWidgetPredicate(
  (w) => w is CalcKeyButton && w.keyDef.id == settingsKey,
);

void main() {
  // 세로 폰 — #190 전에는 상단 띠가 최소 높이(줄 20dp)였다.
  const phone = Size(360, 640);
  const phoneInsets = EdgeInsets.only(top: 24, bottom: 48);

  group('상단 띠 없음 (#190)', () {
    for (final (name, size, padding) in const [
      ('세로 폰', phone, phoneInsets),
      ('21:9 폰', Size(411, 960), EdgeInsets.only(top: 24, bottom: 24)),
      ('태블릿 세로', Size(800, 1280), EdgeInsets.only(top: 24, bottom: 48)),
      ('태블릿 가로', Size(1280, 800), EdgeInsets.only(top: 24, bottom: 48)),
    ]) {
      testWidgets('$name: 설정 버튼·장식 없이 LCD(가로형은 위 띠)가 본체 윗변부터다', (tester) async {
        await _pump(tester, size: size, padding: padding);
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.settings), findsNothing);
        expect(find.byType(IconButton), findsNothing);
        expect(find.text('AltCalc'), findsNothing);
        final bodyTop = padding.top + CalcTheme.screenPadding;
        final top = [
          tester.getRect(_lcd).top,
          if (find.byKey(HistoryPanel.panelKey).evaluate().isNotEmpty)
            tester.getRect(find.byKey(HistoryPanel.panelKey)).top,
        ].reduce((a, b) => a < b ? a : b);
        expect(top, moreOrLessEquals(bodyTop));
      });
    }
  });

  group('ON 키로 설정을 연다', () {
    testWidgets('ON 키는 원형 버튼이고 각인 띠에 SETTING이 인쇄되어 있다', (tester) async {
      await _pump(tester, size: phone, padding: phoneInsets);
      expect(
        find.descendant(of: _onKey, matching: find.byType(RoundKeyFace)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _onButton, matching: find.text('SETTING')),
        findsOneWidget,
      );
      expect(find.text('ON'), findsNothing);
      expect(find.text('OFF'), findsNothing);
    });

    testWidgets('ON 키를 누르면 설정이 열리고, LCD를 눌러도 열리지 않는다', (tester) async {
      await _pump(tester, size: phone, padding: phoneInsets);
      final lcd = tester.getRect(_lcd);
      for (final point in [lcd.center, lcd.topRight + const Offset(-10, 10)]) {
        await tester.tapAt(point);
        await tester.pumpAndSettle();
        expect(_dialog, findsNothing, reason: '$point');
      }
      await _open(tester);
    });

    testWidgets('ON 키의 SETTING 인쇄(각인 띠)를 눌러도 열린다 — 터치 영역은 셀 전체다', (
      tester,
    ) async {
      await _pump(tester, size: phone, padding: phoneInsets);
      await tester.tap(find.text('SETTING'));
      await tester.pumpAndSettle();
      expect(_dialog, findsOneWidget);
    });

    testWidgets('ON 키는 계산기 입력이 아니다: LCD 입력이 바뀌지 않고, SHIFT 대기는 풀린다', (
      tester,
    ) async {
      final container = await _pump(tester, size: phone, padding: phoneInsets);
      await tester.tap(find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.num7)));
      await tester.tap(find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.shift)));
      await tester.pump();
      expect(container.read(calcProvider).modifier, KeyModifier.shift);
      final before = container.read(calcProvider);
      await _open(tester);
      final after = container.read(calcProvider);
      expect(after.modifier, KeyModifier.none);
      expect(after.lastInput, before.lastInput);
      expect(after.inputCount, before.inputCount);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('lcd-input-text'))).data,
        '7',
      );
    });

    testWidgets('SHIFT + AC(실물 OFF)는 아무것도 하지 않는다', (tester) async {
      final container = await _pump(tester, size: phone, padding: phoneInsets);
      await tester.tap(find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.shift)));
      await tester.tap(find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.ac)));
      await tester.pump();
      final state = container.read(calcProvider);
      expect(state.modifier, KeyModifier.none);
      expect(state.inputCount, 0);
      expect(_dialog, findsNothing);
    });

    testWidgets('위아래 배치: 대화상자는 지금 화면에서 키패드 위치가 바뀌지 않는다고 안내한다', (tester) async {
      await _pump(tester, size: phone, padding: phoneInsets);
      await _open(tester);
      expect(find.byKey(HandednessDialog.noteKey), findsOneWidget);
      final lcd = tester.getRect(_lcd);
      final keypad = tester.getRect(_keypad);
      await tester.tap(
        find.byKey(HandednessDialog.optionKeyOf(Handedness.left)),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(_lcd), lcd);
      expect(tester.getRect(_keypad), keypad);
    });

    testWidgets('한국어 기기에서는 안내 글이 한국어다', (tester) async {
      useKoreanLocale(tester);
      await _pump(tester, size: phone, padding: phoneInsets);
      await _open(tester);
      expect(
        tester.widget<Text>(find.byKey(HandednessDialog.noteKey)).data,
        '지금 화면에서는 손잡이를 바꿔도 키 배치가 바뀌지 않습니다. '
        '가로로 넓은 화면 등에서 숫자 키를 고른 손 쪽으로 옮깁니다.',
      );
    });

    for (final (name, size, padding, features, handedness, expected) in [
      (
        '가로형 1280×800',
        const Size(1280, 800),
        const EdgeInsets.only(top: 24, bottom: 48),
        const <DisplayFeature>[],
        Handedness.right,
        DrawnArrangement.landscape,
      ),
      (
        '테이블톱 716×1200',
        const Size(716, 1200),
        const EdgeInsets.only(top: 32, bottom: 24),
        const [
          DisplayFeature(
            bounds: Rect.fromLTWH(0, 600, 716, 0),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureHalfOpened,
          ),
        ],
        Handedness.left,
        DrawnArrangement.tabletop,
      ),
      (
        '세로 접힘선 841×701',
        const Size(841, 701),
        const EdgeInsets.only(top: 24, bottom: 24),
        const [
          DisplayFeature(
            bounds: Rect.fromLTWH(420, 0, 0, 701),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
        Handedness.right,
        DrawnArrangement.sideBySide,
      ),
    ]) {
      testWidgets('$name: 손잡이가 적용되는 배치라 안내 글이 없다', (tester) async {
        final container = await _pump(
          tester,
          size: size,
          padding: padding,
          displayFeatures: features,
        );
        container.read(handednessProvider.notifier).set(handedness);
        await tester.pump();
        expect(drawnArrangementOf(tester), expected);
        await _open(tester);
        expect(find.byKey(HandednessDialog.noteKey), findsNothing);
      });
    }

    testWidgets('대화상자가 열린 채 배치가 바뀌면 안내 글이 따라 나타나고 사라진다', (tester) async {
      const padding = EdgeInsets.only(top: 24, bottom: 48);
      final container = await _pump(
        tester,
        size: const Size(1280, 800),
        padding: padding,
      );
      await _open(tester);
      expect(find.byKey(HandednessDialog.noteKey), findsNothing);
      await _pump(
        tester,
        size: const Size(800, 1280),
        padding: padding,
        container: container,
      );
      await tester.pumpAndSettle();
      expect(_dialog, findsOneWidget);
      expect(find.byKey(HandednessDialog.noteKey), findsOneWidget);
      await _pump(
        tester,
        size: const Size(1280, 800),
        padding: padding,
        container: container,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(HandednessDialog.noteKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('대화상자가 열린 채 접힘선 기준 배치로 바뀌면 지금 ON 키가 있는 절반으로 옮겨 간다 (#41 R2)', (
      tester,
    ) async {
      // Fold 내부 화면 가로(펼친 가로 접힘선): 위아래 배치
      final container = await _pump(
        tester,
        size: const Size(841, 701),
        displayFeatures: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(0, 350, 841, 0),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
      );
      expect(isStackedArrangement(tester), isTrue);
      await _open(tester);
      // 세로로 돌림 → 세로 접힘선 기준 배치, 오른손잡이라 키패드·ON 키는 오른쪽 절반
      await _pump(
        tester,
        size: const Size(701, 841),
        displayFeatures: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(350, 0, 0, 841),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
        container: container,
      );
      await tester.pumpAndSettle();
      expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
      expect(tester.getRect(_onKey).left, greaterThanOrEqualTo(350));
      expect(tester.getRect(_surface).left, greaterThanOrEqualTo(350));
      expect(tester.takeException(), isNull);
    });

    testWidgets('회전으로 배치가 바뀌어도 ON 키 element가 유지된다', (tester) async {
      const padding = EdgeInsets.only(top: 24, bottom: 48);
      final container = await _pump(
        tester,
        size: const Size(1280, 800),
        padding: padding,
      );
      final element = tester.element(_onButton);
      await _pump(
        tester,
        size: const Size(800, 1280),
        padding: padding,
        container: container,
      );
      expect(isStackedArrangement(tester), isTrue);
      expect(identical(tester.element(_onButton), element), isTrue);
    });
  });

  group('스크린리더 (#190)', () {
    testWidgets('ON 키는 "Settings" 버튼으로 읽히고, SETTING 인쇄·없어진 설정 버튼은 따로 읽히지 않는다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, size: phone, padding: phoneInsets);
      expect(
        tester.getSemantics(_onButton),
        isSemantics(label: 'Settings', isButton: true, hasTapAction: true),
      );
      expect(find.bySemanticsLabel('Settings'), findsOneWidget);
      expect(find.bySemanticsLabel('SETTING'), findsNothing);
      expect(find.byTooltip('Settings'), findsNothing);
      handle.dispose();
    });

    testWidgets('스크린리더로 ON 키를 활성화해도 설정이 열린다', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, size: phone, padding: phoneInsets);
      tester.semantics.tap(find.semantics.byLabel('Settings'));
      await tester.pumpAndSettle();
      expect(_dialog, findsOneWidget);
      handle.dispose();
    });
  });

  group('키보드 (#190 — 설정 버튼의 키보드 경로 #106을 잇는다)', () {
    testWidgets('Tab으로 ON 키에 포커스하고 Enter로 열며, Esc로 닫으면 포커스가 ON 키로 돌아온다', (
      tester,
    ) async {
      await _pump(tester, size: phone, padding: phoneInsets);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusIn(_onButton), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_dialog, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_dialog, findsNothing);
      expect(_focusIn(_onButton), isTrue);
      // Space로도 연다
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(_dialog, findsOneWidget);
    });

    testWidgets('ON 키 말고 다른 계산기 키는 Tab 포커스를 받지 않는다 (하드웨어 키보드 입력은 #39)', (
      tester,
    ) async {
      await _pump(tester, size: phone, padding: phoneInsets);
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus?.context;
        final inOtherKey =
            focused != null &&
            find
                .descendant(
                  of: find.byWidgetPredicate(
                    (w) => w is CalcKeyButton && w.keyDef.id != settingsKey,
                  ),
                  matching: find.byElementPredicate(
                    (e) => identical(e, focused),
                  ),
                )
                .evaluate()
                .isNotEmpty;
        expect(inOtherKey, isFalse);
      }
    });
  });
}
