import 'package:material_ui/material_ui.dart';

import '../constants/key_definitions.dart';

/// 카시오 fx-991EX ClassWiz 계산기의 테마 정의.
///
/// 본체, LCD, 키캡, 상태 표시줄, SHIFT/ALPHA 각인에 사용되는
/// 모든 색상 팔레트와 텍스트 스타일을 중앙에서 관리한다.
///
/// ## 각인 배치 규약
/// 실물과 같이 SHIFT(금색)/ALPHA(빨간색) 각인은 키캡 **안쪽이 아니라 키캡 위쪽 본체 영역**
/// ([bodyBackground] 위)에 그린다. 따라서 [shiftLabel]/[alphaLabel]은 본체 배경 대비
/// 4.5:1 이상을 유지해야 한다. 각인이 놓일 수 있는 본체 색([bodyBackground], [bodyFrame],
/// [bodyBottomGradient]) 모두에 대해 `test/unit/calc_theme_test.dart`에서 검증한다.
///
/// 어두운 키캡(함수·커서·DEL)은 본체와 명도가 비슷하므로, 키 경계는 [keyBorder]로
/// 테두리를 그려 본체 대비 3:1(WCAG 1.4.11 비텍스트 대비) 이상을 확보한다.
abstract final class CalcTheme {
  // ───────────────────────────────────────────
  // 본체 색상 (Body Colors)
  // ───────────────────────────────────────────

  /// 계산기 본체 배경 (진한 차콜 그레이)
  static const Color bodyBackground = Color(0xFF2D2D2D);

  /// 본체 상단 프레임 (약간 밝은 차콜)
  static const Color bodyFrame = Color(0xFF3A3A3A);

  /// 본체 하단 그라디언트 끝 색상
  static const Color bodyBottomGradient = Color(0xFF1A1A1A);

  // ───────────────────────────────────────────
  // LCD 화면 색상 (LCD Display Colors)
  // ───────────────────────────────────────────

  /// LCD 배경 (연한 연두색 → 실제 fx-991EX 도트 매트릭스 배경)
  static const Color lcdBackground = Color(0xFFD5E8D0);

  /// LCD 텍스트 (짙은 흑색)
  static const Color lcdText = Color(0xFF1A1A1A);

  /// LCD 커서 블록 (깜빡이는 커서)
  static const Color lcdCursor = Color(0xFF333333);

  /// LCD 프레임 테두리 (은색 베젤)
  static const Color lcdFrame = Color(0xFF8A8A8A);

  /// LCD 상태 표시줄 활성 텍스트 (S, A, DEG 등이 켜졌을 때)
  static const Color lcdStatusActive = Color(0xFF2A2A2A);

  /// LCD 상태 표시줄 비활성 텍스트 — [lcdStatusActive]를 약 4% 불투명도로 (#44, 사용자 결정).
  /// 실물의 꺼진 표시기는 정면에서 거의 보이지 않고 비스듬히 볼 때만 희미하게 비친다(사용자 실물 확인).
  /// 픽셀 색은 도트 격자선([lcdDotGrid])보다 옅다 — 다만 글자는 면이라 밝은 화면에서는 희미하게 보일 수 있다.
  /// 고대비 모드에서 올리는 것은 #54에서 다룬다.
  static const Color lcdStatusInactive = Color(0x0A2A2A2A);

  /// LCD 도트 매트릭스 격자선 (픽셀 사이 틈을 표현하는 아주 옅은 선)
  static const Color lcdDotGrid = Color(0x0F000000);

  // ───────────────────────────────────────────
  // 키캡 카테고리 색상 (Keycap Category Colors)
  // ───────────────────────────────────────────

  /// 밝은 키캡 그룹 (0~9, 소수점, ×10ˣ, Ans) — 밝은 회색
  static const Color keyNumber = Color(0xFFE8E8E8);

  /// 밝은 키캡 그룹 텍스트
  static const Color keyNumberText = Color(0xFF1A1A1A);

  /// 연산자 키 (+, −, ×, ÷) — 짙은 회색
  static const Color keyOperator = Color(0xFF6B6B6B);

  /// 연산자 키 텍스트
  static const Color keyOperatorText = Color(0xFFFFFFFF);

  /// 함수 키 (sin, cos, log◼◻ 등) — 중간 회색
  static const Color keyFunction = Color(0xFF4A4A4A);

  /// 함수 키 텍스트
  static const Color keyFunctionText = Color(0xFFFFFFFF);

  /// 등호(=) 키 — 진한 파란색 (ClassWiz 계열)
  static const Color keyEquals = Color(0xFF1565C0);

  /// 등호 키 텍스트
  static const Color keyEqualsText = Color(0xFFFFFFFF);

  /// AC(All Clear) 키 — 진한 주황 계열
  static const Color keyAC = Color(0xFFBF360C);

  /// AC 키 텍스트
  static const Color keyACText = Color(0xFFFFFFFF);

  /// DEL(Delete) 키 — 진한 갈색
  static const Color keyDEL = Color(0xFF5D4037);

