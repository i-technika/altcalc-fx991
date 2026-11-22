import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:material_ui/material_ui.dart';

/// CIELAB 명도 L* (0 ~ 100) — 사람이 느끼는 밝기에 가까운 척도 (D65, sRGB 상대 휘도 기준)
double lightness(Color c) {
  final y = c.computeLuminance();
  const epsilon = 216 / 24389;
  const kappa = 24389 / 27;
  return y > epsilon ? 116 * math.pow(y, 1 / 3) - 16 : kappa * y;
}

/// WCAG 2.x 명암비 (1.0 ~ 21.0)
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const minTextContrast = 4.5; // WCAG AA 일반 텍스트 기준

  group('색상 대비 (WCAG AA)', () {
    test('모든 키캡 카테고리의 메인 라벨은 배경 대비 4.5:1 이상이다', () {
      for (final c in KeyCategory.values) {
        expect(
          contrastRatio(c.foreground, c.background),
          greaterThanOrEqualTo(minTextContrast),
          reason: c.name,
        );
      }
    });

    test('SHIFT/ALPHA 각인은 모든 본체 색 대비 4.5:1 이상이다', () {
      for (final body in [
        CalcTheme.bodyBackground,
        CalcTheme.bodyFrame,
        CalcTheme.bodyBottomGradient,
      ]) {
        for (final legend in [CalcTheme.shiftLabel, CalcTheme.alphaLabel]) {
          expect(
            contrastRatio(legend, body),
            greaterThanOrEqualTo(minTextContrast),
            reason: 'legend=$legend body=$body',
          );
        }
      }
    });

    test('키캡 테두리는 본체 배경 대비 3:1 이상이다 (비텍스트 대비)', () {
      expect(
        contrastRatio(CalcTheme.keyBorder, CalcTheme.bodyBackground),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('LCD 텍스트와 활성 상태 표시는 LCD 배경 대비 4.5:1 이상이다', () {
      expect(
        contrastRatio(CalcTheme.lcdText, CalcTheme.lcdBackground),
        greaterThanOrEqualTo(minTextContrast),
      );
      expect(
        contrastRatio(CalcTheme.lcdStatusActive, CalcTheme.lcdBackground),
        greaterThanOrEqualTo(minTextContrast),
      );
    });

    test('비활성 상태 표시는 활성 상태보다 LCD 배경과의 대비가 낮다', () {
      expect(
        contrastRatio(CalcTheme.lcdStatusInactive, CalcTheme.lcdBackground),
        lessThan(
          contrastRatio(CalcTheme.lcdStatusActive, CalcTheme.lcdBackground),
        ),
      );
    });
  });

  group('키 눌림 색 (#22)', () {
    test('CIELAB 명도 계산 기준점 (검정 0, 흰색 100, 중간 회색 #777777 약 50)', () {
      expect(lightness(const Color(0xFF000000)), closeTo(0, 1e-9));
      expect(lightness(const Color(0xFFFFFFFF)), closeTo(100, 1e-6));
      expect(lightness(const Color(0xFF777777)), closeTo(50.0, 0.5));
    });

    test('모든 카테고리: 눌림 전후 명도 차가 하한 이상이다', () {
      for (final c in KeyCategory.values) {
        final delta = (lightness(c.background) - lightness(c.pressedBackground))
            .abs();
        expect(
          delta,
          greaterThanOrEqualTo(CalcTheme.keyPressedMinLightnessDelta),
          reason: '${c.name}: ΔL*=${delta.toStringAsFixed(1)}',
        );
      }
    });

    test('모든 카테고리: 눌린 상태에서도 메인 라벨이 4.5:1 이상이다', () {
      for (final c in KeyCategory.values) {
        expect(
          contrastRatio(c.foreground, c.pressedBackground),
          greaterThanOrEqualTo(minTextContrast),
          reason: c.name,
        );
      }
    });

    test('모든 카테고리: 눌린 키캡이 본체 배경에 묻히지 않는다', () {
      final body = lightness(CalcTheme.bodyBackground);
      for (final c in KeyCategory.values) {
        final delta = (lightness(c.pressedBackground) - body).abs();
        expect(
          delta,
          greaterThanOrEqualTo(CalcTheme.keyPressedMinBodyLightnessDelta),
          reason: '${c.name}: 본체와 ΔL*=${delta.toStringAsFixed(1)}',
        );
      }
    });

    test('눌림 테두리: 평소 테두리보다 L* 30 이상 밝다', () {
      expect(
        lightness(CalcTheme.keyPressedBorder) - lightness(CalcTheme.keyBorder),
        greaterThanOrEqualTo(30),
      );
    });

    test('눌림 테두리: 맞닿는 본체 배경 대비 3:1 이상이고 평소 테두리보다 뚜렷하다 (비텍스트 대비)', () {
      // 보이는 단서는 키캡 바깥쪽(본체 쪽) 경계다 — 테마 "눌림 표시" 주석 참조.
      final pressed = contrastRatio(
        CalcTheme.keyPressedBorder,
        CalcTheme.bodyBackground,
      );
      expect(pressed, greaterThanOrEqualTo(3.0));
      expect(
        pressed,
        greaterThan(
          contrastRatio(CalcTheme.keyBorder, CalcTheme.bodyBackground),
        ),
      );
    });

    test('눌림 색은 불투명하다 (키캡 아래 그림자·본체가 비치지 않는다)', () {
      for (final c in KeyCategory.values) {
        expect(c.pressedBackground.a, 1.0, reason: c.name);
      }
      expect(CalcTheme.keyPressedBorder.a, 1.0);
    });
  });

  group('텍스트 스타일', () {
    test('모든 스타일은 고정폭 폰트와 대체 폰트를 지정한다', () {
      for (final style in [
        CalcTheme.lcdInputStyle,
        CalcTheme.lcdResultStyle,
        CalcTheme.lcdStatusStyle,
        CalcTheme.keyMainLabelStyle,
        CalcTheme.keyShiftLabelStyle,
        CalcTheme.keyAlphaLabelStyle,
      ]) {
        expect(style.fontFamily, CalcTheme.monoFontFamily);
        expect(style.fontFamilyFallback, CalcTheme.monoFontFallback);
        expect(style.fontSize, isNotNull);
        expect(style.fontSize!, greaterThan(0));
      }
    });

    test('각인 스타일 색은 각인 팔레트와 일치한다', () {
      expect(CalcTheme.keyShiftLabelStyle.color, CalcTheme.shiftLabel);
      expect(CalcTheme.keyAlphaLabelStyle.color, CalcTheme.alphaLabel);
    });
  });

  group('치수', () {
    test('광고 슬롯 높이는 50~60dp, 안전 여백은 8~12dp 범위다', () {
      expect(CalcTheme.adSlotHeight, inInclusiveRange(50, 60));
      expect(CalcTheme.adSlotMaxHeight, inInclusiveRange(50, 60));
      expect(
        CalcTheme.adSlotHeight,
        lessThanOrEqualTo(CalcTheme.adSlotMaxHeight),
      );
      expect(CalcTheme.adSlotSafetyMargin, inInclusiveRange(8, 12));
      expect(CalcTheme.adSlotMinSafetyMargin, 8);
      expect(CalcTheme.adSlotMaxSafetyMargin, 12);
      expect(
        CalcTheme.adSlotSafetyMargin,
        inInclusiveRange(
          CalcTheme.adSlotMinSafetyMargin,
          CalcTheme.adSlotMaxSafetyMargin,
        ),
      );
      expect(CalcTheme.adSlotLargeScreenShortestSide, greaterThan(0));
    });

    test('LCD 치수 상수는 양수이며 베젤 안쪽 모서리가 음수가 되지 않는다', () {
      for (final v in [
        CalcTheme.lcdFrameWidth,
        CalcTheme.lcdBorderRadius,
        CalcTheme.lcdInnerPadding,
        CalcTheme.lcdDotPitch,
        CalcTheme.lcdDotGridStrokeWidth,
        CalcTheme.lcdStatusBarHeightRatio,
        CalcTheme.lcdStatusSlotGapRatio,
        CalcTheme.lcdStatusCharWidthRatio,
        CalcTheme.lcdScrollArrowFontRatio,
        CalcTheme.lcdScrollArrowWidthRatio,
      ]) {
        expect(v, greaterThan(0));
      }
      expect(
        CalcTheme.lcdBorderRadius,
        greaterThanOrEqualTo(CalcTheme.lcdFrameWidth),
      );
      // 격자선은 픽셀 간격보다 얇아야 도트처럼 보인다.
      expect(CalcTheme.lcdDotGridStrokeWidth, lessThan(CalcTheme.lcdDotPitch));
      // 상태 표시줄은 글자보다 높아야 잘리지 않는다.
      expect(CalcTheme.lcdStatusBarHeightRatio, greaterThanOrEqualTo(1.0));
      expect(CalcTheme.lcdMaxTextScaleFactor, inInclusiveRange(1.0, 2.0));
    });

    test('LCD 내부 구성: 입력·결과 줄은 각각 분수(2D) 2행 이상을 담는다', () {
      expect(CalcTheme.lcdInputLineFlex, greaterThanOrEqualTo(2));
      // MathO 결과도 분수(⅓ 등)로 표시된다.
      expect(CalcTheme.lcdResultLineFlex, greaterThanOrEqualTo(2));
      // LcdDisplay는 flex 비율로 줄 높이를 나누므로, 줄마다 분수 막대 몫을 같게 받으려면 행 수가 같아야 한다.
      expect(CalcTheme.lcdInputLineFlex, CalcTheme.lcdResultLineFlex);
      // 분수 막대·여백은 한 행보다 얇다.
      expect(CalcTheme.lcdFractionBarRatio, inExclusiveRange(0, 1));
      // 상태 표시는 줄 글자보다 작다.
      expect(CalcTheme.lcdStatusFontRatio, inExclusiveRange(0, 1));
      // 고정폭 글꼴 글자 폭은 1em보다 좁다.
      expect(CalcTheme.lcdLineCharWidthRatio, inExclusiveRange(0, 1));
    });

    test('결과 줄 칸 수는 가장 긴 10자리 결과(부호·가수·×10 + 위첨자 지수)를 담는다', () {
      // 위첨자 지수(−99)는 lcdExponentMaxScale 이하 크기로 그린다는 전제다.
      // 실제 글꼴 폭 실측은 test/widget/bundled_font_test.dart (#16).
      const mantissa = '−1.234567891×10';
      const exponent = '−99';
      expect(
        CalcTheme.lcdLineColumns,
        greaterThanOrEqualTo(
          mantissa.runes.length +
              exponent.runes.length * CalcTheme.lcdExponentMaxScale,
        ),
      );
      // 유니코드 위첨자로 같은 크기로 그리면 넘친다 — 지수는 반드시 작게 그려야 한다.
      expect(
        CalcTheme.lcdLineColumns,
        lessThan(mantissa.runes.length + exponent.runes.length),
      );
      expect(CalcTheme.lcdExponentMaxScale, inExclusiveRange(0, 1));
    });

    test('도트 격자는 LCD 글자 가독성을 해치지 않을 만큼 옅다', () {
      expect(CalcTheme.lcdDotGrid.a, lessThan(0.15));
    });

    test('키 버튼 비율 상수는 0~1 사이이며 키캡이 각인 띠보다 크다', () {
      for (final ratio in [
        CalcTheme.keyLegendHeightRatio,
        CalcTheme.keyLegendFontRatio,
        CalcTheme.keyMainLabelFontRatio,
        CalcTheme.keyCapHorizontalPaddingRatio,
        CalcTheme.keyLegendGapRatio,
        CalcTheme.keyLegendGapMaxWidthRatio,
        CalcTheme.keyDisabledLabelOpacity,
      ]) {
        expect(ratio, inExclusiveRange(0, 1));
      }
      expect(CalcTheme.keyLegendHeightRatio, lessThan(0.5));
      expect(CalcTheme.keyCapHorizontalPaddingRatio, lessThan(0.25));
      expect(CalcTheme.keyBorderWidth, greaterThan(0));
      expect(CalcTheme.keyPressedOffset, greaterThanOrEqualTo(0));
      expect(CalcTheme.keyMaxTextScaleFactor, inInclusiveRange(1.0, 2.0));
      expect(
        CalcTheme.keyPressAnimationDuration,
        lessThanOrEqualTo(const Duration(milliseconds: 100)),
      );
    });

    test('키 간격 비율은 0~0.1 사이의 양수다', () {
      expect(CalcTheme.keyHorizontalGapRatio, inExclusiveRange(0, 0.1));
      expect(CalcTheme.keyVerticalGapRatio, inExclusiveRange(0, 0.1));
    });

    test('키패드 배치 상수: 숫자 행이 더 크고, 가로/세로 비 하한 < 상한이다', () {
      expect(CalcTheme.keypadNumberRowHeightRatio, inInclusiveRange(1.0, 2.0));
      expect(CalcTheme.keypadSectionGapRatio, inExclusiveRange(0, 0.1));
      expect(CalcTheme.keypadMinAspectRatio, greaterThan(0));
      expect(
        CalcTheme.keypadMinAspectRatio,
        lessThan(CalcTheme.keypadMaxAspectRatio),
      );
      expect(CalcTheme.keyMinTouchTargetHeight, greaterThanOrEqualTo(44));
    });

    test('통일 글자 하한 비율은 0.5~1, 커서 패드 경계선은 양수 두께다', () {
      expect(CalcTheme.keypadUniformFontMinRatio, inInclusiveRange(0.5, 1.0));
      expect(CalcTheme.cursorPadDividerWidth, greaterThan(0));
      expect(CalcTheme.keyLegendPriorityMaxRunes, inInclusiveRange(1, 3));
    });

    test('키 라벨 스타일은 자간을 명시해 테마 자간을 물려받지 않는다', () {
      for (final style in [
        CalcTheme.keyMainLabelStyle,
        CalcTheme.keyShiftLabelStyle,
        CalcTheme.keyAlphaLabelStyle,
      ]) {
        expect(style.letterSpacing, 0);
      }
    });

    test('화면 배치 상수는 양수이며 LCD 비율은 본체의 절반 미만이다', () {
      expect(CalcTheme.screenPadding, greaterThanOrEqualTo(0));
      expect(CalcTheme.screenLcdKeypadGap, greaterThanOrEqualTo(0));
      expect(CalcTheme.screenLcdHeightRatio, inExclusiveRange(0, 0.5));
      expect(CalcTheme.screenLcdMinHeight, greaterThan(0));
      // LCD는 세로보다 가로가 길다.
      expect(CalcTheme.screenLcdMinAspectRatio, greaterThanOrEqualTo(1));
    });

    test('폰 폭에서 LCD 최대 높이(폭 / 최소 가로세로비)는 최소 높이 이상이다', () {
      // 가장 좁은 폰(320dp)의 LCD 폭 = 320 − 좌우 여백
      const narrowest = 320 - 2 * CalcTheme.screenPadding;
      expect(
        narrowest / CalcTheme.screenLcdMinAspectRatio,
        greaterThanOrEqualTo(CalcTheme.screenLcdMinHeight),
      );
    });
  });

  group('대화면·좌우 분할 배치 (#24)', () {
    test('키패드 최대 폭은 가장 넓은 폰(430dp)의 키패드 폭보다 넓다 — 폰에는 걸리지 않는다', () {
      const widestPhoneKeypad = 430 - 2 * CalcTheme.screenPadding;
      expect(CalcTheme.keypadMaxWidth, greaterThan(widestPhoneKeypad));
      // 실물 fx-991EX 본체 폭(약 77mm = 약 485dp, 1dp = 1/160인치)을 크게 넘지 않는다.
      expect(CalcTheme.keypadMaxWidth, lessThanOrEqualTo(77 / 25.4 * 160));
    });

    test('분할 배치 상수: 간격은 양수, 키패드 몫은 0~0.5 (LCD 쪽이 키패드보다 좁아지지 않는다)', () {
      expect(CalcTheme.screenSplitGap, greaterThan(0));
      expect(
        CalcTheme.screenSplitKeypadMaxWidthRatio,
        inInclusiveRange(0.3, 0.5),
      );
      expect(CalcTheme.screenSplitSettingsGap, greaterThanOrEqualTo(0));
    });

    test('설정 버튼은 접근성 권장 터치 대상(48dp) 이상이고 아이콘은 본체 배경 대비 4.5:1 이상이다', () {
      expect(
        CalcTheme.settingsButtonSize,
        greaterThanOrEqualTo(CalcTheme.keyMinTouchTargetHeight),
      );
      expect(
        contrastRatio(CalcTheme.settingsIcon, CalcTheme.bodyBackground),
        greaterThanOrEqualTo(minTextContrast),
      );
    });
  });
}
