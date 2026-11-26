import 'package:meta/meta.dart';

import 'key_legend.dart';

export 'key_legend.dart';

// ═══════════════════════════════════════════════════════════════
// 카시오 fx-991EX ClassWiz 50키 키패드 명세
// ═══════════════════════════════════════════════════════════════
//
// 실물 배열 (위 → 아래, 왼쪽 → 오른쪽):
//
//   ┌ 상단 조작부 (8키 + 커서 패드 4방향 = 12키) ───────────────┐
//   │ SHIFT  ALPHA     ┌───────┐     MENU   ON                  │
//   │                  │ ▲ ◄► ▼│                                 │
//   │ OPTN   CALC      └───────┘     ∫◻◻◼   x                   │
//   └───────────────────────────────────────────────────────────┘
//   ┌ 함수부 (3행 × 6열 = 18키) ────────────────────────────────┐
//   │ ◼/◻   √◼   x²   x^◼   log◼◻ ln                            │
//   │ (−)   °'"  x⁻¹  sin   cos   tan                           │
//   │ STO   ENG  (    )     S⇔D   M+                            │
//   └───────────────────────────────────────────────────────────┘
//   ┌ 숫자부 (4행 × 5열 = 20키) ────────────────────────────────┐
//   │ 7  8  9  DEL  AC                                          │
//   │ 4  5  6  ×    ÷                                           │
//   │ 1  2  3  +    −                                           │
//   │ 0  .  ×10ˣ  Ans  =                                        │
//   └───────────────────────────────────────────────────────────┘
//
// ※ 각인 출처 (#15에서 확정):
//   - fx-991EX Quick Start Guide 1쪽의 제품 사진 (전체 50키의 메인·SHIFT·ALPHA 각인)
//   - fx-570EX/fx-991EX User's Guide (RJA532432-001V01)의 키 조작 예제 (쪽수는 인쇄 쪽 기준)
//     ("Key Markings" 3쪽, "Variables (A, B, C, D, E, F, M, x, y)" 13쪽, log 14쪽, ∑·Abs 16쪽)
//   각인 색상 규칙(가이드 "Key Markings" 3쪽):
//   - 노란색 = SHIFT, 빨간색 = ALPHA
//   - 보라색(또는 보라 괄호) = Complex 모드 전용 (ENG 키 위의 ∠·i)
//   - 파란색(또는 파란 괄호) = Base-N 모드 전용 (DEC·HEX·BIN·OCT).
//     A~F는 빨간 글자(ALPHA 변수)에 파란 괄호가 둘러져 있어, Base-N에서는 16진 숫자로 바로 입력된다.
//   이 명세는 노란색·빨간색 각인만 담는다. 모드별 각인은 #33에서 다룬다.
//   숫자 1~6 키에는 각인이 없다.
//
// ※ 각인 표기 (#16에서 칸 규칙 확정, #155에서 2차원 모양으로 바꿈 — 실물 키캡 각인과 같은 규칙):
//   - 각인은 구조([KeyLegend], `key_legend.dart`)로 담는다. 글자만 있는 각인은 [LegendText]이고,
//     분수·위첨자·아래첨자·근호·위아래 끝(∑)이 있는 각인은 실물처럼 2차원으로 그린다(아래 "2차원 각인" 절).
//     실물 비율이 필요한 칸은 글자 대신 직접 그리는 칸([LegendBox])으로 둔다(지금은 ∑ 각인만, #169).
//     키캡 각인 어디에도 한 줄 임시 표기(분수 `/`, 위첨자 `^`, 유니코드 위첨자 `²`·`⁻¹`·`ˣ`)를 쓰지 않는다
//     (테스트로 검증). 한 줄 표기는 [KeyLegend.plainText]로만 만든다(M1 LCD 임시 표시·로그용).
//   - 입력 칸은 **실물 각인에 그려진 칸 수**만큼 쓴다(템플릿의 실제 입력 칸 수와 다를 수 있다 —
//     예: `d/dx◼` 각인은 칸 1개지만 템플릿은 함수·x값 2칸). `◼` = 템플릿을 넣은 직후 커서가 들어가는 칸,
//     `◻` = 나머지 칸. 템플릿 각인에는 `◼`가 정확히 하나 있다(테스트로 검증).
//     예: `log◼◻`(밑 → 진수), `◼√◻`(지수 → 피개법수), `∫◻◻◼`(본문 → 아래·위 끝).
//     (예시는 [KeyLegend.plainText] 표기다. 칸의 채움 여부는 Quick Start Guide 1쪽 제품 사진을 따른다.)
//   - `▭`(U+25AD)는 쓰지 않는다. 번들 글꼴 Noto Sans Mono에서 두 칸 폭이라 라벨 폭 측정을 왜곡한다.
//     같은 이유로 커서 패드 좌우는 `◀`·`▶` 대신 한 칸 폭인 `◄`·`►`를 쓴다 (`▲`·`▼`와 같은 디자인).
//     두 칸 폭 글자는 실물 각인에 꼭 필요한 `⇔`(S⇔D)만 허용한다(테스트로 검증).
//   - 근호는 글자(`√`·`∛`)가 아니라 그림으로 그린다(가로줄이 칸 위를 덮어야 해서). ∫·∑는 번들 대체 글꼴
//     Noto Sans Math의 글자다.