  /// DEL 키 텍스트
  static const Color keyDELText = Color(0xFFFFFFFF);

  /// 커서 패드 — 원형 4방향 패드 배경
  static const Color keyCursor = Color(0xFF3E3E3E);

  /// 방향키 텍스트/아이콘
  static const Color keyCursorText = Color(0xFFFFFFFF);

  /// ON 키 — 작은 사각형
  static const Color keyON = Color(0xFF4A4A4A);

  /// ON 키 텍스트
  static const Color keyONText = Color(0xFFFFFFFF);

  // ───────────────────────────────────────────
  // SHIFT / ALPHA 모디파이어 색상
  // ───────────────────────────────────────────

  /// SHIFT 키 본체 — 황금색
  static const Color keyShift = Color(0xFFE5A823);

  /// SHIFT 키 텍스트 (금색 위 흰 글자는 대비가 낮아 흑색 사용)
  static const Color keyShiftText = Color(0xFF1A1A1A);

  /// SHIFT 각인 텍스트 (키 위 본체에 인쇄되는 금색 라벨)
  static const Color shiftLabel = Color(0xFFE5A823);

  /// ALPHA 키 본체 — 진한 빨간색
  static const Color keyAlpha = Color(0xFFC62828);

  /// ALPHA 키 텍스트
  static const Color keyAlphaText = Color(0xFFFFFFFF);

  /// ALPHA 각인 텍스트 (키 위 본체에 인쇄되는 빨간색 라벨, 어두운 배경용으로 밝게)
  static const Color alphaLabel = Color(0xFFFF8080);

  // ───────────────────────────────────────────
  // 키 눌림 상태 (Pressed State)
  // ───────────────────────────────────────────

  /// 키캡 테두리 — 어두운 키캡과 본체의 경계 표시용 (본체 대비 3:1 이상)
  static const Color keyBorder = Color(0xFF808080);

  // 눌림 표시 (#22) — 두 단서를 함께 쓴다.
  // 1) 배경 명도 변화: 카테고리별로 평소 색에 흰색 또는 검정을 덧씌운다([KeyCategoryColors.pressedOverlay]).
  //    눌림 전후 명도 차(CIELAB L*)가 [keyPressedMinLightnessDelta] 이상, 눌린 상태의 메인 라벨이 4.5:1 이상,
  //    눌린 키가 본체와 [keyPressedMinBodyLightnessDelta] 이상 떨어지도록 방향·세기를 정했다(테스트로 검증).
  //    - 가장 어두운 키(함수·MENU·ON·DEL·커서, L* 26~32, 흰 라벨): 흰색 20%로 **밝게**. 어둡게 해서 명도 차 12를
  //      얻으려면 검정 36~42%가 필요한데, 그러면 L* 14~19가 되어 본체(L* 18.5)에 묻힌다.
  //    - 중간 밝기 흰 라벨 키(연산자·=·AC·ALPHA, L* 43~45): 검정 30%로 **어둡게**. 밝히면 라벨 4.5:1을 지키는
  //      한도(흰색 약 8~15%)에서 명도 차가 4~7에 그친다.
  //    - 밝은 키(숫자·SHIFT, 어두운 라벨): 검정 20%로 **어둡게**.
  //    (L* 약 38~41의 흰 라벨 회색 키는 어느 방향으로도 세 조건을 함께 만족하지 못한다 — 이 구간의 키 색은 피한다.)
  // 2) 테두리: 눌리면 카테고리와 무관하게 [keyBorder] → [keyPressedBorder]로 바뀐다. 회색 카테고리(L* 26·32·45)가
  //    좁게 몰려 있어 눌린 색이 다른 카테고리의 평소 색과 겹칠 수 있으므로(눌린 연산자 ≈ 평소 함수 키,
  //    눌린 함수 키 ≈ 평소 연산자), "종류가 바뀐 것"이 아니라 "눌린 것"으로 읽히게 하는 공통 단서다.
  //    보이는 단서는 키캡 **바깥쪽** 경계(본체와 맞닿는 쪽)다 — 본체 대비가 평소 3.5:1 → 눌림 12:1로 커진다.
  //    안쪽(키캡 배경 쪽) 대비는 밝은 키에서 오히려 낮아지지만(숫자 키 3.2 → 1.7:1), 그 키들은 배경 자체가
  //    크게 어두워져 1)로 충분하다.
  //    예외: 커서 패드는 방향 구역 모양으로 잘리고 그 위에 회색 경계선을 덧그려 눌림 테두리가 거의 보이지 않는다 —
  //    커서 키는 1)(ΔL* 약 17)에만 의존한다.

  /// 눌림 전후 키캡 배경의 최소 명도 차 (CIELAB L*, 0~100).
  /// 옛 표현(검정 20% 일괄)에서 "거의 안 보인다"고 보고된 키는 5.4~6.6, 보고되지 않은 키는 8.5 이상이었다.
  /// 12는 그 경계에 여유를 둔 설계값이다(측정된 지각 임계값이 아니다).
  static const double keyPressedMinLightnessDelta = 12.0;

