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

/// LCD 상태 표시줄의 고정 슬롯. 선언 순서가 화면의 왼쪽 → 오른쪽 배치 순서다 (#44, #58).
///
/// 실물 LCD처럼 슬롯 위치는 고정이다. 표시기가 꺼져도 자리를 비워 두어 다른 표시기가 밀리지 않는다.
/// 슬롯 하나가 실물 LCD 세그먼트 하나다. 그래서 D/R/G와 i/∠도 각자 자리가 따로 있다.
///
/// 출처:
/// - 표시기 종류·모양: fx-570EX/fx-991EX User's Guide (RJA532432-001V01) 인쇄 4쪽 표시기 표,
///   3쪽 "Reading the Display"(▲), 7쪽 Note(E, i/∠). STO 대기는 `→x`, MathI는 `√▭✎`, 다중 문장 중간
///   결과는 `‖` 아이콘이다. 표에 RCL 표시기는 없다.
/// - 좌→우 순서와 가로 위치(#58): ClassWiz LCD 세그먼트 좌표와 실물 사진을 대조해 확정했다.
///   - 좌표: CasioEmu(user202729/CasioEmu, `models/fx991cnx/model.lua`의 `rsd_*` 스프라이트, fx-991EX와 같은
///     ClassWiz 하드웨어)를 썼다. 사각형은 LCD 왼쪽(x=47)부터 192도트를 빈틈없이 덮는다. `interface.png`
///     y=603~610을 흰 배경에 알파 합성한 회색값 < 200인 열을 잉크 범위 [lo, hi)로 읽고, 그 가운데를 [dotCenter]로 삼았다
///     (표는 `test/unit/lcd_status_test.dart`).
///   - 대조: Wikimedia Commons "Casio fx-991EX Scientific Calculator.jpg"를 썼다. 사진 x를 도트로 바꿀 때는
///     켜진 D와 ☀의 가운데를 이 좌표에 맞췄다. 그렇게 잰 나머지 켜진 √▭✎·▲의 위치가 1도트 안쪽으로 맞았다.
///     흐린 꺼진 세그먼트의 순서도 같다.
///   - 실물 순서: S, A, M, →x, √▭✎, D, R, G, FIX, SCI, E, i, ∠, (⇩), (◀), ▼, ▲, (▶), ‖, (☀).
///     #44에서 받은 순서(√▭✎가 SCI 뒤)는 사진과 달라 사용자 확인을 받아 사진 기준으로 고쳤다(2026-11-26).
///   - 이 순서로 #44의 잠정 자리를 확정했다. E는 SCI 바로 뒤, i·∠는 E 바로 뒤의 서로 다른 두 자리다.
///   - ▼·▲는 한 자리에 위아래로 겹친 것이 아니라 나란한 두 자리다(▼ 왼쪽). 세그먼트도 따로 있다.
///   - 괄호 안 세그먼트는 넣지 않고 자리만 비워 둔다. ⇩·◀·▶는 가이드 표시기 표에 없고, ☀는 앱에 해당 상태가
///     없다(#44 결정). ◀·▶는 입력 줄 가로 넘침을 상태줄에서 알리는 표시일 가능성이 있다. 그렇다면 줄 안에 ◄/►를
///     그리는 지금 설계(`LcdLineOverflow`)와 다르다. 실기기로 확인하지 못했으며, #36에서 함께 확인한다.
///   - 사용자 정보의 "Disp"와 "‖"는 가이드 표의 "‖ = 다중 문장 중간 결과" 하나로 보고 슬롯 하나([disp])로 둔다.
/// - 그리는 방식: 대부분은 글자로 그리고, 글꼴에 맞는 글자가 없는 슬롯은 **직접 그리는 아이콘**([icon])으로 그린다(#57).
///   - `→x`·`√▭✎`·`‖`는 글꼴 글자로는 기준선·크기가 맞지 않는다. `‖`는 기준선 아래로 내려가고, `√`의 윗선은
///     칸을 덮지 않는다.
///   - `▭`는 두 칸 폭이고, `✎`(U+270E)는 번들 글꼴에 없다(`assets/fonts/README.md`).
///   - [template]은 아이콘 슬롯에서도 표시 문자(식별자)로 쓰이고 화면에는 그려지지 않는다.
///   - S·A·D·R·G는 어두운 상자 안의 밝은 글자(반전 상자, [boxed])다(#160). 근거:
///     - 사진: 위 Commons 사진에서 켜진 D가 어두운 상자 안의 밝은 D로 보인다.
///     - 스프라이트: `interface.png` 같은 줄에서 다섯 글자 모두 상자다(`‖`도 상자 안의 밝은 두 획).
///     - 한계: S·A·R·G가 켜진 모습은 사진으로 확인하지 못했다. 스프라이트는 8도트 축소본이라 세부가 뭉개진다.
enum LcdIndicatorSlot {
  /// S — SHIFT 1회성 대기 (반전 상자 글자)
  shift('S', columns: 1, dotCenter: 3.5, boxed: true),

  /// A — ALPHA 1회성 대기 (반전 상자 글자)
  alpha('A', columns: 1, dotCenter: 11.5, boxed: true),

  /// M — 독립 메모리에 값이 있음
  memory('M', columns: 1, dotCenter: 20.5),

  /// →x — 변수 지정 대기 (STO 키를 누른 뒤). 아이콘으로 그린다.
  store('→x', columns: 2, dotCenter: 32, icon: LcdIndicatorIcon.storeArrow),

  /// √◻ — MathI 입출력. 실물 `√▭✎`(근호 + 칸 + 연필)를 아이콘으로 그린다(3칸).
  math('√◻', columns: 3, dotCenter: 47, icon: LcdIndicatorIcon.mathInput),

