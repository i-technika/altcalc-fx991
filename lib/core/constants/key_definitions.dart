import 'package:meta/meta.dart';

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
// ※ 라벨 표기 (#16에서 확정, 실물 키캡 각인과 같은 규칙):
//   - 입력 칸은 **실물 각인에 그려진 칸 수**만큼 쓴다(템플릿의 실제 입력 칸 수와 다를 수 있다 —
//     예: `d/dx◼` 각인은 칸 1개지만 템플릿은 함수·x값 2칸). `◼` = 템플릿을 넣은 직후 커서가 들어가는 칸,
//     `◻` = 나머지 칸. 템플릿 라벨에는 `◼`가 정확히 하나 있다(테스트로 검증).
//     예: `log◼◻`(밑 → 진수), `◼√◻`(지수 → 피개법수), `∫◻◻◼`(본문 → 아래·위 끝).
//   - 칸의 위치(위첨자·아래첨자·분수)는 한 줄 텍스트로 나타낼 수 없어 읽는 순서로 늘어놓는다.
//     위첨자는 `^`로 표시한다(`x^◼`, `10^◼`). 2차원 모양은 LCD 수식 렌더링(M2)에서 그린다.
//   - `▭`(U+25AD)는 쓰지 않는다. 번들 글꼴 Noto Sans Mono에서 두 칸 폭이라 라벨 폭 측정을 왜곡한다.
//     같은 이유로 커서 패드 좌우는 `◀`·`▶` 대신 한 칸 폭인 `◄`·`►`를 쓴다 (`▲`·`▼`와 같은 디자인).
//     두 칸 폭 글자는 실물 각인에 꼭 필요한 `⇔`(S⇔D)만 허용한다(테스트로 검증).

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

  /// 키캡 중앙에 표시되는 메인 라벨
  final String mainLabel;

  /// SHIFT 후 입력되는 기능의 금색 각인. 없으면 `null`.
  final String? shiftLabel;

  /// ALPHA 후 입력되는 기능의 빨간색 각인. 없으면 `null`.
  final String? alphaLabel;

  /// 키 시각적 카테고리 (색상 테마 결정)
  final KeyCategory category;

  const CalcKeyDef({
    required this.id,
    required this.mainLabel,
    this.shiftLabel,
    this.alphaLabel,
    required this.category,
  });

  /// SHIFT 기능 보유 여부
  bool get hasShift => shiftLabel != null;

  /// ALPHA 기능 보유 여부
  bool get hasAlpha => alphaLabel != null;

  @override
  String toString() => 'CalcKeyDef(${id.name}, "$mainLabel")';
}

// ═══════════════════════════════════════════════════════════════
// 상단 조작부 (커서 패드 좌우 2행 × 2열씩)
// ═══════════════════════════════════════════════════════════════

/// 커서 패드 왼쪽 2×2 키 (1행: SHIFT, ALPHA / 2행: OPTN, CALC)
const List<List<CalcKeyDef>> controlLeftRows = [
  [
    CalcKeyDef(
      id: CalcKeyId.shift,
      mainLabel: 'SHIFT',
      category: KeyCategory.shift,
    ),
    CalcKeyDef(
      id: CalcKeyId.alpha,
      mainLabel: 'ALPHA',
      category: KeyCategory.alpha,
    ),
  ],
  [
    CalcKeyDef(
      id: CalcKeyId.optn,
      mainLabel: 'OPTN',
      shiftLabel: 'QR',
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.calc,
      mainLabel: 'CALC',
      shiftLabel: 'SOLVE',
      alphaLabel: '=',
      category: KeyCategory.function,
    ),
  ],
];

