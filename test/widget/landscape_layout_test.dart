import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/calc_semantic_strings.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/history_panel.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/settings_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bundled_fonts.dart';
import '../support/korean_locale.dart';
import '../support/screen_arrangement.dart';

/// 가로형 배치 (#142) — 아래 넓은 키패드 배열, 위 띠에 활성 LCD(숫자부 위)와 계산 기록(함수부 위).
/// 규칙은 `CalcTheme` "가로형 배치" 절, 배치 계산은 [CalcLandscapeLayout].

final _lcd = find.byType(LcdDisplay);
final _keypad = find.byKey(const ValueKey('calc-keypad'));
final _settings = find.byKey(SettingsButton.buttonKey);
final _history = find.byKey(HistoryPanel.panelKey);

/// [size] 창·[padding] 인셋으로 [CalculatorScreen]을 띄운다.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required Size size,
  EdgeInsets padding = EdgeInsets.zero,
  double textScale = 1.0,
  Handedness handedness = Handedness.right,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({
    HandednessNotifier.storageKey: handedness.storageValue,
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: padding,
            viewPadding: padding,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const CalculatorScreen(),
        ),
      ),
    ),
  );
  return container;
}

/// 창·인셋에서 본체 영역 (화면 좌표)
Rect _bodyRectOf(Size window, EdgeInsets padding) => Rect.fromLTRB(
  padding.left + CalcTheme.screenPadding,
  padding.top + CalcTheme.screenPadding,
  window.width - padding.right - CalcTheme.screenPadding,
  window.height - padding.bottom - CalcTheme.screenPadding,
);

Rect _keyRect(WidgetTester tester, CalcKeyId id) =>
    tester.getRect(find.byKey(CalcKeyButton.keycapKeyOf(id)));