  /// 눌린 키캡과 본체 배경([bodyBackground])의 최소 명도 차 (CIELAB L*) — 눌린 키가 본체에 묻히지 않게 한다.
  static const double keyPressedMinBodyLightnessDelta = 10.0;

  /// 어두운 키 눌림: 흰색 20%를 덧씌워 밝게
  static const Color keyPressedLightenOverlay = Color(0x33FFFFFF);

  /// 밝은 키 눌림: 검정 20%를 덧씌워 어둡게
  static const Color keyPressedDarkenOverlay = Color(0x33000000);

  /// 중간 밝기 흰 라벨 키 눌림: 검정 30%를 덧씌워 어둡게
  static const Color keyPressedDeepDarkenOverlay = Color(0x4D000000);

  /// 눌린 키캡 테두리 — 카테고리와 무관한 눌림 단서. 평소 [keyBorder]보다 L* 30 이상 밝고, 본체와 3:1 이상
  static const Color keyPressedBorder = Color(0xFFF0F0F0);

  // ───────────────────────────────────────────
  // 광고 슬롯 (Banner Ad Slot)
  // ───────────────────────────────────────────

  /// 광고 슬롯 배경 (본체와 조화)
  static const Color adSlotBackground = Color(0xFF222222);

  // ───────────────────────────────────────────
  // 폰트 (Fonts)
  // ───────────────────────────────────────────

  /// LCD·키캡 고정폭 폰트 패밀리 이름 (번들 글꼴 Noto Sans Mono, `assets/fonts/`).
  ///
  /// 모든 글자 폭이 0.6em인 고정폭 글꼴이라 LCD 칸 수([lcdLineCharWidthRatio])와 키 라벨 폭 측정이
  /// 플랫폼과 무관하게 같다. LCD와 키캡은 같은 패밀리를 쓴다 — 키캡도 고정폭이어야 라벨 폭이 글자 수에
  /// 비례해 각인 배분 규칙(`_LegendRow`)과 폭 측정(`KeypadMetrics`)이 단순해지기 때문이다.
  /// 실물 LCD의 도트 매트릭스 글꼴을 따로 쓸지는 LCD 렌더링(M2)에서 정한다.
  static const String monoFontFamily = 'NotoSansMono';

  /// 수학 기호 대체 폰트 패밀리 이름 (번들 글꼴 Noto Sans Math).
  /// [monoFontFamily]에 없는 `∑`·`∛`·`∫`를 채운다. 고정폭이 아니므로 LCD 줄 글자에는 쓰지 않는다.
  static const String mathFontFamily = 'NotoSansMath';

  /// [monoFontFamily]에 없는 글자를 찾을 대체 폰트 (모두 번들 글꼴이다).
  /// 라벨·LCD 템플릿의 모든 글자가 여기까지 안에서 찾아지는지 테스트로 검증한다
  /// (`test/unit/font_glyph_coverage_test.dart`).
  static const List<String> monoFontFallback = [mathFontFamily];

  // ───────────────────────────────────────────
  // LCD 텍스트 스타일 (LCD Text Styles)
  // ───────────────────────────────────────────

  /// LCD 수식 입력줄 기본 텍스트 스타일.
  /// 실제 계산기의 도트 매트릭스 느낌을 위해 고정폭 폰트 사용.
  static const TextStyle lcdInputStyle = TextStyle(
    fontFamily: monoFontFamily,
    fontFamilyFallback: monoFontFallback,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    color: lcdText,
    letterSpacing: 1.2,
    height: 1.3,
  );

  /// LCD 결과줄 텍스트 스타일 (실물 Natural 표시처럼 입력줄과 같은 크기, 굵게).
  static const TextStyle lcdResultStyle = TextStyle(
    fontFamily: monoFontFamily,
    fontFamilyFallback: monoFontFallback,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: lcdText,
    letterSpacing: 1.0,
    height: 1.3,
  );

  /// LCD 상태 표시줄 텍스트 스타일 (S, A, D/R/G, √◻ 등 — 슬롯은 `LcdIndicatorSlot`).
  static const TextStyle lcdStatusStyle = TextStyle(
    fontFamily: monoFontFamily,
    fontFamilyFallback: monoFontFallback,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: lcdStatusActive,
    letterSpacing: 0.5,
  );

  /// 키캡 메인 라벨 텍스트 스타일 (기준 크기). `CalcKeyButton`은 [keyMainLabelFontRatio]로
  /// 키캡 높이에 맞춰 `fontSize`를 덮어쓴다.
  /// 색은 카테고리마다 다르므로 [KeyCategoryColors.foreground]로 지정한다.
  ///
  /// 키 라벨 스타일은 `letterSpacing`을 명시한다. 생략하면 테마의 [DefaultTextStyle] 자간을
  /// 물려받아, 키패드가 측정한 라벨 폭(`KeypadMetrics`)과 실제 렌더링 폭이 어긋난다.
  static const TextStyle keyMainLabelStyle = TextStyle(
    fontFamily: monoFontFamily,
    fontFamilyFallback: monoFontFallback,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.0,
  );

