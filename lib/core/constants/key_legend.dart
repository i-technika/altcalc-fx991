import 'package:meta/meta.dart';

// ═══════════════════════════════════════════════════════════════
// 키 각인 모델 (#155)
// ═══════════════════════════════════════════════════════════════
//
// 실물 키캡 각인에는 분수·위첨자·아래첨자·근호가 2차원 모양으로 인쇄돼 있다(`◼/◻`는 위아래로 쌓은 분수,
// `x^◼`는 x 오른쪽 위의 작은 칸). 한 줄 문자열로는 이 모양을 나타낼 수 없으므로 각인을 구조로 담는다.
//
// - 글자만 있는 각인은 [LegendText] 하나다(`sin`, `SOLVE` 등 — 화면에서는 지금처럼 `Text`로 그린다).
// - 2차원 각인은 [LegendRow]·[LegendScript]·[LegendLimits]·[LegendFraction]·[LegendRadical]을 조합한다.
//   그리는 쪽은 `presentation/widgets/key_legend_view.dart`(`KeyLegendView`)다.
// - 이 파일은 도메인 계층에서도 쓰도록 UI 패키지에 의존하지 않는다.
//
// M2의 LCD 수식 렌더링(`MathNodeWidget`)과의 관계: 이 모델은 키캡 각인 전용이다. 입력 칸은 글자(`◼`·`◻`)로
// 두고 커서·편집 정보가 없다. LCD 수식 AST(`domain/models/math_node.dart`)와 노드 종류(분수·첨자·근호)는
// 겹치므로, M2에서 같은 배치 규칙(첨자 크기·분수 막대 높이 등)을 공유할지 정한다.

/// 키캡 각인(메인·SHIFT·ALPHA 한 층)의 구조.
///
/// 값 객체다 — 구조가 같으면 같다(`==`·`hashCode`). 크기 측정 캐시(`KeyLegendView.emSize`)가 이 동등성으로
/// 항목을 찾으므로, 상수가 아닌 각인을 만들어도 캐시가 늘어나지 않는다.
@immutable
sealed class KeyLegend {
  const KeyLegend();

  /// 한 줄 읽기 표기 — 2차원 모양을 읽는 순서로 늘어놓은 글자열.
  ///
  /// 화면의 키캡 각인에는 쓰지 않는다. M1의 LCD 임시 표시(마지막 입력 기능)·개발용 미리보기 입력 로그·
  /// 테스트에서 키를 가리킬 때 쓴다. 규칙(#16의 표기를 그대로 잇는다):
  /// - 분수: `분자/분모`. 앞이 글자·숫자·칸으로 끝나면 대분수로 보고 한 칸 띄운다(`a b/c`).
  /// - 위첨자: 숫자·`−`·`x`만이면 유니코드 위첨자(`x²`, `sin⁻¹`, `×10ˣ`), 아니면 `^`를 앞에 붙인다(`x^◼`).
  ///   아래첨자와 함께 있으면(∫의 아래·위 끝) 아래첨자 다음에 그대로 잇는다(`∫◻◻◼`).
  /// - 위아래 끝([LegendLimits], ∑): 바탕 다음에 아래 끝, 위 끝 순서로 잇는다(`∑◻◻◼`).
  /// - 아래첨자: 그대로 잇는다(`log◼◻`).
  /// - 근호: `√피개법수`, 지수가 `3`이면 `∛`, 그 밖의 지수는 앞에 둔다(`◼√◻`).
  String get plainText;

  /// 각인에 쓰인 글자 묶음 (그리는 순서와 무관). 글꼴 커버리지 검사·입력 칸 개수 검사에 쓴다.
  Iterable<LegendText> get texts;

  /// 글자만 있는 각인인지 여부. `true`면 2차원 모양 없이 한 줄로 그린다.
  bool get isPlain => this is LegendText;
}

/// 글자열 각인 조각. 입력 칸은 글자 `◼`(커서가 처음 들어가는 칸)·`◻`(나머지 칸)로 쓴다.
final class LegendText extends KeyLegend {
  /// 그릴 글자열
  final String text;

  const LegendText(this.text);

  @override
  String get plainText => text;

  @override
  Iterable<LegendText> get texts => [this];

  @override
  bool operator ==(Object other) => other is LegendText && other.text == text;

  @override
  int get hashCode => Object.hash(LegendText, text);

  @override
  String toString() => 'LegendText($text)';
}

/// 왼쪽부터 차례로 늘어놓는 각인 조각들 (`log◼◻` = 아래첨자 붙은 log, 그다음 칸).
final class LegendRow extends KeyLegend {
  /// 늘어놓을 조각 (2개 이상 — 하나면 감싸지 않는다. 상수 생성자라 assert 대신 테스트로 검증한다)
  final List<KeyLegend> children;

  const LegendRow(this.children);

  @override
  String get plainText {
    final out = StringBuffer();
    for (final child in children) {
      final text = child.plainText;
      // 대분수: 정수부(글자·숫자·칸) 바로 뒤의 분수는 띄어 읽는다 (`a b/c`, `◼ ◻/◻`).
      if (child is LegendFraction &&
          out.isNotEmpty &&
          _mixedFractionWholePart.hasMatch(out.toString())) {
        out.write(' ');
      }
      out.write(text);
    }
    return out.toString();
  }

  static final RegExp _mixedFractionWholePart = RegExp(r'[0-9A-Za-z◼◻]$');

  @override
  Iterable<LegendText> get texts => children.expand((c) => c.texts);

  @override
  bool operator ==(Object other) =>
      other is LegendRow &&
      other.children.length == children.length &&
      Iterable<int>.generate(children.length)
          .every((i) => other.children[i] == children[i]);