// ═══════════════════════════════════════════════════════════════
// 키 식별자
// ═══════════════════════════════════════════════════════════════

/// 50개 물리 키의 고유 식별자.
///
/// 상태 머신·입력 처리에서 `switch`로 전수 검사(exhaustive)할 수 있도록
/// 문자열 대신 열거형으로 정의한다. 선언 순서 = 실물 배열 순서.
enum CalcKeyId {
  // ── 상단 조작부 ──
  shift,
  alpha,
  menu,
  on,
  optn,
  calc,
  integral,
  variableX,

  // ── 커서 패드 ──
  cursorUp,
  cursorDown,
  cursorLeft,
  cursorRight,

  // ── 함수부 1행 ──
  fraction,
  sqrt,
  square,
  power,

  /// 밑 지정 로그 템플릿 키 `log◼◻`. 밑 생략 상용로그 `log`는 (−) 키의 SHIFT 기능이다.
  logBase,
  ln,

  // ── 함수부 2행 ──
  negative,
  degMinSec,
  reciprocal,
  sin,
  cos,
  tan,

  // ── 함수부 3행 ──
  sto,
  eng,
  parenOpen,
  parenClose,
  sdToggle,
  mPlus,

  // ── 숫자부 ──
  num7,
  num8,
  num9,
  del,
  ac,
  num4,
  num5,
  num6,
  multiply,
  divide,
  num1,
  num2,
  num3,
  add,
  subtract,
  num0,
  dot,
  exp10,
  ans,
  equals,
}

// ═══════════════════════════════════════════════════════════════
// 키 카테고리
// ═══════════════════════════════════════════════════════════════

/// 키캡의 시각적 카테고리. 카테고리마다 배경색/텍스트색이 다르다.
///
/// 색상 매핑은 `core/theme/calc_theme.dart`의 `KeyCategoryColors` 확장에 있다.
/// 이 파일은 도메인 계층에서도 import할 수 있도록 UI 패키지에 의존하지 않는다.
enum KeyCategory {
  /// 밝은 키캡 그룹 (0~9, 소수점, ×10ˣ, Ans).
  /// 시각 분류일 뿐이며 "숫자 입력" 여부를 뜻하지 않는다.
  number,

  /// 사칙연산 키 (+, −, ×, ÷)
  operator,

  /// 함수 키 (sin, log◼◻, x², OPTN, CALC 등)
  function,

  /// 등호(=) 키
  equals,

  /// AC(All Clear) 키
  ac,

  /// DEL(Delete) 키
  del,

  /// SHIFT 모디파이어 키
  shift,

  /// ALPHA 모디파이어 키
  alpha,

  /// 커서 패드 방향 (▲, ▼, ◄, ►)
  cursor,

  /// ON 키
  on,

  /// MENU(모드 선택) 키
  menu,
}