/// 커서 패드 오른쪽 2×2 키 (1행: MENU, ON / 2행: ∫◻◻◼, x)
const List<List<CalcKeyDef>> controlRightRows = [
  [
    CalcKeyDef(
      id: CalcKeyId.menu,
      mainLabel: 'MENU',
      shiftLabel: 'SETUP',
      category: KeyCategory.menu,
    ),
    CalcKeyDef(id: CalcKeyId.on, mainLabel: 'ON', category: KeyCategory.on),
  ],
  [
    CalcKeyDef(
      id: CalcKeyId.integral,
      mainLabel: '∫◻◻◼',
      shiftLabel: 'd/dx◼',
      alphaLabel: ':',
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.variableX,
      mainLabel: 'x',
      shiftLabel: '∑◻◻◼',
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
    mainLabel: '▲',
    category: KeyCategory.cursor,
  ),
  down: CalcKeyDef(
    id: CalcKeyId.cursorDown,
    mainLabel: '▼',
    category: KeyCategory.cursor,
  ),
  left: CalcKeyDef(
    id: CalcKeyId.cursorLeft,
    mainLabel: '◄',
    category: KeyCategory.cursor,
  ),
  right: CalcKeyDef(
    id: CalcKeyId.cursorRight,
    mainLabel: '►',
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
      mainLabel: '◼/◻',
      shiftLabel: '◼◻/◻',
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.sqrt,
      mainLabel: '√◼',
      shiftLabel: '∛◼',
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.square,
      mainLabel: 'x²',
      shiftLabel: 'x³',
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.power,
      mainLabel: 'x^◼',
      shiftLabel: '◼√◻',
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.logBase,
      mainLabel: 'log◼◻',
      shiftLabel: '10^◼',
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.ln,
      mainLabel: 'ln',
      shiftLabel: 'e^◼',
      category: KeyCategory.function,
    ),
  ],
  // ── 2행: 음수, 도분초, 역수, 삼각함수 (ALPHA: 변수 A~F) ──
  [
    CalcKeyDef(
      id: CalcKeyId.negative,
      mainLabel: '(−)',
      shiftLabel: 'log', // log(a,b) 입력, 밑 a 생략 시 10 (가이드 "log" 예제)
      alphaLabel: 'A',
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.degMinSec,
      mainLabel: '°\'"',
      shiftLabel: 'FACT',
      alphaLabel: 'B',
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.reciprocal,
      mainLabel: 'x⁻¹',
      shiftLabel: 'x!',
      alphaLabel: 'C',
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.sin,
      mainLabel: 'sin',
      shiftLabel: 'sin⁻¹',
      alphaLabel: 'D',
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.cos,
      mainLabel: 'cos',
      shiftLabel: 'cos⁻¹',
      alphaLabel: 'E',
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.tan,
      mainLabel: 'tan',
      shiftLabel: 'tan⁻¹',
      alphaLabel: 'F',
      category: KeyCategory.function,
    ),
  ],
  // ── 3행: 저장, 공학표기, 괄호, S⇔D, 메모리 (ALPHA: 변수 x, y, M) ──
  [
    CalcKeyDef(
      id: CalcKeyId.sto,
      mainLabel: 'STO',
      shiftLabel: 'RECALL',
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.eng,
      mainLabel: 'ENG',
      // ALPHA 기능은 없다. 키 위의 보라색 ∠·i는 Complex 모드 전용 각인이다 (#33).
      shiftLabel: '←',
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.parenOpen,
      mainLabel: '(',
      shiftLabel: 'Abs',
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.parenClose,
      mainLabel: ')',
      shiftLabel: ',',
      alphaLabel: 'x', // 변수 x (실물 각인은 빨간 이탤릭 소문자)
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.sdToggle,
      mainLabel: 'S⇔D',
      shiftLabel: 'a b/c⇔d/c',
      alphaLabel: 'y', // 변수 y
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.mPlus,
      mainLabel: 'M+',
      shiftLabel: 'M−',
      alphaLabel: 'M',
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
      mainLabel: '7',
      shiftLabel: 'CONST',
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.num8,
      mainLabel: '8',
      shiftLabel: 'CONV',
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.num9,
      mainLabel: '9',
      shiftLabel: 'RESET',
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.del,
      mainLabel: 'DEL',
      shiftLabel: 'INS',
      alphaLabel: 'UNDO',
      category: KeyCategory.del,
    ),
    CalcKeyDef(
      id: CalcKeyId.ac,
      mainLabel: 'AC',
      shiftLabel: 'OFF',
      category: KeyCategory.ac,
    ),
  ],
  [
    CalcKeyDef(
      id: CalcKeyId.num4,
      mainLabel: '4',
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.num5,
      mainLabel: '5',
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.num6,
      mainLabel: '6',
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.multiply,
      mainLabel: '×',
      shiftLabel: 'nPr',
      category: KeyCategory.operator,
    ),
    CalcKeyDef(
      id: CalcKeyId.divide,
      mainLabel: '÷',
      shiftLabel: 'nCr',
      category: KeyCategory.operator,
    ),
  ],
  [
    CalcKeyDef(
      id: CalcKeyId.num1,
      mainLabel: '1',
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.num2,
      mainLabel: '2',
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.num3,
      mainLabel: '3',
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.add,
      mainLabel: '+',
      shiftLabel: 'Pol',
      category: KeyCategory.operator,
    ),
    CalcKeyDef(
      id: CalcKeyId.subtract,
      mainLabel: '−',
      shiftLabel: 'Rec',
      category: KeyCategory.operator,
    ),
  ],
  [
    CalcKeyDef(
      id: CalcKeyId.num0,
      mainLabel: '0',
      shiftLabel: 'Rnd',
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.dot,
      mainLabel: '.',
      shiftLabel: 'Ran#',
      alphaLabel: 'RanInt',
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.exp10,
      mainLabel: '×10ˣ',
      shiftLabel: 'π',
      alphaLabel: 'e',
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.ans,
      mainLabel: 'Ans',
      shiftLabel: '%', // ALPHA 기능 없음
      category: KeyCategory.number,
    ),
    CalcKeyDef(
      id: CalcKeyId.equals,
      mainLabel: '=',
      shiftLabel: '≈',
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
