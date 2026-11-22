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

/// 수치 표시 형식의 **표시기 투영** (SETUP → Number Format). Norm이면 표시기가 꺼진다.
/// 자릿수·Norm1/2를 담는 설정 모델은 M3 SETUP(#27)에서 따로 정의하고 이 값으로 매핑한다.
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

/// 복소수 결과 형식 표시기 — SETUP → Complex Result 설정의 **표시기 투영**.
///
/// User's Guide 인쇄 7쪽 Note: `i`는 a+bi, `∠`는 r∠θ 설정을 나타낸다. 결과 값이 복소수인지가 아니라
/// **설정**을 따른다. [none]은 설정 값이 아니라 "표시하지 않음"이다 — 설정 모델은 M3 SETUP(#27)에서
/// 따로 정의하고, 어느 앱에서 표시할지(예: Complex 앱 #5)와 함께 이 값으로 매핑한다.
enum ComplexResultIndicator {
  /// 표시하지 않음
  none(null),

  /// 직교 형식(a+bi) 설정
  rectangular('i'),

  /// 극형식(r∠θ) 설정
  polar('∠');

  /// 상태 표시줄 표시 문자 (`null`이면 표시하지 않음)
  final String? indicator;

  const ComplexResultIndicator(this.indicator);
}

/// LCD 상태 표시줄의 고정 슬롯. 선언 순서가 화면의 왼쪽 → 오른쪽 배치 순서다 (#44).
///
/// 실물 LCD처럼 슬롯 위치는 고정이며, 표시기가 꺼져도 자리를 비워 두어 다른 표시기가 밀리지 않는다.
///
/// 출처:
/// - 표시기 종류·모양: fx-570EX/fx-991EX User's Guide (RJA532432-001V01) 인쇄 4쪽 표시기 표,
///   3쪽 "Reading the Display"(▲), 7쪽 Note(E, i/∠). STO 대기는 `→x`, MathI는 `√▭✎`, 다중 문장 중간
///   결과는 `‖` 아이콘이다. 표에 RCL 표시기는 없다.
/// - 좌→우 순서: 사용자 제공 fx-991EX(ClassWiz) 실물 정보 — S, A, M, →x, D/R/G, FIX, SCI, √▭✎, ▼/▲,
///   Disp ‖, ☀. 가이드에는 순서가 없다. 결정 기록은 #44 결정 요약 코멘트(2026-11-22)이며, 이슈 본문의
///   S A M STO RCL … Math … Disp 순서는 구형 fx-991ES PLUS의 표시줄로 정정되었다.
///   - E와 i/∠는 이 순서에 없어 위치가 **잠정**이다: E는 수치 형식(FIX/SCI) 뒤, i/∠는 입출력 형식 뒤(#58).
///   - "▼/▲"는 동시에 켜질 수 있어(위·아래 모두 내용이 있을 때) 슬롯 두 개로 두고 표기 순서대로 ▼를 왼쪽에
///     둔다(D/R/G는 셋 중 하나만 켜지므로 슬롯 하나). 실물이 한 자리에 위아래로 겹친 모양인지는 미확인이고
///     (#58), 가이드에서 확인된 것은 ▲뿐이다(인쇄 3쪽 그림).
///   - 사용자 정보의 "Disp"와 "‖"는 가이드 표의 "‖ = 다중 문장 중간 결과" 하나로 보고 슬롯 하나([disp])로 둔다.
///   - 태양전지 `☀`는 앱에 해당 상태가 없어 넣지 않는다(#44 결정).
/// - 그리는 방식: 글자로 그리는 슬롯과, 글꼴에 맞는 글자가 없어 **직접 그리는 아이콘** 슬롯([icon])이 있다(#57).
///   `→x`·`√▭✎`·`‖`는 글꼴 글자로는 기준선·크기가 맞지 않고(`‖`는 기준선 아래로 내려감, `√`의 윗선이
///   칸을 덮지 않음), `▭`는 두 칸 폭, `✎`(U+270E)는 번들 글꼴에 없다(`assets/fonts/README.md`).
///   [template]은 아이콘 슬롯에서도 표시 문자(식별자)로 쓰이고 화면에는 그려지지 않는다.
enum LcdIndicatorSlot {
  /// S — SHIFT 1회성 대기
  shift('S', columns: 1),

  /// A — ALPHA 1회성 대기
  alpha('A', columns: 1),

  /// M — 독립 메모리에 값이 있음
  memory('M', columns: 1),

  /// →x — 변수 지정 대기 (STO 키를 누른 뒤). 아이콘으로 그린다.
  store('→x', columns: 2, icon: LcdIndicatorIcon.storeArrow),

  /// D/R/G — 각도 단위 (항상 켜짐, 한 자리에서 셋 중 하나)
  angleUnit('D', columns: 1),

  /// FIX — 소수점 이하 자릿수 고정 (SCI와 다른 자리 — Norm이면 둘 다 꺼짐)
  fixFormat('FIX', columns: 3),

  /// SCI — 유효숫자 자릿수 고정
  sciFormat('SCI', columns: 3),

  /// E — 공학 기호(Engineer Symbol) On (위치 잠정 — [provisional])
  engineering('E', columns: 1),

