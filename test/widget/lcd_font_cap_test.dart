import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/release_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bundled_fonts.dart';
import '../support/ttf_cmap.dart';

/// 큰 창의 LCD 줄 글자 상한 (#189, 사용자 결정 "글자 + LCD 높이 상한, 40dp") — 기준은 `CalcTheme.lcdLineMaxFontSize`와
/// "화면 배치"·"가로형 배치" 절.
/// - 줄 글자는 [CalcTheme.lcdLineMaxFontSize]를 넘지 않는다.
/// - LCD가 목표로 가져가는 높이는 줄 글자 상한 높이([LcdFontSizes.heightAtMaxLineFont])까지다(LCD 최소 높이가 더 높으면 최소
///   높이) — 그보다 남는 높이는 키패드가 세로 한계까지 받는다(태블릿 세로).
/// - 키패드도 쓰지 못해 남는 높이는 LCD가 상한 높이를 넘어 모두 받는다(#232 — 전에는 LCD 위가 빈 곳이었다). 줄 글자는 상한
///   그대로이고 입력·결과 줄만 높아진다. 가로형·가로 접힘선은 LCD가 위 띠(위 패널) 전체다(#284).
/// - 계산기 화면의 줄 글자 상한은 40dp와 키 숫자 × [CalcTheme.lcdLineKeyNumberFontRatio] 중 큰 쪽이다(#270, 사용자 결정 "키 숫자
///   따라 올림" — [LcdFontSizes.lineMaxFontSizeFor]). 배치 계산(LCD 높이)은 40dp 기준 그대로다.

