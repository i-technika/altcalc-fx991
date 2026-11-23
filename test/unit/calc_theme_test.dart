import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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

  group('Material 테마 (#97)', () {
    final normal = CalcPalette.standard.materialTheme;
    final high = CalcPalette.highContrast.materialTheme;
    // 기준값은 리터럴로 둔다 (상수를 낮춰도 테스트가 느슨해지지 않게)
    const aaa = 7.0; // WCAG AAA 일반 텍스트
    const nonText = 3.0; // WCAG 1.4.11 비텍스트 대비

    // 대화상자가 쓰는 색 역할 (M3 기본값): 면 surfaceContainerHigh, 제목·선택지 이름 onSurface,
    // 선택지 설명·꺼진 라디오 onSurfaceVariant, 닫기 버튼·켜진 라디오 primary.
    // SnackBar: 면 inverseSurface, 글자 onInverseSurface, 동작 버튼 inversePrimary.
    List<(String, Color, Color)> textPairs(ColorScheme s) => [
      ('대화상자 onSurface', s.onSurface, s.surfaceContainerHigh),
      ('대화상자 onSurfaceVariant', s.onSurfaceVariant, s.surfaceContainerHigh),
      ('대화상자 primary', s.primary, s.surfaceContainerHigh),
      ('SnackBar 글자', s.onInverseSurface, s.inverseSurface),
      ('SnackBar 동작', s.inversePrimary, s.inverseSurface),
    ];

    test('일반 테마는 그동안의 테마(ThemeData 기본 어두운 색 구성·본체색 배경) 그대로다', () {
      final before = ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: CalcTheme.bodyBackground,
      );
      expect(normal.colorScheme, before.colorScheme);
      expect(normal.scaffoldBackgroundColor, before.scaffoldBackgroundColor);
      expect(normal.textButtonTheme, before.textButtonTheme);
      expect(normal.iconButtonTheme, before.iconButtonTheme);
      // 대화상자는 모양만 직접 지정한다 (M3 기본 모양과 같은지는 위젯 테스트가 확인)
      expect(
        normal.dialogTheme,
        const DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
        ),
      );
      expect(normal.useMaterial3, isTrue);
    });

    test('고대비 테마는 Flutter M3 고대비 기준 색 구성을 쓰고, 어두운 테마·본체색 배경이다', () {
      expect(
        high.colorScheme,
        ThemeData(
          brightness: Brightness.dark,
          contrastLevel: ContrastLevel.high,
        ).colorScheme,
      );
      for (final t in [normal, high]) {
        expect(t.brightness, Brightness.dark);
        expect(t.scaffoldBackgroundColor, CalcTheme.bodyBackground);
      }
      expect(high.useMaterial3, isTrue);
      // 대화상자 면은 일반 테마와 같다 (글자·버튼만 밝아진다)
      expect(
        high.colorScheme.surfaceContainerHigh,
        normal.colorScheme.surfaceContainerHigh,
      );
    });

    test('고대비 테마의 대화상자·SnackBar 글자는 7:1 이상이고 일반 테마 이상이다', () {
      final hc = textPairs(high.colorScheme);
      final std = textPairs(normal.colorScheme);
      for (var i = 0; i < hc.length; i++) {
        final (name, fg, bg) = hc[i];
        final (_, stdFg, stdBg) = std[i];
        expect(fg.a, 1.0, reason: name);
        expect(bg.a, 1.0, reason: name);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(aaa), reason: name);
        expect(
          contrastRatio(fg, bg),
          greaterThanOrEqualTo(contrastRatio(stdFg, stdBg)),
          reason: name,
        );
      }
    });

    test('고대비 대화상자 가장자리 선은 고대비 키캡 테두리 색이고 대화상자 면·어둡게 덮인 본체 모두와 3:1 이상이다', () {
      final shape = high.dialogTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      final border = shape! as RoundedRectangleBorder;
      expect(border.side.color, CalcPalette.highContrast.keyBorder);
      expect(border.side.width, greaterThanOrEqualTo(1.0));
      // showDialog 기본 장벽(black54)으로 덮인 본체
      final dimmedBody = Color.alphaBlend(
        Colors.black54,
        CalcTheme.bodyBackground,
      );
      final surface = high.colorScheme.surfaceContainerHigh;
      expect(
        contrastRatio(border.side.color, surface),
        greaterThanOrEqualTo(nonText),
      );
      expect(
        contrastRatio(border.side.color, dimmedBody),
        greaterThanOrEqualTo(nonText),
      );
      // 일반 테마는 가장자리 선이 없고, 모서리는 두 테마가 같다 (전환 보간 중 반경이 바뀌지 않게)
      final normalShape = normal.dialogTheme.shape! as RoundedRectangleBorder;
      expect(normalShape.side, BorderSide.none);
      expect(normalShape.borderRadius, border.borderRadius);
    });

    // 키보드 포커스 테두리가 겹쳐 그려지는 면. 대화상자 면·본체는 WCAG 2.4.13(포커스 전후 같은 픽셀)의 기준이고,
    // 포커스 겹침은 테두리 안쪽에 맞닿는 면과의 인접 대비(추가 확인)다. 닫기 버튼(primary 10%)·설정 버튼(아이콘색 10%)은
    // M3 버튼 기본 포커스 겹침이다 — 실제 위젯이 이 값을 쓰는지는 `test/widget/material_theme_test.dart`가 확인한다.
    Map<String, Color> focusSurfaces(CalcPalette palette) {
      final theme = palette.materialTheme;
      final surface = theme.colorScheme.surfaceContainerHigh;
      return {
        '대화상자 면': surface,
        '선택지 포커스 겹침': Color.alphaBlend(theme.focusColor, surface),
        '닫기 버튼 포커스 겹침': Color.alphaBlend(
          theme.colorScheme.primary.withValues(alpha: 0.1),
          surface,
        ),
        '본체': CalcTheme.bodyBackground,
        '설정 버튼 포커스 겹침': Color.alphaBlend(
          palette.settingsIcon.withValues(alpha: 0.1),
          CalcTheme.bodyBackground,
        ),
      };
    }

    test(
      '키보드 포커스 테두리는 두 모드 모두 대화상자 면·본체·포커스 겹침 위 3:1 이상이고, 고대비가 더 높다 (#106)',
      () {
        expect(
          CalcPalette.highContrast.materialFocusRing,
          CalcTheme.materialFocusRingHighContrast,
        );
        expect(
          CalcPalette.standard.materialFocusRing,
          CalcTheme.materialFocusRingStandard,
        );
        expect(CalcTheme.materialFocusRingWidth, greaterThanOrEqualTo(2.0));
        const std = CalcPalette.standard;
        const hc = CalcPalette.highContrast;
        final stdSurfaces = focusSurfaces(std);
        final hcSurfaces = focusSurfaces(hc);
        for (final MapEntry(key: name, value: bg) in stdSurfaces.entries) {
          final stdRatio = contrastRatio(std.materialFocusRing, bg);
          expect(stdRatio, greaterThanOrEqualTo(nonText), reason: '일반 $name');
          final hcRatio = contrastRatio(
            hc.materialFocusRing,
            hcSurfaces[name]!,
          );
          expect(hcRatio, greaterThanOrEqualTo(nonText), reason: '고대비 $name');
          expect(hcRatio, greaterThanOrEqualTo(stdRatio), reason: name);
        }
      },
    );

    test('고대비 선택지 포커스 겹침 위의 글자도 7:1 이상 남는다', () {
      final surface = high.colorScheme.surfaceContainerHigh;
      final focusFill = Color.alphaBlend(high.focusColor, surface);
      for (final fg in [
        high.colorScheme.onSurface,
        high.colorScheme.onSurfaceVariant,
      ]) {
        expect(contrastRatio(fg, focusFill), greaterThanOrEqualTo(aaa));
      }
    });
  });

  group('플랫폼별 Material 테마 (#130)', () {
    // Flutter가 플랫폼마다 고르는 기본 터치 영역·밀도 — 리터럴로 둔다 (터치 기기는 48dp 터치 영역·standard,
    // 데스크톱은 줄인 터치 영역·compact)
    const expected = {
      TargetPlatform.android: (
        MaterialTapTargetSize.padded,
        VisualDensity.standard,
      ),
      TargetPlatform.fuchsia: (
        MaterialTapTargetSize.padded,
        VisualDensity.standard,
      ),
      TargetPlatform.iOS: (
        MaterialTapTargetSize.padded,
        VisualDensity.standard,
      ),
      TargetPlatform.linux: (
        MaterialTapTargetSize.shrinkWrap,
        VisualDensity.compact,
      ),
      TargetPlatform.macOS: (
        MaterialTapTargetSize.shrinkWrap,
        VisualDensity.compact,
      ),
      TargetPlatform.windows: (
        MaterialTapTargetSize.shrinkWrap,
        VisualDensity.compact,
      ),
    };

    test('표는 모든 플랫폼을 다룬다', () {
      expect(expected.keys.toSet(), TargetPlatform.values.toSet());
    });

    /// [platform]인 동안의 두 팔레트 테마 (일반, 고대비)
    (ThemeData, ThemeData) themesOn(TargetPlatform platform) {
      debugDefaultTargetPlatformOverride = platform;
      try {
        return (
          CalcPalette.standard.materialTheme,
          CalcPalette.highContrast.materialTheme,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    test('만들어 둔 테마를 비우면 다음 읽기에서 새로 만든다 (아래 순서 테스트의 전제)', () {
      final (normal, high) = themesOn(TargetPlatform.android);
      CalcTheme.resetMaterialThemesForTesting();
      final (normalAgain, highAgain) = themesOn(TargetPlatform.android);
      expect(normalAgain, isNot(same(normal)));
      expect(highAgain, isNot(same(high)));
    });

    // 정적 값 하나로 두면 어느 순서든 처음 읽은 플랫폼으로 굳어 뒤 플랫폼이 틀린다. 두 순서로 확인한다.
    // 앞 테스트가 이미 만든 테마를 읽기만 하지 않도록 만들어 둔 테마를 비워, 실제로 이 순서대로 만든다.
    for (final order in [
      TargetPlatform.values,
      TargetPlatform.values.reversed.toList(),
    ]) {
      test('${order.first.name}부터 차례로 만들어도 테마마다 그 플랫폼의 터치 영역·밀도다', () {
        CalcTheme.resetMaterialThemesForTesting();
        for (final platform in order) {
          final (normal, high) = themesOn(platform);
          final (tap, density) = expected[platform]!;
          for (final (name, theme) in [('일반', normal), ('고대비', high)]) {
            final reason = '${platform.name} $name';
            expect(theme.platform, platform, reason: reason);
            expect(theme.materialTapTargetSize, tap, reason: reason);
            expect(theme.visualDensity, density, reason: reason);
          }
        }
      });
    }

    test(
      '같은 플랫폼에서는 늘 같은 객체다 (MaterialApp·AnimatedTheme이 매 빌드 새 테마로 보지 않는다)',
      () {
        for (final platform in TargetPlatform.values) {
          final (normal, high) = themesOn(platform);
          // 다른 플랫폼을 한 번 거친 뒤에도 같다
          themesOn(
            platform == TargetPlatform.android
                ? TargetPlatform.windows
                : TargetPlatform.android,
          );
          final (normalAgain, highAgain) = themesOn(platform);
          expect(normalAgain, same(normal), reason: platform.name);
          expect(highAgain, same(high), reason: platform.name);
          expect(normal, isNot(same(high)), reason: platform.name);
          // 정적 접근자와 팔레트 접근자가 같은 객체다
          debugDefaultTargetPlatformOverride = platform;
          try {
            expect(CalcTheme.materialTheme, same(normal));
            expect(CalcTheme.materialHighContrastTheme, same(high));
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        }
      },
    );

    test('앱이 정한 색 구성·대화상자 모양·배경은 플랫폼과 무관하다', () {
      final (androidNormal, androidHigh) = themesOn(TargetPlatform.android);
      for (final platform in TargetPlatform.values) {
        final (normal, high) = themesOn(platform);
        for (final (theme, base) in [
          (normal, androidNormal),
          (high, androidHigh),
        ]) {
          expect(theme.colorScheme, base.colorScheme, reason: platform.name);
          expect(theme.dialogTheme, base.dialogTheme, reason: platform.name);
          expect(
            theme.textButtonTheme,
            base.textButtonTheme,
            reason: platform.name,
          );
          expect(
            theme.scaffoldBackgroundColor,
            base.scaffoldBackgroundColor,
            reason: platform.name,
          );
        }
      }
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

    test('쓸 수 있는 키 최소: 일반 하한보다 낮은 양수이고, 테이블톱 하한은 그 아래로 내려가지 않는다 (#38)', () {
      expect(CalcTheme.keyTouchHeightUsableMin, greaterThan(0));
      expect(
        CalcTheme.keyTouchHeightUsableMin,
        lessThan(CalcTheme.keyTouchHeightFloor),
      );
      // 테이블톱 하한이 더 낮으면, 고른 테이블톱 배치가 곧바로 "창이 너무 작다" 안내가 된다.
      expect(
        CalcTheme.tabletopKeyTouchHeightFloor,
        greaterThanOrEqualTo(CalcTheme.keyTouchHeightUsableMin),
      );
      expect(CalcTheme.windowTooSmallIconSize, greaterThan(0));
      expect(CalcTheme.windowTooSmallFontSize, greaterThan(0));
      expect(CalcTheme.windowTooSmallPadding, greaterThanOrEqualTo(0));
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

    group('상단 띠 (#41)', () {
      // 최소 띠에서의 내용 줄 높이 = 본체 위 화면 여백 + 띠 최소 높이
      const minRow =
          CalcTheme.screenPadding + CalcTheme.screenTopStripMinHeight;

      test('최소 띠에서도 설정 아이콘(최소 크기 + 위아래 여백)이 내용 줄에 들어간다', () {
        expect(CalcTheme.screenTopStripMinHeight, greaterThan(0));
        expect(
          CalcTheme.settingsIconMinSize + 2 * CalcTheme.topStripIconMargin,
          lessThanOrEqualTo(minRow),
        );
        expect(
          CalcTheme.settingsIconMinSize,
          lessThanOrEqualTo(CalcTheme.settingsIconSize),
        );
        // 내용 줄은 설정 버튼 터치 영역보다 높아지지 않는다 — 그 이상이면 아이콘이 터치 영역 가운데에 온다.
        expect(CalcTheme.topStripRowMaxHeight, CalcTheme.settingsButtonSize);
        expect(
          CalcTheme.settingsIconSize,
          lessThanOrEqualTo(CalcTheme.topStripRowMaxHeight),
        );
      });

      test('낮은 띠에서 LCD 위로 넓힌 설정 터치 영역은 LCD 안에서 끝난다 (키패드까지 내려가지 않는다)', () {
        // 최소 띠에서 터치 영역이 LCD 위에 겹치는 높이 = 버튼 − 줄 높이
        expect(
          CalcTheme.screenLcdMinHeight,
          greaterThan(CalcTheme.settingsButtonSize - minRow),
        );
      });

      test('간격·여백·반경은 양수다', () {
        for (final v in [
          CalcTheme.topStripInset,
          CalcTheme.topStripGap,
          CalcTheme.topStripIconMargin,
          CalcTheme.topStripSolarBorderRadius,
          CalcTheme.topStripSolarCellGapRatio,
          CalcTheme.topStripWordmarkMinWidth,
        ]) {
          expect(v, greaterThan(0));
        }
      });

      test('숨기는 순서: 워드마크는 최소 띠부터, 태양전지는 그보다 높은 줄부터 그린다', () {
        expect(CalcTheme.topStripWordmarkMinHeight, minRow);
        expect(
          CalcTheme.topStripSolarMinHeight,
          greaterThan(CalcTheme.topStripWordmarkMinHeight),
        );
        expect(
          CalcTheme.topStripSolarMinHeight,
          lessThanOrEqualTo(CalcTheme.topStripRowMaxHeight),
        );
      });

      test('워드마크 글자는 배율 상한을 반영해도 내용 줄 높이 안에 들어간다', () {
        for (final ratio in [
          CalcTheme.topStripWordmarkFontRatio,
          CalcTheme.topStripSolarHeightRatio,
          CalcTheme.topStripWordmarkMaxWidthRatio,
        ]) {
          expect(ratio, inExclusiveRange(0, 1));
        }
        expect(
          CalcTheme.topStripWordmarkFontRatio *
              CalcTheme.keyMaxTextScaleFactor *
              CalcTheme.topStripWordmarkStyle.height!,
          lessThanOrEqualTo(1.0),
        );
        expect(
          CalcTheme.topStripWordmarkMaxFontSize *
              CalcTheme.keyMaxTextScaleFactor,
          lessThanOrEqualTo(CalcTheme.topStripRowMaxHeight),
        );
        expect(
          CalcTheme.topStripWordmarkStyle.fontSize,
          CalcTheme.topStripWordmarkMaxFontSize,
        );
      });

      test('가장 좁은 폰(320dp)에도 워드마크 자리와 설정 버튼이 함께 들어간다', () {
        const row = 320 - 2 * CalcTheme.screenPadding;
        final wordmark = row * CalcTheme.topStripWordmarkMaxWidthRatio;
        expect(
          wordmark,
          greaterThanOrEqualTo(CalcTheme.topStripWordmarkMinWidth),
        );
        expect(
          CalcTheme.topStripInset +
              wordmark +
              CalcTheme.topStripGap +
              CalcTheme.settingsButtonSize,
          lessThanOrEqualTo(row),
        );
      });

      test('태양전지 장식: 가로로 길고 칸이 2개 이상이며, 칸은 바탕·본체와 구분된다', () {
        expect(CalcTheme.topStripSolarAspectRatio, greaterThan(1));
        expect(CalcTheme.topStripSolarCellCount, greaterThanOrEqualTo(2));
        // 안쪽 여백 2 + 칸 사이 간격(칸 수 − 1)이 장식 폭보다 좁아 칸에 폭이 남는다.
        expect(
          (CalcTheme.topStripSolarCellCount + 1) *
              CalcTheme.topStripSolarCellGapRatio,
          lessThan(CalcTheme.topStripSolarAspectRatio),
        );
        expect(2 * CalcTheme.topStripSolarCellGapRatio, lessThan(1));
        expect(CalcTheme.solarPanelCell, isNot(CalcTheme.solarPanelBackground));
        expect(CalcTheme.solarPanelBackground, isNot(CalcTheme.bodyBackground));
        expect(
          contrastRatio(
            CalcTheme.solarPanelCell,
            CalcTheme.solarPanelBackground,
          ),
          greaterThan(1.2),
        );
      });
    });
  });
}