  /// SHIFT 각인 (키캡 위 본체 영역 좌측, 금색) 텍스트 스타일.
  static const TextStyle keyShiftLabelStyle = TextStyle(
    fontFamily: monoFontFamily,
    fontFamilyFallback: monoFontFallback,
    fontSize: 9,
    fontWeight: FontWeight.w500,
    color: shiftLabel,
    letterSpacing: 0,
    height: 1.0,
  );

  /// ALPHA 각인 (키캡 위 본체 영역 우측, 빨간색) 텍스트 스타일.
  static const TextStyle keyAlphaLabelStyle = TextStyle(
    fontFamily: monoFontFamily,
    fontFamilyFallback: monoFontFallback,
    fontSize: 9,
    fontWeight: FontWeight.w500,
    color: alphaLabel,
    letterSpacing: 0,
    height: 1.0,
  );

  // ───────────────────────────────────────────
  // 키 치수 비율 (Key Dimension Ratios)
  // ───────────────────────────────────────────
  // 반응형 레이아웃을 위해 비율 기반으로 정의.
  // 실제 dp 값은 CalculatorScreen에서 화면 크기에 따라 계산.

  /// 키 사이 수평 간격 비율 (키패드 너비 대비)
  static const double keyHorizontalGapRatio = 0.012;

  /// 키 사이 수직 간격 비율 (키패드 높이 대비)
  static const double keyVerticalGapRatio = 0.015;

  /// 키 모서리 둥글기 (dp)
  static const double keyBorderRadius = 6.0;

  /// 키 그림자 높이 (dp)
  static const double keyElevation = 2.0;

  /// 키캡 테두리 두께 (dp)
  static const double keyBorderWidth = 1.0;

  /// 키 눌림 시 키캡이 아래로 이동하는 거리 (dp)
  static const double keyPressedOffset = 1.0;

  /// 키 버튼 전체 높이 중 상단 각인 띠가 차지하는 비율 (나머지는 키캡)
  static const double keyLegendHeightRatio = 0.28;

  /// 각인 띠 높이 대비 각인 글자 크기 비율
  static const double keyLegendFontRatio = 0.8;

  /// 키캡 높이 대비 메인 라벨 글자 크기 비율
  static const double keyMainLabelFontRatio = 0.42;

  /// 키캡 안쪽 좌우 여백 비율 (키캡 너비 대비)
  static const double keyCapHorizontalPaddingRatio = 0.08;

  /// SHIFT·ALPHA 각인 사이 간격 (각인 글자 크기 대비)
  static const double keyLegendGapRatio = 0.3;

  /// 자연 폭 우선 배분을 받는 짧은 각인의 최대 글자 수 (변수 이름 `A`~`F`, `x`, `y`, `M` 등).
  /// 이보다 긴 각인 쌍은 글자 수 비례로 폭을 나눈다.
  static const int keyLegendPriorityMaxRunes = 2;

  /// SHIFT·ALPHA 각인 사이 간격 상한 (키 너비 대비) — 좁고 긴 셀에서 넘침 방지
  static const double keyLegendGapMaxWidthRatio = 0.05;

  /// 키 라벨에 반영하는 시스템 글자 크기 배율 상한 (넘침은 FittedBox가 추가로 막는다)
  static const double keyMaxTextScaleFactor = 1.3;

  /// 키캡 그림자 색
  static const Color keyShadow = Color(0x66000000);

  /// 비활성 키 메인 라벨 불투명도
  static const double keyDisabledLabelOpacity = 0.5;

  /// 키를 뗄 때 눌림 색·테두리·그림자가 돌아오는 시간 (누를 때는 즉시 바뀐다 — #22)
  static const Duration keyPressAnimationDuration = Duration(milliseconds: 60);

  // ───────────────────────────────────────────
  // LCD 치수 (LCD Dimensions)
  // ───────────────────────────────────────────
  // LCD 전체 크기와 화면 비율은 아래 "화면 배치"에서 정의한다.

  /// LCD 은색 베젤 두께 (dp)
  static const double lcdFrameWidth = 3.0;

  /// LCD 모서리 둥글기 (dp)
  static const double lcdBorderRadius = 6.0;

  /// LCD 베젤 안쪽 여백 (dp)
  static const double lcdInnerPadding = 6.0;

  /// 도트 매트릭스 격자 간격 (dp)
  static const double lcdDotPitch = 3.0;

  /// 도트 매트릭스 격자선 두께 (dp)
  static const double lcdDotGridStrokeWidth = 0.5;

  /// 상태 표시줄 높이 (상태 표시 글자 크기 대비)
  static const double lcdStatusBarHeightRatio = 1.4;

  /// 상태 표시 슬롯 사이 간격 (상태 표시 글자 크기 대비)
  static const double lcdStatusSlotGapRatio = 0.5;

