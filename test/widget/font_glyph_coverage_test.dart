import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/lcd_status.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/top_strip.dart';

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
  CalcTheme.topStripWordmarkStyle,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, List<String>> fonts;
  late Set<int> mono;
  late Set<int> fallback;
  setUpAll(() async {
    fonts = await _manifestFonts();
    mono = await _familyCodePoints(fonts[CalcTheme.monoFontFamily]!);
    fallback = {
      for (final family in CalcTheme.monoFontFallback)
        ...await _familyCodePoints(fonts[family]!),
    };
  });

  group('번들 글꼴 등록', () {
    test('테마가 쓰는 패밀리가 모두 FontManifest에 있고 번들에서 읽힌다', () async {
      for (final family in [
        CalcTheme.monoFontFamily,
        ...CalcTheme.monoFontFallback,
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

    test('기본 글꼴은 테마가 쓰는 굵기를 모두 정적 파일로 갖는다', () {
      final assets = fonts[CalcTheme.monoFontFamily]!;
      expect(assets, hasLength(4), reason: '400/500/600/700');
      const suffix = {
        400: 'Regular',
        500: 'Medium',
        600: 'SemiBold',
        700: 'Bold',
      };
      for (final style in _themeStyles) {
        final w = style.fontWeight!.value;
        expect(
          assets.any((a) => a.endsWith('-${suffix[w]}.ttf')),
          isTrue,
          reason: 'weight $w',
        );
      }
    });
  });

  group('글리프 커버리지 (플랫폼 대체 글꼴 없이 그려진다)', () {
    test('50키의 모든 각인 글자는 기본 글꼴 또는 번들 대체 글꼴에 있다', () {
      // 2차원 각인(#155)은 글자 조각(texts)만 글꼴로 그리고, 분수 가로줄·근호는 선으로 그린다.
      final missing = <String>{};
      for (final key in allKeys) {
        for (final legend in [
          key.mainLegend,
          ?key.shiftLegend,
          ?key.alphaLegend,
        ]) {
          for (final code in legend.texts.expand((t) => t.text.runes)) {
            if (!mono.contains(code) && !fallback.contains(code)) {
              missing.add('${key.id.name}: ${_describe(code)}');
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

    test('대체 글꼴이 필요한 각인 글자는 ∑·∫뿐이다', () {
      // 대체 글꼴(Noto Sans Math)은 고정폭이 아니고 Regular뿐이다. 대체 글꼴로 그리는 글자가 늘면
      // 굵기 통일이 더 어긋나므로 목록을 고정해 둔다. (`∛`는 #155부터 근호를 그림으로 그려 쓰지 않는다.)
      final viaFallback = {
        for (final key in allKeys)
          for (final legend in [
            key.mainLegend,
            ?key.shiftLegend,
            ?key.alphaLegend,
          ])
            for (final code in legend.texts.expand((t) => t.text.runes))
              if (!mono.contains(code)) String.fromCharCode(code),
      };
      expect(viaFallback, {'∑', '∫'});
    });

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

    test('상단 띠 워드마크 글자는 모두 고정폭 기본 글꼴에 있다 (#41)', () {
      final missing = [
        for (final code in TopStripDecoration.wordmarkText.runes)
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