  @override
  int get hashCode => Object.hash(LegendRow, Object.hashAll(children));

  @override
  String toString() => 'LegendRow($children)';
}

/// 위첨자·아래첨자가 붙은 조각 (`x²`, `log◼`, `∫`의 아래·위 끝 — 기호 오른쪽).
final class LegendScript extends KeyLegend {
  /// 첨자가 붙는 바탕 조각
  final KeyLegend base;

  /// 위첨자 (오른쪽 위). 없으면 `null`.
  final KeyLegend? superscript;

  /// 아래첨자 (오른쪽 아래). 없으면 `null`.
  final KeyLegend? subscript;

  const LegendScript(this.base, {this.superscript, this.subscript})
    : assert(superscript != null || subscript != null, '첨자가 하나는 있어야 한다');

  @override
  String get plainText {
    final out = StringBuffer(base.plainText);
    final sub = subscript;
    final sup = superscript;
    if (sub != null) out.write(sub.plainText);
    if (sup != null) {
      final text = sup.plainText;
      final unicode = _unicodeSuperscript(text);
      if (sub != null) {
        out.write(text);
      } else if (unicode != null) {
        out.write(unicode);
      } else {
        out.write('^$text');
      }
    }
    return out.toString();
  }

  /// [text]의 모든 글자에 유니코드 위첨자가 있으면 그 글자열, 아니면 `null`.
  static String? _unicodeSuperscript(String text) {
    final out = StringBuffer();
    for (final ch in text.split('')) {
      final sup = _superscripts[ch];
      if (sup == null) return null;
      out.write(sup);
    }
    return out.toString();
  }

  static const Map<String, String> _superscripts = {
    '0': '⁰',
    '1': '¹',
    '2': '²',
    '3': '³',
    '4': '⁴',
    '5': '⁵',
    '6': '⁶',
    '7': '⁷',
    '8': '⁸',
    '9': '⁹',
    '−': '⁻',
    'x': 'ˣ',
  };

  @override
  Iterable<LegendText> get texts => [
    ...base.texts,
    ...?superscript?.texts,
    ...?subscript?.texts,
  ];

  @override
  bool operator ==(Object other) =>
      other is LegendScript &&
      other.base == base &&
      other.superscript == superscript &&
      other.subscript == subscript;

  @override
  int get hashCode => Object.hash(LegendScript, base, superscript, subscript);

  @override
  String toString() =>
      'LegendScript($base, sup: $superscript, sub: $subscript)';
}

/// 바탕 바로 위·아래에 작게 쌓은 끝 칸 (`∑`의 위아래 끝 — #169).
///
/// [LegendScript]의 첨자는 바탕 **오른쪽** 위·아래에 붙지만(∫의 끝 칸), 이 노드는 바탕 **위·아래 가운데**에 쌓는다.
/// 실물 fx-991EX는 ∑ 각인의 끝 칸을 기호 위·아래에 둔다(Quick Start Guide 1쪽 제품 사진, #169에서 대조).
final class LegendLimits extends KeyLegend {
  /// 끝 칸이 붙는 바탕 조각 (∑)
  final KeyLegend base;

  /// 위 끝 (바탕 위 가운데)
  final KeyLegend over;

  /// 아래 끝 (바탕 아래 가운데)
  final KeyLegend under;

  const LegendLimits(this.base, {required this.over, required this.under});

  @override
  String get plainText =>
      '${base.plainText}${under.plainText}${over.plainText}';

  @override
  Iterable<LegendText> get texts => [
    ...base.texts,
    ...over.texts,
    ...under.texts,
  ];

  @override
  bool operator ==(Object other) =>
      other is LegendLimits &&
      other.base == base &&
      other.over == over &&
      other.under == under;

  @override
  int get hashCode => Object.hash(LegendLimits, base, over, under);

  @override
  String toString() => 'LegendLimits($base, over: $over, under: $under)';
}

/// 위아래로 쌓고 가로줄을 그은 분수 (`◼/◻`, `d/dx`).
final class LegendFraction extends KeyLegend {
  /// 분자 (위)
  final KeyLegend numerator;

  /// 분모 (아래)
  final KeyLegend denominator;

  const LegendFraction(this.numerator, this.denominator);

  @override
  String get plainText => '${numerator.plainText}/${denominator.plainText}';

  @override
  Iterable<LegendText> get texts => [...numerator.texts, ...denominator.texts];

  @override
  bool operator ==(Object other) =>
      other is LegendFraction &&
      other.numerator == numerator &&
      other.denominator == denominator;

  @override
  int get hashCode => Object.hash(LegendFraction, numerator, denominator);

  @override
  String toString() => 'LegendFraction($numerator, $denominator)';
}

/// 근호 (`√◼`). 근호의 가로줄이 [radicand] 위를 덮고, [index]가 있으면 근호 왼쪽 위에 작게 쓴다(`∛◼`, `◼√◻`).
final class LegendRadical extends KeyLegend {
  /// 근호 안 (피개법수)
  final KeyLegend radicand;

  /// 거듭제곱근 지수. 없으면 제곱근이다.
  final KeyLegend? index;

  const LegendRadical(this.radicand, {this.index});

  @override
  String get plainText {
    final idx = index?.plainText;
    final sign = switch (idx) {
      null => '√',
      '3' => '∛',
      _ => '$idx√',
    };
    return '$sign${radicand.plainText}';
  }

  @override
  Iterable<LegendText> get texts => [...?index?.texts, ...radicand.texts];

  @override
  bool operator ==(Object other) =>
      other is LegendRadical &&
      other.radicand == radicand &&
      other.index == index;

  @override
  int get hashCode => Object.hash(LegendRadical, radicand, index);

  @override
  String toString() => 'LegendRadical($radicand, index: $index)';
}