// ═══════════════════════════════════════════════════════════════
// 키 정의 모델
// ═══════════════════════════════════════════════════════════════

/// 단일 키의 3단 각인(메인·SHIFT·ALPHA) 및 카테고리를 정의하는 불변 모델.
@immutable
class CalcKeyDef {
  /// 키 고유 식별자
  final CalcKeyId id;

  /// 키캡 중앙에 표시되는 메인 각인
  final KeyLegend mainLegend;

  /// SHIFT 후 입력되는 기능의 금색 각인. 없으면 `null`.
  final KeyLegend? shiftLegend;

  /// ALPHA 후 입력되는 기능의 빨간색 각인. 없으면 `null`.
  final KeyLegend? alphaLegend;

  /// 키 시각적 카테고리 (색상 테마 결정)
  final KeyCategory category;

  const CalcKeyDef({
    required this.id,
    required this.mainLegend,
    this.shiftLegend,
    this.alphaLegend,
    required this.category,
  });

  /// 메인 각인의 한 줄 표기 ([KeyLegend.plainText] — 화면 각인에는 쓰지 않는다)
  String get mainLabel => mainLegend.plainText;

  /// SHIFT 각인의 한 줄 표기. 없으면 `null`.
  String? get shiftLabel => shiftLegend?.plainText;

  /// ALPHA 각인의 한 줄 표기. 없으면 `null`.
  String? get alphaLabel => alphaLegend?.plainText;

  /// SHIFT 기능 보유 여부
  bool get hasShift => shiftLegend != null;

  /// ALPHA 기능 보유 여부
  bool get hasAlpha => alphaLegend != null;

  @override
  String toString() => 'CalcKeyDef(${id.name}, "$mainLabel")';
}

// ═══════════════════════════════════════════════════════════════
// 2차원 각인 (#155)
// ═══════════════════════════════════════════════════════════════
//
// 실물 키캡처럼 분수는 위아래로 쌓고, 지수 칸은 오른쪽 위, 밑 칸은 오른쪽 아래에 작게 그린다.
// 주석의 한 줄 표기는 [KeyLegend.plainText]다.
//
// 실물 대조 (#169, Quick Start Guide 1쪽 제품 사진 `All_CASIO_QuickStartGuide_fx-991EX_fx-570EX_page-0001.jpg` —
// 원본 1275×1650을 원본 픽셀로 재고, 키캡 부분을 6배 확대해 봄. 각인 높이 약 13~17px라 칸 크기도 잴 수 있다):
// - **자리**(칸이 첨자·분수·근호·위아래 끝 중 어디에 있는지, 채운 칸·빈 칸)
//   - ∑◻◻◼(SHIFT): 끝 칸 두 개가 ∑ **바로 위·아래 가운데**에 쌓인다(오른쪽 첨자가 아니다) → [LegendLimits]로 고쳤다.
//     칸은 ∑에 맞춘 납작한 직사각형(사진 끝 칸 9×4px·본문 칸 8×4px, ∑ 7×7px)이라 [LegendBox]로 직접 그린다.
//   - log◼◻: 채운 밑 칸은 작은 정사각형으로 **아래끝이 기준선**(o의 아래끝 높이)이다. g의 내림 획까지 내려가지 않는다
//     → `subscriptOnBaseline`으로 고쳤다(#155는 g 아래끝에 맞췄다).
//   - ∫◻◻◼(메인): 끝 칸 두 개가 ∫ **오른쪽** 위·아래 → [LegendScript]의 위·아래첨자로 맞다.
//   - 나머지도 맞다: 대분수 `◼ ◻/◻`(채운 정수 칸이 분수 가운데 높이, 분수 두 칸은 빈 칸), `d/dx◼`, `a b/c⇔d/c`(작게
//     쌓은 분수 둘), `√◼`·`∛◼`(작은 3이 근호 왼쪽 위), `◼√◻`(채운 지수 칸이 근호 왼쪽 위), `x^◼`·`10^◼`·`e^◼`(채운 칸이
//     위첨자), 분수 키 `◼/◻`(분자 채움·분모 빈 칸).
// - **모양**(칸의 가로세로 비)은 ∑ 각인 말고는 아직 사진과 다르다 — 실물 칸은 자리마다 비가 다른 직사각형인데
//   (log 진수 칸 약 6×13px로 세로로 길고, ∫ 본문 칸 약 12×6px로 가로로 길며, ∫ 아래 끝 칸은 ∫ 기울기를 따라 위 끝
//   칸보다 약 4px 왼쪽) 앱은 글꼴의 정사각형 `◼`·`◻`를 쓴다. 칸 모양을 맞출지는 #186에서 정한다.

