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
//   모드 전용 각인도 이 명세에 담는다 (#266 — [CalcKeyDef.modeLegend]·[CalcKeyDef.modeShiftLegend]·
//   [CalcKeyDef.alphaBracketMode]). 그 모드에서의 키 **기능**은 #33과 각 모드 마일스톤(Complex M7·Base-N M14)이 다룬다.
//   숫자 1~6 키에는 각인이 없다.
//
// ※ 각인 표기 (#16에서 칸 규칙 확정, #155에서 2차원 모양으로 바꿈 — 실물 키캡 각인과 같은 규칙):
//   - 각인은 구조([KeyLegend], `key_legend.dart`)로 담는다. 글자만 있는 각인은 [LegendText]이고,
//     분수·위첨자·아래첨자·근호·위아래 끝(∑)이 있는 각인은 실물처럼 2차원으로 그린다(아래 "2차원 각인" 절).
//     입력 칸은 모두 글자 대신 자리별 비율로 직접 그리는 칸([LegendBox])으로 둔다(#169 ∑, #186 나머지 — 테스트로 검증).
//     키캡 각인 어디에도 한 줄 임시 표기(분수 `/`, 위첨자 `^`, 유니코드 위첨자 `²`·`⁻¹`·`ˣ`)를 쓰지 않는다
//     (테스트로 검증). 한 줄 표기는 [KeyLegend.plainText]로만 만든다(M1 LCD 임시 표시·로그용).
//   - 입력 칸은 **실물 각인에 그려진 칸 수**만큼 쓴다(템플릿의 실제 입력 칸 수와 다를 수 있다 —
//     예: `d/dx◼` 각인은 칸 1개지만 템플릿은 함수·x값 2칸). `◼` = 템플릿을 넣은 직후 커서가 들어가는 칸,
//     `◻` = 나머지 칸. 템플릿 각인에는 `◼`가 정확히 하나 있다(테스트로 검증).
//     예: `log◼◻`(밑 → 진수), `◼√◻`(지수 → 피개법수), `∫◻◻◼`(본문 → 아래·위 끝).
//     (예시는 [KeyLegend.plainText] 표기다. 칸의 채움 여부는 Quick Start Guide 1쪽 제품 사진을 따른다.
//     [LegendBox]의 채움 여부가 곧 `◼`·`◻`다.)
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

  /// ON 키 — 이 앱에서는 앱 설정 키다 ([settingsKey], #190)
  on,

  /// MENU(모드 선택) 키
  menu,
}

// ═══════════════════════════════════════════════════════════════
// 키 정의 모델
// ═══════════════════════════════════════════════════════════════

/// 키를 그리는 모양 (#190).
enum KeyFace {
  /// 둥근 사각형 키캡 — 메인 각인은 키캡 면에, SHIFT·ALPHA 각인은 키캡 위 본체에 있다.
  keycap,

  /// 실물 SHIFT·ALPHA·MENU·ON처럼 작은 원형 은색 버튼 — 버튼 면에는 글자가 없고, 메인 각인은 버튼 위 본체에
  /// 인쇄돼 있다(Quick Start Guide 1쪽 제품 사진). #190에서 ON 키를, #156에서 SHIFT·ALPHA·MENU를 이 모양으로 바꿨다.
  /// 원형 버튼에는 SHIFT·ALPHA 각인이 없다 — 실물 MENU의 SHIFT 각인 `SETUP`은 앱에서 뺐다(#253, `CalcKeyDef` 생성자 assert).
  roundButton,
}

/// 각인을 보일지 정하는 배포 단위 (#267) — 그 기능이 배포돼야([releasedKeyFeatures]) 그 기능의 각인을 인쇄한다.
///
/// 기능이 없는 각인은 눌러도 아무 일이 없어 사용자를 헷갈리게 하므로, 기능이 들어가는 버전까지 숨긴다. 키 명세
/// ([CalcKeyDef])는 실물 인쇄 그대로 두고, 여기서 정한 단위로 보이는 것만 가른다.
enum KeyFeature {
  /// Complex 모드 (v1.0) — ENG 키의 보라 `i`·보라 괄호 `∠`
  complex,

  /// Base-N 모드 (v1.3, 에픽 #244) — 파랑 `DEC`·`HEX`·`BIN`·`OCT`, `A`~`F`를 둘러싼 파란 괄호
  baseN,

