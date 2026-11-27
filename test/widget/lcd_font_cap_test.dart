import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/history_panel.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bundled_fonts.dart';

/// 큰 창의 LCD 줄 글자 상한 (#189, 사용자 결정 "글자 + LCD 높이 상한, 40dp") — 기준은 `CalcTheme.lcdLineMaxFontSize`와
/// "화면 배치"·"가로형 배치" 절.
/// - 줄 글자는 [CalcTheme.lcdLineMaxFontSize]를 넘지 않는다.
/// - LCD 높이는 줄 글자 상한 높이([LcdFontSizes.heightAtMaxLineFont])까지만이다(LCD 최소 높이가 더 높으면 최소 높이).
/// - 남는 높이: 세로형은 키패드(세로 한계까지, 그 위는 LCD 위 빈 곳 — #190), 가로형은 위 띠 높이 그대로 — 기록 영역이 위 띠
///   전체를 쓰고 활성 LCD는 키패드 바로 위에 붙는다.

final _lcd = find.byType(LcdDisplay);
final _keypad = find.byKey(const ValueKey('calc-keypad'));
final _history = find.byKey(HistoryPanel.panelKey);

const double _cap = CalcTheme.lcdLineMaxFontSize;

/// 배치가 쓰는 LCD 높이 상한 — 줄 글자 상한 높이와 LCD 최소 높이 중 높은 쪽
final double _lcdHeightLimit = math.max(
  CalcTheme.screenLcdMinHeight,
  LcdFontSizes.heightAtMaxLineFont,
);

double _lineFontOf(Size lcd) =>
    LcdFontSizes.forSize(lcd, TextScaler.noScaling).input;

/// [size] 창·[padding] 인셋으로 [CalculatorScreen]을 띄운다.
Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  EdgeInsets padding = EdgeInsets.zero,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({});
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
}