const _box = LegendText('◼');
const _emptyBox = LegendText('◻');

/// `∫◻◻◼` — ∫ 오른쪽 아래·위 끝 칸, 그다음 본문 칸
const _integral = LegendRow([
  LegendScript(LegendText('∫'), subscript: _emptyBox, superscript: _emptyBox),
  _box,
]);

/// `d/dx◼` — d 위·dx 아래로 쌓은 분수, 그다음 칸
const _derivative = LegendRow([
  LegendFraction(LegendText('d'), LegendText('dx')),
  _box,
]);

/// `∑◻◻◼` — ∑ 바로 아래·위에 쌓은 납작한 끝 칸, 그다음 ∑ 가운데 높이의 납작한 본문 칸 (#169 — 실물은 오른쪽 첨자가
/// 아니라 위아래에 쌓고, 칸은 글꼴 정사각형이 아니라 ∑ 크기에 맞춘 직사각형이다)
const _sumLimit = LegendBox(LegendBoxShape.sumLimit, filled: false);
const _sum = LegendRow([
  LegendLimits(LegendText('∑'), over: _sumLimit, under: _sumLimit),
  LegendBox(LegendBoxShape.sumOperand, filled: true),
]);

/// `◼/◻` — 위 ◼, 가로줄, 아래 ◻
const _fraction = LegendFraction(_box, _emptyBox);

/// `◼ ◻/◻` — 대분수: 왼쪽 ◼, 오른쪽에 쌓은 분수
const _mixedFraction = LegendRow([_box, LegendFraction(_emptyBox, _emptyBox)]);

/// `√◼` — 근호 가로줄이 칸 위를 덮는다
const _squareRoot = LegendRadical(_box);

/// `∛◼` — 근호 왼쪽 위에 작은 3
const _cubeRoot = LegendRadical(_box, index: LegendText('3'));

/// `x²`
const _square = LegendScript(LegendText('x'), superscript: LegendText('2'));

/// `x³`
const _cube = LegendScript(LegendText('x'), superscript: LegendText('3'));

/// `x^◼` — x 오른쪽 위에 작은 칸
const _power = LegendScript(LegendText('x'), superscript: _box);

/// `◼√◻` — 근호 왼쪽 위에 작은 지수 칸
const _nthRoot = LegendRadical(_emptyBox, index: _box);

/// `log◼◻` — log 오른쪽에 작은 밑 칸(아래끝이 기준선 — #169 사진 대조), 그다음 진수 칸
const _logBase = LegendRow([
  LegendScript(LegendText('log'), subscript: _box, subscriptOnBaseline: true),
  _emptyBox,
]);

/// `10^◼` — 10 오른쪽 위에 작은 칸
const _tenPower = LegendScript(LegendText('10'), superscript: _box);

/// `e^◼` — e 오른쪽 위에 작은 칸
const _ePower = LegendScript(LegendText('e'), superscript: _box);

/// 위첨자 −1 (역수·역삼각함수)
const _inverse = LegendText('−1');

/// `x⁻¹`
const _reciprocal = LegendScript(LegendText('x'), superscript: _inverse);

/// `sin⁻¹`
const _arcsin = LegendScript(LegendText('sin'), superscript: _inverse);

/// `cos⁻¹`
const _arccos = LegendScript(LegendText('cos'), superscript: _inverse);

/// `tan⁻¹`
const _arctan = LegendScript(LegendText('tan'), superscript: _inverse);

