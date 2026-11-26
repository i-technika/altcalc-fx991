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
