import 'package:meta/meta.dart';

/// 각도 단위 (SETUP → Angle Unit). LCD 상태 표시줄에 D/R/G로 표시된다.
enum AngleUnit {
  /// 도 (Degree)
  degree('D'),

  /// 라디안 (Radian)
  radian('R'),

  /// 그라디안 (Gradian)
  gradian('G');

  /// 상태 표시줄 표시 문자
  final String indicator;

  const AngleUnit(this.indicator);
}

/// 수치 표시 형식 (SETUP → Number Format). Norm이면 표시기가 꺼진다.
enum NumberDisplayFormat {
  /// Norm 1/2 — 표시기 없음
  norm(null),

  /// 소수점 이하 자릿수 고정
  fix('FIX'),

  /// 유효숫자 자릿수 고정
  sci('SCI');

  /// 상태 표시줄 표시 문자 (`null`이면 표시하지 않음)
  final String? indicator;

  const NumberDisplayFormat(this.indicator);
}

/// 복소수 결과 형식 표시기. 결과가 복소수일 때만 켜진다.
enum ComplexResultIndicator {
  /// 복소수 결과 아님 — 표시기 없음
  none(null),

  /// 직교 형식(a+bi) 결과
  rectangular('i'),

  /// 극형식(r∠θ) 결과
  polar('∠');

  /// 상태 표시줄 표시 문자 (`null`이면 표시하지 않음)
  final String? indicator;

  const ComplexResultIndicator(this.indicator);
}

/// LCD 상태 표시줄의 고정 슬롯. 선언 순서가 화면의 왼쪽 → 오른쪽 배치 순서다.
///
/// 실물 LCD처럼 슬롯 위치는 고정이며, 표시기가 꺼져도 자리를 비워 두어 다른 표시기가 밀리지 않는다.
/// (사용자 가이드 "Reading the Display" 기준. 실물 배치 순서 대조는 TODO(#15).)
enum LcdIndicatorSlot {
  /// S — SHIFT 1회성 대기
  shift('S'),

  /// A — ALPHA 1회성 대기
  alpha('A'),

  /// M — 독립 메모리에 값이 있음
  memory('M'),

  /// STO — 변수 지정 대기 (SHIFT + RCL)
  store('STO'),

  /// D/R/G — 각도 단위 (항상 켜짐)
  angleUnit('D'),

  /// FIX/SCI — 수치 표시 형식 (Norm이면 꺼짐)
  numberFormat('FIX'),

  /// E — 공학 기호(Engineer Symbol) On
  engineering('E'),

  /// Math — MathI 입출력
  math('Math'),

  /// i / ∠ — 복소수 결과 형식
  complex('∠'),

  /// Disp — 멀티 스테이트먼트 중간 결과 표시 중
  disp('Disp');

  /// 꺼진 상태에서 흐리게 보여줄 대표 문자이자, 슬롯 너비 산정 기준 문자열
  final String template;

  const LcdIndicatorSlot(this.template);
}

/// LCD 상태 표시줄에 표시할 상태의 불변 스냅샷.
///
/// 계산기 전체 상태(`CalcState`, #11)에서 파생해 `LcdDisplay`에 넘긴다.
@immutable
class LcdStatus {
  /// SHIFT 1회성 대기 (S)
  final bool shift;

  /// ALPHA 1회성 대기 (A)
  final bool alpha;

  /// 독립 메모리에 0이 아닌 값이 있음 (M)
  final bool memory;

  /// 변수 지정 대기 (STO)
  final bool store;

  /// 각도 단위 (D/R/G)
  final AngleUnit angleUnit;

  /// 수치 표시 형식 (FIX/SCI)
  final NumberDisplayFormat numberFormat;

  /// 공학 기호 On (E)
  final bool engineering;

  /// MathI 입출력 (Math)
  final bool mathIO;

  /// 복소수 결과 형식 (i/∠)
  final ComplexResultIndicator complex;

