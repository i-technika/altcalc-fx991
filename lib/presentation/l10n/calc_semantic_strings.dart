import 'package:material_ui/material_ui.dart';

import '../../core/constants/key_definitions.dart';
import '../../domain/models/calc_state.dart';
import '../../domain/models/lcd_status.dart';
import 'device_locale_scope.dart';

/// 키 하나의 음성 라벨 (스크린리더용). 표시 라벨([CalcKeyDef])과 같은 층 구성을 갖는다.
@immutable
class KeySpeech {
  /// 키캡 메인 기능
  final String main;

  /// SHIFT 기능. 키에 SHIFT 기능이 없으면 `null`.
  final String? shift;

  /// ALPHA 기능. 키에 ALPHA 기능이 없으면 `null`.
  final String? alpha;

  const KeySpeech(this.main, {this.shift, this.alpha});

  /// [layer] 기능의 음성 라벨. 그 층에 기능이 없으면 `null`.
  String? of(KeyLayer layer) => switch (layer) {
    KeyLayer.main => main,
    KeyLayer.shift => shift,
    KeyLayer.alpha => alpha,
  };
}

/// 스크린리더(TalkBack/VoiceOver)가 읽는 문구 모음 (#20).
///
/// 키 각인·LCD 표시기는 `sin⁻¹`, `∫◻◻◼`, `◄`, `S` 같은 표시용 기호라 그대로 읽히면 기호 이름이나
/// 알파벳 한 글자로 들린다. 화면에 보이는 문자열 대신 이 문구를 시맨틱 라벨로 쓴다.
///
/// ## 언어 선택
/// 기기(플랫폼) 로캘로 고른다: 한국어 기기는 [KoSemanticStrings], 그 밖에는 [EnSemanticStrings].
/// 앱(`MaterialApp`)은 `supportedLocales`를 지정하지 않아 `Localizations` 로캘이 항상 en_US이므로
/// 그것을 쓰지 않는다. 실행 중 기기 언어가 바뀌면 앱 루트의 [DeviceLocaleScope]가 다시 빌드시킨다.
/// 한국어·영어가 아닌 기기는 영어 문구를 그 기기 언어의 TTS가 읽는다(예: 독일어 TTS가 "Sine"을 읽음).
/// 앱 전체 다국어(`flutter_localizations`·ARB)를 도입할 때 언어를 늘리거나 문구에 로캘 표식을 붙인다 — TODO(#48).
abstract class CalcSemanticStrings {
  const CalcSemanticStrings();

  /// 등록된 모든 언어 구현 (불변식 테스트가 모두 검사한다)
  static const List<CalcSemanticStrings> all = [
    KoSemanticStrings(),
    EnSemanticStrings(),
  ];

  /// [locale]에 맞는 문구. 한국어가 아니면 영어.
  static CalcSemanticStrings forLocale(Locale locale) =>
      switch (locale.languageCode) {
        'ko' => const KoSemanticStrings(),
        _ => const EnSemanticStrings(),
      };

  /// 기기 로캘에 맞는 문구. [DeviceLocaleScope] 아래면 기기 언어가 바뀔 때 다시 빌드된다.
  /// (범위 밖 — 위젯 단독 테스트 등 — 에서는 플랫폼 로캘을 직접 읽는다.)
  static CalcSemanticStrings of(BuildContext context) => forLocale(
    DeviceLocaleScope.maybeOf(context) ??
        (View.maybeOf(context)?.platformDispatcher ??
                WidgetsBinding.instance.platformDispatcher)
            .locale,
  );

  /// 50키의 음성 라벨. 모든 [CalcKeyId]를 담는다(테스트로 검증).
  Map<CalcKeyId, KeySpeech> get keys;

  /// SHIFT 기능 앞에 붙는 말
  String get shiftLayer;

  /// ALPHA 기능 앞에 붙는 말
  String get alphaLayer;

  /// [id] 키의 [layer] 기능 음성 라벨. 그 층에 기능이 없으면 `null`.
  String? keyFunction(CalcKeyId id, KeyLayer layer) => keys[id]!.of(layer);

  /// 키 버튼의 시맨틱 라벨 — 메인 기능 (예: "사인").
  String keyButton(CalcKeyId id) => keys[id]!.main;

