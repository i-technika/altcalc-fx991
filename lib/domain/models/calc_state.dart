import 'package:meta/meta.dart';

import '../../core/constants/key_definitions.dart';
import 'lcd_status.dart';

/// 1회성 모디파이어 대기 상태. 다음 키 하나에만 적용되고 자동으로 해제된다.
enum KeyModifier {
  /// 대기 없음
  none,

  /// SHIFT 대기 (LCD `S`)
  shift,

  /// ALPHA 대기 (LCD `A`)
  alpha,
}

/// 키 입력이 선택한 기능 층 (키캡 메인 / 금색 SHIFT 각인 / 빨간 ALPHA 각인).
enum KeyLayer {
  /// 키캡 메인 기능
  main,

  /// SHIFT 기능 (금색 각인)
  shift,

  /// ALPHA 기능 (빨간 각인)
  alpha,
}

/// 모디파이어 해석이 끝난 단일 키 입력.
///
/// [layer]에 기능이 있는 입력만 만들 수 있다(생성자 assert). 즉 [label]은 항상 존재한다.
/// 모디파이어 키(SHIFT/ALPHA) 자체와 설정 키([settingsKey] — ON, #190)는 입력이 아니다.
@immutable
class KeyInput {
  /// 눌린 물리 키
  final CalcKeyId id;

  /// 선택된 기능 층
  final KeyLayer layer;

  /// 길게 누름에 의한 반복 입력 여부 (반복은 항상 [KeyLayer.main]의 [autoRepeatKeys])
  final bool isRepeat;

  KeyInput(this.id, this.layer, {this.isRepeat = false})
    : assert(
        id != CalcKeyId.shift && id != CalcKeyId.alpha,
        '모디파이어 키는 입력이 아니다: $id',
      ),
      assert(id != settingsKey, '설정 키(ON)는 계산기 입력이 아니다 (#190)'),
      assert(labelOf(id, layer) != null, '$id 키에는 $layer 기능이 없다'),
      assert(
        !isRepeat || (layer == KeyLayer.main && autoRepeatKeys.contains(id)),
        '반복 입력은 반복 키의 메인 기능만 가능하다: $id $layer',
      );

  /// [layer]에 해당하는 각인. 해당 층에 기능이 없으면 `null`.
  static String? labelOf(CalcKeyId id, KeyLayer layer) {
    final def = keyDefOf(id);
    return switch (layer) {
      KeyLayer.main => def.mainLabel,
      KeyLayer.shift => def.shiftLabel,
      KeyLayer.alpha => def.alphaLabel,
    };
  }

  /// 입력된 기능의 각인 (예: SHIFT + CALC → `SOLVE`)
  String get label => labelOf(id, layer)!;

  @override
  bool operator ==(Object other) =>
      other is KeyInput &&
      other.id == id &&
      other.layer == layer &&
      other.isRepeat == isRepeat;

  @override
  int get hashCode => Object.hash(id, layer, isRepeat);

  @override
  String toString() =>
      'KeyInput(${id.name}, ${layer.name}${isRepeat ? ', repeat' : ''})';
}

/// 계산기 전체 상태의 불변 스냅샷.
///
/// M1 범위는 1회성 SHIFT/ALPHA 상태 머신이다. 수식 AST·커서(M2), 계산 결과·메모리·설정(M3~)은
/// 이후 마일스톤에서 필드로 추가한다. 상태 전이는 순수 함수([pressKey]/[repeatKey])로 정의해
/// UI 없이 단위 테스트한다.
///
/// ## 1회성 모디파이어 규칙
/// - SHIFT를 누르면 SHIFT 대기(S), 대기 중 다시 누르면 해제한다. ALPHA도 같다.
/// - 한 모디파이어 대기 중 다른 모디파이어를 누르면 그쪽으로 바뀐다(SHIFT → ALPHA = A만 켜짐).
/// - 모디파이어가 아닌 키를 누르면 대기 중인 층의 기능을 입력하고 대기를 **항상** 해제한다.
///   그 층에 기능이 없는 키(예: SHIFT + 4, SHIFT + AC — 실물 OFF는 뺐다)는 아무것도 입력하지 않고 대기만 해제한다.
/// - 설정 키([settingsKey] — ON)는 계산기 입력이 아니다(#190). 화면이 설정을 열고, 상태 머신은 기능 없는 층의
///   키처럼 대기만 해제한다 — 실물 ON 키도 대기를 지운다.
///
/// 위 규칙과 아래 "모디파이어 기능은 반복하지 않는다"는 #15에서 확정했다.
/// - 키를 누르면 대기가 해제된다: User's Guide 인쇄 4쪽 "S … will disappear when you press a key"
/// - 기능 없는 층 입력 무시, SHIFT↔ALPHA 전환, 모디파이어 기능 비반복: 사용자 제공 실물 정보
///   (2026-11-22, #15 댓글에 기록)
///
/// ## 반복 입력 규칙 ([autoRepeatKeys])
/// - 반복은 **모디파이어 없이** 누른 반복 키를 계속 누르고 있을 때만 메인 기능으로 이어진다
///   (SHIFT + DEL = INS 같은 모디파이어 기능은 반복하지 않는다).
/// - 반복 입력은 모디파이어 대기를 소비·변경하지 않는다. 반복 중 다른 손가락으로 SHIFT를 눌러도
///   S는 다음 키 누름까지 유지된다.
/// - 반복 중 모디파이어가 아닌 다른 키를 누르면 이전 키의 반복은 끊긴다(실물처럼 마지막 키만 반복).
/// - [repeatKey]는 키를 **누르고 있는 동안에만** 호출해야 한다(호출자 계약 — `CalcKeyButton`의
///   반복 타이머가 지킨다). 손을 뗀 뒤에도 [repeatableKey]는 남지만 다음 누름에서 갱신된다.
///   하드웨어 키보드 등 다른 입력 경로의 키 해제 처리는 M2 입력 설계에서 정한다.
@immutable
class CalcState {
  /// 1회성 모디파이어 대기 상태
  final KeyModifier modifier;

