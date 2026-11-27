import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/lcd_status.dart';
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
    // 포커스 겹침은 테두리 안쪽에 맞닿는 면과의 인접 대비(추가 확인)다. 닫기 버튼(primary 10%)은
    // M3 버튼 기본 포커스 겹침이다. 설정 키(ON, #190)의 테두리는 원형 버튼 고리 가장자리에 그린다 — 실제 위젯이 이 값을 쓰는지는 `test/widget/material_theme_test.dart`가 확인한다.
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
        // 설정 키(ON)의 테두리는 원형 버튼 고리 가장자리에 그린다 (#190)
        '원형 버튼 고리': CalcTheme.roundKeyBezel,
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

    test(
      '입체 장식은 일반 모드만 그리고, 원형 버튼 이름 인쇄 색은 SHIFT 금색·ALPHA 자홍색·나머지 흰색이다 (#156)',
      () {
        expect(normal.drawsRelief, isTrue);
        expect(high.drawsRelief, isFalse);
        for (final p in [normal, high]) {
          for (final c in KeyCategory.values) {
            expect(p.bodyPrintOf(c), switch (c) {
              KeyCategory.shift => p.shiftLabel,
              KeyCategory.alpha => p.alphaLabel,
              _ => p.bodyPrint,
            }, reason: '${p.isHighContrast} ${c.name}');
          }
        }
        expect(normal.cursorPadGroove, CalcTheme.cursorPadGroove);
        expect(high.cursorPadGroove, CalcTheme.cursorPadGrooveHighContrast);
      },
    );

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
      expect(normal.noticeForeground, CalcTheme.noticeForeground);
      expect(normal.bodyPrint, CalcTheme.bodyPrint);
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
      // (고대비 색, 일반 색, 맞닿는 색) — 테두리는 본체, 커서 패드 홈은 방향 키캡과 맞닿는다(#156부터 홈은 따로 정한 어두운 색).
      for (final (hc, std, against) in [
        (high.keyBorder, normal.keyBorder, CalcTheme.bodyBackground),
        (high.cursorPadGroove, normal.cursorPadGroove, CalcTheme.keyCursor),
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

    test('화면 안내 글자는 본체 배경 대비 7:1 이상이고 일반 팔레트 이상이며, 고대비 각인보다는 덜 띈다', () {
      final hc = contrastRatio(high.noticeForeground, CalcTheme.bodyBackground);
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
          contrastRatio(normal.noticeForeground, CalcTheme.bodyBackground),
        ),
      );
    });

    test('본체 인쇄 글자(원형 버튼 위 SETTING, #190)는 본체 배경 대비 7:1 이상이고 일반 팔레트 이상이다', () {
      for (final body in [
        CalcTheme.bodyBackground,
        CalcTheme.bodyFrame,
        CalcTheme.bodyBottomGradient,
      ]) {
        final hc = contrastRatio(high.bodyPrint, body);
        expect(hc, greaterThanOrEqualTo(aaa), reason: '$body');
        expect(
          hc,
          greaterThanOrEqualTo(contrastRatio(normal.bodyPrint, body)),
          reason: '$body',
        );
      }
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
    test('LCD 스타일은 고정폭 폰트와 대체 폰트를 지정한다', () {
      for (final style in [
        CalcTheme.lcdInputStyle,
        CalcTheme.lcdResultStyle,
        CalcTheme.lcdStatusStyle,
      ]) {
        expect(style.fontFamily, CalcTheme.monoFontFamily);
        expect(style.fontFamilyFallback, CalcTheme.monoFontFallback);
        expect(style.fontSize, isNotNull);
        expect(style.fontSize!, greaterThan(0));
      }
    });

    test('키 각인 스타일은 비례폭 각인 글꼴과, 기호를 찾을 고정폭·수학 대체 글꼴을 지정한다 (#156)', () {
      for (final style in [
        CalcTheme.keyMainLabelStyle,
        CalcTheme.keyShiftLabelStyle,
        CalcTheme.keyAlphaLabelStyle,
        CalcTheme.keyBodyPrintStyle,
      ]) {
        expect(style.fontFamily, CalcTheme.keyFontFamily);
        expect(style.fontFamilyFallback, [
          CalcTheme.monoFontFamily,
          CalcTheme.mathFontFamily,
        ]);
        expect(style.fontSize, isNotNull);
        expect(style.fontSize!, greaterThan(0));
      }
      // 줄 상자는 #156 전 각인 글꼴(고정폭)의 것을 그대로 쓴다 — 2차원 각인 배치·키패드 글자 크기 계산이 그대로다.
      expect(CalcTheme.keyStrutFontFamily, CalcTheme.monoFontFamily);
    });

    test('변수 이탤릭 글자: x·y는 늘, e는 한 글자 각인일 때만 (#156)', () {
      bool italic(String text, int i) => CalcTheme.isKeyVariableLetter(text, i);
      expect(italic('x', 0), isTrue);
      expect(italic('x!', 0), isTrue);
      expect(italic('x!', 1), isFalse);
      expect(italic('dx', 0), isFalse);
      expect(italic('dx', 1), isTrue);
      expect(italic('y', 0), isTrue);
      expect(italic('π', 0), isTrue);
      // ⇔만 수학 글꼴로 그린다 (#156 R2)
      expect(CalcTheme.isKeyMathSymbol('⇔'), isTrue);
      expect(CalcTheme.isKeyMathSymbol('×'), isFalse);
      final symbol = CalcTheme.keyMathSymbolStyle(
        CalcTheme.keyMainLabelStyle.copyWith(fontSize: 12),
      );
      expect(symbol.fontFamily, CalcTheme.mathFontFamily);
      expect(symbol.fontWeight, FontWeight.w400);
      expect(symbol.fontSize, 12);
      expect(italic('e', 0), isTrue);
      expect(italic('Rec', 1), isFalse);
      expect(italic('SETUP', 1), isFalse);
      expect(italic('X', 0), isFalse);
      final style = CalcTheme.keyVariableStyle(
        CalcTheme.keyShiftLabelStyle.copyWith(fontSize: 11),
      );
      expect(style.fontFamily, CalcTheme.keyVariableFontFamily);
      expect(style.fontStyle, FontStyle.italic);
      expect(style.fontSize, 11);
      expect(style.color, CalcTheme.shiftLabel);
    });

    test('각인 스타일 색은 각인 팔레트와 일치한다', () {
      expect(CalcTheme.keyShiftLabelStyle.color, CalcTheme.shiftLabel);
      expect(CalcTheme.keyAlphaLabelStyle.color, CalcTheme.alphaLabel);
    });
  });

  group('치수', () {
    test('상태 아이콘 치수: 높이 비율은 x높이 < 대문자 높이 < 1, 선 굵기는 ‖ 두 획이 붙지 않을 만큼 가늘고, 상자 안 글자는 상자보다 작다 (#57, #160)', () {
      expect(CalcTheme.lcdStatusXHeightRatio, greaterThan(0));
      expect(
        CalcTheme.lcdStatusXHeightRatio,
        lessThan(CalcTheme.lcdStatusCapHeightRatio),
      );
      expect(CalcTheme.lcdStatusCapHeightRatio, lessThan(1));
      expect(CalcTheme.lcdStatusIconStrokeRatio, greaterThan(0));
      // ‖ 밝은 두 획 중심 간격 = 칸 폭(0.6em)의 26%(37%·63% 위치) — 획 굵기가 그보다 작아야 두 획 사이에
      // 어두운 부분이 남는다(#160).
      expect(
        CalcTheme.lcdStatusIconStrokeRatio,
        lessThan(0.26 * CalcTheme.lcdStatusCharWidthRatio),
      );
      // 상자 안 글자는 상자보다 작다(위아래에 상자가 남는다).
      expect(CalcTheme.lcdStatusBoxedLetterRatio, greaterThan(0));
      expect(CalcTheme.lcdStatusBoxedLetterRatio, lessThan(1));
      // →x의 x는 테두리에 붙지 않도록 상자 글자보다 작다.
      expect(CalcTheme.lcdStatusStoreXRatio, greaterThan(0));
      expect(
        CalcTheme.lcdStatusStoreXRatio,
        lessThan(CalcTheme.lcdStatusBoxedLetterRatio),
      );
      // →x 화살표(#183): 머리 끝은 상자 안으로 들어가되 머리 전체가 상자 안에 있지는 않다.
      expect(CalcTheme.lcdStatusStoreTipDepthCells, greaterThan(0));
      expect(
        CalcTheme.lcdStatusStoreHeadCells,
        greaterThan(CalcTheme.lcdStatusStoreTipDepthCells),
      );
      // →x 잉크 = x 상자 한 칸 + 상자 밖 화살표(머리가 내민 부분 + 몸통). 몸통이 남으려면(없으면 경로가 뒤집힌다)
      // 한 칸 + 머리가 내민 부분보다 넓어야 하고, 2칸 슬롯에 들어가야 한다. 몸통 0.1칸은 몸통 굵기(대문자 높이의
      // 0.26 ≈ 0.22칸)의 절반쯤 — 이보다 짧으면 몸통 없는 삼각형으로 보인다고 보고 둔 하한이다(측정값이 아니다).
      final headOutside =
          CalcTheme.lcdStatusStoreHeadCells -
          CalcTheme.lcdStatusStoreTipDepthCells;
      expect(
        CalcTheme.lcdStatusStoreInkCells,
        greaterThan(1 + headOutside + 0.1),
        reason: '몸통 0.1칸 이상',
      );
      expect(CalcTheme.lcdStatusStoreInkCells, lessThanOrEqualTo(2));
      // 실물 →x 잉크 폭은 대문자 높이(7도트)의 8/7배다(스프라이트 8도트, #58 표). 상한은 회귀 방지용이다:
      // 대문자 높이 대비 앱 폭(칸 × 0.6em ÷ 0.714em)이 지금(1.5칸 = 1.26배, 실물 +10%)에서 조금 여유를 둔 15%를
      // 넘지 않게 한다(약 1.56칸까지). #160의 1.88칸 + 자간은 약 1.58배였다.
      // 옆 반전 상자(S) 대비로는 1.5배 대 실물 1.14배다(앱 S 상자가 실물보다 좁은 탓 — CalcTheme 문서).
      final storeCapRatio =
          CalcTheme.lcdStatusStoreInkCells *
          CalcTheme.lcdStatusCharWidthRatio /
          CalcTheme.lcdStatusCapHeightRatio;
      expect(storeCapRatio, lessThanOrEqualTo(8 / 7 * 1.15));
      // √▭✎ 잉크(#217)는 3칸 슬롯 안에 들어가고, 대문자 높이 대비 폭이 스프라이트(14도트 ÷ 대문자 높이 7도트 =
      // 2.0배, #58 표)에서 5% 안이다. #160의 3칸 슬롯 전체(3칸만으로 2.52배, 자간 포함 10dp에서 약 2.66배)로
      // 되돌아가지 않게 한다. 가이드 인쇄 아이콘(S 상자 대비 1.86배)·#183 영상(약 1.7배)은 더 좁다 — 2.0배를 택한 이유는 CalcTheme 문서.
      expect(CalcTheme.lcdStatusMathInkCells, greaterThan(0));
      expect(
        CalcTheme.lcdStatusMathInkCells,
        lessThanOrEqualTo(LcdIndicatorSlot.math.columns),
      );
      final mathCapRatio =
          CalcTheme.lcdStatusMathInkCells *
          CalcTheme.lcdStatusCharWidthRatio /
          CalcTheme.lcdStatusCapHeightRatio;
      expect(mathCapRatio, closeTo(14 / 7, 2.0 * 0.05));
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
      // 키캡 크기 (#220): 실물 키캡 가로/세로 비(함수 약 1.85, 숫자 약 1.49)와 키캡 폭 하한(실물 키 사이보다 넓히지 않는다)
      expect(CalcTheme.keyCapMaxAspectRatio, closeTo(1.85, 0.05));
      expect(CalcTheme.keyCapNumberMaxAspectRatio, closeTo(1.49, 0.05));
      expect(
        CalcTheme.keyCapNumberMaxAspectRatio,
        lessThan(CalcTheme.keyCapMaxAspectRatio),
      );
      expect(CalcTheme.keyCapMinWidthRatio, inInclusiveRange(0.8, 1.0));
      // 폭 하한에서 키캡 폭 / 가로 간격(열 폭)이 실물(함수부 약 0.82, 숫자부 약 0.81)과 2% 안이다 — 셀은 열 폭에서
      // 키 사이 간격(키패드 폭 × keyHorizontalGapRatio)을 뺀 폭이다(함수부 6열, 숫자부 5열).
      for (final (columns, real) in [(6, 0.82), (5, 0.81)]) {
        final cellPerPitch = 1 - columns * CalcTheme.keyHorizontalGapRatio;
        expect(
          CalcTheme.keyCapMinWidthRatio * cellPerPitch,
          closeTo(real, 0.02),
          reason: '$columns열',
        );
      }
      expect(CalcTheme.keyBorderWidth, greaterThan(0));
      expect(CalcTheme.keyPressedOffset, greaterThanOrEqualTo(0));
      expect(CalcTheme.keyMaxTextScaleFactor, inInclusiveRange(1.0, 2.0));
      expect(
        CalcTheme.keyPressAnimationDuration,
        lessThanOrEqualTo(const Duration(milliseconds: 100)),
      );
    });

    test('2차원 각인 배치 상수 (#155)', () {
      // 크기 비율은 바탕 글자보다 작다(첨자·분자·분모·근호 지수). 각인 전체가 분수 하나일 때만 더 크게 그린다.
      for (final scale in [
        CalcTheme.keyLegendScriptScale,
        CalcTheme.keyLegendFractionScale,
        CalcTheme.keyLegendRadicalIndexScale,
      ]) {
        expect(scale, inExclusiveRange(0.4, 1));
      }
      expect(
        CalcTheme.keyLegendFractionScale,
        lessThan(CalcTheme.keyLegendDisplayFractionScale),
      );
      expect(CalcTheme.keyLegendDisplayFractionScale, lessThanOrEqualTo(1));
      // 위치·두께·간격 비율은 글자 크기보다 작은 양수다.
      for (final ratio in [
        CalcTheme.keyLegendSuperscriptRaise,
        CalcTheme.keyLegendSubscriptDrop,
        CalcTheme.keyLegendScriptGap,
        CalcTheme.keyLegendFractionAxis,
        CalcTheme.keyLegendFractionBarThickness,
        CalcTheme.keyLegendFractionGap,
        CalcTheme.keyLegendFractionOverhang,
        CalcTheme.keyLegendDisplayFractionBarThickness,
        CalcTheme.keyLegendDisplayFractionGap,
        CalcTheme.keyLegendBoxStrokeRatio,
        CalcTheme.keyLegendRadicalStroke,
        CalcTheme.keyLegendRadicalGap,
        CalcTheme.keyLegendRadicalSignWidth,
      ]) {
        expect(ratio, inExclusiveRange(0, 1));
      }
      // 분수 가로줄 아래 가장자리와 간격을 빼도 기준선 위다 — 분모가 바탕 글자보다 지나치게 내려가지 않는다.
      expect(
        CalcTheme.keyLegendFractionAxis -
            CalcTheme.keyLegendFractionBarThickness / 2 -
            CalcTheme.keyLegendFractionGap,
        greaterThan(0),
      );
      // 선은 아무리 작은 각인에서도 보인다(1dp 미만의 얇은 선은 화면에 따라 흐려진다 — 1dp를 넘지 않게 둔다).
      expect(CalcTheme.keyLegendMinStroke, inExclusiveRange(0, 1));
    });

    test('최소 선 두께로 굵게 칠해도 분수·근호 가로줄 옆 여백이 남는다 — 작은 분수는 각인 4dp, 분수 키·근호는 3.2dp부터 (#155 R2, #206 R2)', () {
      // 배치는 비율 두께로 하고 칠은 최소 두께로 굵게 한다. 굵어진 만큼은 가로줄 옆 여백을 덮는다
      // (분수는 가운데 기준으로 위아래 절반씩, 근호 가로줄은 안쪽(아래)으로 전부 — key_legend_view.dart).
      // 평소 화면의 각인은 6dp 이상이다. 작은 분수(가로줄 0.06em)는 4dp(짧은 창 하한 각인 약 3.2dp보다 조금 큰 값)부터
      // 여백이 남는다(#155 R2). 굵은 분수 키 가로줄(0.146em)·근호(0.14em)는 3.4~3.6dp 아래에서만 최소 두께가 걸리므로
      // 짧은 창 하한 3.2dp부터 본다(#206 R2).
      for (var f = 3.2; f <= 12; f += 0.1) {
        for (final (barRatio, gapRatio) in [
          if (f >= 4 - 1e-9)
            (
              CalcTheme.keyLegendFractionBarThickness,
              CalcTheme.keyLegendFractionGap,
            ),
          (
            CalcTheme.keyLegendDisplayFractionBarThickness,
            CalcTheme.keyLegendDisplayFractionGap,
          ),
        ]) {
          final bar = f * barRatio;
          final paintBar = bar > CalcTheme.keyLegendMinStroke
              ? bar
              : CalcTheme.keyLegendMinStroke;
          expect(
            f * gapRatio - (paintBar - bar) / 2,
            greaterThan(0),
            reason: '분수 $f ($barRatio)',
          );
        }
        final stroke = f * CalcTheme.keyLegendRadicalStroke;
        final paintStroke = stroke > CalcTheme.keyLegendMinStroke
            ? stroke
            : CalcTheme.keyLegendMinStroke;
        expect(
          f * CalcTheme.keyLegendRadicalGap - (paintStroke - stroke),
          greaterThan(0),
          reason: '근호 $f',
        );
      }
    });

    test(
      '∑ 각인 상수 (#169): 칸은 납작하고 끝 칸이 본문 칸보다 넓으며, 쌓은 높이가 d/dx◼(약 1.141em)보다 낮다',
      () {
        expect(CalcTheme.keyLegendLimitBaseScale, inExclusiveRange(0.3, 1));
        expect(CalcTheme.keyLegendSumBoxHeightRatio, inExclusiveRange(0, 1));
        expect(CalcTheme.keyLegendSumLimitWidthRatio, greaterThan(1));
        expect(
          CalcTheme.keyLegendSumLimitWidthRatio,
          greaterThan(CalcTheme.keyLegendSumOperandWidthRatio),
        );
        expect(
          CalcTheme.keyLegendSumOperandWidthRatio,
          greaterThan(CalcTheme.keyLegendSumBoxHeightRatio),
        ); // 본문 칸도 납작하다
        expect(CalcTheme.keyLegendLimitGap, inExclusiveRange(0, 0.1));
        // ∑ 잉크 범위 0.954em (Noto Sans Math, KeyLegendView.glyphInk) — 쌓은 잉크 높이식
        const sigma = 0.954 * CalcTheme.keyLegendLimitBaseScale;
        const stack =
            sigma +
            2 * sigma * CalcTheme.keyLegendSumBoxHeightRatio +
            2 * CalcTheme.keyLegendLimitGap;
        expect(stack, lessThan(1.141));
      },
    );

    test('칸 모양 상수 (#186): 사진대로 log 진수 칸은 세로로 길고, ∫ 본문·분수 칸은 가로로 길다', () {
      double ratio(LegendBoxShape s) => CalcTheme.keyLegendBoxAspectRatio(s);
      for (final shape in LegendBoxShape.values) {
        expect(ratio(shape), inExclusiveRange(0.4, 2.5), reason: '$shape');
      }
      // ∑ 칸은 #169의 ∑ 기준 상수에서 나온다(사진 9×4·8×4px).
      expect(ratio(LegendBoxShape.sumLimit), moreOrLessEquals(9 / 4));
      expect(ratio(LegendBoxShape.sumOperand), moreOrLessEquals(8 / 4));
      // 세로로 긴 칸: log 진수(1:2), log 밑(조금)
      expect(ratio(LegendBoxShape.logArgument), inInclusiveRange(0.45, 0.55));
      expect(ratio(LegendBoxShape.logBase), lessThan(1));
      // 가로로 긴 칸: 사진에서 비가 1.3을 넘는 칸
      for (final shape in [
        LegendBoxShape.integralOperand,
        LegendBoxShape.fractionPart,
        LegendBoxShape.mixedFractionPart,
        LegendBoxShape.derivativeOperand,
      ]) {
        expect(ratio(shape), greaterThan(1.3), reason: '$shape');
      }
      expect(ratio(LegendBoxShape.integralOperand), greaterThan(2));
      // 나머지는 정사각형에 가깝다(사진 번짐 ±1px 안)
      for (final shape in [
        LegendBoxShape.integralLimit,
        LegendBoxShape.mixedWhole,
        LegendBoxShape.squareRootRadicand,
        LegendBoxShape.cubeRootRadicand,
        LegendBoxShape.rootIndex,
        LegendBoxShape.rootRadicand,
        LegendBoxShape.powerExponent,
        LegendBoxShape.tenPowerExponent,
        LegendBoxShape.ePowerExponent,
      ]) {
        expect(ratio(shape), inInclusiveRange(1, 1.3), reason: '$shape');
      }
      // 글꼴 ◼의 좌우 여백 (0.6em 칸 − 잉크 0.482em의 절반 — 실제 글꼴 값은 위젯 테스트가 확인)
      expect(CalcTheme.keyLegendBoxSideBearing, moreOrLessEquals(0.059));
      // ∫ 아래 끝 칸 당김: 사진 9px ÷ 메인 각인 글자 크기 약 33px ≈ 0.27em (∫ 꼬리와 떨어져 있는지는 위젯 테스트가 본다)
      expect(
        CalcTheme.keyLegendIntegralSubscriptShift,
        inInclusiveRange(0.2, 0.3),
      );
      // ∫ 본문 칸 높이: 사진 12px(비 25/12와 같은 경계) ÷ 33px ≈ 0.36em, 글꼴 칸(0.482em)보다 낮다
      expect(
        CalcTheme.keyLegendIntegralOperandHeight,
        inInclusiveRange(0.33, 0.40),
      );
      // 분수 키 가로줄 나감: 가로줄/칸 잉크 폭이 사진(37~38px / 25~26px ≈ 1.46)과 같다(#186 R1, #206에서 칸 배율을
      // 바꾸며 다시 맞춤). 칸 잉크 폭 = ◼ 잉크 높이 0.482 × 칸 배율 × 25/14, 칸 조각 폭 = 잉크 + 좌우 여백.
      const s = CalcTheme.keyLegendDisplayFractionScale;
      final boxInk =
          0.482 *
          s *
          CalcTheme.keyLegendBoxAspectRatio(LegendBoxShape.fractionPart);
      final barWidth =
          boxInk +
          2 * CalcTheme.keyLegendBoxSideBearing * s +
          2 * CalcTheme.keyLegendDisplayFractionOverhang;
      expect(barWidth / boxInk, moreOrLessEquals(1.46, epsilon: 0.01));
      expect(
        CalcTheme.keyLegendDisplayFractionOverhang,
        greaterThan(CalcTheme.keyLegendFractionOverhang),
      );
    });

    test('빈 칸 테두리는 칸 짧은 변의 사진 비율이고, 구멍이 칸의 절반 이상 남는다 (#206, #169 R2)', () {
      // 근접 사진의 빈 칸 테두리: 칸 짧은 변의 0.24~0.31 (분수 키 분모 0.26, ∫ 끝 칸 0.28~0.31, log 진수 칸 0.24).
      expect(CalcTheme.keyLegendBoxStrokeRatio, inInclusiveRange(0.24, 0.31));
      // 테두리는 칸 안쪽에 칠하므로 구멍 = 1 − 2 × 비율. 칸 크기에 비례하므로 글자 크기(짧은 창 하한 각인 약 3.2dp
      // 포함)와 상관없이 구멍이 칸의 절반 이상이다 — 작은 각인에서도 빈 칸이 채운 칸처럼 메워지지 않는다(#169 R2).
      expect(
        1 - 2 * CalcTheme.keyLegendBoxStrokeRatio,
        greaterThanOrEqualTo(0.5 - 1e-9),
      );
    });

    test('분수 키 가로줄·간격·칸은 사진 비율이고, 작은 분수보다 굵다 (#206)', () {
      // 근접 사진(메인 각인 글자 크기 33.5px): 가로줄 4.9px, 간격 2.4~2.5px, 칸 높이 14px(분자 13.6·분모 14.4px)
      expect(
        CalcTheme.keyLegendDisplayFractionBarThickness,
        moreOrLessEquals(4.9 / 33.5, epsilon: 0.01),
      );
      expect(
        CalcTheme.keyLegendDisplayFractionGap,
        moreOrLessEquals(2.45 / 33.5, epsilon: 0.01),
      );
      // 칸 높이 = 글꼴 ◼ 잉크 0.482em × 분수 키 배율
      const box = 0.482 * CalcTheme.keyLegendDisplayFractionScale;
      expect(box, moreOrLessEquals(14 / 33.5, epsilon: 0.01));
      // 각인 높이 = 칸 둘 + 간격 둘 + 가로줄: 사진 37.9px ≈ 1.13em. 메인 라벨 높이 맞춤을 바꾸지 않는지(가장 높은 메인
      // 각인 ∫◻◻◼ 이하)는 실제 배치로 위젯 테스트가 본다.
      const height =
          2 * box +
          2 * CalcTheme.keyLegendDisplayFractionGap +
          CalcTheme.keyLegendDisplayFractionBarThickness;
      expect(height, moreOrLessEquals(37.9 / 33.5, epsilon: 0.02));
      // 작은 분수는 높이 예산 때문에 가늘게 둔다(CalcTheme "2차원 각인 배치" 절)
      expect(
        CalcTheme.keyLegendDisplayFractionBarThickness,
        greaterThan(CalcTheme.keyLegendFractionBarThickness),
      );
      expect(
        CalcTheme.keyLegendDisplayFractionGap,
        greaterThan(CalcTheme.keyLegendFractionGap),
      );
      // 근호: 사진 가로줄 4.8px·비스듬한 획 약 4.6px
      expect(
        CalcTheme.keyLegendRadicalStroke,
        moreOrLessEquals(4.7 / 33.5, epsilon: 0.01),
      );
    });

    test('키 간격 비율은 0~0.1 사이의 양수다', () {
      expect(CalcTheme.keyHorizontalGapRatio, inExclusiveRange(0, 0.1));
      expect(CalcTheme.keyVerticalGapRatio, inExclusiveRange(0, 0.1));
    });

    test('키패드 배치 상수: 숫자 행이 더 크고, 가로/세로 비 하한은 키가 세로로 길어지지 않는 0~1 사이다', () {
      expect(CalcTheme.keypadNumberRowHeightRatio, inInclusiveRange(1.0, 2.0));
      expect(CalcTheme.keypadSectionGapRatio, inExclusiveRange(0, 0.1));
      // 가로 쪽 상한은 없다 (#141) — 하한만 둔다.
      expect(CalcTheme.keypadMinAspectRatio, inExclusiveRange(0, 1));
      expect(CalcTheme.keyMinTouchTargetHeight, greaterThanOrEqualTo(44));
    });

    test('키 글자 크기 상한: 양수이고 각인이 메인 라벨보다 작다 (#141)', () {
      expect(CalcTheme.keyMainLabelMaxFontSize, greaterThan(0));
      expect(CalcTheme.keyLegendMaxFontSize, greaterThan(0));
      expect(
        CalcTheme.keyLegendMaxFontSize,
        lessThan(CalcTheme.keyMainLabelMaxFontSize),
      );
      // 폰에 걸리지 않는지·태블릿에서 멈추는지는 calc_keypad_test가 번들 글꼴로 실측한다.
    });

    test('통일 글자 하한 비율은 0.5~1, 커서 패드 경계선은 양수 두께다', () {
      expect(CalcTheme.keypadUniformFontMinRatio, inInclusiveRange(0.5, 1.0));
      expect(CalcTheme.cursorPadDividerWidth, greaterThan(0));
      expect(CalcTheme.keyLegendPriorityMaxRunes, inInclusiveRange(1, 3));
    });

    test('커서 패드 모양 상수: 가로로 긴 둥근 마름모·대각선보다 가파른 홈·데드존보다 큰 허브 (#43·#65)', () {
      // 가로로 긴 패드: 비율 하한이 1보다 크고 하한 < 상한
      expect(CalcTheme.cursorPadMinAspectRatio, greaterThan(1.0));
      expect(
        CalcTheme.cursorPadMinAspectRatio,
        lessThan(CalcTheme.cursorPadMaxAspectRatio),
      );
      // 2이면 타원, 무한대면 뾰족한 마름모 — 2보다 크고 너무 크지 않아야 꼭짓점이 둥근 마름모다.
      expect(CalcTheme.cursorPadOutlineExponent, inExclusiveRange(2.0, 6.0));
      // 실물처럼 1보다 작아야 홈이 상자 대각선보다 가팔라 ▲·▼가 위·아래 띠, ◀·▶가 넓은 구역이 된다(실측 0.9, #65).
      // 너무 작으면 ▲·▼가 누르기 어렵게 좁아진다.
      expect(CalcTheme.cursorPadGrooveSlope, inExclusiveRange(0.5, 1.0));
      // 허브는 반높이(짧은 쪽)의 3/4 미만이고(넘으면 그린 ▲·▼가 외곽 쪽 얇은 띠만 남는다, 실측 0.5),
      // 데드존은 허브보다 작은 양수다. 실제 터치 깊이·라벨 위치는 위젯·화면 테스트가 화면 크기별로 확인한다.
      expect(CalcTheme.cursorPadHubRadiusRatio, inExclusiveRange(0.0, 0.75));
      expect(CalcTheme.cursorPadDeadZoneRadiusRatio, greaterThan(0));
      expect(
        CalcTheme.cursorPadDeadZoneRadiusRatio,
        lessThan(CalcTheme.cursorPadHubRadiusRatio),
      );
    });

    test('커서 패드 허브·홈은 은색 방향 키캡보다 어둡고 3:1 이상 구분된다 (#156)', () {
      expect(
        lightness(CalcTheme.cursorPadHub),
        lessThan(lightness(CalcTheme.keyCursor)),
      );
      for (final c in [
        CalcTheme.cursorPadHub,
        CalcTheme.cursorPadGroove,
        CalcTheme.cursorPadGrooveHighContrast,
      ]) {
        expect(
          contrastRatio(c, CalcTheme.keyCursor),
          greaterThanOrEqualTo(3.0),
          reason: '$c',
        );
      }
      expect(CalcTheme.cursorPadGrooveWidthRatio, inExclusiveRange(0.0, 0.1));
    });

    test('키캡 입체감 상수 (#156): 모서리 반경 비는 숫자부가 덜 둥글고, 광택은 글자 자리(가운데)를 비운다', () {
      expect(
        CalcTheme.keyCapNumberCornerRadiusRatio,
        lessThan(CalcTheme.keyCapCornerRadiusRatio),
      );
      expect(CalcTheme.keyCapCornerRadiusRatio, inExclusiveRange(0.0, 0.5));
      expect(CalcTheme.keyCapMaxCornerRadius, greaterThan(0));
      // 옆면은 눌림 이동이 비워 둔 셀 안 자리에 그린다 — 깊이가 같아야 셀 밖으로 나가지 않고 눌린 키캡이 옆면을 덮는다.
      expect(CalcTheme.keyCapSideDepth, CalcTheme.keyPressedOffset);
      expect(CalcTheme.keyCapSheenClearStart, inExclusiveRange(0.0, 0.5));
      expect(CalcTheme.keyCapSheenClearEnd, inExclusiveRange(0.5, 1.0));
      // 광택·그늘은 반투명 덧칠이다
      for (final c in [
        CalcTheme.keyCapSheen,
        CalcTheme.keyCapGloss,
        CalcTheme.keyCapShade,
        CalcTheme.keyCapSide,
      ]) {
        expect(c.a, inExclusiveRange(0.0, 1.0), reason: '$c');
      }
    });

    test('숫자부 메인 각인 크기 (#225): 숫자 키캡 비율은 실물 글자/키캡 비로 함수부 비율에서 이끈 값이다', () {
      // 근접 사진(같은 모양 글자끼리): 숫자 / 숫자 키캡 45/80, 대문자 / 함수 키캡 26/55. Saira는 숫자·대문자 잉크 높이가 같다.
      const derived = CalcTheme.keyMainLabelFontRatio * (45 / 80) / (26 / 55);
      expect(CalcTheme.keyNumberMainLabelFontRatio, closeTo(derived, 0.005));
      expect(
        CalcTheme.keyNumberMainLabelFontRatio,
        greaterThan(CalcTheme.keyMainLabelFontRatio),
      );
      expect(
        CalcTheme.keyNumberMainLabelMaxFontSize,
        greaterThan(CalcTheme.keyMainLabelMaxFontSize),
      );
      // 글자 각인은 숫자보다 작고(실물 약 0.83), 연산 기호는 숫자 대비 크게 키운다(실물/Mono 비 1.38~1.47 — 평균은 number_label_size_test가 고정한다)
      expect(CalcTheme.keyNumberWordLabelScale, inExclusiveRange(0.8, 0.86));
      expect(
        CalcTheme.keyNumberOperatorLabelScale,
        inInclusiveRange(1.38, 1.47),
      );
    });

    test(
      '숫자부 연산 기호 스타일 (#225): Noto Sans Mono Medium, 줄 상자·자간 규칙은 메인 라벨과 같다',
      () {
        const op = CalcTheme.keyNumberOperatorLabelStyle;
        expect(op.fontFamily, CalcTheme.monoFontFamily);
        expect(op.fontFamily, CalcTheme.keyStrutFontFamily);
        expect(op.fontWeight, FontWeight.w500);
        expect(op.letterSpacing, 0);
        expect(op.height, CalcTheme.keyMainLabelStyle.height);
      },
    );

    test('연산 기호 각인 (#225): 메인 각인이 연산 기호 한 글자인 키는 숫자부 × ÷ + − = 다섯 키뿐이다', () {
      final numberIds = {for (final r in numberRows) ...r.map((d) => d.id)};
      final operators = {
        for (final d in allKeys)
          if (CalcTheme.isKeyOperatorLegend(d.mainLegend)) d.id,
      };
      expect(operators, {
        CalcKeyId.multiply,
        CalcKeyId.divide,
        CalcKeyId.add,
        CalcKeyId.subtract,
        CalcKeyId.equals,
      });
      expect(numberIds.containsAll(operators), isTrue);
      // 다른 글자 사이의 기호·SHIFT·ALPHA 각인은 연산 기호 각인이 아니다
      for (final text in ['M+', '(−)', '×10', '==', '']) {
        expect(CalcTheme.isKeyOperatorLegend(LegendText(text)), isFalse);
      }
      expect(
        CalcTheme.keyMainLabelStyleFor(const LegendText('7')),
        CalcTheme.keyMainLabelStyle,
      );
      expect(
        CalcTheme.keyMainLabelStyleFor(const LegendText('×')),
        CalcTheme.keyNumberOperatorLabelStyle,
      );
    });

    test('본체 바탕 (#156): 그라데이션 아래 끝과 잔무늬 색이 각인 대비를 검사하는 본체 색 범위 안이다', () {
      // 잔무늬 밝은 면 = bodyFrame, 어두운 면 = bodyBottomGradient — 둘 다 "모든 본체 색" 대비 검사 대상이다.
      expect(
        lightness(CalcTheme.bodyFrame),
        greaterThan(lightness(CalcTheme.bodyBackground)),
      );
      expect(
        lightness(CalcTheme.bodyBottomGradient),
        lessThan(lightness(CalcTheme.bodyBackground)),
      );
      expect(CalcTheme.bodyTexturePitch, greaterThan(0));
      expect(CalcTheme.bodyRimWidth, greaterThan(0));
      expect(CalcTheme.bodyRimWidth, lessThan(CalcTheme.screenPadding / 2));
    });

    test(
      'LCD 베젤 (#156): 검은 베젤은 바깥 테두리로 본체와 구분되고, 유리 그늘을 덧칠해도 LCD 글자는 4.5:1 이상이다',
      () {
        expect(
          lightness(CalcTheme.lcdFrame),
          lessThan(lightness(CalcTheme.bodyBackground)),
        );
        expect(
          contrastRatio(CalcTheme.lcdBezelEdge, CalcTheme.lcdFrame),
          greaterThanOrEqualTo(1.5),
        );
        final shaded = Color.alphaBlend(
          CalcTheme.lcdGlassShade,
          CalcTheme.lcdBackground,
        );
        for (final text in [CalcTheme.lcdText, CalcTheme.lcdStatusActive]) {
          expect(
            contrastRatio(text, shaded),
            greaterThanOrEqualTo(minTextContrast),
          );
        }
        expect(CalcTheme.lcdGlassShadeExtent, inExclusiveRange(0.0, 0.5));
      },
    );

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

  group('가로형·접힘선 기준 배치 (#142, #25)', () {
    test(
      '가로형 기록 영역 문턱: LCD 최소 높이보다 높다 — 가로 폰처럼 위 띠가 LCD 최소 높이에 묶인 창에는 두지 않는다',
      () {
        expect(
          CalcTheme.screenLandscapeHistoryMinHeight,
          greaterThan(CalcTheme.screenLcdMinHeight),
        );
        // 문턱이 최소 높이보다 높아야 기록이 생기고 없어지는 경계에서 활성 LCD가 최대 높이에 걸리지 않는다 — 최대 높이가
        // 최소 높이로 올려진 좁은 블록은 위 띠가 최소 높이라 문턱에 닿지 않는다(CalcLandscapeLayout, screen_layout_test).
      },
    );

    test('키 터치 하한: 터치 확장 기준 이하의 양수 (#25)', () {
      expect(CalcTheme.keyTouchHeightFloor, greaterThan(0));
      expect(
        CalcTheme.keyTouchHeightFloor,
        lessThanOrEqualTo(CalcTheme.keyMinTouchTargetHeight),
      );
    });

    test('Flip 위 패널 기록 영역 (#143): 간격은 0 이상, 문턱은 LCD 최소 높이 이상', () {
      expect(CalcTheme.screenLcdHistoryGap, greaterThanOrEqualTo(0));
      expect(
        CalcTheme.screenHistoryBelowLcdMinHeight,
        greaterThanOrEqualTo(CalcTheme.screenLcdMinHeight),
      );
    });

    test('넓은 키패드 배열 블록 간격: 키 사이 가로 간격보다 넓고 블록 폭보다 훨씬 좁다 (#80)', () {
      expect(
        CalcTheme.keypadWideSectionGapRatio,
        greaterThan(CalcTheme.keyHorizontalGapRatio),
      );
      expect(CalcTheme.keypadWideSectionGapRatio, lessThan(0.2));
    });

    test('쓸 수 있는 키 최소: 일반 하한보다 낮은 양수 (#38)', () {
      expect(CalcTheme.keyTouchHeightUsableMin, greaterThan(0));
      expect(
        CalcTheme.keyTouchHeightUsableMin,
        lessThan(CalcTheme.keyTouchHeightFloor),
      );
      expect(CalcTheme.windowTooSmallIconSize, greaterThan(0));
      expect(CalcTheme.windowTooSmallFontSize, greaterThan(0));
      expect(CalcTheme.windowTooSmallPadding, greaterThanOrEqualTo(0));
    });

    test('접힘선 간격: 양수 (#25)', () {
      expect(CalcTheme.screenHingeMargin, greaterThan(0));
    });

    test('화면 안내 글자는 본체 배경 대비 4.5:1 이상이다', () {
      expect(
        contrastRatio(CalcTheme.noticeForeground, CalcTheme.bodyBackground),
        greaterThanOrEqualTo(minTextContrast),
      );
    });
  });

  group('원형 버튼 (#190)', () {
    test('원판은 고리 안에 들고, 결은 밝은 결·어두운 결이 구분되며, 눌림은 원판을 어둡게 한다', () {
      expect(CalcTheme.roundKeyDiscRatio, inExclusiveRange(0.5, 1));
      expect(CalcTheme.roundKeySilverStreaks, greaterThanOrEqualTo(2));
      expect(
        contrastRatio(
          CalcTheme.roundKeySilverLight,
          CalcTheme.roundKeySilverDark,
        ),
        greaterThan(1.5),
      );
      expect(CalcTheme.roundKeyPressedOverlay.a, greaterThan(0));
      expect(CalcTheme.roundKeyPressedOverlay.r, 0);
    });

    test('은색 원판은 어두운 고리와 3:1 이상 구분되고, 고리는 본체보다 어둡다', () {
      for (final silver in [
        CalcTheme.roundKeySilverLight,
        CalcTheme.roundKeySilverDark,
      ]) {
        expect(
          contrastRatio(silver, CalcTheme.roundKeyBezel),
          greaterThanOrEqualTo(3),
          reason: '$silver',
        );
      }
      expect(
        CalcTheme.roundKeyBezel.computeLuminance(),
        lessThan(CalcTheme.bodyBackground.computeLuminance()),
      );
    });

    test('본체 인쇄 글자 스타일은 각인과 같은 글꼴·줄 높이·자간이다 (키패드 각인 크기 계산을 공유한다)', () {
      const print = CalcTheme.keyBodyPrintStyle;
      const shift = CalcTheme.keyShiftLabelStyle;
      expect(print.fontFamily, shift.fontFamily);
      expect(print.fontFamilyFallback, shift.fontFamilyFallback);
      expect(print.height, shift.height);
      expect(print.letterSpacing, 0);
      expect(print.fontSize, shift.fontSize);
      expect(print.color, CalcTheme.bodyPrint);
      expect(
        contrastRatio(CalcTheme.bodyPrint, CalcTheme.bodyBackground),
        greaterThanOrEqualTo(minTextContrast),
      );
    });
  });

  group('본체 아래 여백 규칙 (screenBottomMargin, #63)', () {
    test('실측한 기기들은 화면 여백 그대로다 (#63)', () {
      // (인셋, 제스처 영역) — CalcTheme.screenBottomMargin 문서의 실측값
      for (final (padding, gesture) in const [
        (24.0, 32.0), // API 36 폰, 제스처 내비게이션
        (48.0, 48.0), // 같은 폰, 3버튼
        (32.0, 32.0), // API 36 Pixel Fold 내부
        (0.0, 8.0), // API 33 폰, 제스처 내비게이션(edge-to-edge 아님)
        (34.0, 0.0), // iOS — 제스처 영역을 전달하지 않는다
        (0.0, 0.0),
      ]) {
        expect(
          CalcTheme.screenBottomMargin(
            bottomInset: padding,
            bottomGestureInset: gesture,
          ),
          CalcTheme.screenPadding,
          reason: '인셋 $padding / 제스처 $gesture',
        );
      }
    });

    test('제스처 영역이 인셋보다 화면 여백 넘게 깊으면 그 차이만큼 넓힌다', () {
      expect(
        CalcTheme.screenBottomMargin(bottomInset: 0, bottomGestureInset: 32),
        32,
      );
      expect(
        CalcTheme.screenBottomMargin(bottomInset: 24, bottomGestureInset: 48),
        24,
      );
      // 본체 아래 끝(화면 높이 − 인셋 − 여백)이 언제나 제스처 영역 윗변(화면 높이 − 제스처 영역) 이상 위에 있고,
      // 여백은 화면 여백보다 작아지지 않는다.
      for (final padding in [0.0, 8.0, 24.0, 48.0]) {
        for (final gesture in [0.0, 8.0, 24.0, 32.0, 40.0, 64.0]) {
          final margin = CalcTheme.screenBottomMargin(
            bottomInset: padding,
            bottomGestureInset: gesture,
          );
          expect(margin, greaterThanOrEqualTo(CalcTheme.screenPadding));
          expect(padding + margin, greaterThanOrEqualTo(gesture));
        }
      }
    });
  });
}
