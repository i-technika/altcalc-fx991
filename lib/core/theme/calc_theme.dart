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

  /// LCD 상태 표시줄 비활성 텍스트
  static const Color lcdStatusInactive = Color(0xFFB8CCB0);

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
  /// (폰트 번들은 후속 이슈에서 처리).
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

  /// LCD 결과줄 텍스트 스타일 (입력줄보다 약간 큼).
  static const TextStyle lcdResultStyle = TextStyle(
    fontFamily: monoFontFamily,
    fontFamilyFallback: monoFontFallback,
    fontSize: 28,
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

  /// 키캡 메인 라벨 텍스트 스타일 (기준 크기, 위젯에서 키 크기에 맞춰 스케일).
  /// 색은 카테고리마다 다르므로 [KeyCategoryColors.foreground]로 지정한다.
  static const TextStyle keyMainLabelStyle = TextStyle(
    fontFamily: monoFontFamily,
    fontFamilyFallback: monoFontFallback,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );

  /// SHIFT 각인 (키캡 위 본체 영역 좌측, 금색) 텍스트 스타일.
  static const TextStyle keyShiftLabelStyle = TextStyle(
    fontFamily: monoFontFamily,
    fontFamilyFallback: monoFontFallback,
    fontSize: 9,
    fontWeight: FontWeight.w500,
    color: shiftLabel,
    height: 1.0,
  );

  /// ALPHA 각인 (키캡 위 본체 영역 우측, 빨간색) 텍스트 스타일.
  static const TextStyle keyAlphaLabelStyle = TextStyle(
    fontFamily: monoFontFamily,
    fontFamilyFallback: monoFontFallback,
    fontSize: 9,
    fontWeight: FontWeight.w500,
    color: alphaLabel,
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

  // ───────────────────────────────────────────
  // 광고 슬롯 치수 (Banner Ad Slot Dimensions)
  // ───────────────────────────────────────────

  /// 하단 배너 광고 슬롯 기본(최소) 높이 (dp)
  static const double adSlotHeight = 50.0;

  /// 광고 슬롯 최대 높이 (dp) — 대형 화면용
  static const double adSlotMaxHeight = 60.0;

  /// 광고 슬롯 상단 안전 여백 — 오터치 방지 (dp)
  static const double adSlotSafetyMargin = 10.0;
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