  /// QR 코드 표시 (SHIFT+OPTN) — 앱에 넣지 않는 기능이다(제조사 서버 연동). 배포 계획이 없다.
  qrCode,
}

/// 배포되는 기능 — **각인 표시를 정하는 한 곳** (#267).
///
/// 지금 값은 v1.0(Calculate·Complex·Equation/Func·Table)이다. 숨는 각인은 OPTN 키의 `QR`과 Base-N의 파랑 각인이다
/// (테스트 `key_definitions_test.dart` "배포 기능에 따른 각인 (#267)"이 목록을 고정한다). 버전을 올릴 때 그 버전의 기능을
/// 여기에 더하면 각인·입력 해석·스크린리더 문구가 함께 되살아난다 — v1.3에서 [KeyFeature.baseN]을 더한다.
/// 여기에 없는 기능의 각인도 명세에는 남아 있다([CalcKeyDef.printedShiftLegend]·[CalcKeyDef.printedBandLegends]).
const Set<KeyFeature> releasedKeyFeatures = {KeyFeature.complex};

/// 모든 기능 — 실물 인쇄 전체를 볼 때 쓴다([CalcKeyDef.printedBandLegends], 테스트·미리보기)
const Set<KeyFeature> allKeyFeatures = {
  KeyFeature.complex,
  KeyFeature.baseN,
  KeyFeature.qrCode,
};

/// 모드 전용 각인이 가리키는 계산 모드 (#266, User's Guide 3쪽 "Key Markings").
///
/// 실물은 SHIFT(노랑)·ALPHA(빨강) 말고 두 색을 더 쓴다 — 그 모드에 들어가야 쓸 수 있는 기능이다.
enum KeyLegendMode {
  /// Complex 모드 — 보라색 각인(ENG 키의 `i`) 또는 보라 괄호로 둘러싼 각인(ENG 키의 `∠`)
  complex(KeyFeature.complex),

  /// Base-N 모드 — 파란색 각인(`DEC`·`HEX`·`BIN`·`OCT`) 또는 파란 괄호로 둘러싼 각인(`A`~`F`)
  baseN(KeyFeature.baseN);

  const KeyLegendMode(this.feature);

  /// 이 모드의 각인이 보이려면 배포돼 있어야 하는 기능 (#267)
  final KeyFeature feature;
}

/// 모드 전용 각인 하나 — 각인과 그 모드 (#266)
@immutable
class ModeLegend {
  /// 각인
  final KeyLegend legend;

  /// 이 각인의 기능을 쓸 수 있는 모드
  final KeyLegendMode mode;

  const ModeLegend(this.legend, this.mode);

  @override
  bool operator ==(Object other) =>
      other is ModeLegend && other.legend == legend && other.mode == mode;

  @override
  int get hashCode => Object.hash(legend, mode);

  @override
  String toString() => 'ModeLegend("${legend.plainText}", ${mode.name})';
}

/// 키캡 위 각인 띠에 인쇄하는 각인의 역할 (#266) — 글자 색을 정한다
enum BandLegendRole {
  /// SHIFT를 누른 뒤의 기능 (노랑)
  shift,

  /// ALPHA를 누른 뒤의 기능 (빨강)
  alpha,

  /// 그 모드에서 키를 그냥 누를 때의 기능 (모드 색 — Complex 보라·Base-N 파랑)
  mode,
}

/// 키캡 위 각인 띠에 인쇄하는 각인 하나 (#266) — [CalcKeyDef.bandLegends]가 왼쪽부터 순서대로 돌려준다.
///
/// 각인 띠를 그리는 쪽(`CalcKeyButton`)과 글자 크기를 재는 쪽(`KeypadMetrics`)이 같은 목록을 쓴다 — 한쪽만 아는 각인이
/// 생기면 그 키만 글자가 줄거나 기준선이 갈린다(#264 R1).
@immutable
class BandLegend {
  /// 각인
  final KeyLegend legend;

  /// 역할 — 글자 색을 정한다
  final BandLegendRole role;

  /// 모드 전용 각인이면 그 모드. [role]이 [BandLegendRole.mode]이면 글자를 이 모드 색으로 인쇄하고, [bracketed]이면 괄호를
  /// 이 모드 색으로 그린다. 둘 다 아니면 `null`이다.
  final KeyLegendMode? mode;