  /// D — 각도 단위 도 (D/R/G 세 자리 중 하나만 켜짐, 반전 상자 글자)
  angleDegree('D', columns: 1, dotCenter: 60.5, boxed: true),

  /// R — 각도 단위 라디안 (반전 상자 글자)
  angleRadian('R', columns: 1, dotCenter: 67.5, boxed: true),

  /// G — 각도 단위 그라디안 (반전 상자 글자)
  angleGradian('G', columns: 1, dotCenter: 74.5, boxed: true),

  /// FIX — 소수점 이하 자릿수 고정 (SCI와 다른 자리 — Norm이면 둘 다 꺼짐)
  fixFormat('FIX', columns: 3, dotCenter: 87),

  /// SCI — 유효숫자 자릿수 고정
  sciFormat('SCI', columns: 3, dotCenter: 100.5),

  /// E — 공학 기호(Engineer Symbol) On
  engineering('E', columns: 1, dotCenter: 113),

  /// i — 복소수 결과 형식 a+bi 설정 (∠와 다른 자리, 둘 중 하나만 켜짐)
  complexRectangular('i', columns: 1, dotCenter: 121),

  /// ∠ — 복소수 결과 형식 r∠θ 설정
  complexPolar('∠', columns: 1, dotCenter: 128.5),

  /// ▼ — 아래쪽에 이력·데이터가 더 있음
  historyDown('▼', columns: 1, dotCenter: 152.5),

  /// ▲ — 위쪽에 이력·데이터가 더 있음 (계산 이력 재생 가능 등)
  historyUp('▲', columns: 1, dotCenter: 159.5),

  /// ‖ — 멀티 스테이트먼트 중간 결과 표시 중. 아이콘으로 그린다.
  disp(
    '‖',
    columns: 1,
    dotCenter: 176.5,
    icon: LcdIndicatorIcon.multiStatement,
  );

  /// 대표 표시 문자 — 글자 슬롯은 꺼진 상태에서 흐리게 그리는 글자, 아이콘 슬롯은 표시 문자(식별자)
  final String template;

  /// 슬롯 폭 (LCD 상태 표시 글자 칸 수). 글자 슬롯은 표시할 수 있는 모든 글자 수 이상이다(테스트로 검증).
  final int columns;

  /// 실물 세그먼트 가운데의 가로 위치. 상태 표시줄 폭을 [dotColumns]도트로 본 값이다(#58).
  final double dotCenter;

  /// 직접 그리는 아이콘. `null`이면 [template]·표시 문자를 글자로 그린다.
  final LcdIndicatorIcon? icon;

  /// 반전 상자 글자 — 어두운 상자 안에 글자를 밝게(상자를 글자 모양으로 비워) 그린다(#160).
  /// 실물 S·A·D·R·G가 이렇게 생겼다. 글자 하나짜리 1칸 글자 슬롯만 된다(테스트로 검증).
  final bool boxed;

  const LcdIndicatorSlot(
    this.template, {
    required this.columns,
    required this.dotCenter,
    this.icon,
    this.boxed = false,
  });

  /// 실물 ClassWiz LCD의 가로 도트 수 — [dotCenter]의 기준 폭
  static const int dotColumns = 192;

  /// 상태 표시줄 폭 대비 세그먼트 가운데 위치 (0~1)
  double get centerFraction => dotCenter / dotColumns;
}

/// 상태 표시줄에서 글자 대신 직접 그리는 아이콘 (#57). 모양은 표현 계층(`LcdStatusIcon`)이 그린다.
enum LcdIndicatorIcon {
  /// `→x` — 오른쪽 화살표 + 테두리 상자 안의 x (변수 지정 대기, 2칸, #160)
  storeArrow,

  /// `√▭✎` — 근호 윗선이 칸의 윗변이 되고, 칸 오른쪽 변에 촉을 댄 연필 (MathI 입출력, 3칸, #160)
  mathInput,

  /// `‖` — 어두운 상자 안의 밝은 세로 두 획 (다중 문장 중간 결과, 1칸, #160)
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

  /// MathI 입출력 (√▭✎ 아이콘, 표시 문자 `√◻`)
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
    LcdIndicatorSlot.math => mathIO ? '√◻' : null,
    LcdIndicatorSlot.angleDegree => _ifAngle(AngleUnit.degree),
    LcdIndicatorSlot.angleRadian => _ifAngle(AngleUnit.radian),
    LcdIndicatorSlot.angleGradian => _ifAngle(AngleUnit.gradian),
    LcdIndicatorSlot.fixFormat =>
      numberFormat == NumberDisplayFormat.fix ? numberFormat.indicator : null,
    LcdIndicatorSlot.sciFormat =>
      numberFormat == NumberDisplayFormat.sci ? numberFormat.indicator : null,
    LcdIndicatorSlot.engineering => engineering ? 'E' : null,
    LcdIndicatorSlot.complexRectangular => _ifComplex(
      ComplexResultIndicator.rectangular,
    ),
    LcdIndicatorSlot.complexPolar => _ifComplex(ComplexResultIndicator.polar),
    LcdIndicatorSlot.historyDown => historyDown ? '▼' : null,
    LcdIndicatorSlot.historyUp => historyUp ? '▲' : null,
    LcdIndicatorSlot.disp => disp ? '‖' : null,
  };

  /// 각도 단위가 [unit]이면 그 표시 문자 (D/R/G는 자리가 따로 있다)
  String? _ifAngle(AngleUnit unit) =>
      angleUnit == unit ? angleUnit.indicator : null;

  /// 복소수 결과 형식 설정이 [form]이면 그 표시 문자 (i와 ∠는 자리가 따로 있다)
  String? _ifComplex(ComplexResultIndicator form) =>
      complex == form ? complex.indicator : null;

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