  /// 멀티 스테이트먼트 중간 결과 표시 중 (Disp)
  final bool disp;

  const LcdStatus({
    this.shift = false,
    this.alpha = false,
    this.memory = false,
    this.store = false,
    this.angleUnit = AngleUnit.degree,
    this.numberFormat = NumberDisplayFormat.norm,
    this.engineering = false,
    this.mathIO = true,
    this.complex = ComplexResultIndicator.none,
    this.disp = false,
  });

  /// 실물 초기 설정(RESET 직후)과 같은 상태: Deg, Norm, MathI/MathO
  static const LcdStatus initial = LcdStatus();

  /// [slot]에 지금 켜져 있는 표시 문자. 꺼져 있으면 `null`.
  String? indicatorFor(LcdIndicatorSlot slot) => switch (slot) {
    LcdIndicatorSlot.shift => shift ? 'S' : null,
    LcdIndicatorSlot.alpha => alpha ? 'A' : null,
    LcdIndicatorSlot.memory => memory ? 'M' : null,
    LcdIndicatorSlot.store => store ? 'STO' : null,
    LcdIndicatorSlot.angleUnit => angleUnit.indicator,
    LcdIndicatorSlot.numberFormat => numberFormat.indicator,
    LcdIndicatorSlot.engineering => engineering ? 'E' : null,
    LcdIndicatorSlot.math => mathIO ? 'Math' : null,
    LcdIndicatorSlot.complex => complex.indicator,
    LcdIndicatorSlot.disp => disp ? 'Disp' : null,
  };

  /// 켜져 있는 표시 문자 목록 (슬롯 순서)
  List<String> get activeIndicators => [
    for (final slot in LcdIndicatorSlot.values) ?indicatorFor(slot),
  ];

  LcdStatus copyWith({
    bool? shift,
    bool? alpha,
    bool? memory,
    bool? store,
    AngleUnit? angleUnit,
    NumberDisplayFormat? numberFormat,
    bool? engineering,
    bool? mathIO,
    ComplexResultIndicator? complex,
    bool? disp,
  }) => LcdStatus(
    shift: shift ?? this.shift,
    alpha: alpha ?? this.alpha,
    memory: memory ?? this.memory,
    store: store ?? this.store,
    angleUnit: angleUnit ?? this.angleUnit,
    numberFormat: numberFormat ?? this.numberFormat,
    engineering: engineering ?? this.engineering,
    mathIO: mathIO ?? this.mathIO,
    complex: complex ?? this.complex,
    disp: disp ?? this.disp,
  );

  @override
  bool operator ==(Object other) =>
      other is LcdStatus &&
      other.shift == shift &&
      other.alpha == alpha &&
      other.memory == memory &&
      other.store == store &&
      other.angleUnit == angleUnit &&
      other.numberFormat == numberFormat &&
      other.engineering == engineering &&
      other.mathIO == mathIO &&
      other.complex == complex &&
      other.disp == disp;

  @override
  int get hashCode => Object.hash(
    shift,
    alpha,
    memory,
    store,
    angleUnit,
    numberFormat,
    engineering,
    mathIO,
    complex,
    disp,
  );

  @override
  String toString() => 'LcdStatus(${activeIndicators.join(' ')})';
}

/// 입력·결과 줄이 LCD 폭을 넘을 때 좌/우 스크롤 표시(◀/▶) 여부.
@immutable
class LcdLineOverflow {
  /// 왼쪽에 가려진 내용이 있음 (◀)
  final bool left;

  /// 오른쪽에 가려진 내용이 있음 (▶)
  final bool right;

  const LcdLineOverflow({this.left = false, this.right = false});

  /// 넘침 없음
  static const LcdLineOverflow none = LcdLineOverflow();

  @override
  bool operator ==(Object other) =>
      other is LcdLineOverflow && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);

  @override
  String toString() => 'LcdLineOverflow(left: $left, right: $right)';
}
