import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/lcd_status.dart';
import 'package:material_ui/material_ui.dart' show FontStyle;

import '../support/lcd_glyphs.dart';
import '../support/ttf_cmap.dart';

/// 앱 번들의 `FontManifest.json`(= `pubspec.yaml`의 `fonts:`를 빌드 도구가 변환한 것)을
/// 패밀리 → 에셋 경로 목록으로 읽는다. 엔진이 실제로 읽는 파일이라 pubspec 문법에 기대지 않는다.
Future<Map<String, List<String>>> _manifestFonts() async {
  final manifest = jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  return {
    for (final entry in manifest.cast<Map<String, dynamic>>())
      entry['family'] as String: [
        for (final font
            in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>())
          font['asset'] as String,
      ],
  };
}

/// 패밀리의 모든 굵기 파일에 공통으로 있는 코드 포인트 (굵기마다 글리프가 같아야 한다).
/// 글꼴은 앱 번들(`rootBundle`)에서 읽는다 — 엔진이 실제로 로드하는 데이터와 같다.
Future<Set<int>> _familyCodePoints(List<String> assets) async {
  final sets = [
    for (final asset in assets)
      readCmapCodePoints(await rootBundle.load(asset)),
  ];
  return sets.reduce((a, b) => a.intersection(b));
}

String _describe(int code) =>
    '"${String.fromCharCode(code)}" U+${code.toRadixString(16).toUpperCase().padLeft(4, '0')}';