void main() {
  group('가로형 배치: 화면 크기 × 손잡이', () {
    // 가로로 넓은 창 (Android 태블릿: 상태 표시줄 24·작업 표시줄 48, iPad: 상태 표시줄 24·홈 표시줄 20)
    const windows = [
      (Size(1280, 800), EdgeInsets.only(top: 24, bottom: 48)),
      (Size(960, 600), EdgeInsets.only(top: 24, bottom: 48)),
      (Size(1024, 768), EdgeInsets.only(top: 24, bottom: 20)),
      (Size(1194, 834), EdgeInsets.only(top: 24, bottom: 20)),
      (Size(1366, 1024), EdgeInsets.only(top: 24, bottom: 20)),
      (Size(2000, 1400), EdgeInsets.zero),
      (Size(1280, 500), EdgeInsets.zero), // 낮은 데스크톱 창 — 위 띠 132dp, 기록 있음
      // 가로 화면 좌우 인셋 (카메라 컷아웃·측면 내비게이션 바)
      (Size(1280, 800), EdgeInsets.only(left: 32, top: 24, right: 48)),
    ];

    for (final (size, padding) in windows) {
      for (final handedness in Handedness.values) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            '${size.width}×${size.height}·${handedness.name}·배율 $scale'
            '${padding.horizontal > 0 ? '·좌우 인셋' : ''}',
            (tester) async {
              await _pump(
                tester,
                size: size,
                padding: padding,
                textScale: scale,
                handedness: handedness,
              );
              expect(tester.takeException(), isNull);
              expect(find.byType(CalcKeyButton), findsNWidgets(totalKeyCount));
              expect(drawnArrangementOf(tester), DrawnArrangement.landscape);

              final body = _bodyRectOf(size, padding);
              final lcd = tester.getRect(_lcd);
              final keypad = tester.getRect(_keypad);
              final settings = tester.getRect(_settings);
              final keypadWidget = tester.widget<CalcKeypad>(
                find.byType(CalcKeypad),
              );

              // 키패드: 넓은 배열, 본체 폭 전체·본체 아래, 세로 한계 이하 (키가 세로로 길어지지 않는다)
              expect(keypadWidget.arrangement, KeypadArrangement.wide);
              expect(keypadWidget.numbersOnLeft, !handedness.keypadOnRight);
              expect(keypad.left, moreOrLessEquals(body.left));
              expect(keypad.right, moreOrLessEquals(body.right));
              expect(keypad.bottom, moreOrLessEquals(body.bottom));
              expect(
                keypad.height,
                lessThanOrEqualTo(
                  KeypadMetrics.fitSize(
                        Size(keypad.width, double.infinity),
                        KeypadArrangement.wide,
                      ).height +
                      0.01,
                ),
              );
              // 숫자부는 주로 쓰는 손 쪽 블록이다.
              final number = _keyRect(tester, CalcKeyId.num7);
              final function = _keyRect(tester, CalcKeyId.sin);
              expect(
                handedness.keypadOnRight
                    ? number.left > function.right
                    : number.right < function.left,
                isTrue,
              );

              // 위 띠: 활성 LCD는 키패드 바로 위(간격 8)이고, 기록 영역이 있으면 숫자부 블록 폭으로 손 쪽에 붙는다.
              expect(
                keypad.top - lcd.bottom,
                moreOrLessEquals(CalcTheme.screenLcdKeypadGap),
              );
              expect(_history, findsOneWidget);
              final history = tester.getRect(_history);
              final block = KeypadMetrics.wideBlockWidthOf(body.width);
              expect(lcd.width, moreOrLessEquals(block));
              expect(history.width, moreOrLessEquals(block));
              expect(history.top, moreOrLessEquals(lcd.top));
              expect(history.height, moreOrLessEquals(lcd.height));
              if (handedness.keypadOnRight) {
                expect(lcd.right, moreOrLessEquals(body.right));
                expect(history.left, moreOrLessEquals(body.left));
              } else {
                expect(lcd.left, moreOrLessEquals(body.left));
                expect(history.right, moreOrLessEquals(body.right));
              }
              // 기록 영역과 활성 LCD 사이는 키패드 블록 사이 간격과 같다.
              expect(
                (handedness.keypadOnRight
                        ? lcd.left - history.right
                        : history.left - lcd.right)
                    .abs(),
                moreOrLessEquals(body.width - 2 * block),
              );
              expect(
                lcd.height,
                lessThanOrEqualTo(
                  block / CalcTheme.screenLcdMinAspectRatio + 0.01,
                ),
              );
              expect(
                lcd.height,
                greaterThanOrEqualTo(CalcTheme.screenLandscapeHistoryMinHeight),
              );

              // 설정 버튼: 상단 띠의 오른쪽 끝(손잡이와 무관), 48dp, 눌리고 키패드와 겹치지 않는다.
              expect(settings.right, moreOrLessEquals(body.right));
              expect(settings.top, lessThan(lcd.top));
              expect(
                settings.width,
                moreOrLessEquals(CalcTheme.settingsButtonSize),
              );
              expect(settings.overlaps(keypad), isFalse);
              expect(_settings.hitTestable(), findsOneWidget);
            },
          );
        }
      }
    }
  });

  group('기록 영역이 없는 가로형 (#142)', () {
    for (final (size, padding) in const [
      (Size(1280, 400), EdgeInsets.zero), // 위 띠 112dp(LCD 최소 높이)
      (Size(844, 390), EdgeInsets.only(left: 47, right: 47, bottom: 21)),
      (Size(932, 430), EdgeInsets.only(left: 59, right: 59, bottom: 21)),
    ]) {
      testWidgets(
        '${size.width}×${size.height}: 활성 LCD가 띠 폭 전체를 쓰고 기록 영역은 없다',
        (tester) async {
          await _pump(
            tester,
            size: size,
            padding: padding,
            handedness: Handedness.left,
          );
          expect(tester.takeException(), isNull);
          expect(drawnArrangementOf(tester), DrawnArrangement.landscape);
          final body = _bodyRectOf(size, padding);
          final lcd = tester.getRect(_lcd);
          expect(lcd.left, moreOrLessEquals(body.left));
          expect(lcd.right, moreOrLessEquals(body.right));
          expect(
            lcd.height,
            lessThan(CalcTheme.screenLandscapeHistoryMinHeight),
          );
          expect(_history, findsNothing);
          // 숨긴 기록 영역은 스크린리더에도 없다.
          final handle = tester.ensureSemantics();
          await tester.pump();
          expect(
            find.bySemanticsLabel(const EnSemanticStrings().historyEmpty),
            findsNothing,
          );
          handle.dispose();
        },
      );
    }
  });

  testWidgets('태블릿 가로: 상단 띠가 내용 줄 전체 높이까지 늘어 설정 버튼이 LCD·기록 영역에 겹치지 않는다', (
    tester,
  ) async {
    // 10인치 Android 1280×800: LCD가 목표 높이보다 커진 몫(282.9 → 196)에서 띠를 줄 전체 높이(본체 안 40dp)까지 늘린다.
    const size = Size(1280, 800);
    const padding = EdgeInsets.only(top: 24, bottom: 48);
    await _pump(tester, size: size, padding: padding);
    final body = _bodyRectOf(size, padding);
    final lcd = tester.getRect(_lcd);
    expect(
      lcd.top - body.top,
      moreOrLessEquals(
        CalcTheme.topStripRowMaxHeight - CalcTheme.screenPadding,
      ),
    );
    final settings = tester.getRect(_settings);
    expect(settings.bottom, lessThanOrEqualTo(lcd.top + 0.01));
    expect(settings.overlaps(tester.getRect(_history)), isFalse);
  });

  testWidgets('한국어 기기: 빈 기록 영역은 "계산 기록 없음"으로 읽힌다', (tester) async {
    useKoreanLocale(tester);
    final handle = tester.ensureSemantics();
    await _pump(tester, size: const Size(1280, 800));
    expect(
      tester.getSemantics(_history),
      isSemantics(label: const KoSemanticStrings().historyEmpty),
    );
    handle.dispose();
  });

  for (final handedness in Handedness.values) {
    testWidgets(
      '스크린리더 읽기 순서: 활성 LCD → 기록 → 키패드(함수부 → 숫자부) → 설정 버튼 (${handedness.name})',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          size: const Size(1280, 800),
          handedness: handedness,
        );
        final order = <int>[];
        void visit(SemanticsNode node) {
          order.add(node.id);
          for (final child in node.debugListChildrenInOrder(
            DebugSemanticsDumpOrder.traversalOrder,
          )) {
            visit(child);
          }
        }

        final root = tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!;
        visit(root);
        int indexOf(Finder f) {
          final i = order.indexOf(tester.getSemantics(f).id);
          expect(i, isNonNegative, reason: '$f');
          return i;
        }

        final lcd = indexOf(_lcd);
        final history = indexOf(_history);
        final function = indexOf(
          find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.sin)),
        );
        final number = indexOf(
          find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.num7)),
        );
        final settings = indexOf(_settings);
        expect(lcd, lessThan(history));
        expect(history, lessThan(function));
        expect(function, lessThan(number));
        expect(number, lessThan(settings));
        handle.dispose();
      },
    );
  }

  group('CalcLandscapeLayout', () {
    test('10인치 Android 가로(본체 1264×712) 오른손잡이 배치 고정값', () {
      final l = CalcLandscapeLayout.of(const Size(1264, 712), Handedness.right);
      const block = 1264 / 2.06;
      const keypadHeight = block / 1.5; // 넓은 배열 세로 한계 409.1
      // LCD: 남는 높이 692 − 409.1 = 282.9(최대 높이 350.6 이하) → 목표 196을 넘는 몫에서 띠를 28dp 늘린다.
      const lcdHeight = 712 - 12 - 8 - keypadHeight - 28;
      expect(l.top, moreOrLessEquals(40));
      expect(
        l.lcd,
        rectMoreOrLessEquals(
          const Rect.fromLTWH(1264 - block, 40, block, lcdHeight),
        ),
      );
      expect(
        l.history,
        rectMoreOrLessEquals(const Rect.fromLTWH(0, 40, block, lcdHeight)),
      );
      expect(
        l.keypad,
        rectMoreOrLessEquals(
          const Rect.fromLTWH(0, 712 - keypadHeight, 1264, keypadHeight),
        ),
      );
      expect(l.numbersOnLeft, isFalse);
      expect(
        l.band,
        rectMoreOrLessEquals(Rect.fromLTWH(0, 40, 1264, lcdHeight)),
      );
    });

    test('모든 영역은 본체 안에 있고 서로 겹치지 않으며, 높이 합계가 본체 높이와 같다', () {
      for (final body in const [
        Size(1264, 712),
        Size(1350, 964),
        Size(1984, 1384),
        Size(734, 353),
        Size(395, 380),
        Size(304, 184),
        Size(40, 40),
        Size(0, 0),
      ]) {
        for (final h in Handedness.values) {
          final l = CalcLandscapeLayout.of(body, h);
          final bounds = (Offset.zero & body).inflate(0.01);
          final rects = [l.lcd, l.keypad, ?l.history];
          for (final r in rects) {
            expect(r.width, greaterThanOrEqualTo(0), reason: '$body $h $l');
            expect(r.height, greaterThanOrEqualTo(0), reason: '$body $h $l');
            expect(
              bounds.contains(r.topLeft) && bounds.contains(r.bottomRight),
              isTrue,
              reason: '$body $h $l',
            );
          }
          expect(l.lcd.overlaps(l.keypad), isFalse, reason: '$body $h $l');
          final history = l.history;
          if (history != null) {
            expect(history.overlaps(l.lcd), isFalse, reason: '$body $h $l');
            expect(history.overlaps(l.keypad), isFalse, reason: '$body $h $l');
          }
          expect(l.top, greaterThanOrEqualTo(0));
          expect(l.keypad.bottom, moreOrLessEquals(body.height));
        }
      }
    });

    test('왼손잡이 배치는 오른손잡이 배치의 좌우 대칭이다', () {
      for (final body in const [
        Size(1264, 712),
        Size(1350, 964),
        Size(734, 353),
      ]) {
        final r = CalcLandscapeLayout.of(body, Handedness.right);
        final l = CalcLandscapeLayout.of(body, Handedness.left);
        Rect mirror(Rect x) => Rect.fromLTRB(
          body.width - x.right,
          x.top,
          body.width - x.left,
          x.bottom,
        );
        expect(l.lcd, rectMoreOrLessEquals(mirror(r.lcd)), reason: '$body');
        expect(l.keypad, rectMoreOrLessEquals(mirror(r.keypad)));
        expect(l.history == null, r.history == null);
        if (r.history != null) {
          expect(l.history, rectMoreOrLessEquals(mirror(r.history!)));
        }
        expect(l.top, r.top);
      }
    });

    test('본체 높이를 늘릴 때 키·LCD·띠가 줄지 않고, 기록 영역이 생기는 경계에서도 높이가 튀지 않는다', () {
      for (final width in const [1264.0, 984.0, 640.0, 395.0]) {
        CalcLandscapeLayout? previous;
        var sawHistoryAppear = false;
        for (var height = 150.0; height <= 1000; height += 0.5) {
          final l = CalcLandscapeLayout.of(
            Size(width, height),
            Handedness.right,
          );
          final p = previous;
          if (p != null) {
            final reason = '$width×$height $p → $l';
            expect(
              l.keypad.height,
              greaterThanOrEqualTo(p.keypad.height - 1e-6),
              reason: reason,
            );
            expect(
              l.lcd.height,
              greaterThanOrEqualTo(p.lcd.height - 1e-6),
              reason: reason,
            );
            // 높이 0.5dp에 LCD·띠는 0.5dp보다 많이 바뀌지 않는다(연속).
            expect(
              (l.lcd.height - p.lcd.height).abs(),
              lessThanOrEqualTo(0.5 + 1e-6),
              reason: reason,
            );
            expect(
              (l.top - p.top).abs(),
              lessThanOrEqualTo(0.5 + 1e-6),
              reason: reason,
            );
            if (p.history == null && l.history != null) {
              sawHistoryAppear = true;
            }
          }
          previous = l;
        }
        // 넓은 창은 기록 영역이 생기는 경계를 지난다.
        if (width >= 640) expect(sawHistoryAppear, isTrue, reason: '$width');
      }
    });

    test('기록 영역 문턱: 위 띠가 문턱 이상이면 기록이 있고, 블록이 좁아 위 띠가 문턱에 닿지 않는 창에는 없다', () {
      for (var height = 150.0; height <= 1000; height += 7) {
        for (final width in const [1264.0, 984.0, 640.0, 461.0, 395.0]) {
          final l = CalcLandscapeLayout.of(
            Size(width, height),
            Handedness.right,
          );
          if (l.history != null) {
            expect(
              l.lcd.height,
              greaterThanOrEqualTo(CalcTheme.screenLandscapeHistoryMinHeight),
              reason: '$width×$height $l',
            );
          } else if (width >= 462) {
            // 블록이 224dp 이상이면 기록이 없을 때 LCD가 최대 높이에 걸리지 않아, 블록 폭으로 나눈 값과 같고 문턱 아래다.
            expect(
              l.lcd.height,
              lessThan(CalcTheme.screenLandscapeHistoryMinHeight),
              reason: '$width×$height $l',
            );
          }
        }
      }
      // 블록 224dp 미만(본체 폭 약 461dp 미만)은 LCD 최대 높이가 문턱 아래라 어떤 높이에서도 기록이 없다.
      for (var height = 150.0; height <= 2000; height += 10) {
        expect(
          CalcLandscapeLayout.of(Size(440, height), Handedness.right).history,
          isNull,
        );
      }
    });

    test('음수·비유한 크기는 0으로 본다', () {
      for (final body in const [
        Size(double.nan, double.nan),
        Size(-10, -10),
        Size(double.infinity, 500),
      ]) {
        final l = CalcLandscapeLayout.of(body, Handedness.right);
        for (final r in [l.lcd, l.keypad, ?l.history]) {
          expect(
            [
              r.left,
              r.top,
              r.width,
              r.height,
            ].every((v) => v.isFinite && v >= 0),
            isTrue,
            reason: '$body $l',
          );
        }
      }
    });
  });

  // 실제 번들 글꼴로 키 각인 크기를 잰다. 글꼴 등록은 이후 테스트에도 남으므로 파일 맨 끝 그룹에 둔다.
  group('태블릿 가로: 실제 글꼴 기준 LCD 줄 글자', () {
    setUpAll(loadBundledFonts);

    testWidgets('12.9인치 iPad 가로: 활성 LCD 줄 글자는 키 메인 각인보다 크다', (tester) async {
      await _pump(
        tester,
        size: const Size(1366, 1024),
        padding: const EdgeInsets.only(top: 24, bottom: 20),
      );
      final lineFont = tester
          .widget<DefaultTextStyle>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('lcd-input-text')),
                  matching: find.byType(DefaultTextStyle),
                )
                .first,
          )
          .style
          .fontSize!;
      final keyFont = tester
          .widgetList<CalcKeyButton>(find.byType(CalcKeyButton))
          .first
          .mainLabelFontSize!;
      // 활성 LCD 655×374.5(블록 폭의 최대 높이) — 줄 글자 약 54.7dp. 키 메인 각인은 상한 16.5dp.
      expect(keyFont, moreOrLessEquals(CalcTheme.keyMainLabelMaxFontSize));
      expect(lineFont, greaterThan(keyFont));
      expect(
        lineFont,
        moreOrLessEquals(
          LcdFontSizes.forSize(
            tester.getSize(_lcd),
            TextScaler.noScaling,
          ).input,
          epsilon: 0.5,
        ),
      );
    });
  });
}