  /// 상태 표시 슬롯 너비 산정용 글자당 글리프 폭 (글자 크기 대비, 고정폭 폰트 0.6em).
  /// 자간([lcdStatusStyle]의 `letterSpacing`, 글자 배율과 무관한 dp)은 글자마다 따로 더한다 —
  /// 비율에 섞어 두면 특정 글자 크기에서만 맞고 작은 LCD에서 슬롯이 축소된다(#44 리뷰 R1).
  static const double lcdStatusCharWidthRatio = 0.6;

  /// 스크롤 표시(◄/►) 글자 크기 (해당 줄 글자 크기 대비)
  static const double lcdScrollArrowFontRatio = 0.6;

  /// 스크롤 표시(◄/►) 자리 너비 (스크롤 표시 글자 크기 대비)
  ///
  /// 화살표는 `◄`(U+25C4)·`►`(U+25BA)를 쓴다. 번들 글꼴 Noto Sans Mono에서 한 칸(0.6em) 폭이라
  /// 이 자리에 줄지 않고 들어간다. `◀`·`▶`(U+25C0·U+25B6)는 모양은 같지만 글자 폭이 두 칸(1.2em)이라
  /// `FittedBox`가 75%로 줄여 버린다(#16 실측).
  static const double lcdScrollArrowWidthRatio = 0.9;

  /// LCD 안의 모든 글자에 반영하는 시스템 글자 크기 배율 상한.
  /// 계산기 화면(LCD 크기로 글자 산출)에서는 줄 글자가 LCD를 채우므로 상태 표시에만 효과가 있다.
  static const double lcdMaxTextScaleFactor = 1.3;

  // ── LCD 내부 구성 (#23) ──
  // 위 → 아래: 상태 표시줄 + 입력 줄(행 [lcdInputLineFlex]개) + 결과 줄(행 [lcdResultLineFlex]개).
  // 한 "행"은 줄 글자 하나의 줄 높이(글자 크기 × 스타일 height)다. 2행 줄에는 분수 막대·여백
  // ([lcdFractionBarRatio])을 더한다. 줄 글자 크기는 LCD 크기에서 `LcdFontSizes.forSize`가
  // 높이 기준과 폭 기준([lcdLineColumns])을 모두 만족하는 가장 큰 값으로 산출한다.

  /// 입력 줄 높이 (행 수) — 자연 표기(Natural Textbook Display) 분수 1단(분자·분모)을 담는 2행.
  /// 정적분·시그마처럼 더 높은 템플릿의 처리는 #36(M2)에서 정한다.
  /// [lcdResultLineFlex]와 같아야 한다(줄마다 분수 막대 몫을 같게 받는다).
  static const int lcdInputLineFlex = 2;

  /// 결과 줄 높이 (행 수) — MathO 결과도 자연 표기(⅓, √2/2 같은 분수 결과)이므로 2행.
  static const int lcdResultLineFlex = 2;

  /// 2행 줄의 분수 막대 두께 + 막대 위아래 여백 (줄 글자 크기 대비)
  static const double lcdFractionBarRatio = 0.25;

  /// 상태 표시 글자 크기 (줄 글자 크기 대비)
  static const double lcdStatusFontRatio = 0.42;

  /// 결과 줄이 스크롤 없이 담아야 하는 글자 칸 수 (폭 기준 글자 크기 산출용).
  /// 가장 긴 결과 `−1.234567891×10⁻⁹⁹` = 부호 1 + 가수 11 + `×10` 3 + 위첨자 지수 약 2칸.
  static const int lcdLineColumns = 17;

  /// 줄 글자 한 칸 폭 (글자 크기 대비). 번들 글꼴 Noto Sans Mono의 글자 폭(600/1000)과 같다.
  /// 자간([lcdInputStyle]·[lcdResultStyle]의 `letterSpacing`)은 따로 더한다.
  ///
  /// 실측(#16, `test/widget/bundled_font_test.dart`): 숫자·`.`·`−`·`×`·`E`·유니코드 위첨자가 모두 한 칸이다.
  /// 그래서 [lcdLineColumns]의 17칸은 **지수를 [lcdExponentMaxScale] 이하 크기로 그린다**는 전제가 필요하다.
  /// `×10⁻⁹⁹`를 유니코드 위첨자 글자로 그리면 지수 3글자가 3칸을 차지해 18칸이 되어 넘친다.
  /// LCD 줄에는 두 칸 폭 글자(`▶`·`℃`·`⇔` 등)를 쓰지 않는다 — `assets/fonts/README.md` "글리프 선택 규칙".
  static const double lcdLineCharWidthRatio = 0.6;

  /// [lcdLineColumns]가 전제하는 결과 줄 지수(위첨자) 글자 크기 상한 (줄 글자 크기 대비).
  ///
  /// 지수 3글자(`−99`)가 2칸(= 3 × 2/3)에 들어가야 17칸이 성립한다. 2/3 그대로면 여유가 0이라
  /// 위첨자 올림 오프셋·픽셀 맞춤 하나에도 넘치므로, 0.6(지수 1.8칸, 여유 0.2칸)을 상한으로 둔다.
  /// 지수의 자간도 같은 비율로 줄여야 한다 — 자간은 글자 크기와 무관한 dp 값이라 그대로 두면
  /// 지수 3글자가 자간 3개를 온전히 더해 넘친다(실측 #16).
  /// 실제 위첨자 비율은 자연 표기 렌더링(M2)에서 정하되 이 값을 넘지 않는다.
  static const double lcdExponentMaxScale = 0.6;