void main() {
  group('배치 계산: LCD 높이·줄 글자 상한', () {
    test('세로형: 어떤 본체에서도 LCD는 상한 높이 이하이고 줄 글자는 상한 이하다', () {
      for (var width = 280.0; width <= 2400; width += 37) {
        for (var height = 300.0; height <= 4000; height += 53) {
          final body = Size(width, height);
          final l = CalcScreenLayout.of(body);
          final reason = '$body $l';
          expect(
            l.lcdHeight,
            lessThanOrEqualTo(_lcdHeightLimit + 1e-9),
            reason: reason,
          );
          expect(
            _lineFontOf(Size(width, l.lcdHeight)),
            lessThanOrEqualTo(_cap),
            reason: reason,
          );
          expect(
            l.top + l.lcdHeight + l.gap + l.keypadHeight,
            moreOrLessEquals(height),
            reason: reason,
          );
        }
      }
    });

    test(
      '세로형: LCD가 상한 높이에서 멈춘 몫은 키패드가 세로 한계까지 받고, 그 위는 LCD 위 빈 곳이다 (#190)',
      () {
        // 10인치 Android 세로 본체 784×1192 — #189 전 LCD 330.4·키패드 813.6.
        final tablet = CalcScreenLayout.of(const Size(784, 1192));
        expect(
          tablet.lcdHeight,
          moreOrLessEquals(LcdFontSizes.heightAtMaxLineFont),
        );
        expect(tablet.keypadHeight, moreOrLessEquals(1192 - 8 - 273.52));
        expect(tablet.top, 0);
        expect(_lineFontOf(Size(784, tablet.lcdHeight)), _cap);
        // 세로 창 2160×3800 (본체 2144×3784): 키패드가 세로 한계(폭 / 0.75)에 닿아 나머지는 LCD 위 빈 곳이 된다.
        const tall = Size(2144, 3784);
        final l = CalcScreenLayout.of(tall);
        expect(l.lcdHeight, moreOrLessEquals(LcdFontSizes.heightAtMaxLineFont));
        expect(
          l.keypadHeight,
          moreOrLessEquals(2144 / CalcTheme.keypadMinAspectRatio),
        );
        expect(
          l.top,
          moreOrLessEquals(
            3784 - l.keypadHeight - l.lcdHeight - CalcTheme.screenLcdKeypadGap,
          ),
        );
        // 폰(폭 424dp 이하)은 줄 글자가 폭에 묶여 상한에 닿지 않는다. 키패드가 세로 한계에 닿아 남는 높이는 LCD가 상한 높이까지
        // 받고(#190 — 폭 기준 최대 높이를 넘는다), 그보다 남으면 LCD 위가 빈다.
        for (final width in const [304.0, 374.0, 424.0]) {
          final phone = CalcScreenLayout.of(Size(width, 2000));
          expect(
            phone.lcdHeight,
            moreOrLessEquals(LcdFontSizes.heightAtMaxLineFont),
          );
          expect(phone.top, greaterThan(0));
          expect(_lineFontOf(Size(width, phone.lcdHeight)), lessThan(_cap));
        }
        expect(
          _lineFontOf(
            Size(752, CalcScreenLayout.of(const Size(752, 964)).lcdHeight),
          ),
          // #190 전(상단 띠 12dp) 38.9dp — 띠가 빠져 LCD가 266.6 → 269.9dp로 높아졌다
          moreOrLessEquals(39.4, epsilon: 0.05),
        );
      },
    );

    test('세로형: 창 높이를 키워도 가장 낮은 키 셀이 줄지 않는다 — 폭 250~2600 (#188)', () {
      for (var width = 250.0; width <= 2600; width += 7) {
        double? previous;
        for (var height = 200.0; height <= 4000; height += 1) {
          final l = CalcScreenLayout.of(Size(width, height));
          final cell = KeypadMetrics.minKeyCellHeightOf(
            Size(width, l.keypadHeight),
            KeypadArrangement.standard,
          );
          final p = previous;
          if (p != null) {
            expect(
              cell,
              greaterThanOrEqualTo(p - 1e-9),
              reason: '$width×$height $l',
            );
          }
          previous = cell;
        }
      }
    });

    test('세로형: 창 폭을 넓혀도 가장 낮은 키 셀이 줄지 않는다 — 높이 200~4000 (#188의 원인 구간 포함)', () {
      // #189 전에는 본체 약 489~515 × 978~1024에서 LCD가 폭 기준 최대 높이(폭 / 1.75)까지 자라는 몫을 키패드가 내줘 키 셀이
      // 약 1.2% 줄었다(#188). LCD가 폭 478.7dp에서 상한 높이(273.5dp)에 닿아 멈추므로, 키패드가 실물 크기(640dp, 폭 480dp)를
      // 넘어 띠를 늘리는 구간에서는 LCD가 더 자라지 않는다.
      // #188이 요구한 높이 950~1100은 1dp 간격, 그 밖(200~4000)은 13dp 간격으로 훑는다.
      final heights = [
        for (var h = 950.0; h <= 1100; h += 1) h,
        for (var h = 200.0; h <= 4000; h += 13) h,
      ];
      for (final height in heights) {
        double? previous;
        for (var width = 250.0; width <= 2600; width += 0.5) {
          final l = CalcScreenLayout.of(Size(width, height));
          final cell = KeypadMetrics.minKeyCellHeightOf(
            Size(width, l.keypadHeight),
            KeypadArrangement.standard,
          );
          final p = previous;
          if (p != null) {
            expect(
              cell,
              greaterThanOrEqualTo(p - 1e-9),
              reason: '$width×$height $l',
            );
          }
          previous = cell;
        }
      }
    });

    test('가로형: 활성 LCD는 상한 높이 이하로 위 띠 아래(키패드 바로 위)에 붙고, 기록 영역은 위 띠 전체다', () {
      for (var width = 300.0; width <= 4000; width += 41) {
        for (var height = 150.0; height <= 2400; height += 29) {
          final body = Size(width, height);
          for (final h in Handedness.values) {
            final l = CalcLandscapeLayout.of(body, h);
            final reason = '$body $h $l';
            expect(
              l.lcd.height,
              lessThanOrEqualTo(_lcdHeightLimit + 1e-9),
              reason: reason,
            );
            expect(
              _lineFontOf(l.lcd.size),
              lessThanOrEqualTo(_cap),
              reason: reason,
            );
            // 활성 LCD는 위 띠 안, 아래 끝은 위 띠 아래 끝(키패드 위 간격 바로 위)이다.
            expect(
              l.lcd.bottom,
              moreOrLessEquals(l.band.bottom),
              reason: reason,
            );
            expect(
              l.lcd.top,
              greaterThanOrEqualTo(l.band.top - 1e-9),
              reason: reason,
            );
            // 위 띠는 본체 윗변부터(#190) 키패드 윗변 − 간격까지다 — 줄 글자 상한 높이로는 줄이지 않는다.
            expect(
              l.keypad.top - l.band.bottom,
              moreOrLessEquals(CalcTheme.screenLcdKeypadGap),
              reason: reason,
            );
            expect(l.band.top, moreOrLessEquals(0), reason: reason);
            final history = l.history;
            if (history != null) {
              // 기록 영역은 활성 LCD 옆(겹치지 않음)에서 위 띠 윗변부터 활성 LCD 아래 끝까지이고, 활성 LCD보다 낮지 않다
              // (남는 높이를 기록 영역이 쓴다).
              expect(history.overlaps(l.lcd), isFalse, reason: reason);
              expect(history.top, moreOrLessEquals(l.band.top), reason: reason);
              expect(history.top, lessThanOrEqualTo(l.lcd.top + 1e-9));
              expect(
                history.bottom,
                moreOrLessEquals(l.lcd.bottom),
                reason: reason,
              );
            } else {
              expect(l.lcd.width, moreOrLessEquals(width), reason: reason);
            }
          }
        }
      }
    });

    test('가로형: 위 띠 높이는 상한과 무관하게 남는 높이를 받는다 (기록 영역이 쓴다)', () {
      // 데스크톱 창 2000×1400 (본체 1984×1384): 위 띠 733.9dp(#190 전 693.9 — 상단 띠 40dp가 빠졌다). #189 전 활성 LCD는 블록 폭의 실물 비율 높이
      // 963.1×550.3(줄 글자 82dp)이었고, 이제 상한 높이 273.5dp다.
      final l = CalcLandscapeLayout.of(
        const Size(1984, 1384),
        Handedness.right,
      );
      expect(l.history, isNotNull);
      expect(l.band.height, moreOrLessEquals(733.9, epsilon: 0.1));
      expect(l.history!.height, moreOrLessEquals(l.band.height));
      expect(l.lcd.height, moreOrLessEquals(LcdFontSizes.heightAtMaxLineFont));
      expect(l.lcd.width, moreOrLessEquals(963.1, epsilon: 0.1));
      expect(_lineFontOf(l.lcd.size), _cap);
      // 활성 LCD 위 빈 곳 = 위 띠 − 상한 높이
      expect(
        l.lcd.top - l.band.top,
        moreOrLessEquals(l.band.height - LcdFontSizes.heightAtMaxLineFont),
      );
    });

    test(
      '가로형 데스크톱 1000×800: 띠 폭 전체 LCD의 글자가 상한에 묶여 기록 영역이 생긴다 (#189 전에는 없었다)',
      () {
        // 본체 984×784: #189 전에는 띠 폭 전체 LCD 984×417.6의 글자 62.9dp의 0.7배(44dp)에 블록 폭 LCD(38.9dp)가 못 미쳐
        // 기록 영역이 없었다. 이제 띠 폭 전체 LCD 글자가 상한 40dp라 0.7배(28dp)를 넘는다.
        final l = CalcLandscapeLayout.of(
          const Size(984, 784),
          Handedness.right,
        );
        expect(l.history, isNotNull);
        // 위 띠는 본체 윗변부터 키패드 위까지다(#190 — 상단 띠 40dp를 더 받는다)
        expect(l.band.height, moreOrLessEquals(457.6, epsilon: 0.1));
        expect(
          l.lcd,
          rectMoreOrLessEquals(
            const Rect.fromLTRB(506.3, 184.6, 984, 457.6),
            epsilon: 0.1,
          ),
        );
        expect(_lineFontOf(l.lcd.size), moreOrLessEquals(38.9, epsilon: 0.05));
        expect(_lineFontOf(Size(984, l.band.height)), _cap);
      },
    );

    test('가로 접힘선 배치도 LCD 높이는 상한 높이 이하다 (#143 — 실물 배열·넓은 배열 모두)', () {
      for (var width = 300.0; width <= 2400; width += 61) {
        for (var height = 400.0; height <= 2000; height += 47) {
          final body = Size(width, height);
          final hinge = Rect.fromLTWH(0, height * 0.5, width, 0);
          for (final h in Handedness.values) {
            final l = CalcTabletopLayout.of(body, hinge, h);
            final reason = '$body $h $l';
            expect(
              l.lcd.height,
              lessThanOrEqualTo(_lcdHeightLimit + 1e-9),
              reason: reason,
            );
            expect(
              _lineFontOf(l.lcd.size),
              lessThanOrEqualTo(_cap),
              reason: reason,
            );
          }
        }
      }
      // 넓은 위 패널: 넓은 배열의 숫자부 블록 폭 활성 LCD가 상한 높이·상한 글자에 묶인다(#143 전에는 폭 상한 480dp로
      // 480×273.5, 줄 글자 39.1dp였다).
      final wide = CalcTabletopLayout.of(
        const Size(1600, 1200),
        const Rect.fromLTWH(0, 600, 1600, 0),
        Handedness.right,
      );
      expect(wide.keypadArrangement, KeypadArrangement.wide);
      expect(wide.history, isNotNull);
      expect(
        wide.lcd.width,
        moreOrLessEquals(KeypadMetrics.wideBlockWidthOf(1600)),
      );
      expect(
        wide.lcd.height,
        moreOrLessEquals(LcdFontSizes.heightAtMaxLineFont),
      );
      expect(_lineFontOf(wide.lcd.size), _cap);
    });

    test('세로 접힘선 배치(책 자세)도 LCD 높이는 상한 높이 이하다', () {
      for (var width = 400.0; width <= 2400; width += 61) {
        for (var height = 300.0; height <= 1600; height += 47) {
          final body = Size(width, height);
          final hinge = Rect.fromLTWH(width * 0.45, 0, 20, height);
          for (final h in Handedness.values) {
            final l = CalcHingeSplitLayout.of(body, hinge, h);
            final reason = '$body $h $l';
            expect(
              l.lcd.height,
              lessThanOrEqualTo(_lcdHeightLimit + 1e-9),
              reason: reason,
            );
            expect(
              _lineFontOf(l.lcd.size),
              lessThanOrEqualTo(_cap),
              reason: reason,
            );
          }
        }
      }
    });
  });

  // 실제 번들 글꼴로 그린 화면의 줄 글자와 키 각인을 잰다. 글꼴 등록은 이후 테스트에도 남으므로 파일 맨 끝 그룹에 둔다.
  group('큰 창: 그린 화면의 LCD 줄 글자', () {
    setUpAll(loadBundledFonts);

    /// 그려진 입력 줄 글자 크기 (배율 반영 전)
    double drawnLineFont(WidgetTester tester) => tester
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

    double keyFont(WidgetTester tester) => tester
        .widgetList<CalcKeyButton>(find.byType(CalcKeyButton))
        .first
        .mainLabelFontSize!;

    // (이름, 창, 인셋, 기록 영역 유무, #189 전 줄 글자) — 줄 글자는 모두 상한에 멈춘다.
    const windows = <(String, Size, EdgeInsets, bool, double)>[
      (
        '10인치 Android 세로',
        Size(800, 1280),
        EdgeInsets.only(top: 24, bottom: 48),
        false,
        49.0,
      ),
      (
        '12.9인치 iPad 세로',
        Size(1024, 1366),
        EdgeInsets.only(top: 24, bottom: 20),
        false,
        54.1,
      ),
      (
        '12.9인치 iPad 가로',
        Size(1366, 1024),
        EdgeInsets.only(top: 24, bottom: 20),
        true,
        54.7,
      ),
      ('데스크톱 2000×1400', Size(2000, 1400), EdgeInsets.zero, true, 82.0),
      ('4K 데스크톱 3840×2160', Size(3840, 2160), EdgeInsets.zero, true, 133.0),
      ('세로 창 2160×3800', Size(2160, 3800), EdgeInsets.zero, false, 164.5),
    ];

    for (final (name, size, padding, withHistory, before) in windows) {
      testWidgets('$name: 줄 글자는 상한(#189 전 ${before}dp → '
          '${_cap}dp)이고 LCD는 상한 높이, 키패드 바로 위다', (tester) async {
        await _pump(tester, size: size, padding: padding);
        expect(tester.takeException(), isNull);
        final lcd = tester.getRect(_lcd);
        final keypad = tester.getRect(_keypad);
        expect(drawnLineFont(tester), moreOrLessEquals(_cap, epsilon: 1e-6));
        expect(lcd.height, moreOrLessEquals(LcdFontSizes.heightAtMaxLineFont));
        expect(
          keypad.top - lcd.bottom,
          moreOrLessEquals(CalcTheme.screenLcdKeypadGap),
        );
        expect(_history.evaluate().isNotEmpty, withHistory);
        // 키 메인 각인은 상한(16.5dp)이고, 줄 글자는 그 약 2.4배에서 멈춘다(폰 390×844 약 2.3배).
        expect(
          keyFont(tester),
          moreOrLessEquals(CalcTheme.keyMainLabelMaxFontSize),
        );
        expect(drawnLineFont(tester) / keyFont(tester), lessThan(2.5));
      });
    }

    testWidgets(
      '폰 390×844는 상한에 닿지 않는다 (줄 글자 29.8dp — LCD는 상단 띠가 빠진 몫까지 받는다, #190)',
      (tester) async {
        await _pump(
          tester,
          size: const Size(390, 844),
          padding: const EdgeInsets.only(top: 47, bottom: 34),
        );
        expect(drawnLineFont(tester), moreOrLessEquals(29.8, epsilon: 0.05));
        // 키패드가 폭 기준 최대 높이(374 / 0.75)에 닿아 나머지 739 − 498.7 = 240.3을 LCD가 받는다(#189·#190 전 213.7 + 띠 26.6).
        expect(
          tester.getSize(_lcd).height,
          moreOrLessEquals(739 - 374 / 0.75, epsilon: 0.05),
        );
      },
    );
  });
}