  /// 가장 최근에 실제로 입력된 기능. 아직 입력이 없으면 `null`.
  /// 기능 없는 층을 눌러 무시된 입력은 반영되지 않는다.
  final KeyInput? lastInput;

  /// 지금까지 입력된 기능 수 (반복 포함). 같은 입력이 연달아 와도 구분할 수 있도록 단조 증가한다.
  final int inputCount;

  /// 길게 눌렀을 때 반복 입력을 이어갈 키. 마지막 누름이 모디파이어 없는 반복 키일 때만 설정된다.
  final CalcKeyId? repeatableKey;

  CalcState({
    this.modifier = KeyModifier.none,
    this.lastInput,
    this.inputCount = 0,
    this.repeatableKey,
  }) : assert(inputCount >= 0, 'inputCount는 0 이상이어야 한다'),
       assert(
         (lastInput == null) == (inputCount == 0),
         '입력이 있으면 lastInput이 있어야 하고, 없으면 null이어야 한다',
       ),
       assert(
         repeatableKey == null || autoRepeatKeys.contains(repeatableKey),
         '반복 대상은 autoRepeatKeys여야 한다: $repeatableKey',
       );

  /// 앱 시작 직후 상태
  static final CalcState initial = CalcState();

  /// LCD 상태 표시줄 스냅샷. M1에서는 S/A만 상태에서 파생하고 나머지는 초기 설정값이다.
  LcdStatus get lcdStatus => LcdStatus(
    shift: modifier == KeyModifier.shift,
    alpha: modifier == KeyModifier.alpha,
  );

  /// [id] 키를 한 번 눌렀을 때의 다음 상태.
  CalcState pressKey(CalcKeyId id) {
    switch (id) {
      case CalcKeyId.shift:
        return _withModifier(
          modifier == KeyModifier.shift ? KeyModifier.none : KeyModifier.shift,
        );
      case CalcKeyId.alpha:
        return _withModifier(
          modifier == KeyModifier.alpha ? KeyModifier.none : KeyModifier.alpha,
        );
      case settingsKey:
        // 기능 없는 층과 같다: 입력 없이 대기만 해제한다. 반복 대상도 끊는다.
        return CalcState(lastInput: lastInput, inputCount: inputCount);
      default:
        break;
    }

    final layer = switch (modifier) {
      KeyModifier.none => KeyLayer.main,
      KeyModifier.shift => KeyLayer.shift,
      KeyModifier.alpha => KeyLayer.alpha,
    };
    if (KeyInput.labelOf(id, layer) == null) {
      // 기능 없는 층: 입력 없이 대기만 해제한다. 반복 대상도 끊는다.
      return CalcState(lastInput: lastInput, inputCount: inputCount);
    }
    return CalcState(
      lastInput: KeyInput(id, layer),
      inputCount: inputCount + 1,
      repeatableKey: layer == KeyLayer.main && autoRepeatKeys.contains(id)
          ? id
          : null,
    );
  }

  /// [id] 키를 계속 누르고 있어 반복 입력이 발생했을 때의 다음 상태.
  /// 반복할 수 없는 경우(위 반복 입력 규칙)는 `this`를 그대로 반환한다.
  CalcState repeatKey(CalcKeyId id) {
    if (repeatableKey != id) return this;
    return CalcState(
      modifier: modifier,
      lastInput: KeyInput(id, KeyLayer.main, isRepeat: true),
      inputCount: inputCount + 1,
      repeatableKey: repeatableKey,
    );
  }

  /// 모디파이어만 바꾼 상태 (입력·반복 대상은 유지)
  CalcState _withModifier(KeyModifier next) => CalcState(
    modifier: next,
    lastInput: lastInput,
    inputCount: inputCount,
    repeatableKey: repeatableKey,
  );

  @override
  bool operator ==(Object other) =>
      other is CalcState &&
      other.modifier == modifier &&
      other.lastInput == lastInput &&
      other.inputCount == inputCount &&
      other.repeatableKey == repeatableKey;

  @override
  int get hashCode =>
      Object.hash(modifier, lastInput, inputCount, repeatableKey);

  @override
  String toString() =>
      'CalcState(${modifier.name}, last: $lastInput, count: $inputCount, '
      'repeatable: ${repeatableKey?.name})';
}
