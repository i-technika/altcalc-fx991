import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';

void main() {
  group('키패드 명세 불변식', () {
    test('전체 키는 정확히 50개이며 CalcKeyId와 1:1 대응한다', () {
      expect(allKeys.length, totalKeyCount);
      expect(CalcKeyId.values.length, totalKeyCount);
      expect(keyById.length, totalKeyCount, reason: 'ID 중복이 있으면 맵 크기가 줄어든다');
      for (final id in CalcKeyId.values) {
        expect(keyDefOf(id).id, id);
      }
    });

    test('allKeys 순서는 CalcKeyId 선언 순서(실물 배열 순서)와 같다', () {
      expect(allKeys.map((k) => k.id).toList(), CalcKeyId.values);
    });

    test('구역별 키 개수: 조작부 2×2+2×2, 커서 4, 함수부 3×6, 숫자부 4×5', () {
      expect(controlLeftRows.length, 2);
      expect(controlRightRows.length, 2);
      for (final row in [...controlLeftRows, ...controlRightRows]) {
        expect(row.length, 2);
      }
      expect(cursorPad.all.length, 4);
      expect(functionRows.length, 3);
      for (final row in functionRows) {
        expect(row.length, functionColumns);
      }
      expect(numberRows.length, 4);
      for (final row in numberRows) {
        expect(row.length, numberColumns);
      }
    });

    test('커서 패드 각 방향은 올바른 ID에 대응한다', () {
      expect(cursorPad.up.id, CalcKeyId.cursorUp);
      expect(cursorPad.down.id, CalcKeyId.cursorDown);
      expect(cursorPad.left.id, CalcKeyId.cursorLeft);
      expect(cursorPad.right.id, CalcKeyId.cursorRight);
      expect(
        cursorPad.all.every((k) => k.category == KeyCategory.cursor),
        isTrue,
      );
    });

    test('메인 라벨은 키 간에 중복되지 않는다', () {
      final labels = allKeys.map((k) => k.mainLabel).toList();
      expect(labels.toSet().length, labels.length);
    });

    test('ALPHA 각인은 키 간에 중복되지 않는다', () {
      final labels = allKeys
          .map((k) => k.alphaLabel)
          .whereType<String>()
          .toList();
      expect(labels.toSet().length, labels.length);
    });

    test('메인 라벨은 비어 있지 않고, SHIFT/ALPHA 라벨은 null이거나 비어 있지 않다', () {
      for (final key in allKeys) {
        expect(key.mainLabel.trim(), isNotEmpty, reason: '$key');
        if (key.shiftLabel != null) {
          expect(key.shiftLabel!.trim(), isNotEmpty, reason: '$key');
        }
        if (key.alphaLabel != null) {
          expect(key.alphaLabel!.trim(), isNotEmpty, reason: '$key');
        }
      }
    });

    test('등호(=) 메인 키는 하나뿐이다', () {
      expect(allKeys.where((k) => k.mainLabel == '=').length, 1);
      expect(allKeys.where((k) => k.category == KeyCategory.equals).length, 1);
    });

    test('SHIFT 각인은 키 간에 중복되지 않는다', () {
      final labels = allKeys
          .map((k) => k.shiftLabel)
          .whereType<String>()
          .toList();
      expect(labels.toSet().length, labels.length);
    });

    test('ALPHA 층에서 변수 A~F, x, y, M은 각각 정확히 하나의 키에 있다', () {
      // 가이드 인쇄 13쪽 "Variables (A, B, C, D, E, F, M, x, y)" — x, y는 소문자다.
      // ALPHA 층만 센다. 변수 x는 x 키 메인으로도 입력된다 (아래 '층 간 라벨 겹침' 테스트).
      const variables = ['A', 'B', 'C', 'D', 'E', 'F', 'x', 'y', 'M'];
      for (final v in variables) {
        expect(allKeys.where((k) => k.alphaLabel == v).length, 1, reason: v);
      }
      // 변수 A~F는 함수부 2행에 순서대로 배치된다.
      expect(functionRows[1].map((k) => k.alphaLabel).toList(), [
        'A',
        'B',
        'C',
        'D',
        'E',
        'F',
      ]);
    });

    test('모디파이어 키에는 SHIFT/ALPHA 기능이 없다', () {
      for (final id in [CalcKeyId.shift, CalcKeyId.alpha]) {
        expect(keyDefOf(id).hasShift, isFalse);
        expect(keyDefOf(id).hasAlpha, isFalse);
      }
    });

    test('숫자 0~9 키가 모두 number 카테고리로 존재한다', () {
      final digits = allKeys
          .where((k) => RegExp(r'^[0-9]$').hasMatch(k.mainLabel))
          .toList();
      expect(digits.map((k) => k.mainLabel).toSet(), {
        for (var i = 0; i < 10; i++) '$i',
      });
      expect(digits.every((k) => k.category == KeyCategory.number), isTrue);
    });

    test('사칙연산 키 4개는 operator 카테고리다', () {
      final ops = allKeys.where((k) => k.category == KeyCategory.operator);
      expect(ops.map((k) => k.mainLabel).toSet(), {'+', '−', '×', '÷'});
    });

    test('반복 입력 키는 커서 패드 4방향과 DEL뿐이다', () {
      expect(autoRepeatKeys, {
        for (final k in cursorPad.all) k.id,
        CalcKeyId.del,
      });
    });

    // 출처: QSG 1쪽 사진(1~6 키 위 각인 없음). 가이드에도 SHIFT/ALPHA + 1~6 조작 예가 없다.
    test('숫자 1~6 키에는 SHIFT/ALPHA 각인이 없다', () {
      for (final id in [
        CalcKeyId.num1,
        CalcKeyId.num2,
        CalcKeyId.num3,
        CalcKeyId.num4,
        CalcKeyId.num5,
        CalcKeyId.num6,
      ]) {
        expect(keyDefOf(id).hasShift, isFalse, reason: id.name);
        expect(keyDefOf(id).hasAlpha, isFalse, reason: id.name);
      }
    });

    test('SHIFT/ALPHA 층에 모드 전용(보라색·파란색) 각인이 섞이지 않는다', () {
      // 가이드 인쇄 3쪽 "Key Markings": 보라색 = Complex 모드, 파란색 = Base-N 모드 전용.
      // 노란색(SHIFT)·빨간색(ALPHA) 각인 자리에는 두지 않는다 — 모드 전용 각인 자리가 따로 있다(#266, 아래 그룹).
      const modeOnly = {'∠', 'i', 'DEC', 'HEX', 'BIN', 'OCT'};
      for (final key in allKeys) {
        expect(modeOnly, isNot(contains(key.shiftLabel)), reason: '$key');
        expect(modeOnly, isNot(contains(key.alphaLabel)), reason: '$key');
      }
    });

    group('모드 전용 각인 (#266)', () {
      // User's Guide 3쪽 "Key Markings"와 Quick Start Guide 1쪽 제품 사진 대조.
      // (키, 괄호 SHIFT 각인, 모드 색 각인, ALPHA 괄호 모드)
      const complex = KeyLegendMode.complex;
      const baseN = KeyLegendMode.baseN;
      const verified =
          <
            CalcKeyId,
            ((String, KeyLegendMode)?, (String, KeyLegendMode)?, KeyLegendMode?)
          >{
            CalcKeyId.eng: (('∠', complex), ('i', complex), null),
            CalcKeyId.square: (null, ('DEC', baseN), null),
            CalcKeyId.power: (null, ('HEX', baseN), null),
            CalcKeyId.logBase: (null, ('BIN', baseN), null),
            CalcKeyId.ln: (null, ('OCT', baseN), null),
            CalcKeyId.negative: (null, null, baseN),
            CalcKeyId.degMinSec: (null, null, baseN),
            CalcKeyId.reciprocal: (null, null, baseN),
            CalcKeyId.sin: (null, null, baseN),
            CalcKeyId.cos: (null, null, baseN),
            CalcKeyId.tan: (null, null, baseN),
          };

      (String, KeyLegendMode)? pair(ModeLegend? m) =>
          m == null ? null : (m.legend.plainText, m.mode);

      test('모드 전용 각인이 있는 키와 그 각인은 실물 대조표와 일치한다', () {
        for (final key in allKeys) {
          expect(
            (
              pair(key.modeShiftLegend),
              pair(key.modeLegend),
              key.alphaBracketMode,
            ),
            verified[key.id] ?? (null, null, null),
            reason: key.id.name,
          );
        }
      });

      test('파란 괄호가 둘러싸는 ALPHA 각인은 16진 숫자 A~F다', () {
        expect(
          [
            for (final key in allKeys)
              if (key.alphaBracketMode != null) key.alphaLabel,
          ],
          ['A', 'B', 'C', 'D', 'E', 'F'],
        );
      });

      test(
        '각인 띠 목록(bandLegends)은 실물 인쇄 순서다 — 괄호 SHIFT → SHIFT → ALPHA → 모드 색',
        () {
          List<String> describe(CalcKeyId id) => [
            for (final b in keyDefOf(id).bandLegends) b.toString(),
          ];
          expect(describe(CalcKeyId.eng), [
            'BandLegend("∠", shift, complex, 괄호)',
            'BandLegend("←", shift)',
            'BandLegend("i", mode, complex)',
          ]);
          expect(describe(CalcKeyId.square), [
            'BandLegend("x³", shift)',
            'BandLegend("DEC", mode, baseN)',
          ]);
          expect(describe(CalcKeyId.negative), [
            'BandLegend("log", shift)',
            'BandLegend("A", alpha, baseN, 괄호)',
          ]);
          expect(describe(CalcKeyId.calc), [
            'BandLegend("SOLVE", shift)',
            'BandLegend("=", alpha)',
          ]);
          expect(describe(CalcKeyId.num7), ['BandLegend("CONST", shift)']);
        },
      );

      test('모든 키: 목록은 SHIFT·ALPHA 각인을 빠짐없이 담고, 원형 버튼·각인 없는 키는 비어 있다', () {
        for (final key in allKeys) {
          final band = key.bandLegends;
          final expected = [
            ?key.modeShiftLegend?.legend,
            ?key.shiftLegend,
            ?key.alphaLegend,
            ?key.modeLegend?.legend,
          ];
          expect(
            [for (final b in band) b.legend],
            expected,
            reason: key.id.name,
          );
          // 각인 띠는 셋까지만 놓는다 (ENG 키) — 넷이면 배치 규칙이 없다
          expect(band.length, lessThanOrEqualTo(3), reason: key.id.name);
          if (key.face == KeyFace.roundButton) {
            expect(band, isEmpty, reason: key.id.name);
          }
          for (final b in band) {
            // 모드는 모드 색 각인이거나 괄호가 있을 때만 있다
            expect(
              b.mode != null,
              b.role == BandLegendRole.mode || b.bracketed,
              reason: '${key.id.name} $b',
            );
          }
        }
      });

      test('잘못된 조합은 assert로 막는다', () {
        const mode = ModeLegend(LegendText('DEC'), baseN);
        // 원형 버튼의 각인 띠에는 메인 각인만 있다
        expect(
          () => CalcKeyDef(
            id: CalcKeyId.menu,
            mainLegend: const LegendText('MENU'),
            modeLegend: mode,
            category: KeyCategory.menu,
            face: KeyFace.roundButton,
          ),
          throwsA(isA<AssertionError>()),
        );
        // 둘러쌀 ALPHA 각인이 없다
        expect(
          () => CalcKeyDef(
            id: CalcKeyId.sin,
            mainLegend: const LegendText('sin'),
            alphaBracketMode: baseN,
            category: KeyCategory.function,
          ),
          throwsA(isA<AssertionError>()),
        );
        // ALPHA 각인과 모드 색 각인은 같은 자리(오른쪽)다
        expect(
          () => CalcKeyDef(
            id: CalcKeyId.sin,
            mainLegend: const LegendText('sin'),
            alphaLegend: const LegendText('D'),
            modeLegend: mode,
            category: KeyCategory.function,
          ),
          throwsA(isA<AssertionError>()),
        );
        // 모드 없는 괄호·모드 색 각인, 괄호도 모드 색도 아닌데 모드가 있는 각인
        expect(
          () => BandLegend(
            const LegendText('A'),
            BandLegendRole.alpha,
            bracketed: true,
          ),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => BandLegend(const LegendText('i'), BandLegendRole.mode),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => BandLegend(
            const LegendText('A'),
            BandLegendRole.alpha,
            mode: baseN,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('ModeLegend·BandLegend는 값으로 비교한다', () {
        expect(
          const ModeLegend(LegendText('i'), complex),
          const ModeLegend(LegendText('i'), complex),
        );
        expect(
          const ModeLegend(LegendText('i'), complex),
          isNot(const ModeLegend(LegendText('i'), baseN)),
        );
        expect(
          keyDefOf(CalcKeyId.eng).bandLegends,
          keyDefOf(CalcKeyId.eng).bandLegends,
        );
        expect(
          keyDefOf(CalcKeyId.eng).bandLegends.first.hashCode,
          keyDefOf(CalcKeyId.eng).bandLegends.first.hashCode,
        );
      });
    });

    test('층 간 라벨 겹침은 의도된 두 경우뿐이다', () {
      // 라벨 문자열 → (키, 층) 목록
      final owners = <String, List<String>>{};
      void add(String? label, CalcKeyDef key, String layer) {
        if (label == null) return;
        owners.putIfAbsent(label, () => []).add('${key.id.name}.$layer');
      }

      for (final key in allKeys) {
        add(key.mainLabel, key, 'main');
        add(key.shiftLabel, key, 'shift');
        add(key.alphaLabel, key, 'alpha');
      }
      final shared = {
        for (final e in owners.entries)
          if (e.value.length > 1) e.key: e.value.toSet(),
      };
      expect(shared, {
        // 같은 변수 x로 가는 두 경로 (가이드 인쇄 13쪽 각주 *1).
        'x': {'variableX.main', 'parenClose.alpha'},
        // 라벨만 같고 기능은 다르다: ALPHA = 은 방정식 기호 입력, = 키는 계산 실행.
        '=': {'equals.main', 'calc.alpha'},
      });
    });

    test('템플릿 각인은 첫 입력 칸 ◼를 정확히 하나 갖고, ▭는 쓰지 않는다', () {
      // key_definitions.dart 머리 주석 "각인 표기" (#16): ◼ = 커서가 처음 들어가는 칸, ◻ = 나머지 칸.
      // 2차원 각인(#155)은 칸이 분수·첨자 안에 흩어져 있으므로 글자 조각 전체를 센다.
      for (final legend in _allLegends()) {
        final text = legend.texts.map((t) => t.text).join();
        expect(text, isNot(contains('▭')), reason: legend.plainText);
        if (text.contains('◼') || text.contains('◻')) {
          expect('◼'.allMatches(text).length, 1, reason: legend.plainText);
        }
      }
    });

    group('2차원 각인 (#155)', () {
      test('각인 글자에 한 줄 임시 표기(분수 /·위첨자 ^·유니코드 위첨자·근호 글자)가 없다', () {
        // 분수·첨자·근호·위아래 끝은 구조(LegendFraction·LegendScript·LegendRadical·LegendLimits)로 담고 그림으로
        // 그린다. 실물 비율 칸은 LegendBox다.
        final forbidden = RegExp('[/^⁰¹²³⁴⁵⁶⁷⁸⁹⁻ˣ√∛]');
        for (final legend in _allLegends()) {
          for (final t in legend.texts) {
            expect(
              forbidden.hasMatch(t.text),
              isFalse,
              reason: '${legend.plainText}: "${t.text}"',
            );
          }
        }
      });

      test('실물이 2차원 모양인 각인은 모두 2차원 각인이고, 그 밖의 각인은 글자만 있다', () {
        final twoDimensional = {
          for (final k in allKeys)
            for (final (layer, legend) in [
              ('main', k.mainLegend),
              ('shift', k.shiftLegend),
              ('alpha', k.alphaLegend),
            ])
              if (legend != null && !legend.isPlain) (k.id, layer),
        };
        expect(twoDimensional, _twoDimensionalLegends);
      });

      test('LegendRow는 조각이 둘 이상이고 중첩되지 않으며, 빈 글자 조각이 없다', () {
        void check(KeyLegend legend, String reason) {
          switch (legend) {
            case LegendText(:final text):
              expect(text, isNotEmpty, reason: reason);
            case LegendRow(:final children):
              expect(children.length, greaterThanOrEqualTo(2), reason: reason);
              for (final c in children) {
                expect(c, isNot(isA<LegendRow>()), reason: '$reason: 중첩 Row');
                check(c, reason);
              }
            case LegendScript(
              :final base,
              :final superscript,
              :final subscript,
            ):
              check(base, reason);
              if (superscript != null) check(superscript, reason);
              if (subscript != null) check(subscript, reason);
            case LegendLimits(:final base, :final over, :final under):
              check(base, reason);
              check(over, reason);
              check(under, reason);
            case LegendBox():
              break;
            case LegendFraction(:final numerator, :final denominator):
              check(numerator, reason);
              check(denominator, reason);
            case LegendRadical(:final radicand, :final index):
              check(radicand, reason);
              if (index != null) check(index, reason);
          }
        }

        for (final legend in _allLegends()) {
          check(legend, legend.plainText);
        }
      });

      test('입력 칸은 모두 자리별 모양으로 그리는 LegendBox이고, 모양마다 자리가 하나다 (#186)', () {
        // 글자 ◼·◻ 조각이 남으면 그 칸만 글꼴 정사각형으로 그려진다. 모양은 자리 이름이라(예: log 진수 칸)
        // 한 모양이 서로 다른 각인에 쓰이지 않는다 — 같은 각인 안에서 같은 자리가 둘인 경우(∫·∑ 위아래 끝,
        // 대분수 분자·분모, 분수 키 분자·분모)만 겹친다.
        final owners = <LegendBoxShape, Set<String>>{};
        final slanted = <String>[];
        void walk(KeyLegend legend, String owner) {
          switch (legend) {
            case LegendText(:final text):
              expect(text, isNot(matches('[◼◻]')), reason: owner);
            case LegendBox(:final shape):
              (owners[shape] ??= {}).add(owner);
            case LegendRow(:final children):
              for (final c in children) {
                walk(c, owner);
              }
            case LegendScript(
              :final base,
              :final superscript,
              :final subscript,
              :final subscriptFollowsSlant,
            ):
              if (subscriptFollowsSlant) slanted.add(owner);
              walk(base, owner);
              if (superscript != null) walk(superscript, owner);
              if (subscript != null) walk(subscript, owner);
            case LegendLimits(:final base, :final over, :final under):
              walk(base, owner);
              walk(over, owner);
              walk(under, owner);
            case LegendFraction(:final numerator, :final denominator):
              walk(numerator, owner);
              walk(denominator, owner);
            case LegendRadical(:final radicand, :final index):
              walk(radicand, owner);
              if (index != null) walk(index, owner);
          }
        }

        for (final legend in _allLegends()) {
          walk(legend, legend.plainText);
        }
        expect(owners.keys.toSet(), LegendBoxShape.values.toSet());
        for (final MapEntry(key: shape, value: legends) in owners.entries) {
          expect(legends, hasLength(1), reason: '$shape: $legends');
        }
        // ∫ 아래 끝 칸만 기울기를 따라 왼쪽으로 당긴다.
        expect(slanted, ['∫◻◻◼']);
      });
    });

    test('50키의 각인은 실물 대조표와 일치한다', () {
      expect(_verifiedLegends.keys.toSet(), CalcKeyId.values.toSet());
      for (final key in allKeys) {
        final (main, shift, alpha) = _verifiedLegends[key.id]!;
        expect(
          (key.mainLabel, key.shiftLabel, key.alphaLabel),
          (main, shift, alpha),
          reason: key.id.name,
        );
      }
    });

    test('원형 버튼은 실물대로 SHIFT·ALPHA·MENU·ON(설정 키) 넷이다 (#190, #156)', () {
      expect(settingsKey, CalcKeyId.on);
      // Quick Start Guide 1쪽 제품 사진: 커서 패드 양옆 윗줄의 네 버튼이 원형 은색 버튼이다.
      expect(
        [
          for (final key in allKeys)
            if (key.face == KeyFace.roundButton) key.id,
        ],
        [CalcKeyId.shift, CalcKeyId.alpha, CalcKeyId.menu, settingsKey],
      );
      expect(keyDefOf(settingsKey).mainLabel, 'SETUP');
      // 원형 버튼 위 각인 띠에는 이름 하나만 인쇄한다 — SHIFT·ALPHA 각인이 없다 (#253, CalcKeyDef assert)
      for (final key in allKeys) {
        if (key.face != KeyFace.roundButton) continue;
        expect(key.hasShift || key.hasAlpha, isFalse, reason: key.id.name);
      }
    });

    test('원형 버튼에 SHIFT·ALPHA 각인을 주면 assert로 막는다 (#253)', () {
      for (final (shift, alpha) in [
        (const LegendText('SETUP'), null),
        (null, const LegendText('X')),
      ]) {
        expect(
          () => CalcKeyDef(
            id: CalcKeyId.menu,
            mainLegend: const LegendText('MENU'),
            shiftLegend: shift,
            alphaLegend: alpha,
            category: KeyCategory.menu,
            face: KeyFace.roundButton,
          ),
          throwsA(isA<AssertionError>()),
        );
      }
    });

    test('설정(SETUP)은 설정 키 하나로만 들어간다 — 실물 MENU의 SETUP·AC의 OFF·ON 각인은 없다 (#253, #190)', () {
      final setup = [
        for (final key in allKeys)
          for (final (layer, label) in [
            ('main', key.mainLabel),
            ('shift', key.shiftLabel),
            ('alpha', key.alphaLabel),
          ])
            if (label == 'SETUP') (key.id, layer),
      ];
      expect(setup, [(settingsKey, 'main')]);
      expect(keyDefOf(CalcKeyId.menu).hasShift, isFalse);
      expect(keyDefOf(CalcKeyId.ac).hasShift, isFalse);
      for (final key in allKeys) {
        for (final label in [key.mainLabel, key.shiftLabel, key.alphaLabel]) {
          expect(
            label,
            isNot(anyOf('ON', 'OFF', 'SETTING')),
            reason: key.id.name,
          );
        }
      }
    });

    test('컬렉션은 수정할 수 없다', () {
      expect(() => allKeys.add(allKeys.first), throwsUnsupportedError);
      expect(() => keyById.remove(CalcKeyId.ac), throwsUnsupportedError);
      expect(() => cursorPad.all.clear(), throwsUnsupportedError);
    });
  });
}

/// 실물 대조표 (#15).
///
/// 모든 행은 fx-991EX Quick Start Guide 1쪽 제품 사진과 한 줄씩 대조했다. User's Guide
/// (RJA532432-001V01)의 키 조작 예제에서 그 각인을 찾은 행에는 `G<인쇄 쪽>`을 덧붙였다.
/// `G` 표시가 없다고 가이드에 없다는 뜻은 아니다(쪽수를 이 표에 정리하지 않았을 뿐). "없음" 판정은
/// 사진이 근거다(예: Ans·ENG의 ALPHA 없음, 숫자 1~6 무각인).
///
/// `(메인, SHIFT, ALPHA)` — 각인이 없으면 `null`. 이 표는 명세의 사본이라 출처 없이 둘을 함께 고치면
/// 통과한다. 명세를 바꿀 때는 반드시 위 출처를 다시 확인하고 행 주석도 고친다.
const Map<CalcKeyId, (String, String?, String?)> _verifiedLegends = {
  // 상단 조작부
  CalcKeyId.shift: ('SHIFT', null, null),
  CalcKeyId.alpha: ('ALPHA', null, null),
  // 실물 SHIFT 각인은 `SETUP`(G3) — 앱은 설정을 설정 키 하나로만 열어 인쇄하지 않는다
  // (#253, 사용자 결정 — 실물 대조에서 의도적으로 다른 행)
  CalcKeyId.menu: ('MENU', null, null),
  // 실물 각인은 `ON`(버튼 위 본체에 인쇄) — 이 앱에는 전원이 없어 ON을 설정 키로 쓰고 같은 자리에 `SETUP`을
  // 인쇄한다 (#190·#253, 사용자 결정 — 실물 대조에서 의도적으로 다른 행)
  CalcKeyId.on: ('SETUP', null, null),
  CalcKeyId.optn: ('OPTN', 'QR', null), // G7
  CalcKeyId.calc: ('CALC', 'SOLVE', '='),
  CalcKeyId.integral: ('∫◻◻◼', 'd/dx◼', ':'), // G15 d/dx, G11 :
  CalcKeyId.variableX: ('x', '∑◻◻◼', null), // G16 ∑ 예제
  // 커서 패드
  CalcKeyId.cursorUp: ('▲', null, null),
  CalcKeyId.cursorDown: ('▼', null, null),
  CalcKeyId.cursorLeft: ('◄', null, null),
  CalcKeyId.cursorRight: ('►', null, null),
  // 함수부 1행
  CalcKeyId.fraction: (
    '◼/◻',
    '◼ ◻/◻',
    null,
  ), // SHIFT 대분수 (한 줄 표기는 정수부 뒤를 띄운다, #155)
  CalcKeyId.sqrt: ('√◼', '∛◼', null),
  CalcKeyId.square: ('x²', 'x³', null), // G14
  CalcKeyId.power: ('x^◼', '◼√◻', null), // G15
  CalcKeyId.logBase: ('log◼◻', '10^◼', null),
  CalcKeyId.ln: ('ln', 'e^◼', null), // G14
  // 함수부 2행
  CalcKeyId.negative: ('(−)', 'log', 'A'), // G14 log 예제, G13 변수
  CalcKeyId.degMinSec: ('°\'"', 'FACT', 'B'),
  CalcKeyId.reciprocal: ('x⁻¹', 'x!', 'C'), // G16 x!
  CalcKeyId.sin: ('sin', 'sin⁻¹', 'D'),
  CalcKeyId.cos: ('cos', 'cos⁻¹', 'E'),
  CalcKeyId.tan: ('tan', 'tan⁻¹', 'F'),
  // 함수부 3행
  CalcKeyId.sto: ('STO', 'RECALL', null), // G13 변수 저장·호출
  CalcKeyId.eng: (
    'ENG',
    '←',
    null,
  ), // G11 ←, ALPHA 없음은 사진. 보라 ∠·i는 모드 전용 각인(#266)
  CalcKeyId.parenOpen: ('(', 'Abs', null), // G16 Abs 예제
  CalcKeyId.parenClose: (')', ',', 'x'), // G14·G15 ,  G13 변수 x
  CalcKeyId.sdToggle: ('S⇔D', 'a b/c⇔d/c', 'y'), // G11 a b/c⇔d/c, G13 변수 y
  CalcKeyId.mPlus: ('M+', 'M−', 'M'), // G13
  // 숫자부
  CalcKeyId.num7: ('7', 'CONST', null),
  CalcKeyId.num8: ('8', 'CONV', null),
  CalcKeyId.num9: ('9', 'RESET', null), // G7
  CalcKeyId.del: ('DEL', 'INS', 'UNDO'),
  // 실물 SHIFT 각인은 `OFF`(G3 전원 끄기) — 이 앱에는 전원이 없어 인쇄하지 않는다
  // (#253, 사용자 결정 — 실물 대조에서 의도적으로 다른 행)
  CalcKeyId.ac: ('AC', null, null),
  CalcKeyId.num4: ('4', null, null),
  CalcKeyId.num5: ('5', null, null),
  CalcKeyId.num6: ('6', null, null),
  CalcKeyId.multiply: ('×', 'nPr', null), // G16
  CalcKeyId.divide: ('÷', 'nCr', null), // G16
  CalcKeyId.num1: ('1', null, null),
  CalcKeyId.num2: ('2', null, null),
  CalcKeyId.num3: ('3', null, null),
  CalcKeyId.add: ('+', 'Pol', null), // G16
  CalcKeyId.subtract: ('−', 'Rec', null), // G16
  CalcKeyId.num0: ('0', 'Rnd', null),
  CalcKeyId.dot: ('.', 'Ran#', 'RanInt'), // G16
  CalcKeyId.exp10: ('×10ˣ', 'π', 'e'), // G15
  CalcKeyId.ans: ('Ans', '%', null), // G11 %, ALPHA 없음은 사진 (가이드에 PreAns 없음)
  CalcKeyId.equals: ('=', '≈', null), // G7
};

/// 50키의 모든 각인 (메인·SHIFT·ALPHA)
Iterable<KeyLegend> _allLegends() => [
  for (final k in allKeys) ...[k.mainLegend, ?k.shiftLegend, ?k.alphaLegend],
];

/// 실물 키캡에 2차원 모양(분수·위첨자·아래첨자·근호)으로 인쇄된 각인 — 이슈 #155 "대상 각인" 표.
/// 기준은 #15·#16과 같은 Quick Start Guide 1쪽 제품 사진이다.
const Set<(CalcKeyId, String)> _twoDimensionalLegends = {
  (CalcKeyId.fraction, 'main'), // ◼/◻
  (CalcKeyId.fraction, 'shift'), // ◼ ◻/◻ (대분수)
  (CalcKeyId.sqrt, 'main'), // √◼
  (CalcKeyId.sqrt, 'shift'), // ∛◼
  (CalcKeyId.power, 'main'), // x^◼
  (CalcKeyId.power, 'shift'), // ◼√◻
  (CalcKeyId.logBase, 'main'), // log◼◻
  (CalcKeyId.logBase, 'shift'), // 10^◼
  (CalcKeyId.ln, 'shift'), // e^◼
  (CalcKeyId.integral, 'main'), // ∫◻◻◼
  (CalcKeyId.integral, 'shift'), // d/dx◼
  (CalcKeyId.variableX, 'shift'), // ∑◻◻◼
  (CalcKeyId.sdToggle, 'shift'), // a b/c⇔d/c
  (CalcKeyId.square, 'main'), // x²
  (CalcKeyId.square, 'shift'), // x³
  (CalcKeyId.reciprocal, 'main'), // x⁻¹
  (CalcKeyId.sin, 'shift'), // sin⁻¹
  (CalcKeyId.cos, 'shift'), // cos⁻¹
  (CalcKeyId.tan, 'shift'), // tan⁻¹
  (CalcKeyId.exp10, 'main'), // ×10ˣ
};