  /// 모드 색 ┌ ┐ 괄호로 둘러싸는지 — 글자 색은 [role] 색 그대로다(실물 ENG 키의 노랑 `∠`, 빨강 `A`~`F`)
  final bool bracketed;

  const BandLegend(this.legend, this.role, {this.mode, this.bracketed = false})
    : assert(
        (mode != null) == (role == BandLegendRole.mode || bracketed),
        '모드는 모드 색 각인이거나 괄호가 있을 때만 준다',
      );

  @override
  bool operator ==(Object other) =>
      other is BandLegend &&
      other.legend == legend &&
      other.role == role &&
      other.mode == mode &&
      other.bracketed == bracketed;

  @override
  int get hashCode => Object.hash(legend, role, mode, bracketed);

  @override
  String toString() =>
      'BandLegend("${legend.plainText}", ${role.name}'
      '${mode == null ? '' : ', ${mode!.name}'}${bracketed ? ', 괄호' : ''})';
}

/// 단일 키의 3단 각인(메인·SHIFT·ALPHA)과 모드 전용 각인, 카테고리를 정의하는 불변 모델.
///
/// 명세는 실물 인쇄 그대로다. 그 가운데 아직 배포되지 않은 기능의 각인은 숨긴다(#267, [releasedKeyFeatures]):
/// - 앱이 쓰는 값: [shiftLegend]·[shiftLabel]·[hasShift]·[bandLegends] — 배포된 기능의 각인만이다.
/// - 실물 인쇄 그대로: [printedShiftLegend]·[printedBandLegends]와 모드 전용 각인 필드([modeShiftLegend]·[modeLegend]·
///   [alphaBracketMode]).
/// - 배포 목록을 바꿔 볼 때: [shiftLegendIn]·[bandLegendsIn].
@immutable
class CalcKeyDef {
  /// 키 고유 식별자
  final CalcKeyId id;

  /// 키캡 중앙에 표시되는 메인 각인
  final KeyLegend mainLegend;

  /// SHIFT 후 입력되는 기능의 금색 각인 — 실물 인쇄 그대로. 없으면 `null`.
  /// 앱은 배포된 기능의 각인만 돌려주는 [shiftLegend]를 쓴다.
  final KeyLegend? printedShiftLegend;

  /// [printedShiftLegend]의 기능이 속한 배포 단위 (#267). 그 기능이 배포되지 않았으면 SHIFT 각인을 숨기고 SHIFT 기능이
  /// 없는 키로 다룬다. `null`이면 늘 있는 기능이다(대부분의 키).
  final KeyFeature? shiftFeature;

  /// ALPHA 후 입력되는 기능의 빨간색 각인. 없으면 `null`.
  final KeyLegend? alphaLegend;

  /// 그 모드에서 SHIFT 후 입력되는 기능의 각인 (#266) — SHIFT 색 글자를 모드 색 괄호가 둘러싼다. 실물 ENG 키의 `∠`
  /// (Complex 모드의 SHIFT+ENG)뿐이다. [shiftLegend] 왼쪽에 인쇄한다. 없으면 `null`.
  /// 이 필드와 [modeLegend]·[alphaBracketMode]는 실물 인쇄 그대로다 — 그 모드가 배포돼야 [bandLegends]에 들어간다(#267).
  final ModeLegend? modeShiftLegend;

  /// 그 모드에서 키를 그냥 누르면 입력되는 기능의 각인 (#266) — 모드 색으로 인쇄한다. 실물 ENG 키의 보라 `i`(Complex)와
  /// x²·x^◼·log◼◻·ln 키의 파랑 `DEC`·`HEX`·`BIN`·`OCT`(Base-N)다. 각인 띠의 오른쪽 끝에 인쇄한다. 없으면 `null`.
  final ModeLegend? modeLegend;

  /// [alphaLegend]를 둘러싸는 괄호의 모드 (#266) — 그 모드에서는 키를 그냥 눌러 ALPHA 각인의 글자를 입력한다. 실물 (−)·
  /// °'"·x⁻¹·sin·cos·tan 키의 빨강 `A`~`F`를 둘러싼 파란 괄호(Base-N의 16진 숫자)다. 없으면 `null`.
  final KeyLegendMode? alphaBracketMode;

  /// 키 시각적 카테고리 (색상 테마 결정)
  final KeyCategory category;

