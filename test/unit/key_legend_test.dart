import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_legend.dart';

void main() {
  group('KeyLegend.plainText (한 줄 읽기 표기, #155)', () {
    test('글자 조각은 그대로다', () {
      expect(const LegendText('SOLVE').plainText, 'SOLVE');
      expect(const LegendText('SOLVE').isPlain, isTrue);
    });

    test('분수는 분자/분모, 정수부(글자·숫자·칸) 뒤의 분수는 대분수로 띄운다', () {
      const box = LegendText('◼');
      const empty = LegendText('◻');
      expect(const LegendFraction(box, empty).plainText, '◼/◻');
      expect(
        const LegendRow([box, LegendFraction(empty, empty)]).plainText,
        '◼ ◻/◻',
      );
      expect(
        const LegendRow([
          LegendText('a'),
          LegendFraction(LegendText('b'), LegendText('c')),
          LegendText('⇔'),
          LegendFraction(LegendText('d'), LegendText('c')),
        ]).plainText,
        'a b/c⇔d/c',
        reason: '⇔ 뒤의 분수는 대분수가 아니다',
      );
      expect(
        const LegendRow([
          LegendFraction(LegendText('d'), LegendText('dx')),
          box,
        ]).plainText,
        'd/dx◼',
      );
    });

    test('위첨자는 숫자·−·x만이면 유니코드 위첨자, 아니면 ^를 붙인다', () {
      expect(
        const LegendScript(
          LegendText('x'),
          superscript: LegendText('2'),
        ).plainText,
        'x²',
      );
      expect(
        const LegendScript(
          LegendText('sin'),
          superscript: LegendText('−1'),
        ).plainText,
        'sin⁻¹',
      );
      expect(
        const LegendScript(
          LegendText('10'),
          superscript: LegendText('x'),
        ).plainText,
        '10ˣ',
      );
      expect(
        const LegendScript(
          LegendText('x'),
          superscript: LegendText('◼'),
        ).plainText,
        'x^◼',
      );
      expect(
        const LegendScript(
          LegendText('x'),
          superscript: LegendText('2a'),
        ).plainText,
        'x^2a',
        reason: '유니코드 위첨자가 없는 글자가 하나라도 있으면 ^ 표기',
      );
    });

    test('아래첨자는 그대로 잇고, 위아래 첨자가 함께면 아래 → 위 순서로 잇는다', () {
      expect(
        const LegendRow([
          LegendScript(LegendText('log'), subscript: LegendText('◼')),
          LegendText('◻'),
        ]).plainText,
        'log◼◻',
      );
      expect(
        const LegendRow([
          LegendScript(
            LegendText('∫'),
            subscript: LegendText('◻'),
            superscript: LegendText('◻'),
          ),
          LegendText('◼'),
        ]).plainText,
        '∫◻◻◼',
      );
    });

    test('근호: 제곱근 √, 지수 3은 ∛, 그 밖의 지수는 앞에 둔다', () {
      expect(const LegendRadical(LegendText('◼')).plainText, '√◼');
      expect(
        const LegendRadical(LegendText('◼'), index: LegendText('3')).plainText,
        '∛◼',
      );
      expect(
        const LegendRadical(LegendText('◻'), index: LegendText('◼')).plainText,
        '◼√◻',
      );
    });
  });

  test('구조가 같은 각인은 같고 해시도 같다 (상수가 아니어도) — 크기 측정 캐시 키', () {
    KeyLegend build(String exponent) => LegendRow([
      LegendScript(
        LegendText('x'.toString()),
        superscript: LegendText(exponent),
      ),
      LegendFraction(LegendText('a'), LegendText('b')),
      LegendRadical(LegendText('◻'), index: LegendText('◼')),
    ]);
    final a = build('2');
    final b = build('2');
    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(build('3')));
    // 종류가 다르면 같은 글자라도 다르다.
    expect(
      const LegendText('x'),
      isNot(const LegendScript(LegendText('x'), superscript: LegendText('2'))),
    );
    expect(
      const LegendScript(LegendText('x'), superscript: LegendText('2')),
      isNot(const LegendScript(LegendText('x'), subscript: LegendText('2'))),
    );
    expect(
      const LegendRadical(LegendText('◼')),
      isNot(const LegendRadical(LegendText('◼'), index: LegendText('3'))),
    );
    expect(
      const LegendRow([LegendText('a'), LegendText('b')]),
      isNot(
        const LegendRow([LegendText('a'), LegendText('b'), LegendText('c')]),
      ),
    );
  });

  group('위아래 끝(LegendLimits)·직접 그리는 칸(LegendBox)·기준선 아래첨자 (#169)', () {
    test('LegendLimits의 한 줄 표기는 바탕 → 아래 끝 → 위 끝 순서다', () {
      // 순서가 드러나도록 위 끝만 채운 칸으로 둔다(실제 ∑ 각인은 둘 다 빈 칸).
      const limits = LegendLimits(
        LegendText('∑'),
        over: LegendBox(LegendBoxShape.sumLimit, filled: true),
        under: LegendBox(LegendBoxShape.sumLimit, filled: false),
      );
      expect(limits.plainText, '∑◻◼');
      expect(limits.texts.map((t) => t.text).toList(), ['∑', '◼', '◻']);
    });

    test('LegendLimits는 같은 조각의 LegendScript와 다르고, 구조가 같으면 같다(상수가 아니어도)', () {
      KeyLegend limits(bool overFilled) => LegendLimits(
        LegendText('∑'),
        over: LegendBox(LegendBoxShape.sumLimit, filled: overFilled),
        under: LegendBox(LegendBoxShape.sumLimit, filled: false),
      );
      expect(limits(false), limits(false));
      expect(limits(false).hashCode, limits(false).hashCode);
      expect(limits(false), isNot(limits(true)));
      expect(
        limits(false),
        isNot(
          const LegendScript(
            LegendText('∑'),
            superscript: LegendBox(LegendBoxShape.sumLimit, filled: false),
            subscript: LegendBox(LegendBoxShape.sumLimit, filled: false),
          ),
        ),
      );
    });

    test('LegendBox는 한 줄 표기·글자 조각이 ◼(채움)·◻(빈 칸)이고, 모양·채움이 같으면 같다', () {
      const filled = LegendBox(LegendBoxShape.sumOperand, filled: true);
      const empty = LegendBox(LegendBoxShape.sumLimit, filled: false);
      expect(filled.plainText, '◼');
      expect(empty.plainText, '◻');
      expect(filled.texts.map((t) => t.text).toList(), ['◼']);
      expect(empty.texts.map((t) => t.text).toList(), ['◻']);
      expect(
        LegendBox(LegendBoxShape.values.first, filled: true),
        const LegendBox(LegendBoxShape.sumLimit, filled: true),
      );
      expect(
        const LegendBox(LegendBoxShape.sumLimit, filled: true),
        isNot(const LegendBox(LegendBoxShape.sumOperand, filled: true)),
      );
      expect(
        const LegendBox(LegendBoxShape.sumLimit, filled: true),
        isNot(const LegendBox(LegendBoxShape.sumLimit, filled: false)),
      );
      expect(filled, isNot(const LegendText('◼')));
    });

    test('기준선 아래첨자(subscriptOnBaseline)는 한 줄 표기는 같고 구조는 다르다', () {
      const onBaseline = LegendScript(
        LegendText('log'),
        subscript: LegendText('◼'),
        subscriptOnBaseline: true,
      );
      const dropped = LegendScript(
        LegendText('log'),
        subscript: LegendText('◼'),
      );
      expect(onBaseline.plainText, dropped.plainText);
      expect(onBaseline, isNot(dropped));
      expect(onBaseline.hashCode, isNot(dropped.hashCode));
    });
  });

  test('texts는 구조 안의 모든 글자 조각을 돌려준다', () {
    const legend = LegendRow([
      LegendScript(
        LegendText('∫'),
        subscript: LegendText('◻'),
        superscript: LegendText('S'),
      ),
      LegendRadical(LegendText('◼'), index: LegendText('3')),
      LegendFraction(LegendText('a'), LegendText('b')),
    ]);
    expect(legend.texts.map((t) => t.text).toList(), [
      '∫',
      'S',
      '◻',
      '3',
      '◼',
      'a',
      'b',
    ]);
    expect(legend.isPlain, isFalse);
  });
}