/// `a b/c⇔d/c` — 대분수 a b/c ⇔ 분수 d/c (쌓은 작은 분수)
const _fractionToggle = LegendRow([
  LegendText('a'),
  LegendFraction(LegendText('b'), LegendText('c')),
  LegendText('⇔'),
  LegendFraction(LegendText('d'), LegendText('c')),
]);

/// `×10ˣ` — ×10 다음 오른쪽 위에 작은 x
const _exp10 = LegendRow([
  LegendText('×'),
  LegendScript(LegendText('10'), superscript: LegendText('x')),
]);

// ═══════════════════════════════════════════════════════════════
// 상단 조작부 (커서 패드 좌우 2행 × 2열씩)
// ═══════════════════════════════════════════════════════════════

/// 커서 패드 왼쪽 2×2 키 (1행: SHIFT, ALPHA / 2행: OPTN, CALC)
const List<List<CalcKeyDef>> controlLeftRows = [
  [
    CalcKeyDef(
      id: CalcKeyId.shift,
      mainLegend: LegendText('SHIFT'),
      category: KeyCategory.shift,
    ),
    CalcKeyDef(
      id: CalcKeyId.alpha,
      mainLegend: LegendText('ALPHA'),
      category: KeyCategory.alpha,
    ),
  ],
  [
    CalcKeyDef(
      id: CalcKeyId.optn,
      mainLegend: LegendText('OPTN'),
      shiftLegend: LegendText('QR'),
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.calc,
      mainLegend: LegendText('CALC'),
      shiftLegend: LegendText('SOLVE'),
      alphaLegend: LegendText('='),
      category: KeyCategory.function,
    ),
  ],
];

/// 커서 패드 오른쪽 2×2 키 (1행: MENU, ON / 2행: ∫◻◻◼, x)
const List<List<CalcKeyDef>> controlRightRows = [
  [
    CalcKeyDef(
      id: CalcKeyId.menu,
      mainLegend: LegendText('MENU'),
      shiftLegend: LegendText('SETUP'),
      category: KeyCategory.menu,
    ),
    CalcKeyDef(
      id: CalcKeyId.on,
      mainLegend: LegendText('ON'),
      category: KeyCategory.on,
    ),
  ],
  [
    CalcKeyDef(
      id: CalcKeyId.integral,
      mainLegend: _integral,
      shiftLegend: _derivative,
      alphaLegend: LegendText(':'),
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.variableX,
      mainLegend: LegendText('x'),
      shiftLegend: _sum,
      category: KeyCategory.function,
    ),
  ],
];

/// 커서 패드 4방향 키 묶음. 인덱스 규약 대신 방향 이름으로 접근한다.
@immutable
class CursorPadKeys {
  final CalcKeyDef up;
  final CalcKeyDef down;
  final CalcKeyDef left;
  final CalcKeyDef right;

  const CursorPadKeys({
    required this.up,
    required this.down,
    required this.left,
    required this.right,
  });

  /// 상·하·좌·우 순 목록 ([CalcKeyId] 선언 순서와 동일)
  List<CalcKeyDef> get all => List.unmodifiable([up, down, left, right]);
}

/// 커서 패드 (상단 조작부 좌우 블록 사이, 2행에 걸쳐 배치)
const CursorPadKeys cursorPad = CursorPadKeys(
  up: CalcKeyDef(
    id: CalcKeyId.cursorUp,
    mainLegend: LegendText('▲'),
    category: KeyCategory.cursor,
  ),
  down: CalcKeyDef(
    id: CalcKeyId.cursorDown,
    mainLegend: LegendText('▼'),
    category: KeyCategory.cursor,
  ),
  left: CalcKeyDef(
    id: CalcKeyId.cursorLeft,
    mainLegend: LegendText('◄'),
    category: KeyCategory.cursor,
  ),
  right: CalcKeyDef(
    id: CalcKeyId.cursorRight,
    mainLegend: LegendText('►'),
    category: KeyCategory.cursor,
  ),
);

// ═══════════════════════════════════════════════════════════════
// 함수부 (3행 × 6열)
// ═══════════════════════════════════════════════════════════════

/// 함수부 열 수
const int functionColumns = 6;