  // ───────────────────────────────────────────
  // 광고 슬롯 치수 (Banner Ad Slot Dimensions)
  // ───────────────────────────────────────────

  /// 하단 배너 광고 슬롯 기본(최소) 높이 (dp)
  static const double adSlotHeight = 50.0;

  /// 광고 슬롯 최대 높이 (dp) — 대형 화면용
  static const double adSlotMaxHeight = 60.0;

  /// 광고 슬롯 상단 안전 여백 — 오터치 방지 (dp)
  static const double adSlotSafetyMargin = 10.0;

  /// 광고 슬롯 상단 안전 여백 하한 (dp) — 이보다 좁히면 키패드 오터치로 광고가 눌릴 수 있다
  static const double adSlotMinSafetyMargin = 8.0;

  /// 광고 슬롯 상단 안전 여백 상한 (dp) — CLAUDE.md 규칙(8~12dp)
  static const double adSlotMaxSafetyMargin = 12.0;

  /// [adSlotMaxHeight]를 기본값으로 쓰는 대형 화면 기준 (화면 짧은 변, dp)
  static const double adSlotLargeScreenShortestSide = 600.0;

  // ───────────────────────────────────────────
  // 키패드 배치 (Keypad Layout)
  // ───────────────────────────────────────────

  /// 숫자부 행 높이 (함수부·상단 조작부 행 높이 대비) — 실물처럼 숫자 키가 더 크다.
  static const double keypadNumberRowHeightRatio = 1.2;

  /// 함수부와 숫자부 사이 간격 (키패드 높이 대비)
  static const double keypadSectionGapRatio = 0.02;

  /// 키패드 최소 가로/세로 비 — 세로로 긴 화면에서 키가 과도하게 길어지지 않게 높이를 제한한다.
  static const double keypadMinAspectRatio = 0.75;

  /// 키패드 최대 가로/세로 비 — 가로로 넓은 화면에서 키가 과도하게 넓어지지 않게 폭을 제한한다.
  static const double keypadMaxAspectRatio = 1.25;

  /// 키패드 최대 폭 (dp) — 태블릿처럼 큰 화면에서 키가 과도하게 커지지 않게 한다 (#24).
  /// 1dp는 약 1/160인치라 480dp ≈ 76mm로, 실물 fx-991EX 본체 폭(약 77mm)과 비슷하다.
  /// 키패드 최대 높이는 이 값 / [keypadMinAspectRatio] (640dp). 폰 폭(430dp 이하)에서는 걸리지 않는다.
  static const double keypadMaxWidth = 480.0;

  /// 키캡 터치 영역 최소 높이 (dp). 키캡이 이보다 낮으면 각인 띠까지 터치 영역을 넓힌다.
  /// (Material·Android 접근성 권장 터치 대상 48dp)
  static const double keyMinTouchTargetHeight = 48.0;

  /// 키패드 통일 글자 크기 하한 (높이 기준 크기 대비). 이보다 긴 라벨은 키마다 따로 줄어든다.
  static const double keypadUniformFontMinRatio = 0.75;

  /// 커서 패드 X자 홈·외곽선·허브 테두리 두께 (dp). 색은 [keyBorder](본체 대비 3:1 이상).
  static const double cursorPadDividerWidth = 2.0;

  // 커서 패드 모양 (#43) — 실물 fx-991EX(Quick Start Guide 1쪽 제품 사진)처럼 가로로 긴 둥근 마름모를
  // X자 홈으로 4분할하고, 가운데에 누를 수 없는 검은 허브를 둔다. 치수는 패드 크기 비례이고,
  // 패드 상자의 가로/세로 비는 [cursorPadMinAspectRatio]~[cursorPadMaxAspectRatio]로 제한해
  // 폰·폴더블·태블릿 어디서나 "가로로 긴" 모양을 유지한다(셀이 범위를 벗어나면 가운데에 줄여 놓는다).

  /// 커서 패드 상자 최소 가로/세로 비 — 세로로 긴 셀(일반 폰 약 1.3)에서도 납작한 마름모를 유지한다.
  static const double cursorPadMinAspectRatio = 1.4;

  /// 커서 패드 상자 최대 가로/세로 비 — 가로로 긴 셀(태블릿·가로 모드 약 2.2)에서 지나치게 납작해지지 않게 한다.
  /// 실물은 약 1.6이다(제품 사진 눈대중). 범위 안이면 셀을 그대로 써서 터치 넓이를 잃지 않는다.
  static const double cursorPadMaxAspectRatio = 1.8;