final _lcd = find.byType(LcdDisplay);
final _keypad = find.byKey(const ValueKey('calc-keypad'));

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
  Set<KeyFeature>? released,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (released != null)
        releasedKeyFeaturesProvider.overrideWithValue(released),
    ],
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
  group('키 숫자를 따르는 줄 글자 상한 (#270)', () {
    test('상한은 40dp와 키 숫자 × 비 중 큰 쪽이고, 키 숫자에 대해 줄지 않는다', () {
      const ratio = CalcTheme.lcdLineKeyNumberFontRatio;
      // 키 숫자가 40 / 0.62 ≈ 64.5dp 아래면 40dp 그대로다(폰·보통 태블릿).
      for (final digit in const [0.0, 10.0, 32.4, 60.3, 64.0]) {
        expect(LcdFontSizes.lineMaxFontSizeFor(digit), _cap, reason: '$digit');
      }
      for (final digit in const [65.0, 85.0, 170.7]) {
        expect(
          LcdFontSizes.lineMaxFontSizeFor(digit),
          moreOrLessEquals(digit * ratio),
          reason: '$digit',
        );
      }
      var previous = 0.0;
      for (var digit = 0.0; digit <= 400; digit += 0.7) {
        final cap = LcdFontSizes.lineMaxFontSizeFor(digit);
        expect(cap, greaterThanOrEqualTo(previous), reason: '$digit');
        expect(cap, greaterThanOrEqualTo(_cap), reason: '$digit');
        previous = cap;
      }
      // 키 숫자가 무한·NaN이면 기본 상한이다(유한한 값만 LCD에 넘긴다).
      expect(LcdFontSizes.lineMaxFontSizeFor(double.infinity), _cap);
      expect(LcdFontSizes.lineMaxFontSizeFor(double.nan), _cap);
    });

    test('올린 상한은 상한일 뿐이다 — LCD가 담을 수 있는 크기를 넘지 않고, 기본 상한에 묶인 LCD만 더 커진다', () {
      for (final size in const [
        Size(374, 321.3), // 폰 — 폭에 묶인다
        Size(784, 273.52), // 태블릿 세로 — 높이에 묶인다
        Size(1904, 559.8), // 1920×1200 가로 — 기본 상한에 묶인다
        Size(3824, 898.5),
      ]) {
        final base = LcdFontSizes.forSize(size, TextScaler.noScaling).input;
        for (final cap in const [40.0, 52.7, 80.0, 200.0]) {
          final raised = LcdFontSizes.forSize(
            size,
            TextScaler.noScaling,
            maxLineFontSize: cap,
          ).input;
          expect(raised, lessThanOrEqualTo(cap + 1e-9), reason: '$size $cap');
          expect(
            raised,
            // 글자 크기 탐색(`fitFontSize`)은 시작값에 따라 1e-3 안에서 다를 수 있다.
            greaterThanOrEqualTo(base - 1e-3),
            reason: '$size $cap',
          );
          // 기본 상한보다 작은 글자(폭·높이에 묶인 LCD)는 상한을 올려도 그대로다.
          if (base < _cap - 0.01) {
            expect(
              raised,
              moreOrLessEquals(base, epsilon: 1e-3),
              reason: '$size $cap',
            );
          }
        }
      }
      // 1920×1200 가로의 LCD는 올린 상한 52.7dp까지 커진다.
      expect(
        LcdFontSizes.forSize(
          const Size(1904, 559.8),
          TextScaler.noScaling,
          maxLineFontSize: 52.7,
        ).input,
        moreOrLessEquals(52.7),
      );
    });

    test(
      '비는 실물 잉크 비(LCD 글자 M ÷ 키 숫자 7·8 ≈ 15 / 23.5)를 번들 글꼴의 글자 크기 비로 바꾼 값이다',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        // 줄 글자는 Noto Sans Mono Medium, 키 숫자는 Saira SemiBold다 — 굵기가 바뀌면 아래 글꼴 파일도 바꾼다.
        expect(CalcTheme.lcdInputStyle.fontWeight, FontWeight.w500);
        expect(CalcTheme.keyMainLabelStyle.fontWeight, FontWeight.w600);
        final mono = await rootBundle.load(
          'assets/fonts/NotoSansMono-Medium.ttf',
        );
        final saira = await rootBundle.load('assets/fonts/Saira-SemiBold.ttf');
        double ink(ByteData font, String ch) {
          final b = readGlyphYBounds(font, ch.runes.single)!;
          return b.yMax - b.yMin;
        }

        final lcdInk = ink(mono, 'M');
        final digitInk = (ink(saira, '7') + ink(saira, '8')) / 2;
        expect(
          CalcTheme.lcdLineKeyNumberFontRatio * lcdInk / digitInk,
          moreOrLessEquals(15 / 23.5, epsilon: 0.005),
        );
      },
    );
  });

  group('배치 계산: LCD 높이·줄 글자 상한', () {
    test(
      '세로형: 줄 글자는 상한 이하이고, LCD가 상한 높이를 넘는 것은 키패드가 세로 한계에 닿았을 때뿐이다 (#232)',
      () {
        for (var width = 280.0; width <= 2400; width += 37) {
          final keypadMax = KeypadMetrics.fitSize(Size(width, double.infinity))
              .height;
          for (var height = 300.0; height <= 4000; height += 53) {
            final body = Size(width, height);
            final l = CalcScreenLayout.of(body);
            final reason = '$body $l';
            if (l.lcdHeight > _lcdHeightLimit + 1e-9) {
              expect(
                l.keypadHeight,
                moreOrLessEquals(keypadMax),
                reason: reason,
              );
            }
            expect(
              _lineFontOf(Size(width, l.lcdHeight)),
              lessThanOrEqualTo(_cap),
              reason: reason,
            );
            // LCD 위에 빈 곳이 없다 — LCD·간격·키패드가 본체 높이를 다 쓴다.
            expect(
              l.lcdHeight + l.gap + l.keypadHeight,
              moreOrLessEquals(height),
              reason: reason,
            );
          }
        }
      },
    );

    test(
      '세로형: LCD가 상한 높이에서 멈춘 몫은 키패드가 세로 한계까지 받고, 그래도 남으면 LCD가 받는다 (#190, #232)',
      () {
        // 10인치 Android 세로 본체 784×1192 — #189 전 LCD 330.4·키패드 813.6.
        final tablet = CalcScreenLayout.of(const Size(784, 1192));
        expect(
          tablet.lcdHeight,
          moreOrLessEquals(LcdFontSizes.heightAtMaxLineFont),
        );
        expect(tablet.keypadHeight, moreOrLessEquals(1192 - 8 - 273.52));
        expect(_lineFontOf(Size(784, tablet.lcdHeight)), _cap);
        // 세로 창 2160×3800 (본체 2144×3784): 키패드가 세로 한계(폭 / 0.75)에 닿아 나머지를 모두 LCD가 받는다(#232 — 전에는
        // LCD 273.5 위가 빈 곳이었다). 줄 글자는 상한 그대로다.
        const tall = Size(2144, 3784);
        final l = CalcScreenLayout.of(tall);
        expect(
          l.keypadHeight,
          moreOrLessEquals(2144 / CalcTheme.keypadMinAspectRatio),
        );
        expect(
          l.lcdHeight,
          moreOrLessEquals(
            3784 - l.keypadHeight - CalcTheme.screenLcdKeypadGap,
          ),
        );
        expect(l.lcdHeight, greaterThan(LcdFontSizes.heightAtMaxLineFont));
        expect(_lineFontOf(Size(2144, l.lcdHeight)), _cap);
        // 폰(폭 424dp 이하)은 줄 글자가 폭에 묶여 상한에 닿지 않는다. 키패드가 세로 한계에 닿아 남는 높이는 LCD가 모두
        // 받는다(#190·#232 — 폭 기준 최대 높이·줄 글자 상한 높이를 넘는다).
        for (final width in const [304.0, 374.0, 424.0]) {
          final phone = CalcScreenLayout.of(Size(width, 2000));
          expect(
            phone.lcdHeight,
            moreOrLessEquals(
              2000 - phone.keypadHeight - CalcTheme.screenLcdKeypadGap,
            ),
          );
          expect(
            phone.lcdHeight,
            greaterThan(LcdFontSizes.heightAtMaxLineFont),
          );
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

    test('가로형: LCD는 위 띠 전체(본체 폭 전체)이고, 줄 글자는 상한 이하다 (#232, #284)', () {
      for (var width = 300.0; width <= 4000; width += 41) {
        for (var height = 150.0; height <= 2400; height += 29) {
          final body = Size(width, height);
          for (final h in Handedness.values) {
            final l = CalcLandscapeLayout.of(body, h);
            final reason = '$body $h $l';
            expect(
              _lineFontOf(l.lcd.size),
              lessThanOrEqualTo(_cap),
              reason: reason,
            );
            // LCD는 본체 윗변부터(#190) 키패드 윗변 − 간격까지다 — 위에 빈 곳이 없고, 줄 글자 상한 높이로는 줄이지 않는다.
            expect(l.lcd.top, moreOrLessEquals(0), reason: reason);
            expect(
              l.keypad.top - l.lcd.bottom,
              moreOrLessEquals(CalcTheme.screenLcdKeypadGap),
              reason: reason,
            );
            // 기록 영역 없이 본체 폭 전체다(#284).
            expect(l.lcd.width, moreOrLessEquals(width), reason: reason);
          }
        }
      }
    });

    test('가로형: LCD 높이는 상한과 무관하게 남는 높이를 받는다', () {
      // 데스크톱 창 2000×1400 (본체 1984×1384): LCD 1984×733.9dp(#190 전 위 띠 693.9 — 상단 띠 40dp가 빠졌다). #189 전 활성 LCD는
      // 블록 폭의 실물 비율 높이 963.1×550.3(줄 글자 82dp), #232 전에는 상한 높이 273.5dp(그 위 460.4dp가 빈 곳), #284 전에는 블록 폭
      // 963.1×733.9였다 — 줄 글자는 상한.
      final l = CalcLandscapeLayout.of(
        const Size(1984, 1384),
        Handedness.right,
      );
      expect(l.lcd.height, moreOrLessEquals(733.9, epsilon: 0.1));
      expect(l.lcd.top, moreOrLessEquals(0));
      expect(l.lcd.width, moreOrLessEquals(1984));
      expect(_lineFontOf(l.lcd.size), _cap);
    });

    test(
      '가로형 데스크톱 1000×800: LCD는 본체 폭 전체이고 줄 글자가 상한에 묶인다 (#284 전 블록 폭 38.9dp)',
      () {
        // 본체 984×784: #284 전에는 활성 LCD가 숫자부 블록 폭(477.7×457.6, 줄 글자 38.9dp)이고 함수부 위가 기록 영역이었다.
        final l = CalcLandscapeLayout.of(
          const Size(984, 784),
          Handedness.right,
        );
        expect(
          l.lcd,
          rectMoreOrLessEquals(
            // #232 전에는 위 184.6dp가 빈 곳이었다(활성 LCD 477.7×273.0).
            const Rect.fromLTRB(0, 0, 984, 457.6),
            epsilon: 0.1,
          ),
        );
        expect(_lineFontOf(l.lcd.size), _cap);
      },
    );

    test(
      '가로 접힘선 배치: 줄 글자는 상한 이하이고, LCD는 배열과 무관하게 위 패널 전체다 (#143, #232, #284)',
      () {
        for (var width = 300.0; width <= 2400; width += 61) {
          for (var height = 400.0; height <= 2000; height += 47) {
            final body = Size(width, height);
            final hinge = Rect.fromLTWH(0, height * 0.5, width, 0);
            final upperBottom = height * 0.5 - CalcTheme.screenHingeMargin;
            for (final h in Handedness.values) {
              final l = CalcTabletopLayout.of(body, hinge, h);
              final reason = '$body $h $l';
              expect(
                _lineFontOf(l.lcd.size),
                lessThanOrEqualTo(_cap),
                reason: reason,
              );
              expect(
                l.lcd,
                rectMoreOrLessEquals(Rect.fromLTRB(0, 0, width, upperBottom)),
                reason: reason,
              );
            }
          }
        }
        // 넓은 위 패널: LCD가 상한 글자에 묶이고 위 패널 전체다(#143 전에는 폭 상한 480dp로 480×273.5, 줄 글자 39.1dp였다. #232
        // 전에는 높이가 상한 높이 273.5였고, #284 전에는 숫자부 블록 폭이었다).
        final wide = CalcTabletopLayout.of(
          const Size(1600, 1200),
          const Rect.fromLTWH(0, 600, 1600, 0),
          Handedness.right,
        );
        expect(wide.keypadArrangement, KeypadArrangement.wide);
        expect(wide.lcd.width, moreOrLessEquals(1600));
        expect(
          wide.lcd.height,
          moreOrLessEquals(600 - CalcTheme.screenHingeMargin),
        );
        expect(_lineFontOf(wide.lcd.size), _cap);
      },
    );

    test('세로 접힘선 배치(책 자세): 줄 글자는 상한 이하이고, LCD는 본체 윗변부터 키패드 위 간격까지 남는 높이를 모두 받는다 (#232, #285)', () {
      var sawOccluding = 0;
      for (var width = 400.0; width <= 2400; width += 61) {
        for (var height = 200.0; height <= 1600; height += 23) {
          final body = Size(width, height);
          // 폭 0 접힘선과 폭 있는 물리 힌지(LCD가 숫자부 쪽 패널에만, #285)를 모두 본다
          for (final hingeWidth in const [0.0, 20.0]) {
            final hinge = Rect.fromLTWH(width * 0.45, 0, hingeWidth, height);
            for (final h in Handedness.values) {
              final l = CalcHingeSplitLayout.of(body, hinge, h);
              final reason = '$body 힌지 $hingeWidth $h $l';
              expect(l.lcd.top, moreOrLessEquals(0), reason: reason);
              expect(
                _lineFontOf(l.lcd.size),
                lessThanOrEqualTo(_cap),
                reason: reason,
              );
              // 가로형처럼 LCD 아래 간격 바로 밑이 키패드다 — LCD 위·아래에 빈 곳이 없다.
              expect(
                l.lcd.bottom + CalcTheme.screenLcdKeypadGap,
                moreOrLessEquals(l.keypad.top),
                reason: reason,
              );
              if (l.lcdOnNumberPanel) sawOccluding++;
            }
          }
        }
      }
      // 스윕이 물리 힌지 경우를 실제로 지나는지 확인한다.
      expect(sawOccluding, greaterThan(0));
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

    /// 그려진 키 숫자 글자 크기 (배율 반영 전 — 숫자 7 키)
    double digitFont(WidgetTester tester) => tester
        .widget<CalcKeyButton>(
          find.byWidgetPredicate(
            (w) => w is CalcKeyButton && w.keyDef.id == CalcKeyId.num7,
          ),
        )
        .mainLabelFontSize!;

    // (이름, 창, 인셋, #189 전 줄 글자, 지금 줄 글자) — 줄 글자는 LCD가 담을 수 있는 크기와 상한 중 작은 쪽이다. 상한은 40dp와
    // 키 숫자 × 0.62 중 큰 쪽이다(#270 — 키 숫자 64.5dp부터 올라간다). 12.9인치 iPad 세로는 상한이 41.3dp로 올라가지만 LCD가
    // 배치의 목표 높이(40dp 기준 273.5dp)에서 멈춰 40dp다. 기록 영역은 어느 창에도 없다(#284).
    const windows = <(String, Size, EdgeInsets, double, double)>[
      (
        '10인치 Android 세로',
        Size(800, 1280),
        EdgeInsets.only(top: 24, bottom: 48),
        49.0,
        40.0,
      ),
      (
        '12.9인치 iPad 세로',
        Size(1024, 1366),
        EdgeInsets.only(top: 24, bottom: 20),
        54.1,
        40.0,
      ),
      (
        '12.9인치 iPad 가로',
        Size(1366, 1024),
        EdgeInsets.only(top: 24, bottom: 20),
        54.7,
        40.0,
      ),
      ('데스크톱 2000×1400', Size(2000, 1400), EdgeInsets.zero, 82.0, 54.9),
      ('4K 데스크톱 3840×2160', Size(3840, 2160), EdgeInsets.zero, 133.0, 105.8),
      ('세로 창 2160×3800', Size(2160, 3800), EdgeInsets.zero, 164.5, 115.1),
    ];

    for (final (name, size, padding, before, now) in windows) {
      testWidgets(
        '$name: 줄 글자는 #189 전 ${before}dp → ${now}dp(상한 40dp 또는 키 숫자 따라, #270)이고 '
        'LCD는 본체 윗변부터 키패드 바로 위까지다',
        (tester) async {
          await _pump(tester, size: size, padding: padding);
          expect(tester.takeException(), isNull);
          final lcd = tester.getRect(_lcd);
          final keypad = tester.getRect(_keypad);
          final line = drawnLineFont(tester);
          final digit = digitFont(tester);
          final cap = LcdFontSizes.lineMaxFontSizeFor(digit);
          // 화면이 LCD에 넘긴 상한은 그린 키 숫자로 정한 값이다(#270 R1 — 키패드와 같은 크기·배열·배포 기능으로 잰다).
          expect(
            tester.widget<LcdDisplay>(_lcd).maxLineFontSize,
            moreOrLessEquals(cap, epsilon: 1e-9),
          );
          expect(line, moreOrLessEquals(now, epsilon: 0.05));
          // 화면은 그린 키패드의 키 숫자로 정한 상한을 LCD에 넘긴다.
          expect(
            line,
            moreOrLessEquals(
              LcdFontSizes.forSize(
                lcd.size,
                TextScaler.noScaling,
                maxLineFontSize: cap,
              ).input,
            ),
          );
          if (now > _cap) {
            // 키 숫자를 따라 올린 상한에 멈춘다 — LCD 글자 ÷ 키 숫자가 실물 비(글자 크기 비 0.62)다.
            expect(line, moreOrLessEquals(cap, epsilon: 1e-6));
            expect(
              line / digit,
              moreOrLessEquals(CalcTheme.lcdLineKeyNumberFontRatio),
            );
          } else {
            expect(line, lessThanOrEqualTo(cap + 1e-6));
          }
          // LCD는 상한 높이 이상이고(목표가 상한 높이에서 멈춘 태블릿 세로는 정확히 상한 높이), 위에 빈 곳이 없다(#232).
          expect(
            lcd.height,
            greaterThanOrEqualTo(LcdFontSizes.heightAtMaxLineFont - 1e-6),
          );
          expect(
            lcd.top,
            moreOrLessEquals(padding.top + CalcTheme.screenPadding),
          );
          expect(
            keypad.top - lcd.bottom,
            moreOrLessEquals(CalcTheme.screenLcdKeypadGap),
          );
          // 줄 글자는 키 메인 각인의 2.5배 아래에서 멈춘다. (#264 전에는 키 메인 각인도 상한 16.5dp에서 멈춰 약 2.4배였다 —
          // 지금 키 각인은 상한 없이 키 높이의 실물 비율이고, 줄 글자 상한도 큰 창에서 키 숫자를 따라 올라간다, #270.)
          expect(keyFont(tester), greaterThan(16.5));
          expect(drawnLineFont(tester) / keyFont(tester), lessThan(2.5));
        },
      );
    }

    testWidgets(
      '배포 기능을 바꿔 그린 키패드도 LCD 상한은 그 키패드의 키 숫자를 따른다 (#270 R1 — 화면이 같은 배포 기능으로 잰다)',
      (tester) async {
        // 실물 인쇄 전체(배포 뒤 각인 포함, #267)를 그린 4K 가로 창
        await _pump(
          tester,
          size: const Size(3840, 2160),
          released: KeyFeature.values.toSet(),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<LcdDisplay>(_lcd).maxLineFontSize,
          moreOrLessEquals(
            LcdFontSizes.lineMaxFontSizeFor(digitFont(tester)),
            epsilon: 1e-9,
          ),
        );
      },
    );

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
