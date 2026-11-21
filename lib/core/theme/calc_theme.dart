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

  /// LCD 상태 표시줄 비활성 텍스트 (꺼진 세그먼트가 희미하게 비치는 효과)
  static const Color lcdStatusInactive = Color(0xFFB8CCB0);

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

  /// 함수 키 (sin, cos, log 등) — 중간 회색
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

  /// 키 눌림 시 오버레이 (20% 불투명 검정)
  static const Color keyPressedOverlay = Color(0x33000000);

  // ───────────────────────────────────────────
  // 광고 슬롯 (Banner Ad Slot)
  // ───────────────────────────────────────────

  /// 광고 슬롯 배경 (본체와 조화)
  static const Color adSlotBackground = Color(0xFF222222);

  // ───────────────────────────────────────────
  // 폰트 (Fonts)
  // ───────────────────────────────────────────

  /// LCD·키캡 고정폭 폰트 패밀리 이름.
  /// 아직 폰트 에셋을 번들하지 않아 현재는 항상 [monoFontFallback]으로 대체된다
  /// (TODO(#16): 수학 기호 글리프 폰트 번들).
  static const String monoFontFamily = 'RobotoMono';

  /// [monoFontFamily]가 없을 때 순서대로 시도하는 대체 폰트
  /// (Apple 계열은 Menlo/Courier, Android는 monospace가 해석된다)
  static const List<String> monoFontFallback = [
    'Menlo',
    'Courier',
    'monospace',
  ];

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

  /// LCD 상태 표시줄 텍스트 스타일 (S, A, DEG/RAD/GRAD, MATH 등).
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

  /// 자연 폭 우선 배분을 받는 짧은 각인의 최대 글자 수 (변수 이름 `A`~`F`, `X`, `Y`, `M` 등).
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

  /// 키 눌림 색·그림자 전환 시간
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

  /// 상태 표시 슬롯 너비 산정용 글자당 폭 (글자 크기 대비, 고정폭 폰트 기준)
  static const double lcdStatusCharWidthRatio = 0.65;

  /// 스크롤 표시(◀/▶) 글자 크기 (해당 줄 글자 크기 대비)
  static const double lcdScrollArrowFontRatio = 0.6;

  /// 스크롤 표시(◀/▶) 자리 너비 (스크롤 표시 글자 크기 대비)
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

  /// 줄 글자 한 칸 폭 (글자 크기 대비). 고정폭 글꼴(Roboto Mono·Menlo·Courier)의 글자 폭은 0.6em이다.
  /// 자간([lcdInputStyle]·[lcdResultStyle]의 `letterSpacing`)은 따로 더한다.
  /// TODO(#16): 글꼴 번들 전에는 `−`·`×`·위첨자가 폴백 글꼴에 없으면 비례폭 글꼴로 그려져
  /// 이 가정이 어긋날 수 있다. 번들한 글꼴로 17칸이 들어가는지 확인한다.
  static const double lcdLineCharWidthRatio = 0.6;

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

  /// 키캡 터치 영역 최소 높이 (dp). 키캡이 이보다 낮으면 각인 띠까지 터치 영역을 넓힌다.
  /// (Material·Android 접근성 권장 터치 대상 48dp)
  static const double keyMinTouchTargetHeight = 48.0;

  /// 키패드 통일 글자 크기 하한 (높이 기준 크기 대비). 이보다 긴 라벨은 키마다 따로 줄어든다.
  static const double keypadUniformFontMinRatio = 0.75;

  /// 커서 패드 부채꼴 경계선·테두리 두께 (dp). 색은 [keyBorder](본체 대비 3:1 이상).
  static const double cursorPadDividerWidth = 2.0;

  // ───────────────────────────────────────────
  // 화면 배치 (Screen Layout) — 세로 폰 화면의 LCD : 키패드 : 광고 슬롯 기준 (#23)
  // ───────────────────────────────────────────
  // - 광고 슬롯: 비율이 아니라 고정 높이다(배너 규격 [adSlotHeight]~[adSlotMaxHeight] + 안전 여백 8~12dp).
  //   광고 슬롯을 뺀 나머지를 "본체"라 하고, 본체를 LCD와 키패드가 나눈다.
  // - LCD: 본체 높이의 [screenLcdHeightRatio]를 목표로 하되
  //   [screenLcdMinHeight] ~ (LCD 폭 / [screenLcdMinAspectRatio]) 범위로 제한한다.
  // - 키패드: 나머지 높이. 단 키패드 가로/세로 비 하한([keypadMinAspectRatio]) 때문에 키패드가 다 쓰지 못하는
  //   높이는 LCD 최대 높이까지 LCD에 주고, 그래도 남으면 LCD 위 상단 띠로 둔다
  //   (실물의 로고·태양전지 자리). 키패드는 항상 광고 슬롯 바로 위에 붙어 엄지가 닿기 쉽다.
  // 짧은 창(분할 화면 등)에서 LCD를 최소 높이 아래로 줄이는 규칙은 TODO(#38), 대화면 좌우 분할은 #24·#25.

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
