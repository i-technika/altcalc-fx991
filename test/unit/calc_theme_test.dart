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

    test('비활성 상태 표시는 활성 색을 3~5% 불투명도로 그린다 (#44 사용자 결정 4%)', () {
      const inactive = CalcTheme.lcdStatusInactive;
      const active = CalcTheme.lcdStatusActive;
      expect(
        (inactive.r, inactive.g, inactive.b),
        (active.r, active.g, active.b),
      );
      expect(inactive.a, inInclusiveRange(0.03, 0.05));
      // 픽셀 색 기준: LCD 배경 위에 합성한 색이 도트 격자선 색보다 옅다 (면적·커버리지는 따지지 않는다).
      final drawn = Color.alphaBlend(inactive, CalcTheme.lcdBackground);
      final grid = Color.alphaBlend(
        CalcTheme.lcdDotGrid,
        CalcTheme.lcdBackground,
      );
      expect(
        contrastRatio(drawn, CalcTheme.lcdBackground),
        lessThan(contrastRatio(grid, CalcTheme.lcdBackground)),
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

  group('고대비 팔레트 (#54)', () {
    const normal = CalcPalette.standard;
    const high = CalcPalette.highContrast;
    // 기준값은 테스트 대상 상수가 아니라 리터럴로 둔다 — 상수를 낮춰도 테스트가 따라 느슨해지지 않게.
    const aaa = 7.0; // WCAG AAA 일반 텍스트
    const bodies = [
      CalcTheme.bodyBackground,
      CalcTheme.bodyFrame,
      CalcTheme.bodyBottomGradient,
    ];

    double pressDelta(CalcPalette p, KeyCategory c) =>
        (lightness(p.keyBackground(c)) - lightness(p.keyPressedBackground(c)))
            .abs();
    double pressedLabel(CalcPalette p, KeyCategory c) =>
        contrastRatio(p.keyPressedForeground(c), p.keyPressedBackground(c));
    double pressedBodyDelta(CalcPalette p, KeyCategory c) =>
        (lightness(p.keyPressedBackground(c)) -
                lightness(CalcTheme.bodyBackground))
            .abs();

    test('고대비 텍스트 기준 상수는 WCAG AAA(7:1)다', () {
      expect(CalcTheme.highContrastMinTextContrast, aaa);
    });

    test('일반 팔레트는 테마 상수·카테고리 색 그대로다 (일반 모드 화면이 바뀌지 않는다)', () {
      expect(normal.isHighContrast, isFalse);
      expect(high.isHighContrast, isTrue);
      expect(normal.keyBorder, CalcTheme.keyBorder);
      expect(normal.keyPressedBorder, CalcTheme.keyPressedBorder);
      expect(normal.shiftLabel, CalcTheme.shiftLabel);
      expect(normal.alphaLabel, CalcTheme.alphaLabel);
      expect(normal.lcdStatusInactive, CalcTheme.lcdStatusInactive);
      expect(normal.settingsIcon, CalcTheme.settingsIcon);
      for (final c in KeyCategory.values) {
        expect(normal.keyBackground(c), c.background, reason: c.name);
        expect(normal.keyForeground(c), c.foreground, reason: c.name);
        expect(normal.keyPressedBackground(c), c.pressedBackground);
        expect(normal.keyPressedForeground(c), c.foreground, reason: c.name);
        expect(normal.invertsOnPress(c), isFalse, reason: c.name);
      }
    });

    test('모든 카테고리: 메인 라벨이 7:1 이상이고 일반 팔레트 이상이다', () {
      for (final c in KeyCategory.values) {
        final hc = contrastRatio(high.keyForeground(c), high.keyBackground(c));
        expect(hc, greaterThanOrEqualTo(aaa), reason: c.name);
        expect(
          hc,
          greaterThanOrEqualTo(
            contrastRatio(normal.keyForeground(c), normal.keyBackground(c)),
          ),
          reason: c.name,
        );
      }
    });

    test('키캡 색은 바꾸더라도 일반 색보다 어둡게만 하고, 연산자는 함수 키보다 밝게 남긴다', () {
      for (final c in KeyCategory.values) {
        expect(
          lightness(high.keyBackground(c)),
          lessThanOrEqualTo(lightness(normal.keyBackground(c))),
          reason: c.name,
        );
      }
      // 회색 두 카테고리(연산자·함수)의 명도 차는 일반(13.8)보다 줄지만(테마 "고대비 모드" 주석의 맞바꿈),
      // 함수 키와 커서 키 사이(약 5)만큼은 남긴다.
      expect(
        lightness(high.keyBackground(KeyCategory.operator)) -
            lightness(high.keyBackground(KeyCategory.function)),
        greaterThanOrEqualTo(5.0),
      );
    });

    test('반전은 흰 라벨(배경보다 밝은 라벨) 카테고리에만 적용한다', () {
      for (final c in KeyCategory.values) {
        expect(
          high.invertsOnPress(c),
          lightness(c.foreground) > lightness(high.keyBackground(c)),
          reason: c.name,
        );
      }
      // 반전한 라벨은 반전 배경 위에서 어둡다.
      expect(
        lightness(CalcTheme.keyPressedInvertedText),
        lessThan(lightness(CalcTheme.keyPressedInvertedBackground)),
      );
    });

    test('모든 카테고리: 눌림 단서(명도 차·눌린 라벨·본체와의 차)가 하한 이상이고 일반 팔레트 이상이다', () {
      for (final c in KeyCategory.values) {
        final delta = pressDelta(high, c);
        expect(
          delta,
          greaterThanOrEqualTo(CalcTheme.keyPressedMinLightnessDelta),
          reason: '${c.name}: ΔL*=${delta.toStringAsFixed(1)}',
        );
        expect(
          delta,
          greaterThanOrEqualTo(pressDelta(normal, c)),
          reason: c.name,
        );

        final label = pressedLabel(high, c);
        expect(label, greaterThanOrEqualTo(minTextContrast), reason: c.name);
        expect(
          label,
          greaterThanOrEqualTo(pressedLabel(normal, c)),
          reason: c.name,
        );

        final body = pressedBodyDelta(high, c);
        expect(
          body,
          greaterThanOrEqualTo(CalcTheme.keyPressedMinBodyLightnessDelta),
          reason: c.name,
        );
        expect(
          body,
          greaterThanOrEqualTo(pressedBodyDelta(normal, c)),
          reason: c.name,
        );
        expect(high.keyPressedBackground(c).a, 1.0, reason: c.name);
      }
    });

    test('테두리: 본체·커서 패드 허브 대비가 일반 팔레트 이상이고, 눌림 테두리는 L* 30 이상 밝다', () {
      // (고대비 색, 일반 색, 맞닿는 색) — 테두리는 본체, 커서 패드 홈·허브 둘레는 허브·방향 키캡과 맞닿는다.
      for (final (hc, std, against) in [
        (high.keyBorder, normal.keyBorder, CalcTheme.bodyBackground),
        (high.keyBorder, normal.keyBorder, CalcTheme.cursorPadHub),
        (high.keyBorder, normal.keyBorder, CalcTheme.keyCursor),
        (
          high.keyPressedBorder,
          normal.keyPressedBorder,
          CalcTheme.bodyBackground,
        ),
      ]) {
        expect(
          contrastRatio(hc, against),
          greaterThanOrEqualTo(contrastRatio(std, against)),
          reason: 'border=$hc against=$against',
        );
      }
      expect(
        contrastRatio(high.keyBorder, CalcTheme.bodyBackground),
        greaterThanOrEqualTo(minTextContrast),
      );
      expect(
        lightness(high.keyPressedBorder) - lightness(high.keyBorder),
        greaterThanOrEqualTo(30),
      );
      // 어두운(흰 라벨) 키캡과의 안쪽 경계도 일반 이상이다.
      for (final c in KeyCategory.values.where(high.invertsOnPress)) {
        expect(
          contrastRatio(high.keyBorder, high.keyBackground(c)),
          greaterThanOrEqualTo(
            contrastRatio(normal.keyBorder, normal.keyBackground(c)),
          ),
          reason: c.name,
        );
      }
      // 밝은 키캡(숫자·SHIFT)과의 안쪽 경계는 낮아지는 맞바꿈이다 — 대신 키캡 자체가 본체와 4.5:1 이상 구분된다
      // (비텍스트 기준 3:1보다 넉넉하다).
      for (final c in KeyCategory.values.where(
        (c) => !high.invertsOnPress(c),
      )) {
        expect(
          contrastRatio(high.keyBackground(c), CalcTheme.bodyBackground),
          greaterThanOrEqualTo(minTextContrast),
          reason: c.name,
        );
      }
      expect(high.keyBorder.a, 1.0);
      expect(high.keyPressedBorder.a, 1.0);
    });

    test('SHIFT/ALPHA 각인은 모든 본체 색 대비 7:1 이상이고 일반 팔레트 이상이다', () {
      for (final body in bodies) {
        for (final (hc, std) in [
          (high.shiftLabel, normal.shiftLabel),
          (high.alphaLabel, normal.alphaLabel),
        ]) {
          expect(
            contrastRatio(hc, body),
            greaterThanOrEqualTo(aaa),
            reason: 'legend=$hc body=$body',
          );
          expect(
            contrastRatio(hc, body),
            greaterThanOrEqualTo(contrastRatio(std, body)),
            reason: 'legend=$hc body=$body',
          );
        }
      }
    });

    test('설정 아이콘은 본체 배경 대비 7:1 이상이고 일반 팔레트 이상이며, 고대비 각인보다는 덜 띈다', () {
      final hc = contrastRatio(high.settingsIcon, CalcTheme.bodyBackground);
      expect(hc, greaterThanOrEqualTo(aaa));
      for (final legend in [high.shiftLabel, high.alphaLabel]) {
        expect(
          hc,
          lessThan(contrastRatio(legend, CalcTheme.bodyBackground)),
          reason: 'legend=$legend',
        );
      }
      expect(
        hc,
        greaterThanOrEqualTo(
          contrastRatio(normal.settingsIcon, CalcTheme.bodyBackground),
        ),
      );
    });

    test('LCD 비활성 표시기: 일반보다 진하되(배경 대비) 켜진 표시기 색과는 7:1 이상 떨어진다', () {
      final hc = high.lcdStatusInactive;
      const active = CalcTheme.lcdStatusActive;
      expect((hc.r, hc.g, hc.b), (active.r, active.g, active.b));
      expect(hc.a, greaterThan(normal.lcdStatusInactive.a));
      final drawn = Color.alphaBlend(hc, CalcTheme.lcdBackground);
      final normalDrawn = Color.alphaBlend(
        normal.lcdStatusInactive,
        CalcTheme.lcdBackground,
      );
      expect(
        contrastRatio(drawn, CalcTheme.lcdBackground),
        greaterThan(contrastRatio(normalDrawn, CalcTheme.lcdBackground)),
      );
      expect(contrastRatio(active, drawn), greaterThanOrEqualTo(aaa));
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

    test(
      '상태 아이콘 치수: 높이 비율은 x높이 < 대문자 높이 < 1, 선 굵기는 ‖ 두 획이 붙지 않을 만큼 가늘다 (#57)',
      () {
        expect(CalcTheme.lcdStatusXHeightRatio, greaterThan(0));
        expect(
          CalcTheme.lcdStatusXHeightRatio,
          lessThan(CalcTheme.lcdStatusCapHeightRatio),
        );
        expect(CalcTheme.lcdStatusCapHeightRatio, lessThan(1));
        expect(CalcTheme.lcdStatusIconStrokeRatio, greaterThan(0));
        // ‖ 두 획 중심 간격 = 칸 폭(0.6em)의 40% — 획 굵기가 그보다 작아야 사이가 빈다.
        expect(
          CalcTheme.lcdStatusIconStrokeRatio,
          lessThan(0.4 * CalcTheme.lcdStatusCharWidthRatio),
        );
      },
    );

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

    test('커서 패드 모양 상수: 가로로 긴 둥근 마름모·▲▼ 쪽으로 기운 홈·작은 허브 (#43)', () {
      // 가로로 긴 패드: 비율 하한이 1보다 크고 하한 < 상한
      expect(CalcTheme.cursorPadMinAspectRatio, greaterThan(1.0));
      expect(
        CalcTheme.cursorPadMinAspectRatio,
        lessThan(CalcTheme.cursorPadMaxAspectRatio),
      );
      // 2이면 타원, 무한대면 뾰족한 마름모 — 2보다 크고 너무 크지 않아야 꼭짓점이 둥근 마름모다.
      expect(CalcTheme.cursorPadOutlineExponent, inExclusiveRange(2.0, 6.0));
      // 1보다 커야 홈이 ◀·▶ 쪽을 좁힌다. 너무 크면 ◀·▶가 누르기 어렵게 좁아진다.
      expect(CalcTheme.cursorPadGrooveSlope, inExclusiveRange(1.0, 2.0));
      // 허브는 반높이(짧은 쪽)의 절반 미만이고, 데드존은 허브보다 작은 양수다.
      // 실제 터치 깊이·라벨 위치는 위젯·화면 테스트가 화면 크기별로 확인한다.
      expect(CalcTheme.cursorPadHubRadiusRatio, inExclusiveRange(0.0, 0.5));
      expect(CalcTheme.cursorPadDeadZoneRadiusRatio, greaterThan(0));
      expect(
        CalcTheme.cursorPadDeadZoneRadiusRatio,
        lessThan(CalcTheme.cursorPadHubRadiusRatio),
      );
    });

    test('커서 패드 허브는 방향 키캡보다 어둡고, 둘레선은 허브 대비 3:1 이상이다', () {
      expect(
        lightness(CalcTheme.cursorPadHub),
        lessThan(lightness(CalcTheme.keyCursor)),
      );
      expect(
        contrastRatio(CalcTheme.keyBorder, CalcTheme.cursorPadHub),
        greaterThanOrEqualTo(3.0),
      );
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
    test(
      '키패드 최대 폭은 가장 넓은 폰(440dp, iPhone Pro Max)의 키패드 폭보다 넓다 — 폰에는 걸리지 않는다',
      () {
        const widestPhoneKeypad = 440 - 2 * CalcTheme.screenPadding;
        expect(CalcTheme.keypadMaxWidth, greaterThan(widestPhoneKeypad));
        // 실물 fx-991EX 본체 폭(약 77mm = 약 485dp, 1dp = 1/160인치)을 크게 넘지 않는다.
        expect(CalcTheme.keypadMaxWidth, lessThanOrEqualTo(77 / 25.4 * 160));
      },
    );

    test('분할 배치 상수: 간격은 양수, 키패드 몫은 0.3~0.5 (LCD 쪽 패널이 키패드보다 좁아지지 않는다)', () {
      expect(CalcTheme.screenSplitGap, greaterThan(0));
      expect(
        CalcTheme.screenSplitKeypadMaxWidthRatio,
        inInclusiveRange(0.3, 0.5),
      );
      expect(CalcTheme.screenSplitSettingsGap, greaterThanOrEqualTo(0));
    });

    test('LCD 최대 폭 비율: 0 초과 1 이하 — 좌우 분할 LCD가 키패드보다 넓어지지 않는다 (#71)', () {
      // LCD 줄 글자가 키 메인 각인보다 큰지는 split_layout_test에서 번들 글꼴로 실측한다.
      expect(CalcTheme.screenLcdMaxWidthRatio, greaterThan(0));
      expect(CalcTheme.screenLcdMaxWidthRatio, lessThanOrEqualTo(1));
    });

    test('위아래·테이블톱 LCD 최대 폭: 키패드 최대 폭을 넘지 않고, 가장 넓은 폰 본체보다 넓다 (#92)', () {
      // 위아래 배치에서 LCD가 키패드(최대 폭)보다 넓어지지 않는다.
      expect(
        CalcTheme.screenLcdMaxWidth,
        lessThanOrEqualTo(CalcTheme.keypadMaxWidth),
      );
      // 세로 폰 폭에서는 걸리지 않는다 (가장 넓은 폰 440dp − 좌우 여백).
      const widestPhoneBody = 440 - 2 * CalcTheme.screenPadding;
      expect(CalcTheme.screenLcdMaxWidth, greaterThan(widestPhoneBody));
      // 상한 폭에서도 LCD 최대 높이가 최소 높이 이상이다.
      expect(
        CalcTheme.screenLcdMaxWidth / CalcTheme.screenLcdMinAspectRatio,
        greaterThanOrEqualTo(CalcTheme.screenLcdMinHeight),
      );
    });

    test('키 터치 하한: 기본은 터치 확장 기준 이하, 테이블톱 하한은 기본보다 낮은 양수 (#25)', () {
      expect(CalcTheme.keyTouchHeightFloor, greaterThan(0));
      expect(
        CalcTheme.keyTouchHeightFloor,
        lessThanOrEqualTo(CalcTheme.keyMinTouchTargetHeight),
      );
      expect(CalcTheme.tabletopKeyTouchHeightFloor, greaterThan(0));
      expect(
        CalcTheme.tabletopKeyTouchHeightFloor,
        lessThan(CalcTheme.keyTouchHeightFloor),
      );
    });

    test('접힘선 간격: 양수이고, 폭 0 접힘선 양쪽 내용 사이가 좌우 분할 간격과 같다 (#25)', () {
      expect(CalcTheme.screenHingeMargin, greaterThan(0));
      expect(2 * CalcTheme.screenHingeMargin, CalcTheme.screenSplitGap);
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