  /// 커서 패드 외곽 지수 p — 패드 반폭·반높이로 정규화한 좌표 (u, v)에서 |u+v|ᵖ + |u−v|ᵖ = 2
  /// (45° 돌린 Lamé 곡선). 2이면 타원, 클수록 마름모에 가까워진다. 2보다 크면 꼭짓점 곡률이 유한해
  /// 꼭짓점이 둥글다(|u|ⁿ + |v|ⁿ 초타원은 1 < n < 2에서 꼭짓점이 뾰족해진다).
  static const double cursorPadOutlineExponent = 3.0;

  /// 커서 패드 X자 홈의 기울기 k — 정규화 좌표에서 |u| ≤ k·|v|이면 ▲·▼, 아니면 ◀·▶ 구역이다.
  /// 1이면 홈이 패드 상자의 대각선이고, 1보다 크면 실물처럼 ▲·▼가 넓은 사다리꼴, ◀·▶가 좁은 삼각형이 된다.
  /// (가운데 원은 화면 좌표의 원이라 가로로 긴 패드에서는 ▲·▼ 쪽을 더 깎는다 — 넓이 비는 k만으로 정해지지 않는다.)
  static const double cursorPadGrooveSlope = 1.5;

  /// 커서 패드 가운데 허브(검은 원) 반지름 — 패드 반높이·반폭 중 짧은 쪽 대비.
  /// 허브 지름이 패드 높이의 약 1/4이 된다(실물 사진 눈대중).
  static const double cursorPadHubRadiusRatio = 0.25;

  /// 커서 패드 데드존(누를 수 없는 가운데 원) 반지름 — 패드 반높이·반폭 중 짧은 쪽 대비.
  /// 허브보다 작게 두어, 방향이 가장 모호한 한가운데만 무시하고 허브 바깥 고리는 방향 키에 준다.
  /// 그려진 허브 전체를 데드존으로 두면 320×568 폰에서 ▲·▼ 깊이가 23.7dp로 터치 하한 28dp 아래가 된다.
  static const double cursorPadDeadZoneRadiusRatio = 0.1;

  /// 커서 패드 허브 색 — 실물의 검은 허브. 방향 키캡([keyCursor])보다 어둡고, 둘레는 [keyBorder]로 긋는다.
  static const Color cursorPadHub = Color(0xFF151515);

  // ───────────────────────────────────────────
  // 화면 배치 (Screen Layout) — 세로 폰 화면의 LCD : 키패드 : 광고 슬롯 기준 (#23)
  // ───────────────────────────────────────────
  // - 광고 슬롯: 비율이 아니라 고정 높이다(배너 규격 [adSlotHeight]~[adSlotMaxHeight] + 안전 여백 8~12dp).
  //   광고 슬롯을 뺀 나머지를 "본체"라 하고, 본체를 LCD와 키패드가 나눈다.
  // - LCD: 본체 높이의 [screenLcdHeightRatio]를 목표로 하되
  //   [screenLcdMinHeight] ~ (LCD 폭 / [screenLcdMinAspectRatio]) 범위로 제한한다.
  // - 키패드: 나머지 높이. 단 키패드 가로/세로 비 하한([keypadMinAspectRatio]) 때문에 키패드가 다 쓰지 못하는
  //   높이는 LCD 최대 높이까지 LCD에 주고, 그래도 남으면 LCD 위 상단 띠로 둔다
  //   (실물의 로고·태양전지 자리, 활용은 TODO(#41)). 키패드는 항상 광고 슬롯 바로 위에 붙어 엄지가 닿기 쉽다.
  // 짧은 창(분할 화면 등)에서 LCD를 최소 높이 아래로 줄이는 규칙은 TODO(#38).
  // 대화면 가로 창의 좌우 분할은 아래 "좌우 분할 배치"(#24), 폴더블 힌지 기준 분할은 TODO(#25).

  /// 화면 가장자리 여백 (dp)
  static const double screenPadding = 8.0;

  /// LCD와 키패드 사이 간격 (dp)
  static const double screenLcdKeypadGap = 8.0;

  /// LCD 목표 높이 (본체 높이 대비). 실물 fx-991EX 앞면의 LCD 창 : 키 영역 높이(대략 1 : 3, 정밀
  /// 실측값 아님)보다 조금 크게 잡았다 — 앱 LCD는 입력·결과 줄이 각각 분수를 담는 4행 구성이고,
  /// 16:9 소형 폰(320×568)에서도 줄 글자 약 19dp를 확보한다. 그보다 크게 잡으면 소형 폰 키 각인 글자가
  /// 키 크기 하한(calculator_screen_test) 아래로 내려간다. 세로로 긴 폰에서는 LCD 최대 높이에 먼저 걸린다.
  static const double screenLcdHeightRatio = 0.28;

  /// LCD 최소 높이 (dp). 이 높이에서도 상태 표시줄 + 입력 2행 + 결과 2행이 줄 글자 약 14dp로 들어간다.
  static const double screenLcdMinHeight = 112.0;