  /// 키 모양 — [KeyFace.roundButton]이면 메인 각인을 버튼 면이 아니라 버튼 위 본체(각인 띠)에 인쇄한다.
  final KeyFace face;

  const CalcKeyDef({
    required this.id,
    required this.mainLegend,
    KeyLegend? shiftLegend,
    this.shiftFeature,
    this.alphaLegend,
    this.modeShiftLegend,
    this.modeLegend,
    this.alphaBracketMode,
    required this.category,
    this.face = KeyFace.keycap,
  }) : printedShiftLegend = shiftLegend,
       assert(
         shiftFeature == null || shiftLegend != null,
         '배포 단위는 SHIFT 각인이 있을 때만 준다',
       ),
       assert(
         face != KeyFace.roundButton ||
             (shiftLegend == null &&
                 alphaLegend == null &&
                 modeShiftLegend == null &&
                 modeLegend == null),
         '원형 버튼 위 각인 띠에는 메인 각인만 인쇄한다 (#253)',
       ),
       assert(
         alphaBracketMode == null || alphaLegend != null,
         '괄호로 둘러쌀 ALPHA 각인이 있어야 한다',
       ),
       assert(
         alphaLegend == null || modeLegend == null,
         'ALPHA 각인과 모드 색 각인은 같은 자리(오른쪽)라 함께 두지 않는다',
       );

  /// 메인 각인의 한 줄 표기 ([KeyLegend.plainText] — 화면 각인에는 쓰지 않는다)
  String get mainLabel => mainLegend.plainText;

  /// SHIFT 후 입력되는 기능의 금색 각인 — 배포된 기능만이다(#267, [releasedKeyFeatures]). 없으면 `null`.
  KeyLegend? get shiftLegend => shiftLegendIn(releasedKeyFeatures);

  /// 기능 [released]가 배포됐을 때의 SHIFT 각인 (#267). 그 각인의 기능([shiftFeature])이 [released]에 없으면 `null`.
  KeyLegend? shiftLegendIn(Set<KeyFeature> released) =>
      shiftFeature == null || released.contains(shiftFeature)
      ? printedShiftLegend
      : null;

  /// SHIFT 각인의 한 줄 표기. 없으면 `null`.
  String? get shiftLabel => shiftLegend?.plainText;

  /// ALPHA 각인의 한 줄 표기. 없으면 `null`.
  String? get alphaLabel => alphaLegend?.plainText;

  /// 키캡 위 각인 띠에 인쇄하는 각인 — 왼쪽부터 (#266). 원형 버튼(메인 각인을 띠에 인쇄한다)은 빈 목록이다.
  ///
  /// 순서는 실물 인쇄 순서다: 괄호로 둘러싼 모드 전용 SHIFT 각인([modeShiftLegend]) → SHIFT 각인 → ALPHA 각인(괄호는
  /// [alphaBracketMode]) → 모드 색 각인([modeLegend]). 실물 ENG 키는 `┌∠┐ ← i`, x² 키는 `x³ DEC`, (−) 키는 `log ┌A┐`다.
  ///
  /// 배포된 기능의 각인만이다(#267, [releasedKeyFeatures]) — v1.0에서는 x² 키가 `x³` 하나, (−) 키가 괄호 없는 `log A`다.
  List<BandLegend> get bandLegends => bandLegendsIn(releasedKeyFeatures);

  /// 실물 인쇄 그대로의 각인 띠 — 모든 기능이 배포됐을 때의 [bandLegends] (#267)
  List<BandLegend> get printedBandLegends => bandLegendsIn(allKeyFeatures);

  /// 기능 [released]가 배포됐을 때 각인 띠에 인쇄하는 각인 — 왼쪽부터 (#267).
  ///
  /// 배포되지 않은 기능의 각인은 뺀다: SHIFT 각인([shiftFeature]), 모드 전용 각인([KeyLegendMode.feature]). 괄호의 모드가
  /// 배포되지 않았으면 괄호만 빼고 ALPHA 각인은 남긴다(빨강 `A`~`F`는 변수다). 남은 각인은 그 수대로 다시 놓인다 —
  /// 하나면 키캡 가운데다(`CalcKeyButton`의 각인 줄, #265).
  List<BandLegend> bandLegendsIn(Set<KeyFeature> released) {
    bool shown(KeyLegendMode mode) => released.contains(mode.feature);
    final bracket = switch (alphaBracketMode) {
      final mode? when shown(mode) => mode,
      _ => null,
    };
    return [
      if (modeShiftLegend case final m? when shown(m.mode))
        BandLegend(
          m.legend,
          BandLegendRole.shift,
          mode: m.mode,
          bracketed: true,
        ),
      if (shiftLegendIn(released) case final l?)
        BandLegend(l, BandLegendRole.shift),
      if (alphaLegend case final l?)
        BandLegend(
          l,
          BandLegendRole.alpha,
          mode: bracket,
          bracketed: bracket != null,
        ),
      if (modeLegend case final m? when shown(m.mode))
        BandLegend(m.legend, BandLegendRole.mode, mode: m.mode),
    ];
  }