  /// √◻ — MathI 입출력. 실물 `√▭✎`(근호 + 칸 + 연필)를 아이콘으로 그린다(3칸).
  math('√◻', columns: 3, icon: LcdIndicatorIcon.mathInput),

  /// i / ∠ — 복소수 결과 형식 설정 (위치 잠정 — [provisional])
  complex('∠', columns: 1),

  /// ▼ — 아래쪽에 이력·데이터가 더 있음
  historyDown('▼', columns: 1),

  /// ▲ — 위쪽에 이력·데이터가 더 있음 (계산 이력 재생 가능 등)
  historyUp('▲', columns: 1),

  /// ‖ — 멀티 스테이트먼트 중간 결과 표시 중. 아이콘으로 그린다.
  disp('‖', columns: 1, icon: LcdIndicatorIcon.multiStatement);

  /// 대표 표시 문자 — 글자 슬롯은 꺼진 상태에서 흐리게 그리는 글자, 아이콘 슬롯은 표시 문자(식별자)
  final String template;

  /// 슬롯 폭 (LCD 상태 표시 글자 칸 수). 글자 슬롯은 표시할 수 있는 모든 글자 수 이상이다(테스트로 검증).
  final int columns;

  /// 직접 그리는 아이콘. `null`이면 [template]·표시 문자를 글자로 그린다.
  final LcdIndicatorIcon? icon;

  const LcdIndicatorSlot(this.template, {required this.columns, this.icon});

  /// 실물 순서 자료에 없어 위치가 잠정인 슬롯 (가이드에는 있는 표시기). 문서·테스트용 — 테스트가
  /// 나머지 슬롯이 실물 순서와 같은지, 잠정 슬롯이 문서에 적은 자리(E는 SCI 뒤, i/∠는 √◻ 뒤)에 있는지 검사한다.
  static const Set<LcdIndicatorSlot> provisional = {engineering, complex};
}

/// 상태 표시줄에서 글자 대신 직접 그리는 아이콘 (#57). 모양은 표현 계층(`LcdStatusIcon`)이 그린다.
enum LcdIndicatorIcon {
  /// `→x` — 오른쪽 화살표 + x (변수 지정 대기, 2칸)
  storeArrow,

  /// `√▭✎` — 근호가 칸을 덮고 오른쪽에 연필 (MathI 입출력, 3칸)
  mathInput,

  /// `‖` — 대문자 높이의 세로 이중선 (다중 문장 중간 결과, 1칸)
  multiStatement,
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

  /// 변수 지정 대기 (→x)
  final bool store;

  /// 각도 단위 (D/R/G)
  final AngleUnit angleUnit;

  /// 수치 표시 형식 (FIX 또는 SCI 자리, Norm이면 둘 다 꺼짐)
  final NumberDisplayFormat numberFormat;

  /// 공학 기호 On (E)
  final bool engineering;

  /// MathI 입출력 (√◻)
  final bool mathIO;

  /// 복소수 결과 형식 설정 (i/∠)
  final ComplexResultIndicator complex;

  /// 멀티 스테이트먼트 중간 결과 표시 중 (‖)
  final bool disp;

  /// 위쪽에 이력·데이터가 더 있음 (▲)
  final bool historyUp;

  /// 아래쪽에 이력·데이터가 더 있음 (▼)
  final bool historyDown;

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
    this.historyUp = false,
    this.historyDown = false,
  });

  /// 실물 초기 설정(RESET 직후)과 같은 상태: Deg, Norm, MathI/MathO
  static const LcdStatus initial = LcdStatus();

  /// [slot]에 지금 켜져 있는 표시 문자. 꺼져 있으면 `null`.
  String? indicatorFor(LcdIndicatorSlot slot) => switch (slot) {
    LcdIndicatorSlot.shift => shift ? 'S' : null,
    LcdIndicatorSlot.alpha => alpha ? 'A' : null,
    LcdIndicatorSlot.memory => memory ? 'M' : null,
    LcdIndicatorSlot.store => store ? '→x' : null,
    LcdIndicatorSlot.angleUnit => angleUnit.indicator,
    LcdIndicatorSlot.fixFormat =>
      numberFormat == NumberDisplayFormat.fix ? numberFormat.indicator : null,
    LcdIndicatorSlot.sciFormat =>
      numberFormat == NumberDisplayFormat.sci ? numberFormat.indicator : null,
    LcdIndicatorSlot.engineering => engineering ? 'E' : null,
    LcdIndicatorSlot.math => mathIO ? '√◻' : null,
    LcdIndicatorSlot.complex => complex.indicator,
    LcdIndicatorSlot.historyDown => historyDown ? '▼' : null,
    LcdIndicatorSlot.historyUp => historyUp ? '▲' : null,
    LcdIndicatorSlot.disp => disp ? '‖' : null,
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
    bool? historyUp,
    bool? historyDown,
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
    historyUp: historyUp ?? this.historyUp,
    historyDown: historyDown ?? this.historyDown,
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
      other.disp == disp &&
      other.historyUp == historyUp &&
      other.historyDown == historyDown;

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
    historyUp,
    historyDown,
  );

  @override
  String toString() => 'LcdStatus(${activeIndicators.join(' ')})';
}
