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
/// 자릿수·Norm1/2를 담는 설정 모델은 M4 설정 팝업의 계산기 설정(#27)에서 따로 정의하고 이 값으로 매핑한다.
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
/// **설정**을 따른다. [none]은 설정 값이 아니라 "표시하지 않음"이다 — 설정 모델은 M4 설정 팝업(#27)에서
/// 따로 정의하고, 어느 모드에서 표시할지(예: Complex 모드 M7, 에픽 #239)와 함께 이 값으로 매핑한다.
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
///   - 재대조(#183): YouTube "Casio calculator fx-991EX hidden diagnostic test mode functions" 1:22 화면(진단 모드라
///     모든 세그먼트가 켜짐, 사용자가 준 캡처)에서 18개 세그먼트 가운데를 쟀다. 사진 x를 직선 하나로 도트에 맞추면
///     모두 1도트 안쪽으로 맞는다(슬롯이 없는 ⇩·◀·▶·☀ 포함, 표는 `test/unit/lcd_status_test.dart`).
///   - 실물 순서: S, A, M, →x, √▭✎, D, R, G, FIX, SCI, E, i, ∠, (⇩), (◀), ▼, ▲, (▶), ‖, (☀).
///     #44에서 받은 순서(√▭✎가 SCI 뒤)는 사진과 달라 사용자 확인을 받아 사진 기준으로 고쳤다(2026-11-26).
///   - 이 순서로 #44의 잠정 자리를 확정했다. E는 SCI 바로 뒤, i·∠는 E 바로 뒤의 서로 다른 두 자리다.
///   - ▼·▲는 한 자리에 위아래로 겹친 것이 아니라 나란한 두 자리다(▼ 왼쪽). 세그먼트도 따로 있다.
///   - 괄호 안 세그먼트는 넣지 않고 자리만 비워 둔다. ⇩·◀·▶는 가이드 표시기 표에 없고, ☀는 앱에 해당 상태가
///     없다(#44 결정). ◀·▶는 입력 줄 가로 넘침을 상태줄에서 알리는 표시일 가능성이 있다. 그렇다면 줄 안에 ◄/►를
///     그리는 지금 설계(`LcdLineOverflow`)와 다르다. 실물 계산기로 확인하지 못했으며, #36에서 함께 확인한다.
///   - 사용자 정보의 "Disp"와 "‖"는 가이드 표의 "‖ = 다중 문장 중간 결과" 하나로 보고 슬롯 하나([disp])로 둔다.
/// - 그리는 방식: 대부분은 글자로 그리고, 글꼴에 맞는 글자가 없는 슬롯은 **직접 그리는 아이콘**([icon])으로 그린다(#57).
///   - `→x`·`√▭✎`·`‖`는 글꼴 글자로는 기준선·크기가 맞지 않는다. `‖`는 기준선 아래로 내려가고, `√`의 윗선은
///     칸을 덮지 않는다.
///   - `▭`는 두 칸 폭이고, `✎`(U+270E)는 번들 글꼴에 없다(`assets/fonts/README.md`).
///   - [template]은 아이콘 슬롯에서도 표시 문자(식별자)로 쓰이고 화면에는 그려지지 않는다.
/// - 모양(#160): 위 User's Guide 4쪽 표시기 표의 아이콘을 기준으로 삼았다.
///   - S·A·D·R·G는 어두운 상자 안의 밝은 글자(반전 상자, [boxed])다. `‖`도 어두운 상자 안의 밝은 세로 두 획이다.
///   - `→x`: 굵은 화살표(몸통 + 삼각형 머리)가 왼쪽 변 가운데가 열린 상자로 들어가고, 상자 안에 x가 있다.
///     잉크 전체 폭은 S 상자와 비슷하다(스프라이트 8도트 대 7도트, #58 표). 앱은 x를 알아볼 수 있게 x 상자를 한 칸으로
///     두고 상자 밖 화살표를 줄여, 2칸 슬롯 가운데에 1.5칸으로 그린다(#183, `CalcTheme.lcdStatusStoreInkCells`).
///   - `√▭✎`: 근호 윗선 아래에 칸이 떨어져 매달린다. 칸은 오른쪽이 열린 "⊏"이고, 연필 촉이 그 열린 곳에 들어간다.
///     잉크 전체 폭은 대문자 높이의 2.0배다(스프라이트 14도트 대 7도트, #58 표). 앱은 3칸 슬롯 가운데에 2.4칸
///     (대문자 높이의 2.02배)으로 그린다(#217, `CalcTheme.lcdStatusMathInkCells`).
///   - 교차 확인: Commons 사진에서 켜진 D는 상자 안의 밝은 D이고, √▭✎는 "√E✎"처럼(윗선 + 칸의 위·아래 변) 보인다.
///     스프라이트(`interface.png` 같은 줄)도 다섯 글자와 `‖`가 상자다.
///   - 실물 대조(#183, 위 진단 화면 영상 — 흐려서 1도트 단위 모양은 보이지 않는다):
///     - S·A·D·R·G: 어두운 상자 안의 밝은 글자임을 확인했다. 상자 안 여백은 잴 수 없다(글자 크기 5/7은 가이드·
///       스프라이트 근거).
///     - `‖`: 어두운 상자 안의 밝은 세로 두 획이다. 획 위치는 상자 폭의 약 0.41·0.65로 재어 앱의 0.37·0.63
///       (7도트 상자에서 0부터 세어 2·4번째 — 1부터 세면 3·5번째 — 열 가운데 0.357·0.643에 가깝게 잡은 값)과
///       흐림 범위 안에서 맞는다.
///       상자 폭은 S와 흐림 범위(±1도트) 안에서 같다(영상 약 7.4도트 대 6.4도트, 스프라이트는 둘 다 7도트) — 가이드처럼
///       가로로 길다는 근거가 없어 한 칸 슬롯으로 둔다.
///     - `→x`: 왼쪽의 짧은 화살표와, 테두리 안이 밝고 가운데에 어두운 x가 있는 상자다. 잉크 폭(약 7.2도트)은 스프라이트
///       (8도트)와 흐림 범위 안에서 맞는다. 상자 왼쪽 변이 열렸는지, 화살표와 상자의 폭 나눔은 보이지 않아 가이드
///       아이콘을 따른다.
///     - 상자 위 끝은 베젤 그늘에 가려 높이·상자 안 여백·`‖` 획 길이·모서리 모양은 잴 수 없었다.
///   - 출처를 나눠 쓴 것:
///     - `√▭✎` 전체 폭은 스프라이트(14도트)에서, 그 안의 가로 비율(근호 : 틈 : 칸, 연필이 칸 너머로 뻗는 길이)은
///       사진에서 쟀다(#160 — 잉크 폭을 1로 보면 근호 0~0.28, 칸 0.37~0.63, 연필 위 끝 1). #217에서 전체 폭을 줄일 때
///       이 비율을 그대로 두었다. 가이드 아이콘(인쇄 4쪽, 쪽 이미지 `page-0005.jpg`)은 #217에서 다시 쟀다: 폭 39px ×
///       높이 23px(S 상자 21px의 1.86배)이고 근호 0~0.31, 칸 0.33~0.67 — 근호와 칸 사이 틈이 앱보다 좁고(0.03 대 0.08)
///       칸이 조금 넓다(칸 너머 연필은 0.31~0.33). 스프라이트는 8도트 높이 축소본이라 부분 폭을 가를 수 없고, 사진은 다시 받지 않았다(로컬 자료
///       원칙, #185) — 부분 비율의 새 근거는 없어 #160 값을 유지했다.
///     - 연필 굵기는 가이드(대문자 높이의 0.21)에 가까운 0.2로, 위 끝 높이는 가이드(대문자 윗선 아래 0.3)로 정했다.
///       #160은 굵기 0.22, 위 끝은 가이드와 사진(윗선 가까이)의 사이(0.2)였는데, #217에서 가로로 줄이며 연필이 가팔라져
///       작은 크기에서 칸과 이어 보여 가이드 쪽으로 옮겼다. 촉은 짧은 변 바로 아래(칸 바깥 오른쪽 끝에서 0.16칸)에 둔다.
///       칸의 짧은 변·아랫변과 떨어지는 것을 우선했다. 가이드의 촉·몸통 사이 흰 구분선은 작은 크기에서 뭉개지므로 넣지
///       않았다.
///     - 선 굵기는 옆 글자 획(대문자 높이의 0.14 — 실물 1도트/7도트와 같다)이라 가이드(약 0.1)보다 굵다.
///   - 한계:
///     - 실물 상자는 정사각형에 가깝고(7×7도트, 가이드의 `‖`는 가로가 더 길고 모서리가 둥글다), 앱은 슬롯 폭(한 칸
///       0.6em)을 지키느라 폭 0.6em × 대문자 높이 0.714em로, 모서리를 각지게 그린다(도트 LCD는 둥근 모서리가 없다).
///     - `→x` 잉크는 실물보다 넓다: 대문자 높이 대비 약 10%, 옆 반전 상자(S) 대비로는 1.5배 대 실물 1.14배(약 31%).
///       앱 S 상자가 실물보다 좁은 몫이 크다(`CalcTheme.lcdStatusStoreInkCells` 문서).
///     - `√▭✎` 잉크는 옆 반전 상자(S) 대비로는 2.4배 대 스프라이트 2.0배(약 20% 넓다)다 — `→x`와 같이 앱 S 상자가
///       실물보다 좁은 몫이다. 대문자 높이 대비로는 스프라이트와 1% 안이지만, 가이드 인쇄 아이콘(S 상자 대비 1.86배,
///       약 8% 좁다)과 #183 영상(약 12도트 ≈ 1.7배, 흐림 ±1~2도트)은 더 좁다. 스프라이트를 택한 이유는 `CalcTheme.lcdStatusMathInkCells` 문서에
///       있고, 선명한 실물 사진 대조(#216)에서 다시 확인한다.
///     - 작은 물리 크기: 상자 높이가 약 12물리 픽셀(대략 상태 글자 6dp·2x) 아래로 내려가면 상자 안 글자의 획이 1픽셀
///       안팎이라 글자를 알아보기 어렵다. 도트 격자에 맞추지(snap) 않으므로 상자 가장자리도 흐려진다.
///       `√▭✎`의 연필 촉은 뾰족해서, 6dp·2x에서는 끝 픽셀의 덮임이 옅어 촉이 열린 곳 바로 바깥에서 끝나 보일 수 있다
///       (#160 배치에서도 같았다). 칸·연필 사이 틈은 6dp·2x에서 1물리 픽셀 안팎(대문자 높이의 약 0.10)이지만, 픽셀 위상
///       64가지 모두에서 덮임 40% 이상인 회색 다리 없이 떨어졌다(#217). 테스트는 그중 4가지 위상을 본다
///       (`lcd_status_icon_test.dart`).
enum LcdIndicatorSlot {
  /// S — SHIFT 1회성 대기 (반전 상자 글자)
  shift('S', columns: 1, dotCenter: 3.5, boxed: true),

  /// A — ALPHA 1회성 대기 (반전 상자 글자)
  alpha('A', columns: 1, dotCenter: 11.5, boxed: true),

  /// M — 독립 메모리에 값이 있음
  memory('M', columns: 1, dotCenter: 20.5),

  /// →x — 변수 지정 대기 (STO 키를 누른 뒤). 아이콘으로 그린다.
  store('→x', columns: 2, dotCenter: 32, icon: LcdIndicatorIcon.storeArrow),

  /// √◻ — MathI 입출력. 실물 `√▭✎`(근호 + 칸 + 연필)를 아이콘으로 그린다(3칸 슬롯 가운데에 2.4칸).
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
  /// `→x` — 굵은 화살표가 왼쪽이 열린 상자로 들어가고 상자 안에 x (변수 지정 대기, 2칸 슬롯 가운데에 1.5칸, #160·#183)
  storeArrow,

  /// `√▭✎` — 근호 윗선 아래에 매달린 칸(⊏)과, 칸의 열린 오른쪽에 촉을 넣은 연필 (MathI 입출력, 3칸 슬롯 가운데에 2.4칸, #160·#217)
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