  /// SHIFT 기능 보유 여부 — 배포된 기능만 센다(#267)
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
// - **모양**(칸의 가로세로 비, #186): 실물 칸은 자리마다 비가 다른 직사각형이라, 모든 칸을 글꼴의 정사각형
//   `◼`·`◻` 대신 자리별 [LegendBox]로 그린다(사용자 결정 "모든 칸 사진 비율로"). 비는 실물 키패드 근접 사진
//   (가로 2048px — 메인 각인 글자 크기 약 33px, SHIFT 각인 약 22px라 Quick Start Guide 사진보다 약 2배 크다)에서
//   원본 픽셀로 쟀다(밝기 중간값 경계, 번짐 ±1px). 이 사진은 EN판과 각인 몇 개가 다르지만 칸 모양은 같고,
//   Quick Start Guide 사진에서 #169가 잰 값(log 진수 칸 6×13px, ∫ 본문 칸 12×6px)과 비가 맞는다.
//   - 세로로 긴 칸: log 진수 13×26px(1:2) — 아래끝이 기준선, 위끝이 `l` 윗끝이다.
//   - 가로로 긴 칸: ∫ 본문 25×12px, 분수 키 분자·분모 25×14px, 대분수 분자·분모 18×11px, d/dx 칸 14×10px.
//   - 정사각형에 가까운 칸: ∫ 끝 칸 14×13·13×13px, √ 16×15px, ∛ 12×11px, `◼√◻` 지수 12×10px·피개법수 14×11px,
//     x^ 14×14px, 10^ 11×10px, e^ 10×9px, 대분수 정수 칸 14×11px, log 밑 칸 11×13px.
//   - ∫ 아래 끝 칸은 ∫ 아래쪽 끝을 따라 위 끝 칸보다 9px 왼쪽이다(`subscriptFollowsSlant`).
//   크기 규칙은 `KeyLegendView`·`CalcTheme` "2차원 각인 배치" 절에 있다 — 칸 높이는 지금까지의 글꼴 칸 높이를 지키고
//   (그래서 각인 높이 예산이 그대로다) 폭만 사진 비율로 바꾼다. 예외는 ∑ 칸(∑ 기준, #169), log 진수 칸(`l` 높이),
//   ∫ 본문 칸(사진 높이 약 0.36em)이다. 앞 칸과 맞닿는 자리(log 진수 칸, ∫ 본문 칸)는 왼쪽 여백이 없다.
//   비는 맞추지만 사진과 다르게 남는 점(첨자·작은 분수 속 칸의 크기)과 빈 칸 테두리·가로줄·근호 두께(#206)는 `CalcTheme`
//   같은 절에 적었다.

/// `∫◻◻◼` — ∫ 오른쪽 아래·위 끝 칸(아래 칸은 ∫ 기울기를 따라 왼쪽으로 당긴다), 그다음 가로로 긴 본문 칸
const _integralLimit = LegendBox(LegendBoxShape.integralLimit, filled: false);
const _integral = LegendRow([
  LegendScript(
    LegendText('∫'),
    subscript: _integralLimit,
    superscript: _integralLimit,
    subscriptFollowsSlant: true,
  ),
  LegendBox(LegendBoxShape.integralOperand, filled: true),
]);

/// `d/dx◼` — d 위·dx 아래로 쌓은 분수, 그다음 칸
const _derivative = LegendRow([
  LegendFraction(LegendText('d'), LegendText('dx')),
  LegendBox(LegendBoxShape.derivativeOperand, filled: true),
]);

/// `∑◻◻◼` — ∑ 바로 아래·위에 쌓은 납작한 끝 칸, 그다음 ∑ 가운데 높이의 납작한 본문 칸 (#169 — 실물은 오른쪽 첨자가
/// 아니라 위아래에 쌓고, 칸은 글꼴 정사각형이 아니라 ∑ 크기에 맞춘 직사각형이다)
const _sumLimit = LegendBox(LegendBoxShape.sumLimit, filled: false);
const _sum = LegendRow([
  LegendLimits(LegendText('∑'), over: _sumLimit, under: _sumLimit),
  LegendBox(LegendBoxShape.sumOperand, filled: true),
]);

/// `◼/◻` — 위 ◼, 가로줄, 아래 ◻ (둘 다 가로로 긴 칸)
const _fraction = LegendFraction(
  LegendBox(LegendBoxShape.fractionPart, filled: true),
  LegendBox(LegendBoxShape.fractionPart, filled: false),
);

/// `◼ ◻/◻` — 대분수: 왼쪽 ◼, 오른쪽에 쌓은 분수(가로로 긴 빈 칸 둘)
const _mixedFractionPart = LegendBox(
  LegendBoxShape.mixedFractionPart,
  filled: false,
);
const _mixedFraction = LegendRow([
  LegendBox(LegendBoxShape.mixedWhole, filled: true),
  LegendFraction(_mixedFractionPart, _mixedFractionPart),
]);

/// `√◼` — 근호 가로줄이 칸 위를 덮는다
const _squareRoot = LegendRadical(
  LegendBox(LegendBoxShape.squareRootRadicand, filled: true),
);

/// `∛◼` — 근호 왼쪽 위에 작은 3
const _cubeRoot = LegendRadical(
  LegendBox(LegendBoxShape.cubeRootRadicand, filled: true),
  index: LegendText('3'),
);

/// `x²`
const _square = LegendScript(LegendText('x'), superscript: LegendText('2'));

/// `x³`
const _cube = LegendScript(LegendText('x'), superscript: LegendText('3'));

/// `x^◼` — x 오른쪽 위에 작은 칸
const _power = LegendScript(
  LegendText('x'),
  superscript: LegendBox(LegendBoxShape.powerExponent, filled: true),
);

/// `◼√◻` — 근호 왼쪽 위에 작은 지수 칸
const _nthRoot = LegendRadical(
  LegendBox(LegendBoxShape.rootRadicand, filled: false),
  index: LegendBox(LegendBoxShape.rootIndex, filled: true),
);

/// `log◼◻` — log 오른쪽에 작은 밑 칸(아래끝이 기준선 — #169 사진 대조), 그다음 세로로 긴 진수 칸(`l` 높이 — #186)
const _logBase = LegendRow([
  LegendScript(
    LegendText('log'),
    subscript: LegendBox(LegendBoxShape.logBase, filled: true),
    subscriptOnBaseline: true,
  ),
  LegendBox(LegendBoxShape.logArgument, filled: false),
]);

/// `10^◼` — 10 오른쪽 위에 작은 칸
const _tenPower = LegendScript(
  LegendText('10'),
  superscript: LegendBox(LegendBoxShape.tenPowerExponent, filled: true),
);

/// `e^◼` — e 오른쪽 위에 작은 칸
const _ePower = LegendScript(
  LegendText('e'),
  superscript: LegendBox(LegendBoxShape.ePowerExponent, filled: true),
);

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
      face: KeyFace.roundButton,
    ),
    CalcKeyDef(
      id: CalcKeyId.alpha,
      mainLegend: LegendText('ALPHA'),
      category: KeyCategory.alpha,
      face: KeyFace.roundButton,
    ),
  ],
  [
    CalcKeyDef(
      id: CalcKeyId.optn,
      mainLegend: LegendText('OPTN'),
      // QR 코드 표시는 앱에 넣지 않는 기능이라 각인을 숨긴다 (#267 — 명세에는 실물 인쇄대로 남긴다)
      shiftLegend: LegendText('QR'),
      shiftFeature: KeyFeature.qrCode,
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
    // 실물 MENU 버튼 위에는 `MENU`(흰색)와 SHIFT 각인 `SETUP`(금색)이 나란히 인쇄돼 있다. 앱은 설정(SETUP)을 설정 키
    // ([settingsKey]) 하나로만 열므로 `SETUP`을 인쇄하지 않고, SHIFT + MENU는 SHIFT 각인 없는 키처럼 기능이 없다
    // (앱 고유, #253 사용자 결정).
    CalcKeyDef(
      id: CalcKeyId.menu,
      mainLegend: LegendText('MENU'),
      category: KeyCategory.menu,
      face: KeyFace.roundButton,
    ),
    // 실물은 버튼 위 본체에 흰 `ON`이 인쇄된 작은 원형 은색 버튼이다. 이 앱에는 전원이 없어 ON을 설정 키로 쓰고
    // (#190, 사용자 결정), 같은 자리에 `SETUP`을 인쇄한다(#253 — #190의 `SETTING`에서 바꿨다) — [settingsKey].
    CalcKeyDef(
      id: CalcKeyId.on,
      mainLegend: LegendText('SETUP'),
      category: KeyCategory.on,
      face: KeyFace.roundButton,
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
      modeLegend: ModeLegend(LegendText('DEC'), KeyLegendMode.baseN),
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.power,
      mainLegend: _power,
      shiftLegend: _nthRoot,
      modeLegend: ModeLegend(LegendText('HEX'), KeyLegendMode.baseN),
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.logBase,
      mainLegend: _logBase,
      shiftLegend: _tenPower,
      modeLegend: ModeLegend(LegendText('BIN'), KeyLegendMode.baseN),
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.ln,
      mainLegend: LegendText('ln'),
      shiftLegend: _ePower,
      modeLegend: ModeLegend(LegendText('OCT'), KeyLegendMode.baseN),
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
      alphaBracketMode: KeyLegendMode.baseN, // Base-N의 16진 숫자
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.degMinSec,
      mainLegend: LegendText('°\'"'),
      shiftLegend: LegendText('FACT'),
      alphaLegend: LegendText('B'),
      alphaBracketMode: KeyLegendMode.baseN, // Base-N의 16진 숫자
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.reciprocal,
      mainLegend: _reciprocal,
      shiftLegend: LegendText('x!'),
      alphaLegend: LegendText('C'),
      alphaBracketMode: KeyLegendMode.baseN, // Base-N의 16진 숫자
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.sin,
      mainLegend: LegendText('sin'),
      shiftLegend: _arcsin,
      alphaLegend: LegendText('D'),
      alphaBracketMode: KeyLegendMode.baseN, // Base-N의 16진 숫자
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.cos,
      mainLegend: LegendText('cos'),
      shiftLegend: _arccos,
      alphaLegend: LegendText('E'),
      alphaBracketMode: KeyLegendMode.baseN, // Base-N의 16진 숫자
      category: KeyCategory.function,
    ),
    CalcKeyDef(
      id: CalcKeyId.tan,
      mainLegend: LegendText('tan'),
      shiftLegend: _arctan,
      alphaLegend: LegendText('F'),
      alphaBracketMode: KeyLegendMode.baseN, // Base-N의 16진 숫자
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
      // ALPHA 기능은 없다. 키 위의 보라 괄호 ∠(Complex 모드의 SHIFT+ENG)와 보라 i(Complex 모드의 ENG)는 Complex 모드 전용
      // 각인이다 (#266 — 실물은 왼쪽부터 ┌∠┐ ← i).
      modeShiftLegend: ModeLegend(LegendText('∠'), KeyLegendMode.complex),
      shiftLegend: LegendText('←'),
      modeLegend: ModeLegend(LegendText('i'), KeyLegendMode.complex),
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
    // 실물 AC 위의 SHIFT 각인 `OFF`(전원 끄기)는 인쇄하지 않는다 — 이 앱에는 전원이 없다. SHIFT + AC는 SHIFT 각인
    // 없는 키처럼 기능이 없다(AC가 실행되지 않고 SHIFT 대기만 풀린다, 앱 고유, #253 사용자 결정).
    CalcKeyDef(
      id: CalcKeyId.ac,
      mainLegend: LegendText('AC'),
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

/// 앱 설정을 여는 키 (#190, 사용자 결정) — 실물 ON 키 자리다. 이 앱에는 전원이 없으므로 ON 키를 누르면
/// 계산기 입력 대신 설정이 열린다(`CalculatorScreen`). 계산기 상태 머신은 이 키를 입력으로 받지 않는다
/// (`CalcState.pressKey` — 모디파이어 대기만 푼다).
const CalcKeyId settingsKey = CalcKeyId.on;

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