  /// LCD 최소 가로/세로 비 — LCD 최대 높이는 LCD 폭 / 이 값이다.
  /// 폰 폭(304~414dp)에서 폭 기준([lcdLineColumns])으로 정해진 줄 글자로 내부 구성 전체(상태 표시줄 +
  /// 4행 + 분수 막대)를 담는 높이다. 이보다 높여도 글자는 커지지 않고 빈 줄 여백만 늘어난다.
  static const double screenLcdMinAspectRatio = 1.75;

  // ── 좌우 분할 배치 (#24) ──
  // 대화면 가로 창(`FormFactor.arrangementOf`)에서는 LCD 쪽과 키패드 쪽을 좌우로 나눈다.
  // - 키패드: 주로 쓰는 손 쪽 가장자리, 광고 슬롯 바로 위에 붙인다. 폭은 본체 폭의
  //   [screenSplitKeypadMaxWidthRatio] 이하(그리고 [keypadMaxWidth] 이하), 높이는 본체 높이까지.
  // - LCD: 나머지 폭을 채우고, 높이는 그 폭의 최대 높이(폭 / [screenLcdMinAspectRatio])로 키패드 윗변에 맞춘다.
  //   LCD 아래 남는 자리에 설정 버튼을 둔다.
  // - 광고 슬롯: 위아래 배치와 같이 본체 아래 전체 폭 — 키패드 최하단 행 아래 안전 여백 규칙이 그대로 지켜진다.

  /// 좌우 분할 배치의 LCD 쪽과 키패드 쪽 사이 간격 (dp)
  static const double screenSplitGap = 16.0;

  /// 좌우 분할 배치에서 키패드가 차지할 수 있는 최대 폭 (본체 폭에서 간격을 뺀 폭 대비).
  /// 이보다 넓히면 LCD 쪽이 키패드보다 좁아져 LCD 글자가 키 각인보다 작아질 수 있다.
  static const double screenSplitKeypadMaxWidthRatio = 0.5;

  /// 좌우 분할 배치의 LCD와 설정 버튼 사이 간격 (dp)
  static const double screenSplitSettingsGap = 8.0;

  /// 설정 버튼 크기 (dp) — 접근성 권장 터치 대상 48dp
  static const double settingsButtonSize = 48.0;

  /// 설정 버튼 아이콘 색 — 본체 배경([bodyBackground]) 대비 4.5:1 이상, 키 각인보다 눈에 덜 띄게 회색
  static const Color settingsIcon = Color(0xFFB0B0B0);
}

/// [KeyCategory]별 키캡 색상 조회 확장.
extension KeyCategoryColors on KeyCategory {
  /// 키캡 배경색
  Color get background => switch (this) {
    KeyCategory.number => CalcTheme.keyNumber,
    KeyCategory.operator => CalcTheme.keyOperator,
    KeyCategory.function => CalcTheme.keyFunction,
    KeyCategory.equals => CalcTheme.keyEquals,
    KeyCategory.ac => CalcTheme.keyAC,
    KeyCategory.del => CalcTheme.keyDEL,
    KeyCategory.shift => CalcTheme.keyShift,
    KeyCategory.alpha => CalcTheme.keyAlpha,
    KeyCategory.cursor => CalcTheme.keyCursor,
    KeyCategory.on => CalcTheme.keyON,
    KeyCategory.menu => CalcTheme.keyFunction,
  };

  /// 눌릴 때 키캡 배경에 덧씌우는 색 (#22) — 방향·세기 기준은 [CalcTheme] "눌림 표시" 주석 참조
  Color get pressedOverlay => switch (this) {
    KeyCategory.number ||
    KeyCategory.shift => CalcTheme.keyPressedDarkenOverlay,
    KeyCategory.operator ||
    KeyCategory.equals ||
    KeyCategory.ac ||
    KeyCategory.alpha => CalcTheme.keyPressedDeepDarkenOverlay,
    KeyCategory.function ||
    KeyCategory.menu ||
    KeyCategory.on ||
    KeyCategory.del ||
    KeyCategory.cursor => CalcTheme.keyPressedLightenOverlay,
  };

  /// 눌린 키캡 배경색 = 평소 색 + [pressedOverlay]. 평소 색을 바꾸면 함께 바뀐다(불변식 테스트가 다시 검사).
  Color get pressedBackground => Color.alphaBlend(pressedOverlay, background);

  /// 키캡 메인 라벨 텍스트색
  Color get foreground => switch (this) {
    KeyCategory.number => CalcTheme.keyNumberText,
    KeyCategory.operator => CalcTheme.keyOperatorText,
    KeyCategory.function => CalcTheme.keyFunctionText,
    KeyCategory.equals => CalcTheme.keyEqualsText,
    KeyCategory.ac => CalcTheme.keyACText,
    KeyCategory.del => CalcTheme.keyDELText,
    KeyCategory.shift => CalcTheme.keyShiftText,
    KeyCategory.alpha => CalcTheme.keyAlphaText,
    KeyCategory.cursor => CalcTheme.keyCursorText,
    KeyCategory.on => CalcTheme.keyONText,
    KeyCategory.menu => CalcTheme.keyFunctionText,
  };
}