  /// 키 버튼의 시맨틱 힌트 — SHIFT·ALPHA 기능 (예: "시프트 아크사인, 알파 변수 D"). 없으면 `null`.
  ///
  /// iOS VoiceOver는 라벨을 먼저 읽고 잠시 뒤 힌트를 읽는다(힌트를 끈 사용자는 듣지 않는다).
  /// Android TalkBack은 라벨과 힌트를 이어 한 번에 읽는다 — 키를 훑을 때 낭독이 긴 문제는 #2에서 다룬다.
  String? keyButtonHint(CalcKeyId id) {
    final speech = keys[id]!;
    final parts = [
      if (speech.shift case final shift?) '$shiftLayer $shift',
      if (speech.alpha case final alpha?) '$alphaLayer $alpha',
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// [slot] 표시기가 [status]에서 켜져 있으면 그 의미, 꺼져 있으면 `null`.
  String? indicator(LcdIndicatorSlot slot, LcdStatus status);

  /// 상태 표시줄 전체 시맨틱 라벨 (켜진 표시기의 의미를 화면 순서 = 슬롯 순서로)
  String statusBar(LcdStatus status) =>
      [for (final slot in LcdIndicatorSlot.values) ?indicator(slot, status)]
          .join(', ');

  /// LCD 입력 줄
  String get inputLine;

  /// LCD 결과 줄
  String get resultLine;

  /// 줄 왼쪽(◄)·오른쪽(►)에 가려진 내용이 있음
  String scrollMore({required bool left});

  /// 모디파이어 대기가 켜짐/꺼짐을 알리는 말. [modifier]는 SHIFT 또는 ALPHA다.
  String modifierChanged(KeyModifier modifier, {required bool on}) {
    final name = switch (modifier) {
      KeyModifier.shift => shiftLayer,
      KeyModifier.alpha => alphaLayer,
      KeyModifier.none => throw ArgumentError.value(
        modifier,
        'modifier',
        '대기 없음은 알릴 대상이 아니다',
      ),
    };
    return on ? modifierOn(name) : modifierOff(name);
  }

  /// "[name] 켜짐"
  @protected
  String modifierOn(String name);

  /// "[name] 꺼짐"
  @protected
  String modifierOff(String name);
}

// ═══════════════════════════════════════════════════════════════
// 한국어
// ═══════════════════════════════════════════════════════════════

/// 한국어 음성 문구.
class KoSemanticStrings extends CalcSemanticStrings {
  const KoSemanticStrings();

  @override
  Map<CalcKeyId, KeySpeech> get keys => _koKeys;

  @override
  String get shiftLayer => '시프트';

  @override
  String get alphaLayer => '알파';

  @override
  String? indicator(LcdIndicatorSlot slot, LcdStatus status) {
    if (status.indicatorFor(slot) == null) return null;
    return switch (slot) {
      LcdIndicatorSlot.shift => '시프트',
      LcdIndicatorSlot.alpha => '알파',
      LcdIndicatorSlot.memory => '메모리',
      LcdIndicatorSlot.store => '변수 저장 대기',
      LcdIndicatorSlot.angleUnit => switch (status.angleUnit) {
        AngleUnit.degree => '각도 단위 도',
        AngleUnit.radian => '각도 단위 라디안',
        AngleUnit.gradian => '각도 단위 그라디안',
      },
      LcdIndicatorSlot.fixFormat => '소수 자릿수 고정',
      LcdIndicatorSlot.sciFormat => '유효숫자 고정',
      // Engineer Symbol: 결과를 k·M·m·μ 같은 SI 접두어로 표시 (ENG 키의 "공학 표기"와 구분)
      LcdIndicatorSlot.engineering => 'SI 접두어 표시',
      LcdIndicatorSlot.math => '수학 입출력',
      LcdIndicatorSlot.complex => switch (status.complex) {
        ComplexResultIndicator.rectangular => '복소수 직교 형식',
        ComplexResultIndicator.polar => '복소수 극형식',
        ComplexResultIndicator.none => null,
      },
      LcdIndicatorSlot.historyDown => '아래쪽에 내용 더 있음',
      LcdIndicatorSlot.historyUp => '위쪽에 내용 더 있음',
      LcdIndicatorSlot.disp => '중간 결과 표시 중',
    };
  }

  @override
  String get inputLine => '입력';

  @override
  String get resultLine => '결과';

  @override
  String scrollMore({required bool left}) =>
      left ? '왼쪽에 내용 더 있음' : '오른쪽에 내용 더 있음';

  @override
  String modifierOn(String name) => '$name 켜짐';

  @override
  String modifierOff(String name) => '$name 꺼짐';
}

/// 50키 한국어 음성 라벨. 순서는 [CalcKeyId] 선언 순서(실물 배열)다.
///
/// 원칙
/// - 기능을 읽는다(기호 이름·글자 모양이 아니라). 예: `x⁻¹` → "역수", `◄` → "왼쪽 커서".
/// - 같은 층 안에서 서로 달라야 한다. 대소문자만 다른 각인(`E` 변수 / `e` 자연상수)도 말로 구분한다.
/// - 한국어 TTS는 라틴 글자 `e`/`E`를 "이"로 읽어 숫자 2와 같은 소리가 난다. `e`·`E`를 "~의" 앞에 두지 않는다
///   ("e의 거듭제곱"은 "2의 거듭제곱"으로 들린다 → "자연상수의 거듭제곱"). 변수 이름(변수 E)은 그대로 둔다.
/// - 템플릿 입력 칸(`◼`·`◻`)은 읽지 않는다. 칸 수·첫 커서 칸은 수식 편집(M2)에서 LCD가 알려 준다.
/// - 다른 키와 같은 기능이면 같은 말을 쓴다(변수 x: `x` 키 메인 = `)` 키 ALPHA).
const Map<CalcKeyId, KeySpeech> _koKeys = {
  // ── 상단 조작부 ──
  CalcKeyId.shift: KeySpeech('시프트'),
  CalcKeyId.alpha: KeySpeech('알파'),
  CalcKeyId.menu: KeySpeech('메뉴', shift: '설정'),
  CalcKeyId.on: KeySpeech('전원 켜기'),
  CalcKeyId.optn: KeySpeech('옵션', shift: 'QR 코드'),
  CalcKeyId.calc: KeySpeech('변수 대입 계산', shift: '방정식 풀기', alpha: '등호 입력'),
  CalcKeyId.integral: KeySpeech('정적분', shift: '미분계수', alpha: '콜론'),
  CalcKeyId.variableX: KeySpeech('변수 x', shift: '합계 시그마'),

  // ── 커서 패드 ──
  CalcKeyId.cursorUp: KeySpeech('위쪽 커서'),
  CalcKeyId.cursorDown: KeySpeech('아래쪽 커서'),
  CalcKeyId.cursorLeft: KeySpeech('왼쪽 커서'),
  CalcKeyId.cursorRight: KeySpeech('오른쪽 커서'),

  // ── 함수부 1행 ──
  CalcKeyId.fraction: KeySpeech('분수', shift: '대분수'),
  CalcKeyId.sqrt: KeySpeech('제곱근', shift: '세제곱근'),
  CalcKeyId.square: KeySpeech('제곱', shift: '세제곱'),
  CalcKeyId.power: KeySpeech('거듭제곱', shift: '거듭제곱근'),
  CalcKeyId.logBase: KeySpeech('밑 지정 로그', shift: '10의 거듭제곱'),
  CalcKeyId.ln: KeySpeech('자연로그', shift: '자연상수의 거듭제곱'),

  // ── 함수부 2행 (ALPHA: 변수 A~F) ──
  // (−) SHIFT log는 log(a,b) 입력 — 밑을 생략할 때만 상용로그다.
  CalcKeyId.negative: KeySpeech('음수 부호', shift: '로그', alpha: '변수 A'),
  CalcKeyId.degMinSec: KeySpeech('도분초', shift: '소인수분해', alpha: '변수 B'),
  CalcKeyId.reciprocal: KeySpeech('역수', shift: '팩토리얼', alpha: '변수 C'),
  CalcKeyId.sin: KeySpeech('사인', shift: '아크사인', alpha: '변수 D'),
  CalcKeyId.cos: KeySpeech('코사인', shift: '아크코사인', alpha: '변수 E'),
  CalcKeyId.tan: KeySpeech('탄젠트', shift: '아크탄젠트', alpha: '변수 F'),

  // ── 함수부 3행 (ALPHA: 변수 x, y, M) ──
  CalcKeyId.sto: KeySpeech('변수에 저장', shift: '변수 불러오기'),
  // ENG는 지수를 3씩 낮추고(소수점 오른쪽 이동), SHIFT ENG(←)는 3씩 높인다(가이드 인쇄 11쪽).
  CalcKeyId.eng: KeySpeech('공학 표기', shift: '공학 표기 소수점 왼쪽 이동'),
  CalcKeyId.parenOpen: KeySpeech('여는 괄호', shift: '절댓값'),
  CalcKeyId.parenClose: KeySpeech('닫는 괄호', shift: '쉼표', alpha: '변수 x'),
  // S⇔D는 표준형(분수·√·π 형태)과 소수 사이를 전환한다.
  CalcKeyId.sdToggle: KeySpeech('표준 소수 변환', shift: '대분수 가분수 변환', alpha: '변수 y'),
  CalcKeyId.mPlus: KeySpeech('메모리 더하기', shift: '메모리 빼기', alpha: '변수 M'),

  // ── 숫자부 ──
  CalcKeyId.num7: KeySpeech('7', shift: '과학 상수'),
  CalcKeyId.num8: KeySpeech('8', shift: '단위 변환'),
  CalcKeyId.num9: KeySpeech('9', shift: '초기화'),
  CalcKeyId.del: KeySpeech('지우기', shift: '삽입', alpha: '실행 취소'),
  CalcKeyId.ac: KeySpeech('모두 지우기', shift: '전원 끄기'),
  CalcKeyId.num4: KeySpeech('4'),
  CalcKeyId.num5: KeySpeech('5'),
  CalcKeyId.num6: KeySpeech('6'),
  CalcKeyId.multiply: KeySpeech('곱하기', shift: '순열'),
  CalcKeyId.divide: KeySpeech('나누기', shift: '조합'),
  CalcKeyId.num1: KeySpeech('1'),
  CalcKeyId.num2: KeySpeech('2'),
  CalcKeyId.num3: KeySpeech('3'),
  CalcKeyId.add: KeySpeech('더하기', shift: '극좌표 변환'),
  CalcKeyId.subtract: KeySpeech('빼기', shift: '직교좌표 변환'),
  CalcKeyId.num0: KeySpeech('0', shift: '반올림'),
  CalcKeyId.dot: KeySpeech('소수점', shift: '난수', alpha: '정수 난수'),
  // ×10ˣ는 연산자가 아니라 지수 표기 입력이다(× 키 "곱하기"·SHIFT log "10의 거듭제곱"과 구분).
  CalcKeyId.exp10: KeySpeech('지수 표기 입력', shift: '파이', alpha: '자연상수 e'),
  CalcKeyId.ans: KeySpeech('직전 답', shift: '퍼센트'),
  CalcKeyId.equals: KeySpeech('계산 실행', shift: '근삿값'),
};

// ═══════════════════════════════════════════════════════════════
// 영어
// ═══════════════════════════════════════════════════════════════

/// 영어 음성 문구 (한국어가 아닌 기기).
class EnSemanticStrings extends CalcSemanticStrings {
  const EnSemanticStrings();

  @override
  Map<CalcKeyId, KeySpeech> get keys => _enKeys;

  @override
  String get shiftLayer => 'Shift';

  @override
  String get alphaLayer => 'Alpha';

  @override
  String? indicator(LcdIndicatorSlot slot, LcdStatus status) {
    if (status.indicatorFor(slot) == null) return null;
    return switch (slot) {
      LcdIndicatorSlot.shift => 'Shift',
      LcdIndicatorSlot.alpha => 'Alpha',
      LcdIndicatorSlot.memory => 'Memory',
      LcdIndicatorSlot.store => 'Store to variable',
      LcdIndicatorSlot.angleUnit => switch (status.angleUnit) {
        AngleUnit.degree => 'Degrees',
        AngleUnit.radian => 'Radians',
        AngleUnit.gradian => 'Gradians',
      },
      LcdIndicatorSlot.fixFormat => 'Fixed decimals',
      LcdIndicatorSlot.sciFormat => 'Significant digits',
      LcdIndicatorSlot.engineering => 'SI prefixes',
      LcdIndicatorSlot.math => 'Math input output',
      LcdIndicatorSlot.complex => switch (status.complex) {
        ComplexResultIndicator.rectangular => 'Complex rectangular form',
        ComplexResultIndicator.polar => 'Complex polar form',
        ComplexResultIndicator.none => null,
      },
      LcdIndicatorSlot.historyDown => 'More below',
      LcdIndicatorSlot.historyUp => 'More above',
      LcdIndicatorSlot.disp => 'Showing intermediate result',
    };
  }

  @override
  String get inputLine => 'Input';

  @override
  String get resultLine => 'Result';

  @override
  String scrollMore({required bool left}) =>
      left ? 'More to the left' : 'More to the right';

  @override
  String modifierOn(String name) => '$name on';

  @override
  String modifierOff(String name) => '$name off';
}

/// 50키 영어 음성 라벨 (원칙은 [_koKeys]와 같다).
const Map<CalcKeyId, KeySpeech> _enKeys = {
  // ── 상단 조작부 ──
  CalcKeyId.shift: KeySpeech('Shift'),
  CalcKeyId.alpha: KeySpeech('Alpha'),
  CalcKeyId.menu: KeySpeech('Menu', shift: 'Setup'),
  CalcKeyId.on: KeySpeech('Power on'),
  CalcKeyId.optn: KeySpeech('Options', shift: 'QR code'),
  CalcKeyId.calc: KeySpeech(
    'Calculate with variables',
    shift: 'Solve',
    alpha: 'Insert equals sign',
  ),
  CalcKeyId.integral: KeySpeech(
    'Integral',
    shift: 'Derivative',
    alpha: 'Colon',
  ),
  CalcKeyId.variableX: KeySpeech('Variable x', shift: 'Summation'),

  // ── 커서 패드 ──
  CalcKeyId.cursorUp: KeySpeech('Cursor up'),
  CalcKeyId.cursorDown: KeySpeech('Cursor down'),
  CalcKeyId.cursorLeft: KeySpeech('Cursor left'),
  CalcKeyId.cursorRight: KeySpeech('Cursor right'),

  // ── 함수부 1행 ──
  CalcKeyId.fraction: KeySpeech('Fraction', shift: 'Mixed fraction'),
  CalcKeyId.sqrt: KeySpeech('Square root', shift: 'Cube root'),
  CalcKeyId.square: KeySpeech('Square', shift: 'Cube'),
  CalcKeyId.power: KeySpeech('Power', shift: 'Nth root'),
  CalcKeyId.logBase: KeySpeech('Log with base', shift: 'Ten to the power'),
  CalcKeyId.ln: KeySpeech('Natural log', shift: 'Exponential'),

  // ── 함수부 2행 ──
  CalcKeyId.negative: KeySpeech(
    'Negative',
    shift: 'Log function',
    alpha: 'Variable A',
  ),
  CalcKeyId.degMinSec: KeySpeech(
    'Degrees minutes seconds',
    shift: 'Prime factorization',
    alpha: 'Variable B',
  ),
  CalcKeyId.reciprocal: KeySpeech(
    'Reciprocal',
    shift: 'Factorial',
    alpha: 'Variable C',
  ),
  CalcKeyId.sin: KeySpeech('Sine', shift: 'Arcsine', alpha: 'Variable D'),
  CalcKeyId.cos: KeySpeech('Cosine', shift: 'Arccosine', alpha: 'Variable E'),
  CalcKeyId.tan: KeySpeech('Tangent', shift: 'Arctangent', alpha: 'Variable F'),

  // ── 함수부 3행 ──
  CalcKeyId.sto: KeySpeech('Store', shift: 'Recall'),
  CalcKeyId.eng: KeySpeech(
    'Engineering notation',
    shift: 'Engineering shift left',
  ),
  CalcKeyId.parenOpen: KeySpeech('Open parenthesis', shift: 'Absolute value'),
  CalcKeyId.parenClose: KeySpeech(
    'Close parenthesis',
    shift: 'Comma',
    alpha: 'Variable x',
  ),
  CalcKeyId.sdToggle: KeySpeech(
    'Standard to decimal',
    shift: 'Mixed or improper fraction',
    alpha: 'Variable y',
  ),
  CalcKeyId.mPlus: KeySpeech(
    'Memory plus',
    shift: 'Memory minus',
    alpha: 'Variable M',
  ),

  // ── 숫자부 ──
  CalcKeyId.num7: KeySpeech('7', shift: 'Scientific constants'),
  CalcKeyId.num8: KeySpeech('8', shift: 'Unit conversion'),
  CalcKeyId.num9: KeySpeech('9', shift: 'Reset'),
  CalcKeyId.del: KeySpeech('Delete', shift: 'Insert', alpha: 'Undo'),
  CalcKeyId.ac: KeySpeech('All clear', shift: 'Power off'),
  CalcKeyId.num4: KeySpeech('4'),
  CalcKeyId.num5: KeySpeech('5'),
  CalcKeyId.num6: KeySpeech('6'),
  CalcKeyId.multiply: KeySpeech('Times', shift: 'Permutation'),
  CalcKeyId.divide: KeySpeech('Divided by', shift: 'Combination'),
  CalcKeyId.num1: KeySpeech('1'),
  CalcKeyId.num2: KeySpeech('2'),
  CalcKeyId.num3: KeySpeech('3'),
  CalcKeyId.add: KeySpeech('Plus', shift: 'Polar coordinates'),
  CalcKeyId.subtract: KeySpeech('Minus', shift: 'Rectangular coordinates'),
  CalcKeyId.num0: KeySpeech('0', shift: 'Round'),
  CalcKeyId.dot: KeySpeech(
    'Decimal point',
    shift: 'Random number',
    alpha: 'Random integer',
  ),
  CalcKeyId.exp10: KeySpeech(
    'Times ten to the power',
    shift: 'Pi',
    alpha: "Euler's number",
  ),
  CalcKeyId.ans: KeySpeech('Previous answer', shift: 'Percent'),
  CalcKeyId.equals: KeySpeech('Equals', shift: 'Approximate'),
};