/// 함수부 키 행 목록
const List<List<CalcKeyDef>> functionRows = [
  // ── 1행: 분수, 루트, 제곱, 거듭제곱, 밑 지정 로그, 자연로그 ──
  [
    CalcKeyDef(
      id: CalcKeyId.fraction,
      mainLegend: _fraction,
      shiftLegend: _mixedFraction,
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.sqrt,
      mainLegend: _squareRoot,
      shiftLegend: _cubeRoot,
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.square,
      mainLegend: _square,
      shiftLegend: _cube,
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.power,
      mainLegend: _power,
      shiftLegend: _nthRoot,
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.logBase,
      mainLegend: _logBase,
      shiftLegend: _tenPower,
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.ln,
      mainLegend: LegendText('ln'),
      shiftLegend: _ePower,
      category: KeyCategory.function,
    ),
  ],
  // ── 2행: 음수, 도분초, 역수, 삼각함수 (ALPHA: 변수 A~F) ──
  [
    CalcKeyDef(
      id: CalcKeyId.negative,
      mainLegend: LegendText('(−)'),
      shiftLegend: LegendText('log'), // log(a,b) 입력, 밑 a 생략 시 10 (가이드 "log" 예제)
      alphaLegend: LegendText('A'),
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.degMinSec,
      mainLegend: LegendText('°\'"'),
      shiftLegend: LegendText('FACT'),
      alphaLegend: LegendText('B'),
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.reciprocal,
      mainLegend: _reciprocal,
      shiftLegend: LegendText('x!'),
      alphaLegend: LegendText('C'),
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.sin,
      mainLegend: LegendText('sin'),
      shiftLegend: _arcsin,
      alphaLegend: LegendText('D'),
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.cos,
      mainLegend: LegendText('cos'),
      shiftLegend: _arccos,
      alphaLegend: LegendText('E'),
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.tan,
      mainLegend: LegendText('tan'),
      shiftLegend: _arctan,
      alphaLegend: LegendText('F'),
      category: KeyCategory.function,
    ),
  ],
  // ── 3행: 저장, 공학표기, 괄호, S⇔D, 메모리 (ALPHA: 변수 x, y, M) ──
  [
    CalcKeyDef(
      id: CalcKeyId.sto,
      mainLegend: LegendText('STO'),
      shiftLegend: LegendText('RECALL'),
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.eng,
      mainLegend: LegendText('ENG'),
      // ALPHA 기능은 없다. 키 위의 보라색 ∠·i는 Complex 모드 전용 각인이다 (#33).
      shiftLegend: LegendText('←'),
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.parenOpen,
      mainLegend: LegendText('('),
      shiftLegend: LegendText('Abs'),
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.parenClose,
      mainLegend: LegendText(')'),
      shiftLegend: LegendText(','),
      alphaLegend: LegendText('x'), // 변수 x (실물 각인은 빨간 이탤릭 소문자)
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.sdToggle,
      mainLegend: LegendText('S⇔D'),
      shiftLegend: _fractionToggle,
      alphaLegend: LegendText('y'), // 변수 y
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.mPlus,
      mainLegend: LegendText('M+'),
      shiftLegend: LegendText('M−'),
      alphaLegend: LegendText('M'),
      category: KeyCategory.function,
    ),
  ],
];

// ═══════════════════════════════════════════════════════════════
// 숫자부 (4행 × 5열)
// ═══════════════════════════════════════════════════════════════

/// 숫자부 열 수
const int numberColumns = 5;