const _themeStyles = [
  CalcTheme.lcdInputStyle,
  CalcTheme.lcdResultStyle,
  CalcTheme.lcdStatusStyle,
  CalcTheme.keyMainLabelStyle,
  CalcTheme.keyShiftLabelStyle,
  CalcTheme.keyAlphaLabelStyle,
  CalcTheme.keyBodyPrintStyle,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, List<String>> fonts;
  late Set<int> mono;
  late Set<int> fallback;
  late Set<int> key;
  late Set<int> variable;
  setUpAll(() async {
    fonts = await _manifestFonts();
    mono = await _familyCodePoints(fonts[CalcTheme.monoFontFamily]!);
    fallback = {
      for (final family in CalcTheme.monoFontFallback)
        ...await _familyCodePoints(fonts[family]!),
    };
    key = await _familyCodePoints(fonts[CalcTheme.keyFontFamily]!);
    variable = await _familyCodePoints(fonts[CalcTheme.keyVariableFontFamily]!);
  });

  /// 키 각인 글자 [code]를 그리는 패밀리 — 변수 이탤릭이면 이탤릭 글꼴, 아니면 각인 글꼴 → 대체 글꼴 순서로 처음
  /// 글자가 있는 패밀리 (#156, [CalcTheme.keyFontFallback]). 없으면 `null`.
  Future<String?> keyFamilyOf(String text, int index) async {
    final code = text.codeUnitAt(index);
    if (CalcTheme.isKeyVariableLetter(text, index)) {
      return variable.contains(code) ? CalcTheme.keyVariableFontFamily : null;
    }
    if (CalcTheme.isKeyMathSymbol(text[index])) {
      final math = await _familyCodePoints(fonts[CalcTheme.mathFontFamily]!);
      return math.contains(code) ? CalcTheme.mathFontFamily : null;
    }
    for (final family in [
      CalcTheme.keyFontFamily,
      ...CalcTheme.keyFontFallback,
    ]) {
      final codes = family == CalcTheme.keyFontFamily
          ? key
          : await _familyCodePoints(fonts[family]!);
      if (codes.contains(code)) return family;
    }
    return null;
  }

  group('번들 글꼴 등록', () {
    test('테마가 쓰는 패밀리가 모두 FontManifest에 있고 번들에서 읽힌다', () async {
      for (final family in [
        CalcTheme.monoFontFamily,
        ...CalcTheme.monoFontFallback,
        CalcTheme.keyFontFamily,
        ...CalcTheme.keyFontFallback,
        CalcTheme.keyVariableFontFamily,
      ]) {
        expect(fonts.keys, contains(family));
        expect(fonts[family], isNotEmpty, reason: family);
        for (final asset in fonts[family]!) {
          expect((await rootBundle.load(asset)).lengthInBytes, greaterThan(0));
        }
      }
    });

    test('테마 스타일은 번들 글꼴과 번들 대체 글꼴만 쓴다', () {
      for (final style in _themeStyles) {
        expect(fonts.keys, contains(style.fontFamily));
        for (final fallback in style.fontFamilyFallback ?? const <String>[]) {
          expect(fonts.keys, contains(fallback));
        }
      }
    });

    test('각 스타일의 글꼴 패밀리는 그 스타일의 굵기를 정적 파일로 갖는다 (합성 굵기 없음, #156)', () {
      // 패밀리에 그 굵기 파일이 없으면 엔진이 가까운 굵기를 고르거나 굵기를 합성한다. 키 각인(Saira)은 500·600만 있다.
      expect(fonts[CalcTheme.monoFontFamily], hasLength(4));
      const suffix = {
        400: 'Regular',
        500: 'Medium',
        600: 'SemiBold',
        700: 'Bold',
      };
      final styles = [
        ..._themeStyles,
        // 변수 이탤릭 (Noto Serif Bold Italic 하나)
        CalcTheme.keyVariableStyle(CalcTheme.keyMainLabelStyle),
      ];
      for (final style in styles) {
        final assets = fonts[style.fontFamily]!;
        final w = style.fontWeight!.value;
        final italic = style.fontStyle == FontStyle.italic;
        expect(
          assets.any(
            (a) => a.endsWith('-${suffix[w]}${italic ? 'Italic' : ''}.ttf'),
          ),
          isTrue,
          reason: '${style.fontFamily} weight $w italic=$italic',
        );
      }
    });
  });

  group('글리프 커버리지 (플랫폼 대체 글꼴 없이 그려진다)', () {
    test('50키의 모든 각인 글자는 각인 글꼴·번들 대체 글꼴·변수 이탤릭 글꼴에 있다 (#156)', () async {
      // 2차원 각인(#155)은 글자 조각(texts)만 글꼴로 그리고, 분수 가로줄·근호는 선으로 그린다.
      final missing = <String>{};
      for (final k in allKeys) {
        for (final legend in [
          k.mainLegend,
          for (final item in k.printedBandLegends) item.legend,
        ]) {
          for (final piece in legend.texts) {
            for (var i = 0; i < piece.text.length; i++) {
              if (await keyFamilyOf(piece.text, i) == null) {
                missing.add(
                  '${k.id.name}: ${_describe(piece.text.codeUnitAt(i))}',
                );
              }
            }
          }
        }
      }
      expect(missing, isEmpty);
    });

    test('M1 LCD 임시 표시가 그리는 한 줄 표기(plainText) 글자도 모두 번들 글꼴에 있다', () {
      // 마지막 입력 기능의 각인을 LCD에 한 줄 표기로 그린다(`_LcdPanel`, M2에서 수식 렌더링으로 대체).
      // 키캡에서는 그림으로 바꾼 `√`·`∛`·위첨자도 여기서는 글자로 그린다.
      final missing = <String>{};
      for (final key in allKeys) {
        for (final label in [
          key.mainLabel,
          key.printedShiftLegend?.plainText,
          key.alphaLabel,
        ]) {
          for (final code in (label ?? '').runes) {
            if (!mono.contains(code) && !fallback.contains(code)) {
              missing.add('${key.id.name}: ${_describe(code)}');
            }
          }
        }
      }
      expect(missing, isEmpty);
    });

    test(
      '각인 글자가 어느 글꼴로 그려지는지 고정한다 — 수학 글꼴은 ∑·∫·⇔·←뿐, 이탤릭은 변수 글자뿐 (#156, #266)',
      () async {
        // 대체 순서는 Saira → Noto Sans Mono → Noto Sans Math다(CalcTheme.keyFontFallback). `⇔`·`←`만 일부러 Noto Sans Math로 그린다
        // (CalcTheme.isKeyMathSymbol, #156 R2). Noto Sans Math는 Regular뿐이라
        // 그 글꼴로 그리는 글자가 늘면 굵기 통일이 더 어긋나므로 목록을 고정해 둔다. (`∛`는 #155부터 그림으로 그린다.)
        final byFamily = <String, Set<String>>{};
        for (final k in allKeys) {
          for (final legend in [
            k.mainLegend,
            for (final item in k.printedBandLegends) item.legend,
          ]) {
            for (final piece in legend.texts) {
              for (var i = 0; i < piece.text.length; i++) {
                final family = await keyFamilyOf(piece.text, i);
                (byFamily[family ?? '없음'] ??= {}).add(piece.text[i]);
              }
            }
          }
        }
        expect(byFamily[CalcTheme.mathFontFamily], {'∑', '∫', '⇔', '←'});
        // `i`는 ENG 키의 보라 각인(Complex 모드의 허수 단위, #266)이다
        expect(byFamily[CalcTheme.keyVariableFontFamily], {
          'x',
          'y',
          'e',
          'π',
          'i',
        });
        // 연산 기호·입력 칸·화살표는 고정폭 글꼴의 큰 기호로 그린다(Saira 서브셋에서 뺐다)
        expect(
          byFamily[CalcTheme.monoFontFamily],
          containsAll(['+', '=', '−', '×', '÷', '◼', '▲', '◄', '°', '∠']),
        );
        expect(byFamily.keys, isNot(contains('없음')));
        // 글자·숫자는 각인 글꼴로 그린다
        expect(
          byFamily[CalcTheme.keyFontFamily],
          containsAll(['S', 'H', 'I', 'F', 'T', '7', 's', 'n', 'A']),
        );
      },
    );

    test('LCD 줄·상태 표시줄 글자는 모두 고정폭 기본 글꼴에 있다', () {
      final glyphs = {
        ...lcdLineGlyphs.runes,
        // 아이콘 슬롯(#57)은 글자로 그리지 않는다.
        for (final slot in LcdIndicatorSlot.values)
          if (slot.icon == null) ...slot.template.runes,
        for (final c in ComplexResultIndicator.values)
          ...(c.indicator ?? '').runes,
        for (final unit in AngleUnit.values) ...unit.indicator.runes,
      };
      final missing = [
        for (final code in glyphs)
          if (!mono.contains(code)) _describe(code),
      ];
      expect(missing, isEmpty);
    });

    test('M2 이후 LCD 표시에 쓸 글자도 서브셋에 남아 있다', () {
      // 서브셋 범위(assets/fonts/README.md)를 줄일 때 빠뜨리지 않도록 고정한다.
      // 고정폭 기본 글꼴: ħ(CONST), ȳ·ŷ·결합 매크론/서컴플렉스(x̄·x̂ 통계), μ(공학 기호), σ·θ,
      // ᵍ(그라디안 위첨자), █(커서 블록), 부등식
      for (final ch in [
        'ħ',
        'ȳ',
        'ŷ',
        '\u0304',
        '\u0302',
        'μ',
        'σ',
        'θ',
        'ᵍ',
        '█',
        '≤',
        '≥',
        '≠',
      ]) {
        expect(mono, contains(ch.runes.single), reason: ch);
      }
      // Line 표시의 분수 구분 기호 ⌟는 기본 글꼴에 없어 대체 글꼴에만 있다(고정폭 아님 — #2에서 처리).
      expect(mono, isNot(contains('⌟'.runes.single)));
      expect(fallback, contains('⌟'.runes.single));
    });
  });
}
