import 'package:material_ui/material_ui.dart';

import '../../core/constants/key_definitions.dart';
import '../../domain/models/calc_state.dart';
import '../../domain/models/lcd_status.dart';

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
/// ## 다국어 구조
/// 언어마다 이 클래스를 구현하고 [forLanguage]에서 언어 코드로 고른다. 지금은 한국어([KoSemanticStrings])만
/// 있으며, 지원하지 않는 언어는 한국어로 대체한다. 앱 전체 다국어(`flutter_localizations`·ARB)를 도입할 때
/// 이 클래스를 그 체계로 옮긴다.
abstract class CalcSemanticStrings {
  const CalcSemanticStrings();

  /// [languageCode]에 맞는 문구. 지원하지 않거나 `null`이면 한국어.
  /// (언어를 추가하면 여기서 `languageCode`로 분기한다.)
  static CalcSemanticStrings forLanguage(String? languageCode) =>
      const KoSemanticStrings();

  /// [context]의 로캘에 맞는 문구.
  static CalcSemanticStrings of(BuildContext context) =>
      forLanguage(Localizations.maybeLocaleOf(context)?.languageCode);

  /// 50키의 음성 라벨. 모든 [CalcKeyId]를 담는다(테스트로 검증).
  Map<CalcKeyId, KeySpeech> get keys;

  /// SHIFT 기능 앞에 붙는 말
  String get shiftLayer;

  /// ALPHA 기능 앞에 붙는 말
  String get alphaLayer;

  /// [id] 키의 [layer] 기능 음성 라벨. 그 층에 기능이 없으면 `null`.
  String? keyFunction(CalcKeyId id, KeyLayer layer) => keys[id]!.of(layer);

  /// 키 버튼의 시맨틱 라벨: 메인 기능, 이어서 SHIFT·ALPHA 기능 (예: "사인, 시프트 역사인, 알파 변수 D").
  String keyButton(CalcKeyId id) {
    final speech = keys[id]!;
    return [
      speech.main,
      if (speech.shift case final shift?) '$shiftLayer $shift',
      if (speech.alpha case final alpha?) '$alphaLayer $alpha',
    ].join(', ');
  }

  /// [slot] 표시기가 [status]에서 켜져 있으면 그 의미, 꺼져 있으면 `null`.
  String? indicator(LcdIndicatorSlot slot, LcdStatus status);

  /// 상태 표시줄 전체 시맨틱 라벨 (켜진 표시기의 의미를 슬롯 순서로)
  String statusBar(LcdStatus status) =>
      [for (final slot in LcdIndicatorSlot.values) ?indicator(slot, status)]
          .join(', ');

  /// LCD 입력 줄
  String get inputLine;

  /// LCD 결과 줄
  String get resultLine;

  /// 줄 왼쪽(◄)·오른쪽(►)에 가려진 내용이 있음
  String scrollMore({required bool left});

  /// 모디파이어 대기가 켜짐/꺼짐을 알리는 말 (`KeyModifier.none`은 쓰지 않는다)
  String modifierChanged(KeyModifier modifier, {required bool on});
}

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
        AngleUnit.degree => '각도 도',
        AngleUnit.radian => '각도 라디안',
        AngleUnit.gradian => '각도 그라디안',
      },
      LcdIndicatorSlot.numberFormat => switch (status.numberFormat) {
        NumberDisplayFormat.fix => '소수 자릿수 고정',
        NumberDisplayFormat.sci => '유효숫자 고정',
        NumberDisplayFormat.norm => null,
      },
      LcdIndicatorSlot.engineering => '공학 기호',
      LcdIndicatorSlot.math => '수학 입출력',
      LcdIndicatorSlot.complex => switch (status.complex) {
        ComplexResultIndicator.rectangular => '복소수 직교 형식',
        ComplexResultIndicator.polar => '복소수 극형식',
        ComplexResultIndicator.none => null,
      },
      LcdIndicatorSlot.disp => '중간 결과 표시 중',
      LcdIndicatorSlot.historyUp => '위쪽에 내용 더 있음',
      LcdIndicatorSlot.historyDown => '아래쪽에 내용 더 있음',
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
  String modifierChanged(KeyModifier modifier, {required bool on}) {
    final name = switch (modifier) {
      KeyModifier.shift => '시프트',
      KeyModifier.alpha => '알파',
      KeyModifier.none => '',
    };
    return on ? '$name 켜짐' : '$name 꺼짐';
  }
}

/// 50키 한국어 음성 라벨. 순서는 [CalcKeyId] 선언 순서(실물 배열)다.
///
/// 원칙
/// - 기능을 읽는다(기호 이름·글자 모양이 아니라). 예: `x⁻¹` → "역수", `◄` → "왼쪽 커서".
/// - 같은 층 안에서 서로 달라야 한다. 대소문자만 다른 각인(`E` 변수 / `e` 자연상수)도 말로 구분한다.
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
  CalcKeyId.integral: KeySpeech('정적분', shift: '미분', alpha: '콜론'),
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
  CalcKeyId.ln: KeySpeech('자연로그', shift: 'e의 거듭제곱'),

  // ── 함수부 2행 (ALPHA: 변수 A~F) ──
  CalcKeyId.negative: KeySpeech('음수 부호', shift: '상용로그', alpha: '변수 A'),
  CalcKeyId.degMinSec: KeySpeech('도분초', shift: '소인수분해', alpha: '변수 B'),
  CalcKeyId.reciprocal: KeySpeech('역수', shift: '팩토리얼', alpha: '변수 C'),
  CalcKeyId.sin: KeySpeech('사인', shift: '역사인', alpha: '변수 D'),
  CalcKeyId.cos: KeySpeech('코사인', shift: '역코사인', alpha: '변수 E'),
  CalcKeyId.tan: KeySpeech('탄젠트', shift: '역탄젠트', alpha: '변수 F'),

  // ── 함수부 3행 (ALPHA: 변수 x, y, M) ──
  CalcKeyId.sto: KeySpeech('변수에 저장', shift: '변수 불러오기'),
  CalcKeyId.eng: KeySpeech('공학 표기', shift: '공학 표기 반대 방향'),
  CalcKeyId.parenOpen: KeySpeech('여는 괄호', shift: '절댓값'),
  CalcKeyId.parenClose: KeySpeech('닫는 괄호', shift: '쉼표', alpha: '변수 x'),
  CalcKeyId.sdToggle: KeySpeech('분수 소수 변환', shift: '대분수 가분수 변환', alpha: '변수 y'),
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
  CalcKeyId.exp10: KeySpeech('곱하기 10의 거듭제곱', shift: '파이', alpha: '자연상수 e'),
  CalcKeyId.ans: KeySpeech('직전 답', shift: '퍼센트'),
  CalcKeyId.equals: KeySpeech('계산 실행', shift: '근삿값'),
};