/// 숫자부 키 행 목록
const List<List<CalcKeyDef>> numberRows = [
  [
    CalcKeyDef(
      id: CalcKeyId.num7,
      mainLegend: LegendText('7'),
      shiftLegend: LegendText('CONST'),
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.num8,
      mainLegend: LegendText('8'),
      shiftLegend: LegendText('CONV'),
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.num9,
      mainLegend: LegendText('9'),
      shiftLegend: LegendText('RESET'),
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.del,
      mainLegend: LegendText('DEL'),
      shiftLegend: LegendText('INS'),
      alphaLegend: LegendText('UNDO'),
      category: KeyCategory.del,
    ),
    CalcKeyDef(
      id: CalcKeyId.ac,
      mainLegend: LegendText('AC'),
      shiftLegend: LegendText('OFF'),
      category: KeyCategory.ac,
    ),
  ],
  [
    CalcKeyDef(
      id: CalcKeyId.num4,
      mainLegend: LegendText('4'),
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.num5,
      mainLegend: LegendText('5'),
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.num6,
      mainLegend: LegendText('6'),
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.multiply,
      mainLegend: LegendText('×'),
      shiftLegend: LegendText('nPr'),
      category: KeyCategory.operator,
    ),
    CalcKeyDef(
      id: CalcKeyId.divide,
      mainLegend: LegendText('÷'),
      shiftLegend: LegendText('nCr'),
      category: KeyCategory.operator,
    ),
  ],
  [
    CalcKeyDef(
      id: CalcKeyId.num1,
      mainLegend: LegendText('1'),
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.num2,
      mainLegend: LegendText('2'),
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.num3,
      mainLegend: LegendText('3'),
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.add,
      mainLegend: LegendText('+'),
      shiftLegend: LegendText('Pol'),
      category: KeyCategory.operator,
    ),
    CalcKeyDef(
      id: CalcKeyId.subtract,
      mainLegend: LegendText('−'),
      shiftLegend: LegendText('Rec'),
      category: KeyCategory.operator,
    ),
  ],
  [
    CalcKeyDef(
      id: CalcKeyId.num0,
      mainLegend: LegendText('0'),
      shiftLegend: LegendText('Rnd'),
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.dot,
      mainLegend: LegendText('.'),
      shiftLegend: LegendText('Ran#'),
      alphaLegend: LegendText('RanInt'),
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.exp10,
      mainLegend: _exp10,
      shiftLegend: LegendText('π'),
      alphaLegend: LegendText('e'),
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.ans,
      mainLegend: LegendText('Ans'),
      shiftLegend: LegendText('%'), // ALPHA 기능 없음
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.equals,
      mainLegend: LegendText('='),
      shiftLegend: LegendText('≈'),
      category: KeyCategory.equals,
    ),
  ],
];

// ═══════════════════════════════════════════════════════════════
// 조회용 컬렉션
// ═══════════════════════════════════════════════════════════════

/// 전체 키 수 (실물 fx-991EX 기준)
const int totalKeyCount = 50;

/// 전체 50키를 실물 배열 순서로 평탄화한 목록.
///
/// 상단 조작부는 행 단위로 왼쪽 2키 → 오른쪽 2키 순(SHIFT ALPHA MENU ON / OPTN CALC ∫◻◻◼ x),
/// 이어서 커서 패드 → 함수부 → 숫자부 순이다.
final List<CalcKeyDef> allKeys = _buildAllKeys();

List<CalcKeyDef> _buildAllKeys() {
  // 좌우 블록 행 수가 다르면 오른쪽 키가 누락된다 (allKeys.length == 50 테스트로도 검출).
  assert(controlLeftRows.length == controlRightRows.length);
  return List.unmodifiable([
    for (var i = 0; i < controlLeftRows.length; i++) ...[
      ...controlLeftRows[i],
      ...controlRightRows[i],
    ],
    ...cursorPad.all,
    for (final row in functionRows) ...row,
    for (final row in numberRows) ...row,
  ]);
}

/// 길게 누르면 반복 입력되는 키 (커서 패드 4방향, DEL).
const Set<CalcKeyId> autoRepeatKeys = {
  CalcKeyId.cursorUp,
  CalcKeyId.cursorDown,
  CalcKeyId.cursorLeft,
  CalcKeyId.cursorRight,
  CalcKeyId.del,
};

/// [CalcKeyId] → [CalcKeyDef] O(1) 조회 맵.
final Map<CalcKeyId, CalcKeyDef> keyById = Map.unmodifiable({
  for (final key in allKeys) key.id: key,
});

/// [id]에 해당하는 키 정의를 반환한다. 모든 [CalcKeyId]는 정의가 보장된다(테스트로 검증).
CalcKeyDef keyDefOf(CalcKeyId id) => keyById[id]!;
