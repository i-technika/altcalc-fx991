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
        // LCD 쪽(LCD·기록 영역)이 본체 윗변부터다 — LCD 위에 빈 곳도 없다(#232).
        final bodyTop = padding.top + CalcTheme.screenPadding;
        final lcd = tester.getRect(_lcd);
        expect(lcd.top, moreOrLessEquals(bodyTop));
        if (find.byKey(HistoryPanel.panelKey).evaluate().isNotEmpty) {
          expect(
            tester.getRect(find.byKey(HistoryPanel.panelKey)).top,
            moreOrLessEquals(bodyTop),
          );
        }
      });
    }
  });

  group('ON 키로 설정을 연다', () {
    testWidgets('ON 키는 원형 버튼이고 각인 띠에 SETUP이 인쇄되어 있다', (tester) async {
      await _pump(tester, size: phone, padding: phoneInsets);
      expect(
        find.descendant(of: _onKey, matching: find.byType(RoundKeyFace)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _onButton, matching: find.text('SETUP')),
        findsOneWidget,
      );
      // 설정(SETUP)은 이 키 하나로만 들어간다 — MENU 위의 SHIFT 각인 SETUP도, AC 위의 OFF도 없다 (#253).
      expect(find.text('SETUP'), findsOneWidget);
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

    testWidgets('ON 키의 SETUP 인쇄(각인 띠)를 눌러도 열린다 — 터치 영역은 셀 전체다', (tester) async {
      await _pump(tester, size: phone, padding: phoneInsets);
      await tester.tap(find.text('SETUP'));
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

    for (final id in [CalcKeyId.menu, CalcKeyId.ac]) {
      testWidgets(
        'SHIFT + ${id.name}(실물 SHIFT 각인을 뺀 키)는 설정을 열지 않고 아무것도 입력하지 않으며 SHIFT만 푼다 (#253)',
        (tester) async {
          final container = await _pump(
            tester,
            size: phone,
            padding: phoneInsets,
          );
          await tester.tap(
            find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.shift)),
          );
          await tester.pump();
          expect(container.read(calcProvider).modifier, KeyModifier.shift);
          await tester.tap(find.byKey(CalcKeyButton.keycapKeyOf(id)));
          await tester.pumpAndSettle();
          final state = container.read(calcProvider);
          expect(state.modifier, KeyModifier.none);
          expect(state.inputCount, 0);
          expect(_dialog, findsNothing);
        },
      );
    }

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
      // 가로 접힘선의 넓은 배열은 숫자부·활성 LCD가 손 쪽으로 옮겨 간다 (#143)
      (
        '가로 접힘선 Fold 가로 841×673(넓은 배열)',
        const Size(841, 673),
        const EdgeInsets.only(top: 24, bottom: 24),
        const [
          DisplayFeature(
            bounds: Rect.fromLTWH(0, 336.5, 841, 0),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureFlat,
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

    testWidgets('가로 접힘선의 실물 배열(Flip 내부)은 손잡이로 옮겨 가는 것이 없어 안내 글이 있다 (#143)', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(411, 1006),
        padding: const EdgeInsets.only(top: 32, bottom: 24),
        displayFeatures: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(0, 503, 411, 0),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
      );
      expect(drawnArrangementOf(tester), DrawnArrangement.tabletop);
      await _open(tester);
      expect(find.byKey(HandednessDialog.noteKey), findsOneWidget);
    });

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
      // 위 패널이 패널 최소 길이(128dp)보다 짧은 가로 접힘선: 접힘선 기준으로 나누지 않아 위아래 배치
      // (#143 전에는 펼친 가로 접힘선이면 위아래 배치였다 — 이제는 펼쳐도 나눈다)
      final container = await _pump(
        tester,
        size: const Size(841, 701),
        displayFeatures: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(0, 100, 841, 0),
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

    testWidgets(
      '대화상자가 열린 채 접힘선 나뉨이 바뀌어도 대화상자 element와 키보드 포커스가 유지된다 (#41 R2)',
      (tester) async {
        // 세로 접힘선 기준 배치(대화상자를 ON 키 쪽 절반에 둔다) → 접힘선이 없어짐(가로형, 나누지 않음)
        const fold = DisplayFeature(
          bounds: Rect.fromLTWH(420, 0, 0, 701),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureFlat,
        );
        final container = await _pump(
          tester,
          size: const Size(841, 701),
          displayFeatures: const [fold],
        );
        await _open(tester);
        // 전제: 처음에는 대화상자가 ON 키 쪽(오른쪽) 절반에 갇혀 있다 — 나뉨이 바뀌어야 감싸는 위젯이 달라진다.
        expect(tester.getRect(_surface).left, greaterThanOrEqualTo(420));
        final option = find.byKey(
          HandednessDialog.optionKeyOf(Handedness.values.first),
        );
        // 키보드로 첫 선택지에 포커스를 준다.
        for (var i = 0; i < 5 && !_focusIn(option); i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(_focusIn(option), isTrue);
        final focused = FocusManager.instance.primaryFocus;
        final optionElement = tester.element(option);

        for (final features in const [
          <DisplayFeature>[],
          [fold],
        ]) {
          await _pump(
            tester,
            size: const Size(841, 701),
            displayFeatures: features,
            container: container,
          );
          await tester.pumpAndSettle();
          expect(_dialog, findsOneWidget);
          expect(identical(tester.element(option), optionElement), isTrue);
          expect(FocusManager.instance.primaryFocus, same(focused));
        }
      },
    );

    // 작은 창 — 위아래 배치로 남는 창은 안내 글이 나오고, 가로형이 된 짧은 창(#38, #142)은 손잡이가 적용되므로
    // 안내 글이 없다. 어느 쪽이든 첫 선택지가 스크롤 없이 눌린다.
    for (final (size, stacked) in const [
      (Size(300, 420), true),
      (Size(411, 420), true), // #190 뒤로 위아래 배치의 키가 더 크다
      (Size(360, 300), false),
      (Size(568, 320), false),
      (Size(640, 360), false),
    ]) {
      testWidgets('작은 창 ${size.width}×${size.height}: '
          '${stacked ? '안내 글이 있어도' : '가로형(#38, #142)에서'} 첫 선택지가 스크롤 없이 눌린다', (
        tester,
      ) async {
        final container = await _pump(tester, size: size);
        expect(tester.takeException(), isNull);
        expect(
          drawnArrangementOf(tester),
          stacked ? DrawnArrangement.stacked : DrawnArrangement.landscape,
        );
        // 첫 선택지(오른손잡이)를 눌러 바뀌는지 보려고 왼손잡이로 시작한다.
        container.read(handednessProvider.notifier).set(Handedness.left);
        await tester.pump();
        await _open(tester);
        expect(
          find.byKey(HandednessDialog.noteKey),
          stacked ? findsOneWidget : findsNothing,
        );
        final first = Handedness.values.first;
        await tester.tap(find.byKey(HandednessDialog.optionKeyOf(first)));
        await tester.pumpAndSettle();
        expect(container.read(handednessProvider), first);
      });
    }

    testWidgets(
      '세로 접힘선 배치를 한쪽 손잡이로만 쓸 수 있는 화면: 안내 글을 보이지 않고, 대화상자를 좁은 절반에 가두지 않는다 (#41 R1·R2)',
      (tester) async {
        // 세로 접힘선 x=654, 오른쪽 인셋 48 → 오른쪽 손 쪽 패널은 123dp뿐이다(키 13.9dp — 쓸 수 있는 크기 16dp 미만, #143).
        // - 오른손잡이: 키패드가 오른쪽 절반에 들어가지 못해 위아래 배치로 대체한다. ON 키는 키패드 오른쪽 위(접힘선 오른쪽).
        // - 왼손잡이: 키패드가 넓은 왼쪽 절반에 들어가 접힘선 기준 배치가 된다 — 그래서 손잡이 설정이 이 화면에
        //   적용된다(위아래 배치로 그렸어도 안내 글을 보이면 안 된다).
        const fold = DisplayFeature(
          bounds: Rect.fromLTWH(654, 0, 0, 701),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureFlat,
        );
        const padding = EdgeInsets.only(top: 24, right: 48, bottom: 24);
        tester.view.padding = const FakeViewPadding(
          top: 24 * 3,
          right: 48 * 3,
          bottom: 24 * 3,
        );
        addTearDown(tester.view.resetPadding);
        final container = await _pump(
          tester,
          size: const Size(841, 701),
          padding: padding,
          displayFeatures: const [fold],
        );
        expect(isStackedArrangement(tester), isTrue);
        expect(
          tester.getRect(_onKey).center.dx,
          greaterThan(654),
        ); // 대화상자 기준점(ON 키 중심)이 좁은 절반
        await _open(tester);
        Rect surface() => tester.getRect(_surface);
        expect(surface().width, greaterThanOrEqualTo(280));
        expect(surface().left, lessThan(654)); // 접힘선 오른쪽 좁은 절반에 갇히지 않았다
        expect(find.byKey(HandednessDialog.noteKey), findsNothing);

        // 왼손잡이를 고르면 접힘선 기준 배치가 된다. 반대 손잡이로는 위아래 배치라 대화상자는 화면 전체에 그대로 둔다.
        await tester.tap(
          find.byKey(HandednessDialog.optionKeyOf(Handedness.left)),
        );
        await tester.pumpAndSettle();
        expect(container.read(handednessProvider), Handedness.left);
        expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
        expect(_dialog, findsOneWidget);
        expect(surface().width, greaterThanOrEqualTo(280));
        // 화면 전체(인셋 안) 가운데 그대로 — 왼쪽 절반에 가뒀다면 가운데가 접힘선 왼쪽 절반(0~654)의 가운데 327이다.
        expect(surface().center.dx, moreOrLessEquals((841 - 48) / 2));
        expect(find.byKey(HandednessDialog.noteKey), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

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
    testWidgets('ON 키는 "Settings" 버튼으로 읽히고, SETUP 인쇄·없어진 설정 버튼은 따로 읽히지 않는다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, size: phone, padding: phoneInsets);
      expect(
        tester.getSemantics(_onButton),
        isSemantics(label: 'Settings', isButton: true, hasTapAction: true),
      );
      expect(find.bySemanticsLabel('Settings'), findsOneWidget);
      expect(find.bySemanticsLabel('SETUP'), findsNothing);
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
