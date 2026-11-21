import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/lcd_status.dart';

import '../support/ttf_cmap.dart';

/// `pubspec.yaml`의 `flutter: fonts:` 항목을 패밀리 → 에셋 경로 목록으로 읽는다.
/// (테스트용 최소 파서: `- family:`와 `- asset:` 줄만 본다.)
Map<String, List<String>> _pubspecFonts() {
  final lines = File('pubspec.yaml').readAsLinesSync();
  final result = <String, List<String>>{};
  String? family;
  var inFonts = false;
  for (final line in lines) {
    if (line.trimLeft().startsWith('#')) continue;
    if (RegExp(r'^  fonts:\s*$').hasMatch(line)) {
      inFonts = true;
      continue;
    }
    if (inFonts && RegExp(r'^\S|^  \S').hasMatch(line)) inFonts = false;
    if (!inFonts) continue;
    final familyMatch = RegExp(r'^\s*- family:\s*(\S+)').firstMatch(line);
    if (familyMatch != null) {
      family = familyMatch.group(1);
      result[family!] = [];
      continue;
    }
    final assetMatch = RegExp(r'^\s*- asset:\s*(\S+)').firstMatch(line);
    if (assetMatch != null && family != null) {
      result[family]!.add(assetMatch.group(1)!);
    }
  }
  return result;
}

/// 패밀리의 모든 굵기 파일에 공통으로 있는 코드 포인트 (굵기마다 글리프가 같아야 한다).
Set<int> _familyCodePoints(List<String> assets) =>
    assets.map(readCmapCodePoints).reduce((a, b) => a.intersection(b));

String _describe(int code) =>
    '"${String.fromCharCode(code)}" U+${code.toRadixString(16).toUpperCase().padLeft(4, '0')}';

/// LCD 줄에 그려질 글자. 칸 수 계산(0.6em 고정폭)이 성립하려면 모두 기본(고정폭) 글꼴에 있어야 한다.
/// M2 이후 LCD에 새 글자를 쓰면 여기에 추가한다.
const String _lcdLineGlyphs =
    '0123456789.−+×÷()=,:' // 숫자·연산
    '⁰¹²³⁴⁵⁶⁷⁸⁹⁻' // 유니코드 위첨자 (지수)
    'E' // 지수 표기 대체 (Line 표시)
    'ABCDEFMxy' // 변수
    'πe∠i°\'"' // 상수·복소수·도분초
    '■□'; // 입력 칸

void main() {
  final fonts = _pubspecFonts();

  group('번들 글꼴 등록', () {
    test('테마가 쓰는 패밀리가 모두 pubspec에 등록되어 있고 파일이 있다', () {
      for (final family in [
        CalcTheme.monoFontFamily,
        ...CalcTheme.monoFontFallback,
      ]) {
        expect(fonts.keys, contains(family));
        expect(fonts[family], isNotEmpty, reason: family);
        for (final asset in fonts[family]!) {
          expect(File(asset).existsSync(), isTrue, reason: asset);
        }
      }
    });

    test('테마 스타일은 번들 글꼴과 대체 글꼴만 쓴다', () {
      for (final style in [
        CalcTheme.lcdInputStyle,
        CalcTheme.lcdResultStyle,
        CalcTheme.lcdStatusStyle,
        CalcTheme.keyMainLabelStyle,
        CalcTheme.keyShiftLabelStyle,
        CalcTheme.keyAlphaLabelStyle,
      ]) {
        expect(fonts.keys, contains(style.fontFamily));
        for (final fallback in style.fontFamilyFallback ?? const <String>[]) {
          expect(fonts.keys, contains(fallback));
        }
      }
    });

    test('기본 글꼴은 테마가 쓰는 굵기를 모두 정적 파일로 갖는다', () {
      final assets = fonts[CalcTheme.monoFontFamily]!;
      expect(assets, hasLength(4), reason: '400/500/600/700');
      final weights = {
        for (final style in [
          CalcTheme.lcdInputStyle,
          CalcTheme.lcdResultStyle,
          CalcTheme.lcdStatusStyle,
          CalcTheme.keyMainLabelStyle,
          CalcTheme.keyShiftLabelStyle,
          CalcTheme.keyAlphaLabelStyle,
        ])
          style.fontWeight!.value,
      };
      final suffix = {
        400: 'Regular',
        500: 'Medium',
        600: 'SemiBold',
        700: 'Bold',
      };
      for (final w in weights) {
        expect(
          assets.any((a) => a.endsWith('-${suffix[w]}.ttf')),
          isTrue,
          reason: 'weight $w',
        );
      }
    });
  });

  group('글리프 커버리지 (플랫폼 대체 글꼴 없이 그려진다)', () {
    final mono = _familyCodePoints(fonts[CalcTheme.monoFontFamily]!);
    final fallback = {
      for (final family in CalcTheme.monoFontFallback)
        ..._familyCodePoints(fonts[family]!),
    };

    test('50키의 모든 라벨 글자는 기본 글꼴 또는 번들 대체 글꼴에 있다', () {
      final missing = <String>{};
      for (final key in allKeys) {
        for (final label in [key.mainLabel, key.shiftLabel, key.alphaLabel]) {
          for (final code in (label ?? '').runes) {
            if (!mono.contains(code) && !fallback.contains(code)) {
              missing.add('${key.id.name}: ${_describe(code)}');
            }
          }
        }
      }
      expect(missing, isEmpty);
    });

    test('대체 글꼴이 필요한 라벨 글자는 ∑·∛·∫뿐이다', () {
      // 대체 글꼴(Noto Sans Math)은 고정폭이 아니다. 대체 글꼴로 그리는 글자가 늘면
      // 라벨 폭이 글자 수에 비례한다는 가정(각인 배분)이 더 어긋나므로 목록을 고정해 둔다.
      final viaFallback = {
        for (final key in allKeys)
          for (final label in [key.mainLabel, key.shiftLabel, key.alphaLabel])
            for (final code in (label ?? '').runes)
              if (!mono.contains(code)) String.fromCharCode(code),
      };
      expect(viaFallback, {'∑', '∛', '∫'});
    });

    test('LCD 줄·상태 표시줄 글자는 모두 고정폭 기본 글꼴에 있다', () {
      final glyphs = {
        ..._lcdLineGlyphs.runes,
        for (final slot in LcdIndicatorSlot.values) ...slot.template.runes,
        for (final c in ComplexResultIndicator.values)
          ...(c.indicator ?? '').runes,
        for (final unit in AngleUnit.values) ...unit.indicator.runes,
        for (final arrow in ['◄', '►', '▲', '▼']) ...arrow.runes,
      };
      final missing = [
        for (final code in glyphs)
          if (!mono.contains(code)) _describe(code),
      ];
      expect(missing, isEmpty);
    });
  });
}
