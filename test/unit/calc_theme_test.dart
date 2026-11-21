import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:material_ui/material_ui.dart';

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
      expect(CalcTheme.lcdInputLineFlex, greaterThan(0));
      expect(CalcTheme.lcdResultLineFlex, greaterThan(0));
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
    });
  });
}
