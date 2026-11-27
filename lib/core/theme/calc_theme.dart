import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../constants/key_definitions.dart';
import 'high_text_contrast.dart';

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
/// 검정 키캡(함수부)은 본체와 명도가 비슷하므로(파란 키도 본체와 3:1이 안 된다), 키 경계는 [keyBorder]로
/// 테두리를 그려 본체 대비 3:1(WCAG 1.4.11 비텍스트 대비) 이상을 확보한다.
///
/// ## 실물 외관 기준 (#156)
/// 색·모양은 실물 fx-991EX 사진 두 장에서 정했다 (사진 파일은 저장소에 넣지 않는다).
/// - Quick Start Guide 1쪽 제품 사진(`page-0001.jpg`, 고른 조명의 제품 렌더): 키 종류별 색 구성 — 숫자부·사칙연산·`=`가
///   모두 흰 키, DEL·AC가 파랑, 함수부·OPTN·CALC가 검정 광택 키, SHIFT·ALPHA·MENU·ON이 원형 은색 버튼, 커서 패드가
///   은색 금속, 본체가 잔무늬 있는 검정, LCD가 검은 베젤 안의 회녹색 액정이다. DEL·AC 파랑은 이 사진에서 뽑았다(#1A61AF 부근).
/// - 실물 키패드 근접 사진(`licensed-image.jpg`): 키캡 입체감(윗면이 둥글게 빛을 받고 아래 옆면이 보인다)·본체 잔무늬
///   (기울어진 작은 평행사변형이 엇갈리는 무늬)·각인 글꼴(모서리가 둥근 각진 산세리프, 변수 `x`·`y`·`e`는 세리프 이탤릭).
///   이 사진은 노출이 어둡고 녹색으로 치우쳐 색 값은 쓰지 않았다(흰 키가 #C8CEC8 부근으로 찍힌다).
/// 두 사진 모두 조명·노출에 따라 값이 달라, 뽑은 값을 그대로 쓰지 않고 위 대비 불변식(`test/unit/calc_theme_test.dart`)을
/// 지키는 범위에서 가장 가까운 값을 골랐다. 고른 값과 사진 값의 차이는 각 상수 설명에 적는다.
abstract final class CalcTheme {
  // ───────────────────────────────────────────
  // 본체 색상 (Body Colors)
  // ───────────────────────────────────────────
  // 실물 본체는 검정에 가까운 짙은 회색 판에 기울어진 작은 평행사변형 잔무늬가 엇갈려 찍혀 있다(근접 사진). 앱은 바탕
  // ([bodyBackground])에서 아래쪽([bodyBottomGradient])으로 옅은 세로 그라데이션을 깔고, 잔무늬를 [bodyFrame] 색으로
  // 그린다(`CalcBodyBackground`). 각인·본체 인쇄 글자가 이 세 색 모두에 대비 기준을 지킨다(테스트).

  /// 계산기 본체 배경 (짙은 차콜 — 사진의 키 사이 본체 #151C1E~#1E2124 부근)
  static const Color bodyBackground = Color(0xFF202326);

  /// 본체 잔무늬의 밝은 결 (#156 — #190 전에는 상단 띠 색이었다). 각인이 이 위에도 놓이므로 대비 기준을 함께 지킨다.
  static const Color bodyFrame = Color(0xFF2B2F33);

  /// 본체 세로 그라데이션의 아래 끝 색
  static const Color bodyBottomGradient = Color(0xFF16181B);

  /// 본체 가장자리 은색 테두리 선 — 실물은 검은 본체 판을 은백색 플라스틱 테가 감싼다. 앱은 화면을 본체로 쓰므로 테를
  /// 그리지 않고, 본체 영역 둘레에 이 색의 얇은 선([bodyRimWidth])만 긋는다(고대비 모드에서는 긋지 않는다).
  static const Color bodyRim = Color(0xFF5A6066);

  /// 본체 가장자리 선 두께 (dp)
  static const double bodyRimWidth = 1.0;

  /// 본체 잔무늬 한 칸 크기 (dp) — 근접 사진에서 잔무늬 한 칸은 키 높이의 약 1/8이다. 폰 함수 키(약 40dp)에 맞춰 둔다.
  static const double bodyTexturePitch = 5.0;

  // ───────────────────────────────────────────
  // LCD 화면 색상 (LCD Display Colors)
  // ───────────────────────────────────────────

  /// LCD 배경 — 회녹색 액정 (#156). Quick Start Guide 렌더는 밝은 민트(#C9E1D4)지만 실물 액정은 그보다 회색에 가깝다.
  /// 고대비 꺼진 표시기 대비([lcdStatusInactiveHighContrast]와 켜진 표시기 7:1)를 지키는 가장 어두운 쪽으로 골랐다.
  static const Color lcdBackground = Color(0xFFCAD4C4);

  /// LCD 텍스트 (짙은 흑색)
  static const Color lcdText = Color(0xFF1A1A1A);

  /// LCD 커서 블록 (깜빡이는 커서)
  static const Color lcdCursor = Color(0xFF333333);

  /// LCD 베젤 — 실물처럼 검은 유리 테 (#156, 사진의 베젤 #121B1D 부근)
  static const Color lcdFrame = Color(0xFF0C0E10);

  /// LCD 베젤 바깥 테두리 — 검은 베젤이 본체와 구분되도록 바깥에 긋는 얇은 선 (실물 베젤 둘레의 반사 띠)
  static const Color lcdBezelEdge = Color(0xFF4A5056);

  /// LCD 유리 윗부분 그늘 — 액정이 베젤 안으로 들어가 보이도록 유리 위쪽에 덧씌우는 옅은 그림자 (고대비 모드에서는 끈다).
  /// 위끝에서 이 색이고 [lcdGlassShadeExtent]까지 투명해진다. 맨 위끝(상태 표시줄 자리)의 글자 대비는 LCD 글자
  /// 11.4 → 10.5:1, 켜진 표시기 9.4 → 8.7:1로 약 8% 낮아진다(R1에서 7.8%이던 그늘을 3.9%로 줄였다 — 16% 손실이었다).
  static const Color lcdGlassShade = Color(0x0A000000);

  /// LCD 유리 윗부분 그늘이 퍼지는 높이 (LCD 안쪽 높이 대비)
  static const double lcdGlassShadeExtent = 0.25;

  /// LCD 상태 표시줄 활성 텍스트 (S, A, DEG 등이 켜졌을 때)
  static const Color lcdStatusActive = Color(0xFF2A2A2A);

  /// LCD 상태 표시줄 비활성 텍스트 — [lcdStatusActive]를 약 4% 불투명도로 (#44, 사용자 결정).
  /// 실물의 꺼진 표시기는 정면에서 거의 보이지 않고 비스듬히 볼 때만 희미하게 비친다(사용자 실물 확인).
  /// 픽셀 색은 도트 격자선([lcdDotGrid])보다 옅다 — 다만 글자는 면이라 밝은 화면에서는 희미하게 보일 수 있다.
  /// 고대비 모드에서는 [lcdStatusInactiveHighContrast]로 올린다(#54).
  static const Color lcdStatusInactive = Color(0x0A2A2A2A);

  /// LCD 도트 매트릭스 격자선 (픽셀 사이 틈을 표현하는 아주 옅은 선).
  /// #156에서 액정을 회녹색으로 어둡게 하면서도 세기(검정 6%)는 그대로 두었다 — 덧칠 색이라 배경이 어두워진 만큼 격자도
  /// 함께 어두워져 배경과의 대비(약 1.13:1)가 거의 같고, 실물 사진에서도 꺼진 도트는 정면에서 거의 보이지 않는다.
  /// 더 진하게 하면 꺼진 표시기(#44, 격자보다 옅어야 한다 — 테스트)를 함께 올려야 한다.
  static const Color lcdDotGrid = Color(0x0F000000);

  // ───────────────────────────────────────────
  // 키캡 카테고리 색상 (Keycap Category Colors)
  // ───────────────────────────────────────────

  // 실물(Quick Start Guide 1쪽 제품 사진)의 키 색은 네 가지다: 흰 키(숫자부 전체 — 숫자·소수점·×10ˣ·Ans·사칙연산·`=`),
  // 파란 키(DEL·AC), 검정 광택 키(함수부·OPTN·CALC), 은색(커서 패드·원형 버튼). #156 전에는 연산자가 회색, `=`가 파랑,
  // AC가 주황, DEL이 갈색이었다(Material 계열 어림값).

  /// 흰 키캡 (0~9, 소수점, ×10ˣ, Ans) — 사진은 순백(#FFFFFF)에 가깝지만, 그대로 두면 윗면 하이라이트가 보이지 않아
  /// 아주 옅은 회백색으로 둔다
  static const Color keyNumber = Color(0xFFEDEEEA);

  /// 흰 키캡 텍스트 (사진의 검정 각인)
  static const Color keyNumberText = Color(0xFF1A1A1A);

  /// 연산자 키 (+, −, ×, ÷) — 실물은 숫자 키와 같은 흰 키다 (#156)
  static const Color keyOperator = keyNumber;

  /// 연산자 키 텍스트
  static const Color keyOperatorText = keyNumberText;

  /// 함수 키 (sin, cos, log◼◻, OPTN, CALC 등) — 검정 광택 키 (#156, 사진의 키 윗면 #0D0E10~#2E343A, 광택 띠 제외)
  static const Color keyFunction = Color(0xFF17181B);

  /// 함수 키 텍스트
  static const Color keyFunctionText = Color(0xFFFFFFFF);

  /// 등호(=) 키 — 실물은 숫자 키와 같은 흰 키다 (#156)
  static const Color keyEquals = keyNumber;

  /// 등호 키 텍스트
  static const Color keyEqualsText = keyNumberText;

  /// AC(All Clear) 키 — 파랑 (#156, 사진 #195FAE~#1A61AF)
  static const Color keyAC = Color(0xFF1D5FAF);

  /// AC 키 텍스트
  static const Color keyACText = Color(0xFFFFFFFF);

  /// DEL(Delete) 키 — AC와 같은 파랑 (#156)
  static const Color keyDEL = keyAC;

  /// DEL 키 텍스트
  static const Color keyDELText = keyACText;

  /// 커서 패드 방향 키 — 은색 금속 (#156). 사진의 방향 키는 밝은 은색(반사로 #FCFCFD까지)에 그늘진 면이 섞여 있다.
  /// 윗면 그라데이션([keyCapSheen])이 금속 반사를 흉내 내도록 중간 밝기 은색을 바탕으로 둔다.
  static const Color keyCursor = Color(0xFFB9BEC3);

  /// 방향키 텍스트/아이콘 — 은색 위 어두운 화살표. 실물 방향 키에는 글자가 없지만 앱은 방향을 알 수 있게 화살표를 남긴다.
  static const Color keyCursorText = Color(0xFF1A1A1A);

  /// ON 키 카테고리의 키캡 색 — ON 키는 원형 은색 버튼([KeyFace.roundButton], #190)으로 그려 키캡 색을 쓰지 않는다.
  /// 카테고리 색 표(눌림·고대비 불변식)가 모든 카테고리를 다루도록 남겨 둔다.
  static const Color keyON = keyFunction;

  /// ON 키 카테고리의 키캡 글자 색 ([keyON]과 같은 이유로 남겨 둔다)
  static const Color keyONText = Color(0xFFFFFFFF);

  // ── 키캡 입체감 (#156) ──
  // 실물 키캡은 윗면이 둥글게 부풀어 위쪽이 빛을 받고, 아래쪽에 옆면이 살짝 보이며 본체에 그림자를 드리운다(근접 사진).
  // 앱은 평평한 키캡 위에 세 가지를 더한다(모두 고대비 모드에서는 끈다 — 글자 대비를 떨어뜨리지 않게):
  // - 윗면 광택([keyCapSheen]): 위쪽을 흰색으로 밝히고 아래쪽을 검정으로 어둡게 하는 세로 그라데이션. 글자가 놓이는 가운데
  //   ([keyCapSheenClearStart]~[keyCapSheenClearEnd])는 투명이라 글자 대비가 바뀌지 않는다.
  // - 옆면([keyCapSide]): 키캡 바로 아래 [keyCapSideDepth]만큼 같은 모양의 어두운 면 — 눌리면 키캡이 그만큼 내려가 사라진다.
  // - 그림자: 옆면 아래로 번지는 그림자([keyShadow], 눌리면 사라진다 — #22의 눌림 단서 중 하나).
  // 모서리 반경은 키 종류마다 다르다: 함수부 키는 둥글고(높이의 [keyCapCornerRadiusRatio]), 숫자부 키는 덜 둥글다
  // ([keyCapNumberCornerRadiusRatio]) — 근접 사진에서 함수 키 반경 ≈ 키 높이의 0.2, 숫자 키 ≈ 0.12.

  /// 함수부·조작부 키캡 모서리 반경 (키캡 높이 대비)
  static const double keyCapCornerRadiusRatio = 0.22;

  /// 숫자부 키캡 모서리 반경 (키캡 높이 대비)
  static const double keyCapNumberCornerRadiusRatio = 0.14;

  /// 키캡 모서리 반경 상한 (dp) — 큰 키(태블릿)에서 알약 모양이 되지 않게 한다
  static const double keyCapMaxCornerRadius = 12.0;

  /// 키캡 옆면 깊이 (dp) — 키캡 아래로 보이는 어두운 면. 눌림 이동([keyPressedOffset])과 같아, 눌린 키캡이 옆면을 덮는다.
  /// 셀 안에 눌림 이동만큼 비워 둔 자리(`CalcKeyButton`)에 그려지므로 셀 밖으로 나가지 않는다.
  static const double keyCapSideDepth = keyPressedOffset;

  /// 키캡 옆면 색 — 키캡 색에 덧씌우는 검정 (밝은 키는 회색 옆면, 검은 키는 더 검은 옆면이 된다)
  static const Color keyCapSide = Color(0x73000000);

  /// 키캡 윗면 광택의 맨 위 색 (밝은 키) — 위쪽 가장자리가 빛을 받는다
  static const Color keyCapSheen = Color(0x59FFFFFF);

  /// 키캡 윗면 광택의 맨 위 색 (검정 광택 키·파란 키) — 어두운 키는 빛을 받은 위쪽이 더 또렷한 광택 띠가 된다
  static const Color keyCapGloss = Color(0x2EFFFFFF);

  /// 키캡 윗면 아래쪽 그늘 (모든 키) — 둥근 윗면이 아래로 꺾이는 곳
  static const Color keyCapShade = Color(0x29000000);

  /// 광택이 투명해지는 높이 (키캡 높이 대비, 위에서부터)
  static const double keyCapSheenClearStart = 0.3;

  /// 아래쪽 그늘이 시작되는 높이 (키캡 높이 대비, 위에서부터)
  static const double keyCapSheenClearEnd = 0.72;

  // ── 원형 버튼 (#190, #156) ──
  // 실물 SHIFT·ALPHA·MENU·ON은 작은 원형 은색 버튼이다(Quick Start Guide 1쪽 제품 사진, 원본 픽셀로 잼): 어두운
  // 테두리 고리(지름 약 41px) 안에 금속을 돌려 깎은 듯한 바람개비 무늬의 은색 원판(지름 약 35px)이 있고, 버튼 면에는
  // 글자가 없다. 이름(`SHIFT` 금색, `ALPHA` 자홍색, `MENU`·`ON` 흰색)은 버튼 위 본체에 인쇄돼 있다(`RoundKeyFace`,
  // 인쇄 색은 [CalcPalette.bodyPrintOf]). #190에서 ON 키를, #156에서 SHIFT·ALPHA·MENU를 이 모양으로 바꿨다.
  // 실물 MENU 위에는 SHIFT 각인 `SETUP`(금색)도 나란히 인쇄돼 있지만, 앱은 설정을 ON 자리의 설정 키(`SETUP` 인쇄) 하나로
  // 열어 MENU 위에는 `MENU`만 인쇄한다 — 네 버튼 모두 이름 하나만 각인 띠 가운데에 있다(앱 고유, #253).
  // 실물 버튼은 옆 키캡(OPTN 높이 약 22px)보다 크지만, 앱은 셀 크기를 바꾸지 않고 키캡 자리 안에 고리를 내접시킨다 —
  // 터치 영역은 셀 전체다(`CalcKeyButton`).
  // 고리·원판 색은 두 모드가 같다 — 은색 원판과 어두운 고리가 이미 3:1 이상 구분되고, 버튼 경계(고리 바깥 선)는 고대비
  // 모드에서 고대비 테두리 색으로 바뀐다(#156에서 정함).

  /// 원형 버튼 테두리 고리 — 본체보다 어둡다(사진의 검은 고리)
  static const Color roundKeyBezel = Color(0xFF0E0F11);

  /// 원형 버튼 은색 원판의 밝은 결
  static const Color roundKeySilverLight = Color(0xFFF2F2F2);

  /// 원형 버튼 은색 원판의 어두운 결
  static const Color roundKeySilverDark = Color(0xFF9C9C9C);

  /// 원형 버튼 은색 원판 바람개비 무늬의 결 수 (밝은 결·어두운 결 한 쌍을 한 번으로 센다)
  static const int roundKeySilverStreaks = 6;

  /// 테두리 고리 지름 대비 은색 원판 지름 — 사진 35 / 41px
  static const double roundKeyDiscRatio = 0.85;

  /// 눌린 은색 원판에 덧씌우는 색 — 검정 30%. 은색(L* 약 70~95)이 어두워져 눌림이 보이고, 고리 바깥 경계는 키캡처럼
  /// [keyPressedBorder]로 바뀐다(#22의 공통 눌림 단서).
  static const Color roundKeyPressedOverlay = Color(0x4D000000);

  // ───────────────────────────────────────────
  // 본체 인쇄 (Body Print)
  // ───────────────────────────────────────────

  /// 본체에 인쇄된 흰 글자 — 원형 버튼 위 메인 각인(실물 `ON`·`MENU`, 앱은 ON 자리에 `SETUP`, #190·#253).
  /// 본체 배경 대비 4.5:1 이상(테스트로 검증). 고대비는 [bodyPrintHighContrast].
  /// SHIFT·ALPHA 버튼 위 이름은 각인 색([shiftLabel]·[alphaLabel])으로 인쇄한다(#156, [CalcPalette.bodyPrintOf]).
  static const Color bodyPrint = Color(0xFFE8E8E8);

  // ───────────────────────────────────────────
  // SHIFT / ALPHA 모디파이어 색상
  // ───────────────────────────────────────────

  /// SHIFT 카테고리의 키캡 색 — SHIFT는 원형 은색 버튼(#156)이라 키캡 색을 쓰지 않는다. 카테고리 색 표가 모든 카테고리를
  /// 다루도록 남겨 둔다([keyON]과 같은 이유).
  static const Color keyShift = Color(0xFFE5A823);

  /// SHIFT 카테고리의 키캡 글자 색 ([keyShift]와 같은 이유로 남겨 둔다)
  static const Color keyShiftText = Color(0xFF1A1A1A);

  /// SHIFT 각인 텍스트 (키 위 본체에 인쇄되는 금색 라벨) — 실물은 채도가 낮은 금색이다(사진 #AA9F73~#BAAE82 부근,
  /// 어두운 노출). 본체 잔무늬 위 대비를 지키도록 그보다 밝게 둔다.
  static const Color shiftLabel = Color(0xFFD4B262);

  /// ALPHA 카테고리의 키캡 색 — ALPHA는 원형 은색 버튼(#156)이라 키캡 색을 쓰지 않는다([keyShift]와 같은 이유)
  static const Color keyAlpha = Color(0xFFC62828);

  /// ALPHA 카테고리의 키캡 글자 색 ([keyAlpha]와 같은 이유로 남겨 둔다)
  static const Color keyAlphaText = Color(0xFFFFFFFF);

  /// ALPHA 각인 텍스트 (키 위 본체에 인쇄되는 자홍색 라벨) — 실물은 빨강이 아니라 분홍빛 자홍색이다(사진 #9C4867 부근,
  /// 어두운 노출). 본체 잔무늬 위 대비를 지키도록 밝게 둔다.
  static const Color alphaLabel = Color(0xFFF0679F);

  // ───────────────────────────────────────────
  // 키 눌림 상태 (Pressed State)
  // ───────────────────────────────────────────

  /// 키캡 테두리 — 어두운 키캡과 본체의 경계 표시용 (본체 대비 3:1 이상). 실물의 검정 키는 둥근 옆면이 빛을 받아 가장자리가
  /// 밝게 보이는데, 이 테두리가 그 역할을 겸한다.
  static const Color keyBorder = Color(0xFF74797E);

  // 눌림 표시 (#22) — 두 단서를 함께 쓴다.
  // 1) 배경 명도 변화: 카테고리별로 평소 색에 흰색 또는 검정을 덧씌운다([KeyCategoryColors.pressedOverlay]).
  //    눌림 전후 명도 차(CIELAB L*)가 [keyPressedMinLightnessDelta] 이상, 눌린 상태의 메인 라벨이 4.5:1 이상,
  //    눌린 키가 본체와 [keyPressedMinBodyLightnessDelta] 이상 떨어지도록 방향·세기를 정했다(테스트로 검증).
  //    #156 색으로 다시 잰 값:
  //    - 검정 광택 키(함수·MENU·ON, L* 약 8, 흰 라벨): 흰색 20%로 **밝게**(ΔL* 21.5, 본체와 16). 어둡게 하면 본체(L* 13.5)
  //      아래로 묻힌다.
  //    - 파란 키(DEL·AC, L* 약 40, 흰 라벨)·ALPHA: 검정 30%로 **어둡게**(ΔL* 12.5, 본체와 14.5). 밝히면 라벨 4.5:1을 지키는
  //      한도에서 명도 차가 모자란다.
  //    - 밝은 키(흰 키 전부·은색 커서·SHIFT, 어두운 라벨): 검정 20%로 **어둡게**(흰 키 ΔL* 17, 커서 14).
  //    (L* 약 38~41의 흰 라벨 회색 키는 어느 방향으로도 세 조건을 함께 만족하지 못한다 — 이 구간의 키 색은 피한다.)
  // 2) 테두리: 눌리면 카테고리와 무관하게 [keyBorder] → [keyPressedBorder]로 바뀐다. 눌린 색이 다른 카테고리의 평소 색과
  //    겹치더라도(눌린 흰 키 ≈ 평소 은색 커서) "종류가 바뀐 것"이 아니라 "눌린 것"으로 읽히게 하는 공통 단서다.
  //    보이는 단서는 키캡 **바깥쪽** 경계(본체와 맞닿는 쪽)다 — 본체 대비가 평소 3.6:1 → 눌림 13.9:1로 커진다.
  //    안쪽(키캡 배경 쪽) 대비는 밝은 키에서 오히려 낮아지지만, 그 키들은 배경 자체가 크게 어두워져 1)로 충분하다.
  //    눌리면 그림자와 옆면이 사라지고 키캡이 옆면 깊이만큼 내려가는 것도 함께 보인다(#156).
  //    예외: 커서 패드는 방향 구역 모양으로 잘리고 그 위에 홈([cursorPadGroove])을 덧그려 눌림 테두리가 거의 보이지 않는다 —
  //    커서 키는 1)(ΔL* 약 14)에만 의존한다.

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
  // 고대비 모드 (High Contrast) — #54
  // ───────────────────────────────────────────
  // 기기의 고대비 설정이 켜지면([CalcPalette.of]) [CalcPalette.highContrast]가 아래 색을 쓴다. 여기 없는 색은 일반 모드와 같다.
  // 켜지는 설정은 플랫폼마다 다르다. 하나라도 켜져 있으면 고대비다:
  // - `MediaQuery.highContrastOf` (Flutter 엔진이 채운다)
  //   · iOS: 손쉬운 사용 › 디스플레이 및 텍스트 크기 › "대비 증가" (`UIAccessibility.isDarkerSystemColorsEnabled`)
  //   · Android 14(API 34) 이상: 접근성 › 색상 및 동작 › "색상 대비"가 '표준'보다 높을 때('중간'·'높음',
  //     `UiModeManager.getContrast() > 0`). Android 13 이하에서는 켜지지 않는다.
  //     이 설정을 바꾸면 구성 변경(assets paths)이 나므로 `AndroidManifest.xml`의 configChanges에 `assetsPaths`를
  //     선언해 액티비티를 다시 만들지 않게 한다. 대비 값은 엔진이 UiModeManager 대비 변경 리스너로 받아 바로 전환된다 (#96).
  // - Android 모든 버전: 접근성 "고대비 텍스트"(설정 키 `high_text_contrast_enabled`) — 엔진이 읽지 않아 앱이 직접
  //   읽는다([SystemHighTextContrast], #95). 시스템이 넣는 글자 외곽선은 Flutter 화면에 효과가 없으므로 대신 이 팔레트를 준다.
  //
  // 기준(`test/unit/calc_theme_test.dart`가 검증):
  // - 키 메인 라벨과 SHIFT/ALPHA 각인(평소 상태)은 [highContrastMinTextContrast](WCAG AAA 7:1) 이상이다.
  //   일반 모드에서 7:1 미만인 파란 키(DEL·AC, 6.4:1)와 ALPHA 카테고리(원형 버튼이라 그리지 않는다) 키캡만 같은 색조로
  //   어둡게 한다. 흰 키·검정 키·은색 커서는 일반 모드에서 이미 9:1 이상이다(#156 색).
  // - 아래 대비는 일반 팔레트 이상이다: 메인 라벨·각인·화면 안내 글자·본체 인쇄 글자, 본체와 맞닿는 테두리, 커서 패드
  //   홈과 방향 키캡·허브, 눌림 명도 차·눌린 라벨·눌린 키캡과 본체의 차, 눌림 테두리와 본체, LCD 배경과 꺼진 표시기.
  // - 일반 팔레트보다 낮아지는 것 (의도한 맞바꿈 — 테스트가 하한을 따로 지킨다):
  //   · 밝은 키캡(흰 키·은색 커서·SHIFT)과 테두리의 안쪽 경계(흰 키 3.8 → 2.1:1, SHIFT 2.1 → 1.2:1). 밝은 키캡은 자기
  //     색으로 본체와 크게 구분되므로(본체 대비 흰 키 13.6:1·커서 8.4:1) 테두리는 어두운 키캡의 경계를 위해 밝힌다.
  //   · LCD 켜진 표시기와 꺼진 표시기의 대비(약 8.8 → 7.3:1) — 꺼진 표시기를 진하게 하는 대가다. 7:1 이상 남긴다.
  // - 입체 장식(#156): 본체 잔무늬·그라데이션·가장자리 선, 키캡 윗면 광택·옆면, LCD 유리 그늘은 고대비 모드에서 그리지
  //   않는다. 글자 뒤 색이 평평해져 위 대비 값이 그대로 화면의 대비가 된다. 키 그림자는 남긴다(키캡 바깥이라 글자 대비와 무관).
  // - 눌림: 흰 라벨 키는 **반전**한다(흰 키캡 [keyPressedInvertedBackground] + 어두운 라벨
  //   [keyPressedInvertedText], 사용자 결정 #54). 어두운 키캡을 일반 모드처럼 명도만 바꾸면 눌린 라벨 대비가 일반 모드보다
  //   낮아지거나(밝힐 때) 본체에 묻힌다(어둡게 할 때). 반전하면 명도 차·눌린 라벨 대비·본체와의 차가 모두 일반 모드보다 커진다.
  //   반전한 키도 뗄 때는 배경과 라벨이 함께 [keyPressAnimationDuration] 동안 돌아온다.
  //   반전한 키캡은 눌림 테두리와 같은 흰색이라 #22의 공통 눌림 테두리는 보이지 않는다 — 키캡 전체가 흰색으로 바뀌는 것이
  //   그보다 강한 단서이고, 바깥쪽 경계(본체와 15.8:1)는 그대로 남는다.
  // - 어두운 라벨 키(흰 키·은색 커서·SHIFT)는 일반 모드와 같은 방식(검정 20%)으로 어둡게 한다. 눌린 SHIFT 라벨은 일반
  //   모드와 같은 5.3:1, 눌린 커서 라벨은 6.0:1로 7:1에 못 미친다 — 밝은 키캡을 7:1로 누르려면 명도 차가 줄어 눌림이 잘
  //   보이지 않는다(SHIFT는 #156부터 원형 버튼이라 키캡 색을 그리지 않는다).
  // - 비활성 키 라벨([keyDisabledLabelOpacity])은 두 모드가 같다. 지금 앱에는 비활성 키가 없어
  //   고대비 값을 따로 두지 않았다 — 비활성 키를 쓰게 되면 그때 정한다.
  // - 팔레트 밖(두 모드 공통) 색: 본체·LCD 배경·LCD 글자·LCD 커서·켜진 표시기·LCD 베젤·도트 격자·커서 패드 허브·
  //   키 그림자·원형 버튼 고리와 은색 원판(#190). 대비가 이미 충분하거나(LCD 글자 11.4:1·켜진 표시기 9.4:1·은색 원판과
  //   고리 3:1 이상) 경계 대비를 다른 색(테두리·홈)이 맡는다.

  /// 고대비 모드의 키 메인 라벨·SHIFT/ALPHA 각인 최소 명암비 (WCAG AAA 일반 텍스트)
  static const double highContrastMinTextContrast = 7.0;

  /// 고대비 파란 키(AC·DEL) — [keyAC]를 같은 색조로 어둡게 (흰 라벨 8.5:1)
  static const Color keyACHighContrast = Color(0xFF164C8E);

  /// 고대비 ALPHA 카테고리 키캡 — [keyAlpha]를 어둡게 (흰 라벨 7.4:1). ALPHA는 원형 버튼이라 그리지 않는다.
  static const Color keyAlphaHighContrast = Color(0xFFA61E1E);

  /// 고대비 SHIFT 각인 — 본체 색 모두에 7:1 이상 (금색을 밝게)
  static const Color shiftLabelHighContrast = Color(0xFFFFD77A);

  /// 고대비 ALPHA 각인 — 본체 색 모두에 7:1 이상 (자홍색을 밝게)
  static const Color alphaLabelHighContrast = Color(0xFFFFB8D6);

  /// 고대비 키캡 테두리 — 본체 대비 6.5:1 (일반 [keyBorder] 3.6:1)
  static const Color keyBorderHighContrast = Color(0xFFA6A6A6);

  /// 고대비 눌린 키캡 테두리 — [keyBorderHighContrast]보다 L* 30 이상 밝다
  static const Color keyPressedBorderHighContrast = Color(0xFFFFFFFF);

  /// 고대비 모드에서 흰 라벨 키가 눌렸을 때의 키캡 배경 (반전)
  static const Color keyPressedInvertedBackground = Color(0xFFFFFFFF);

  /// 고대비 모드에서 흰 라벨 키가 눌렸을 때의 메인 라벨 (반전)
  static const Color keyPressedInvertedText = Color(0xFF1A1A1A);

  /// 고대비 LCD 비활성 상태 표시기 — [lcdStatusActive]를 약 15% 불투명도로 (#44에서 정한 "고대비에서 올린다"는 방침).
  /// LCD 배경 대비 1.3:1로 꺼진 표시기 자리가 희미하게 보이고(일반 4%는 1.07:1), 켜진 표시기 색과의 대비는
  /// [highContrastMinTextContrast] 이상 남겨 켜짐과 꺼짐을 헷갈리지 않게 한다.
  static const Color lcdStatusInactiveHighContrast = Color(0x262A2A2A);

  /// 고대비 화면 안내 글자·아이콘 — 본체 배경 대비 9.4:1 ([noticeForeground]를 밝게, #156 본체 색). 7:1 이상이되 고대비 SHIFT·ALPHA
  /// 각인보다 대비를 낮게 둔다.
  static const Color noticeForegroundHighContrast = Color(0xFFC8C8C8);

  /// 고대비 본체 인쇄 글자 ([bodyPrint]를 더 밝게) — 본체 배경 대비 7:1 이상
  static const Color bodyPrintHighContrast = Color(0xFFFFFFFF);

  // ───────────────────────────────────────────
  // Material 화면 테마 (대화상자·SnackBar) — #97
  // ───────────────────────────────────────────
  // 설정 대화상자([HandednessDialog] 등) 같은 Material 위젯은 앱 테마를 쓴다. 앱은 플랫폼 밝기와 관계없이 항상
  // 어두운 테마이고, 기기 고대비 설정에서는 [materialHighContrastTheme]으로 바꾼다([CalcPalette.materialTheme]이
  // 고르고, 고대비 판정은 [CalcPalette.of] 하나를 쓴다). 기준은 `test/unit/calc_theme_test.dart`·
  // `test/widget/material_theme_test.dart`가 검증한다.
  //
  // 일반 테마로 잰 대비 (대화상자 면 기준): 제목 11.1:1, 선택지 설명·닫기 버튼·라디오 8.4:1, SnackBar 글자 10.2:1.
  // 글자는 이미 7:1 이상이지만 다음이 모자랐다.
  // - 대화상자 면과 그 뒤(어둡게 덮인 본체)의 대비가 1.3:1이다. 어두운 화면에서는 M3 그림자도 보이지 않아
  //   대화상자 가장자리가 거의 구분되지 않는다.
  // - Material 기본 키보드 포커스 표시가 거의 보이지 않는다: 선택지 타일(흰색 12% 겹침)은 대화상자 면과 1.5:1, 닫기 버튼(primary
  //   10% 겹침)은 1.3:1, 예전 설정 버튼(아이콘색 10% 겹침)은 본체와 1.3:1이었다. 키보드 사용자는 고대비를 켜지 않아도 포커스 위치를
  //   찾아야 하므로, 아래 고대비 테마의 포커스 테두리를 일반 모드에도 그린다(#106, 색 [materialFocusRingStandard]).
  // - SnackBar 동작 버튼 글자가 5.0:1이다 (지금 앱은 SnackBar를 쓰지 않지만 쓰게 되면 바로 7:1 이상이 되게 맞춘다).
  // 툴팁은 M3 기본값이 색 구성과 관계없이 밝기만 보고(어두운 테마: 흰색 90% 바탕·검은 글자) 17.5:1이라 바꾸지 않는다.
  //
  // 고대비 테마는 Flutter가 제공하는 M3 고대비 기준 색 구성(`ThemeData`의 `contrastLevel: ContrastLevel.high`)을
  // 쓴다. 대화상자 면 색은 일반 테마와 같고 글자·버튼만 밝아진다(제목·설명 14.4:1, 닫기 버튼·라디오 12.6:1,
  // SnackBar 글자 16.2:1·동작 10.1:1). 여기에 계산기 고대비 팔레트 색을 더한다.
  // - 대화상자 가장자리: 고대비 키캡 테두리와 같은 색([keyBorderHighContrast]) 선 — 대화상자 면 5.9:1, 덮인 본체 7.5:1(#97 당시 본체 색 — 테스트가 3:1 이상을 지킨다)
  // - 키보드 포커스: 고대비 눌린 키캡 테두리와 같은 흰색([materialFocusRingHighContrast]) 테두리 — 대화상자 면 14.4:1,
  //   포커스 겹침 위 9.8:1, 본체 15.8:1(#156 본체 색). 테마로는 줄 수 없어 `FocusRing` 위젯이 선택지·닫기 버튼·설정 키(ON, #190)에 그린다
  //   (ListTile은 상태별 모양을 받지 않고, 버튼의 focused 상태는 터치 조작 중에도 켜져 있다).
  //
  // 대화상자 모양은 두 테마 모두 M3 기본 모양(반경 [materialDialogBorderRadius])을 직접 지정한다 — 한쪽만 지정하면
  // 고대비를 켜고 끌 때 테마 보간이 반경을 0까지 줄였다가 되돌린다. 보간 중에는 가장자리 선만 나타나거나 사라진다.
  // 고대비 기준 색 구성은 이름·설명 글자색(onSurface·onSurfaceVariant)이 같은 흰색이다 — 위계는 글자 크기로 남는다.

  /// 고대비 대화상자 가장자리 선 굵기
  static const double materialHighContrastDialogBorderWidth = 1.0;

  /// M3 대화상자 기본 모서리 반경 — 두 테마가 대화상자 모양을 직접 지정할 때 쓴다
  /// (M3 기본 대화상자와 같은지 `test/widget/material_theme_test.dart`가 확인한다)
  static const double materialDialogBorderRadius = 28.0;

  /// 고대비 키보드 포커스 테두리 색 (위 "Material 화면 테마" 주석 참조)
  static const Color materialFocusRingHighContrast =
      keyPressedBorderHighContrast;

  /// 일반 모드 키보드 포커스 테두리 색 (#106) — 일반 눌린 키캡 테두리([keyPressedBorder])와 같은 색.
  /// 고대비와 같은 방식(눌림 단서와 같은 밝은 테두리)이라 모드를 바꿔도 포커스 모양이 같다.
  /// - WCAG 2.4.13(포커스 전후 같은 픽셀 3:1 이상): 테두리 자리는 포커스 전에 대화상자 면·본체이므로 그 대비 —
  ///   대화상자 면 12.6:1, 본체 13.9:1(#156 본체 색).
  /// - 추가 확인(테두리 안쪽에 맞닿는 Material 포커스 겹침과의 인접 대비): 선택지 8.6:1, 닫기 버튼 10.1:1, 설정 버튼(#190 전) 10.0:1.
  /// - 고대비 색(흰색)은 모든 면에서 이보다 높다.
  /// 일반 테마의 primary(연보라)는 대화상자 안에서는 어울리지만 본체 위 키(설정 키)에서는 계산기 색과 맞지 않고,
  /// 선택지 겹침과의 대비도 5.7:1로 낮아 쓰지 않았다.
  /// 키캡 눌림 단서와 같은 색이므로, 나중에 키패드 키캡 전체에 키보드 포커스를 주게 되면(#39) 키캡 포커스 표시에는 이
  /// 색을 그대로 쓰지 말고 눌림과 구분되는 표시를 따로 정한다(고대비 [materialFocusRingHighContrast]도 같다).
  /// 지금 포커스를 받는 키는 설정 키(ON, #190) 하나다. 그 키의 포커스 테두리(2dp 원)는 눌림 단서(원형 버튼 고리 가장자리
  /// 1dp)와 같은 자리·색이지만, 포커스 테두리는 키보드 조작 중에만, 눌림은 터치 중에만 보여 함께 나타나는 일이 드물고
  /// 키보드로 누르면 눌림 표시 없이 바로 설정이 열린다 — 그래서 따로 정하지 않았다.
  static const Color materialFocusRingStandard = keyPressedBorder;

  /// 키보드 포커스 테두리 굵기 (두 모드 공통)
  static const double materialFocusRingWidth = 2.0;

  // 두 테마는 지금 플랫폼([defaultTargetPlatform])별로 한 번씩 만들어 둔다 (#130).
  // `ThemeData`는 만들 때의 플랫폼으로 `platform`·`materialTapTargetSize`·`visualDensity`를 정한다. 정적 값 하나로
  // 두면 처음 읽힌 플랫폼으로 굳어, 위젯 테스트의 플랫폼 변형(`TargetPlatformVariant`)에서 다음 변형이 앞 변형의
  // 밀도를 그대로 쓴다(실행 순서에 따라 결과가 달라진다). 같은 플랫폼에서는 늘 같은 객체를 돌려주므로 매 빌드
  // `ThemeData`를 다시 만들거나 MaterialApp·[AnimatedTheme]이 값을 하나하나 비교하지 않고(같은 객체면 바로 같다),
  // 테스트도 `same`으로 앱이 고른 테마를 확인할 수 있다. 실제 앱은 실행 중 플랫폼이 바뀌지 않아 값이 하나뿐이다
  // (디버그 도구의 플랫폼 전환은 다음 빌드부터 그 플랫폼 테마를 쓴다).
  // 만든 값을 계속 쓰므로 아래 정의를 고쳐도 핫 리로드에는 반영되지 않는다(핫 리스타트 필요).
  static final Map<TargetPlatform, ThemeData> _materialThemes = {};
  static final Map<TargetPlatform, ThemeData> _materialHighContrastThemes = {};

  /// 만들어 둔 플랫폼별 테마를 비운다 — 테스트가 같은 isolate 안에서 테마를 만드는 순서를 직접 정할 때 쓴다
  /// (앞 테스트가 이미 만든 테마를 읽기만 하지 않게). 비운 뒤에는 앞서 받은 테마와 다른 객체가 만들어진다.
  @visibleForTesting
  static void resetMaterialThemesForTesting() {
    _materialThemes.clear();
    _materialHighContrastThemes.clear();
  }

  /// 일반 Material 테마 (어두운 테마, 본체색 배경 — 색·모양은 #97 이전과 같다. 대화상자 모양만 기본값을 직접 지정).
  /// 지금 플랫폼의 테마다(위 #130 주석).
  static ThemeData get materialTheme {
    final platform = defaultTargetPlatform;
    return _materialThemes[platform] ??= ThemeData(
      platform: platform,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bodyBackground,
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(materialDialogBorderRadius),
          ),
        ),
      ),
    );
  }

  /// 고대비 Material 테마 — 위 "Material 화면 테마" 주석 참조. 지금 플랫폼의 테마다(위 #130 주석).
  static ThemeData get materialHighContrastTheme {
    final platform = defaultTargetPlatform;
    return _materialHighContrastThemes[platform] ??= ThemeData(
      platform: platform,
      brightness: Brightness.dark,
      contrastLevel: ContrastLevel.high,
      scaffoldBackgroundColor: bodyBackground,
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(materialDialogBorderRadius),
          ),
          side: BorderSide(
            color: keyBorderHighContrast,
            width: materialHighContrastDialogBorderWidth,
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────
  // 폰트 (Fonts)
  // ───────────────────────────────────────────

  /// LCD 고정폭 폰트 패밀리 이름 (번들 글꼴 Noto Sans Mono, `assets/fonts/`).
  ///
  /// 모든 글자 폭이 0.6em인 고정폭 글꼴이라 LCD 칸 수([lcdLineCharWidthRatio])가 플랫폼과 무관하게 같다.
  /// 키캡 각인은 #156부터 비례폭 [keyFontFamily]를 쓰고, 그 글꼴에 없는 기호(`◼`·`◻`·`⇔`·`−`·`×`·`÷`·`+`·`=`·`°`·
  /// `▲` 등)를 이 글꼴에서 찾는다([keyFontFallback]). 각인의 줄 상자(strut)도 이 글꼴의 줄 높이를 쓴다([keyStrutFontFamily]).
  /// 실물 LCD의 도트 매트릭스 글꼴을 따로 쓸지는 LCD 렌더링(M2)에서 정한다.
  static const String monoFontFamily = 'NotoSansMono';

  /// 수학 기호 대체 폰트 패밀리 이름 (번들 글꼴 Noto Sans Math).
  /// [monoFontFamily]에 없는 `∑`·`∫`를 채운다(`∛`도 있지만 키캡 근호는 그림으로 그린다, #155).
  /// 고정폭이 아니므로 LCD 줄 글자에는 쓰지 않는다.
  static const String mathFontFamily = 'NotoSansMath';

  /// [monoFontFamily]에 없는 글자를 찾을 대체 폰트 (모두 번들 글꼴이다).
  /// 라벨·LCD 템플릿의 모든 글자가 여기까지 안에서 찾아지는지 테스트로 검증한다
  /// (`test/widget/font_glyph_coverage_test.dart`).
  static const List<String> monoFontFallback = [mathFontFamily];

  /// 키캡 각인 글꼴 패밀리 이름 (번들 글꼴 Saira Medium·SemiBold, #156).
  ///
  /// 실물 각인은 모서리가 둥근 각진 비례폭 산세리프다(근접 사진의 `OPTN`·`CALC`·`sin`·숫자). 고정폭(Noto Sans Mono)으로
  /// 그리면 `x²`·`sin⁻¹`·`S⇔D`가 띄엄띄엄 보여 코드 편집기처럼 보였다. SIL OFL 비례폭 글꼴 중 Exo 2·Oxanium·Chakra Petch·
  /// Titillium Web·Rajdhani와 견주어 글자 모양(각진 `C`·`S`·`n`, 둥근 모서리, 굵기)이 가장 가까운 Saira를 골랐다.
  /// 서브셋은 ASCII에서 `+`·`=`를 뺀 글자뿐이다 — 연산 기호(`+`·`=`·`−`·`×`·`÷`)·입력 칸·방향 화살표는 Noto Sans Mono에서
  /// 찾는다(Saira의 `×`·`+`는 x높이 안의 작은 기호라 Mono가 실물에 더 가깝다. Mono의 기호도 실물보다 숫자 대비 작아, 숫자부
  /// 연산 기호 키는 키워 그린다 — [keyNumberOperatorLabelScale], #225). `⇔`만 Noto Sans Math로 그린다([isKeyMathSymbol]).
  /// 출처·서브셋은 `assets/fonts/README.md`.
  static const String keyFontFamily = 'Saira';

  /// 키캡 각인에서 변수 글자(`x`·`y`·`π`, 한 글자 각인 `e`)를 그리는 이탤릭 세리프 글꼴 (번들 Noto Serif Bold Italic 서브셋, #156).
  /// 실물은 변수를 교과서처럼 세리프 이탤릭으로 인쇄한다(근접 사진의 `x²`·`x!`·`×10ˣ`·ALPHA `y`·`e`). 어느 글자를 이탤릭으로
  /// 그리는지는 [isKeyVariableLetter]가 정한다.
  static const String keyVariableFontFamily = 'NotoSerifItalic';

  /// 키캡 각인 글꼴의 대체 글꼴 — [keyFontFamily]에 없는 기호를 Noto Sans Mono, 그다음 Noto Sans Math에서 찾는다.
  static const List<String> keyFontFallback = [monoFontFamily, mathFontFamily];

  /// 키캡 각인의 줄 상자(strut)를 정하는 글꼴 — #156 전 각인 글꼴(Noto Sans Mono)의 줄 높이·기준선을 그대로 쓴다.
  /// Saira는 위아래 여백(ascent 1.135·descent 0.439em)이 커서 그대로 쓰면 같은 글자 크기에서 기준선이 내려가고 2차원 각인
  /// 배치·키패드 글자 크기 계산(#155·#169·#186에서 맞춘 값)이 모두 달라진다. 글자 모양만 바꾸고 줄 상자는 유지한다.
  static const String keyStrutFontFamily = monoFontFamily;

  /// [text]의 [index] 글자를 키캡 각인에서 변수 이탤릭([keyVariableFontFamily])으로 그리는지 (#156).
  /// - 소문자 `x`·`y`는 늘 변수다(`x²`·`x!`·`dx`·`×10ˣ`·ALPHA `x`·`y` — 각인에 단어 속 x·y가 없다).
  /// - `π`도 늘 이탤릭이다(SHIFT `π` — 근접 사진에서 `e`와 같은 세리프 이탤릭, #156 R1).
  /// - `e`는 각인 전체가 그 한 글자일 때만이다(자연로그 밑 `e`·`e^◼`) — `Rec`·`SETUP` 같은 단어 속 글자는 바로 쓴다.
  /// (ENG 키 ALPHA의 허수 `i`는 모드별 각인 #33에서 정한다.)
  static bool isKeyVariableLetter(String text, int index) {
    final ch = text[index];
    if (ch == 'x' || ch == 'y' || ch == 'π') return true;
    return ch == 'e' && text.length == 1;
  }

  /// 키캡 각인에서 수학 글꼴([mathFontFamily])로 그리는 기호인지 (#156 R2) — `⇔`(S⇔D 키, `a b/c⇔d/c` 각인).
  /// Noto Sans Mono의 `⇔`는 x높이보다 낮은 작은 화살표(잉크 0.38em)에 좌우 여백이 커서 `S ⇔ D`처럼 벌어져 보였다.
  /// 실물은 대문자 높이의 굵은 이중 화살표가 글자에 붙어 있다(근접 사진). Noto Sans Math의 `⇔`는 잉크 0.62em, 좌우 여백
  /// 0.05em로 그에 가깝다. 다른 기호는 Noto Sans Mono 그대로다([keyFontFallback]).
  static bool isKeyMathSymbol(String ch) => ch == '⇔';

  /// 수학 기호 스타일 — [base]의 크기·색을 그대로 두고 글꼴만 [mathFontFamily]로 바꾼다 (Regular 하나뿐이다)
  static TextStyle keyMathSymbolStyle(TextStyle base) => base.copyWith(
    fontFamily: mathFontFamily,
    fontFamilyFallback: keyFontFallback,
    fontWeight: FontWeight.w400,
  );

  /// 변수 이탤릭 글자 스타일 — [base] 각인 스타일의 크기·색을 그대로 두고 글꼴만 바꾼다
  static TextStyle keyVariableStyle(TextStyle base) => base.copyWith(
    fontFamily: keyVariableFontFamily,
    fontFamilyFallback: keyFontFallback,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w700,
  );

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

  /// LCD 상태 표시줄 텍스트 스타일 (M, FIX 등 — 슬롯은 `LcdIndicatorSlot`. S·A·D/R/G는 `LcdStatusBoxedLetter`가,
  /// →x·√▭✎·‖·👁(화면 켜짐 유지)는 `LcdStatusIcon`이 이 스타일의 크기·글꼴을 기준으로 그림).
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
    fontFamily: keyFontFamily,
    fontFamilyFallback: keyFontFallback,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.0,
  );

  /// SHIFT 각인 (키캡 위 본체 영역 좌측, 금색) 텍스트 스타일.
  static const TextStyle keyShiftLabelStyle = TextStyle(
    fontFamily: keyFontFamily,
    fontFamilyFallback: keyFontFallback,
    fontSize: 9,
    fontWeight: FontWeight.w500,
    color: shiftLabel,
    letterSpacing: 0,
    height: 1.0,
  );

  /// ALPHA 각인 (키캡 위 본체 영역 우측, 빨간색) 텍스트 스타일.
  static const TextStyle keyAlphaLabelStyle = TextStyle(
    fontFamily: keyFontFamily,
    fontFamilyFallback: keyFontFallback,
    fontSize: 9,
    fontWeight: FontWeight.w500,
    color: alphaLabel,
    letterSpacing: 0,
    height: 1.0,
  );

  /// 원형 버튼 위 본체에 인쇄한 메인 각인 (흰색, 각인 띠 가운데) 텍스트 스타일 (#190).
  /// 크기는 SHIFT·ALPHA 각인과 같다 — 키패드가 통일한 각인 글자 크기(`KeypadMetrics.legendFontSize`)를 쓴다.
  static const TextStyle keyBodyPrintStyle = TextStyle(
    fontFamily: keyFontFamily,
    fontFamilyFallback: keyFontFallback,
    fontSize: 9,
    fontWeight: FontWeight.w500,
    color: bodyPrint,
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

  /// 키 모서리 둥글기 (dp) — #156부터 키캡은 높이 비례 반경(`keyCapCornerRadius`, [keyCapCornerRadiusRatio])으로 그린다.
  /// 이 값은 키캡 크기를 모르는 곳의 기본 반경으로만 남는다.
  static const double keyBorderRadius = 6.0;

  /// 키 그림자 높이 (dp)
  static const double keyElevation = 2.0;

  /// 키캡 테두리 두께 (dp)
  static const double keyBorderWidth = 1.0;

  /// 키 눌림 시 키캡이 아래로 이동하는 거리 (dp)
  static const double keyPressedOffset = 1.0;

  /// 상단 각인 띠 높이 — 함수부(상단 조작부 포함) 키 셀 높이 대비 (나머지는 키캡).
  ///
  /// 키패드(`KeypadMetrics`)는 이 높이를 **모든 구역의 키에 같은 dp로** 쓴다 (#220). 숫자부 셀은 함수부보다 높지만 각인 띠는
  /// 함수부와 같고, 남는 높이는 키캡이 받는다. 근거는 아래 "키캡 크기 (#220)" 절이다.
  /// 키패드 밖에서 따로 쓰는 [CalcKeyButton]은(각인 띠 높이를 받지 않으면) 자기 셀 높이에 이 비율을 곱한다.
  static const double keyLegendHeightRatio = 0.28;

  // ── 키캡 크기 (#220) ──
  // 실물 키패드 근접 사진(가이드 폴더의 키패드 사진, 2048×1363 — 저장소에는 넣지 않는다)과 대조한 값이다(px):
  //   구역    | 키 간격(가로 × 세로) | 키캡(가로 × 세로)   | 키캡 가로/세로 | 키캡 폭 / 가로 간격 | (각인 띠 + 키 사이) / 세로 간격
  //   함수부  | 124 × 102           | OPTN 102 × 55       | 약 1.85        | 약 0.82            | 약 0.43~0.46 (약 44~47px)
  //   숫자부  | 150 × 123           | 7 키 122 × 82       | 약 1.49        | 약 0.81            | 약 0.33 (약 41px)
  // #220 전 앱(360×800 폰, 키패드 344×458.7)은 함수 키캡 53.2×27.1(1.97), 숫자 키캡 64.7×33.7(1.92)로 숫자 키가 특히
  // 납작했다. 원인은 행 높이가 아니다 — 숫자부/함수부 세로 간격 비가 실물 123/102 ≈ 1.21이고 앱 [keypadNumberRowHeightRatio]
  // 1.2와 같다. 차이는 두 가지다.
  // 1. 각인 띠: 실물은 숫자부 셀이 함수부보다 높은데도 각인 띠(+ 키 사이)는 오히려 조금 낮고(약 41px 대 44~47px, 각인 글자는
  //    같은 크기), 숫자부 셀이 높은 몫은 키캡이 받는다. 앱은 띠를 셀 높이 비율로 잡아 숫자부 띠가 함수부보다 20% 높았다 — 각인
  //    글자 크기는 키패드에 하나라(`KeypadMetrics.legendFontSize`) 그 몫은 빈 자리였다. → 모든 키의 띠를 함수부 띠와 같은 dp로
  //    둔다([keyLegendHeightRatio]). 360×800 폰의 (띠 + 키 사이) / 세로 간격은 함수부 0.39(실물 0.43~0.46)·숫자부 0.32(실물
  //    0.33)다 — 함수부 띠를 실물만큼 높이면 함수부 키캡이 낮아져 메인 라벨이 작아지고 키캡이 더 납작해지므로 띠 비율은 그대로 둔다.
  // 2. 키캡 폭: 실물 키캡은 가로 간격의 약 0.82만 차지한다(키 사이가 넓다). 앱은 셀이 간격의 약 0.93~0.94이고 키캡이 셀 폭을
  //    다 썼다. → 키캡을 셀 가운데에 가로/세로 비 상한([keyCapMaxAspectRatio]·[keyCapNumberMaxAspectRatio])까지 좁히되,
  //    실물 키 사이보다 넓게 좁히지는 않는다([keyCapMinWidthRatio]). **터치 영역은 셀 폭 그대로다** — 키캡 옆 빈 곳을 눌러도
  //    그 키다. SHIFT·ALPHA 각인도 실물처럼 그린 키캡 폭 안에 인쇄한다(각인 띠 폭 = 키캡 폭, 원형 버튼은 셀 폭).
  // 비교한 다른 방법 — 숫자부 행을 더 높이기(LCD 높이를 덜 쓰기, [keypadMinAspectRatio]를 실물 키패드 비 약 0.69로 낮추기 등):
  // 실물과 같은 행 높이 비(1.2)를 바꾸거나 화면 배치(#141)의 LCD 쪽 영역 — 광고(#18)·계산 기록(#145) 자리, 390×844급 폰의
  // LCD 줄 글자 — 를 줄인다. 그래서 행 높이·키패드 높이 규칙은 그대로 두었다.
  // 결과(그린 키캡 가로/세로 함수 · 숫자, #220 전 → 뒤 — 실물 1.85 · 1.49):
  //   Fold 내부 841×701  1.96 → 1.85 · 1.82 → 1.49     360×800 폰     1.97 → 1.85 · 1.92 → 1.55
  //   320×568 폰         2.14 → 1.86 · 2.09 → 1.69     600×960        2.45 → 2.13 · 2.39 → 1.94
  //   800×1280 태블릿    2.22 → 1.93 · 2.17 → 1.76     1024×1366 iPad 2.53 → 2.20 · 2.48 → 2.01
  //   800×360 가로형     2.51 → 2.18 · 2.33 → 1.86     360×520 짧은 창 2.71 → 2.35 · 2.64 → 2.13
  //   2000×400 초광폭    4.76 → 4.14 · 4.44 → 3.54
  // 키패드가 실물(가로/세로 약 0.69)보다 넓은 배치 — 태블릿·짧은 창·가로형·넓은 창 — 는 폭 하한에 걸려 실물보다 여전히 꽤
  // 납작하다(#220 전보다 약 13~20% 덜 납작할 뿐이다). 그런 배치에서 실물 비를 맞추려면 키 사이를 실물보다 훨씬 넓혀야 한다
  // (iPad 세로 숫자 키는 키캡이 셀의 약 65%, 초광폭은 약 37%) — 키가 작은 섬처럼 떠 보이고 키 크기 감각이 실물과 달라져,
  // 키 사이 간격(실물 비율)을 키캡 비보다 앞에 두었다. 실측은 `test/widget/keycap_proportion_test.dart`가 고정한다.
  // 영향: 셀·행 높이·키패드 크기는 그대로라 화면 배치와 짧은 창 판정(#38, 문턱 28·16dp)은 바뀌지 않는다. 터치 높이는 숫자부
  // 키캡이 높아져 대부분 같거나 커지지만, 숫자부 키캡이 48dp([keyMinTouchTargetHeight])를 넘는 경계가 함수부 셀 약 54.0dp에서
  // 약 50.3dp로 내려와, 그 사이 창에서는 숫자부 키가 각인 띠까지 넓히지 않고 키캡만 터치 영역이 된다 — 600×960(24/48)에서
  // 숫자부 터치 65.1 → 50.3dp, 가장 낮은 키 터치 52.7(함수부) → 50.3dp(숫자부). 48dp 이상이라 터치 대상 권장은 지킨다.
  // 글자 크기는 글자 배율 1.0에서 그대로이고(각인 띠·함수부 키캡 높이가 같고, 숫자부 글자는 이미 목표 배수에 닿아 있으며,
  // 각인 글자는 띠 높이에 묶여 있어 키캡 폭으로 좁힌 띠에서도 줄지 않는다), 글자 배율이 1보다 크면 메인 라벨이 좁아진 키캡
  // 폭에 묶여 작아진다 — 배율 1.3(상한이라 2.0도 같다)에서 360×800 폰 함수부 약 1.7%·숫자부 약 5.5%, 작은 실물 배열 키패드
  // (240×320~280×373)는 약 5~7%, 넓은 배열의 낮은 키패드(접힘선 기준 배치·짧은 가로 창, 320×103.6~400×129.4)는 약 8~12%다.
  // 큰 글자 사용자의 손해라 #225에서 다시 봤다 — 숫자부는 글자 각인을 숫자와 떼어 줄지 않게 됐고, 함수부를 위해 폭 하한·비
  // 상한을 풀지는 않는다(아래 "숫자부 메인 각인 크기 (#225)" 절 4).

  /// 함수부·상단 조작부 키캡의 가로/세로 비 상한 (#220, 실물 OPTN 키 약 1.85) — 더 납작해질 자리에서는 키캡 폭을 줄인다
  static const double keyCapMaxAspectRatio = 1.85;

  /// 숫자부 키캡의 가로/세로 비 상한 (#220, 실물 7 키 약 1.49)
  static const double keyCapNumberMaxAspectRatio = 1.49;

  /// 키캡 폭 하한 (셀 폭 대비, #220) — 실물 키캡은 가로 간격의 약 0.82(함수부)·0.81(숫자부)이고, 앱 셀은 가로 간격의
  /// 0.928(함수부 6열)·0.94(숫자부 5열)다(키 사이 간격 [keyHorizontalGapRatio]). 하나로 두어 하한에서 키캡 / 가로 간격은
  /// 함수부 0.807·숫자부 0.818 — 실물과 2% 안이다(함수부는 실물보다 키 사이가 조금 넓다).
  static const double keyCapMinWidthRatio = 0.87;

  /// 각인 띠 높이 대비 각인 글자 크기 비율
  static const double keyLegendFontRatio = 0.8;

  /// 키캡 높이 대비 메인 라벨 글자 크기 비율
  static const double keyMainLabelFontRatio = 0.42;

  /// 키캡 안쪽 좌우 여백 비율 (그린 키캡 너비 대비 — #220부터 키캡은 셀보다 좁을 수 있다)
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

  // ── 2차원 각인 배치 (#155) ──
  // 분수·위첨자·아래첨자·근호 각인(`KeyLegendView`)의 배치 비율. 모두 그 조각을 품은 글자 크기 대비이며,
  // 세로 위치는 기준선 위가 +다. 잉크 범위(글리프의 실제 위아래 끝)는 `KeyLegendView.glyphInk` 표를 쓴다.
  // 분수·첨자를 넣어도 각인 높이가 한 줄(1em)을 크게 넘지 않도록 정했다 — 가장 높은 `d/dx◼`가 약 1.14em이다
  // (각인 띠는 글자 크기의 1.25em — 테스트로 고정).
  // 각인 높이는 키패드 통일 글자 크기 계산(`KeypadMetrics`)이 폭과 함께 잰다.
  //
  // 실물·화면 대조 (#169):
  // - 자리: Quick Start Guide 1쪽 제품 사진과 대조했다 — ∑의 끝 칸을 위아래로 쌓고(`LegendLimits`, 칸은 사진 비율의
  //   `LegendBox` — 아래 `keyLegendLimit*`·`keyLegendSum*`), log 밑 칸을 기준선에 두도록 고쳤다. 나머지 자리는 사진과
  //   같다.
  // - 칸 모양(#186): 모든 입력 칸을 자리별 가로세로 비([keyLegendBoxAspectRatio] — 실물 키패드 근접 사진에서 잼,
  //   `key_definitions.dart` "2차원 각인" 절)의 직사각형으로 그린다. 높이는 글꼴 `◼`·`◻`의 잉크 높이 그대로라
  //   (∑ 칸·log 진수 칸·∫ 본문 칸 제외) 각인 높이·잉크 범위가 #186 전과 같고 폭만 바뀐다. 바뀐 각인은 키패드 통일
  //   글자 크기를 정하지 않는다(폭 기준은 메인 `SHIFT`·`ALPHA` 3.0em, 각인 `Ran#`·`RanInt` 쌍) — 가장 넓은 `∫◻◻◼`도
  //   약 1.86 → 2.08em로 `SHIFT`보다 좁고, `log◼◻`는 약 2.83 → 2.62em로 좁아진다(테스트로 고정).
  //   크기는 사진과 다른 곳이 남는다: 첨자·작은 분수 속 칸은 첨자·분수 배율([keyLegendScriptScale] 등)을 따르므로
  //   같은 각인 안의 칸끼리 크기 비가 사진과 다르다(∫ 끝 칸:본문 칸 높이 사진 약 1:1 → 앱 0.32:0.36em, 대분수 정수
  //   칸:분자 칸 사진 1:1 → 앱 0.48:0.31em, `◼√◻` 지수:피개법수 사진 약 0.9:1 → 앱 0.6:1). ∫ 각인은 사진(약 1.94em)보다
  //   약 7% 넓고(2.08em), ∫ 꼬리와 아래 끝 칸 사이가 사진(약 0.15em)보다 넓다 — 번들 ∫ 글리프가 사진의 ∫보다 아래쪽이
  //   좁기 때문이다([keyLegendIntegralSubscriptShift]).
  // - 선 두께(#206, 사용자 결정 "사진 비율로"): 같은 근접 사진에서 원본 픽셀로 쟀다(밝기 중간값 경계 — #186과 같다, 메인
  //   각인 글자 크기 약 33.5px = `l` 잉크 25.5px ÷ 0.76).
  //   · 빈 칸 테두리: 3.1~4.2px — 칸 짧은 변의 0.24~0.31(분수 키 분모 25×14px 벽 3.4~4.0px → 0.26, ∫ 위·아래 끝 칸
  //     13~14px 벽 3.7~4.2px → 0.28~0.31, log 진수 칸 13×26px 벽 3.1~3.3px → 0.24), 구멍은 칸의 0.38~0.51. 앱은 칸 짧은
  //     변의 1/4([keyLegendBoxStrokeRatio]) — 구멍이 칸의 절반이다. 잰 빈 칸은 이 셋(메인 각인)뿐이고, SHIFT 각인의 빈 칸
  //     (대분수 분자·분모, `◼√◻` 피개법수, ∑ 끝 칸)은 금색이라 대비가 낮고 번져 재지 못해 같은 비율을 쓴다.
  //   · 분수 키 가로줄 4.9px(0.146em)·칸과의 간격 2.4~2.5px(0.073em)·칸 높이 14px(0.42em) — 각인 전체 1.13em
  //     ([keyLegendDisplayFraction*]).
  //   · 근호 가로줄 4.8px·비스듬한 획 약 4.6px(0.14em, [keyLegendRadicalStroke]). 근호 가로줄과 피개법수 칸 사이는 사진
  //     약 6.2px(0.19em)로 앱([keyLegendRadicalGap] 0.10em)보다 넓다 — 두께와 별개라 바꾸지 않았다. 선을 굵게 하면서 근호
  //     아래 꼭짓점의 잉크 깊이와 지수(`∛◼`의 3, `◼√◻`의 지수 칸)와 머리 사이 틈을 선 두께에 묶었다(`KeyLegendView`
  //     `_radicalBottomInkDrop`·`_radicalIndexClearance`, #206 R1 — 그러지 않으면 지수가 굵은 머리에 붙는다).
  //     근호 머리는 짧게 올라갔다 내려가던 모양에서, 사진의 메인 `√◼`처럼 시작점에서 곧게 내려가는 획으로 바꿨다(올라가는
  //     길이 0.06em이 굵어진 선보다 짧아 머리가 뭉쳤다, #206 R1). 머리 높이는 사진(아래 끝에서 약 0.55~0.59)보다 낮은
  //     0.42 그대로다 — 올리면 지수가 따라 올라가 `∛◼`가 `d/dx◼`의 잉크 위끝을 넘는다. 근호 모양 전체는 외관 작업(#156)에서 본다.
  //   · 사진 글자 획(`l` 줄기 약 5.4px = 0.16em)은 앱 글꼴(메인 SemiBold 0.124em, SHIFT·ALPHA Medium 0.107em)보다 굵어,
  //     앱에서는 선이 글자에 비해 사진보다 굵어 보인다. 선/같은 각인 글자 획 비: 사진 테두리 약 0.6~0.75·가로줄과 근호 약
  //     0.85~0.9 → 앱 테두리 메인 0.64(∫ 끝 칸)~0.85(분수 키 분모)·SHIFT 0.63(∑ 끝 칸)~1.13(`◼√◻` 피개법수 칸), 분수 키
  //     가로줄 1.18, 근호 메인 1.13·SHIFT 1.31. 칸·선끼리의 비를 사진에 맞추는 쪽을 골랐다(글꼴 굵기는 #156).
  //   · 작은 분수(`d/dx◼`·대분수·`a b/c⇔d/c`)의 가로줄([keyLegendFractionBarThickness])은 그대로 0.06em이다. 가장 높은
  //     SHIFT 각인 `d/dx◼`(1.141em)가 SHIFT 각인의 높이 맞춤(키패드 통일 각인 크기)을 정하므로, 그 가로줄·간격을 늘리면
  //     모든 SHIFT·ALPHA 각인이 작아진다(1.15em 테스트 상한에도 0.009em만 남는다). 대분수(1.000em)·`a b/c⇔d/c`(1.066em)는
  //     높이 여유가 있지만 같은 작은 분수끼리 두께를 맞추려고 함께 둔다 — 그래서 대분수 안에서 가로줄(0.06em)이 빈 칸
  //     벽(약 0.078em)보다 가늘다. 사진의 SHIFT 각인(금색)은 대비가 낮고 번져 두께를 믿을 만하게 잴 수 없다(`d/dx`
  //     가로줄 약 2~3px ≈ 0.1em).
  // - 작은 쌓은 분수의 크기: Android 에뮬레이터(1080×2400, 420dpi = 2.625배, 본체 폭 약 396dp)에 실제 앱을 띄워 기기
  //   픽셀로 쟀다(#169 — #206에서 빈 칸 테두리·분수 키 가로줄·근호 선을 굵게 하기 **전** 두께로 잰 값이다. 칸·글자 크기는
  //   분수 키 칸(배율 0.95 → 0.87)만 바뀌었고, 굵어진 선으로 획이 뭉치지 않는지는 #174에서 다시 본다).
  //   그때 모든 모양이 기기 픽셀에서 획이 뭉치지 않고 그려졌다. 크기(기기 픽셀, 1px ≈ 0.06mm):
  //   · 글자 배율 100%: 분수 `d` 약 13px(≈ 0.8mm), `dx`·`c` 약 10px(≈ 0.6mm), 대분수·분수 칸 약 7~8px,
  //     ∑ 약 12px(≈ 0.7mm)·위아래 빈 칸 약 16×7px·본문 칸 약 15×7px
  //   · 글자 배율 130%: 약 1.3배(분수 `d` 약 17px, `dx` 약 13px)
  //   사람이 실제 화면에서 읽을 수 있는지(짧은 창 하한에서 빈 칸·채운 칸이 구분되는지 포함)는 에뮬레이터로 판단할 수
  //   없어, [keyLegendFractionScale]·∑ 크기는 그대로 두고 실기기 확인(#174)에서 정한다.
  // - 한 줄 아래로 넘치는 SHIFT 각인(`d/dx◼`·`∑◻◻◼`)의 세로 자리 (#260): 실물은 이 둘을 이웃 각인과 같은 기준선에 두지 않고
  //   올려 인쇄한다 — 분모 `dx`·아래 끝 칸의 아래끝이 같은 행 `QR`·`SOLVE`의 기준선 높이에 온다. 두 사진을 원본 픽셀로 쟀다
  //   (색 차이의 절반 경계 — 금색·분홍 잉크).
  //   · 실물 키패드 근접 사진(가이드 폴더의 `licensed-image.jpg`, 2048×1363): SHIFT 각인 대문자 높이 15.8px(글자 크기 약
  //     23px). 인쇄가 오른쪽으로 약 0.003 올라가 있어(다섯째 행 `CONST`~`OFF`의 기준선 765.5 → 763.6px) 그만큼 보정했다 — 키
  //     줄은 인쇄보다 더 기울어(약 0.008) 왼쪽·오른쪽 키캡을 기준으로 견주지 않았다. `SOLVE` 기준선 y 352.0 → ∫ 키 자리에서
  //     약 350.8·x 키 자리에서 약 350.5.
  //       `d/dx◼`  잉크 322.4~350.6(높이 28.2px ≈ 1.22em) — `dx` 아래끝이 이웃 기준선과 같다(1px 안). 칸 ◼ 330.4~341.6 —
  //                아래끝이 이웃 기준선보다 9.2px(0.40em) 위
  //       `:`      326.5~344.6 — 아래 점 아래끝이 이웃 기준선보다 6.2px(0.27em) 위, 세로 가운데(335.5)는 칸 ◼ 가운데(336.0)와 같다
  //       ∑ 각인   320.3~351.7 — 아래 끝 칸 아래끝이 이웃 기준선보다 1.1px(0.05em) 아래. 본문 칸 331.4~339.7
  //     키캡 위끝(어두운 틈)까지는 `SOLVE` 기준선에서 8.7px(0.38em), `dx` 아래끝에서 7.1px(0.31em), ∑ 아래 끝 칸에서
  //     4.9px(0.21em)다.
  //   · Quick Start Guide 1쪽 제품 사진(`…_page-0001.jpg`, 대문자 높이 9.5px — 글자 크기 약 14px): `SOLVE` 기준선 775.7
  //     (`QR` 774.7), `dx` 아래끝 773.6, 칸 ◼ 764.4~769.7, `:` 764.0~771.9(아래끝이 기준선보다 약 0.25em 위), ∑ 아래 끝 칸
  //     아래끝 774.6 — 근접 사진과 같다(넘치는 각인의 아래끝이 이웃 기준선과 1~2px 안, 칸 ◼와 `:`은 그 위).
  //   · 넘치지 않는 작은 분수는 실물도 기준선을 함께 쓰고 분모가 기준선 아래로 조금 내려간다 — 근접 사진의 대분수 분모 아래끝
  //     약 0.10em·`a b/c⇔d/c` 분모 약 0.06em 아래(앱 0.103em·0.132em). 그래서 올리는 각인은 넘치는 둘뿐이다
  //     (`KeyLegendView.overhangsLine` — 테스트로 고정).
  //   #260 전 앱은 띠 아래끝에 정렬만 해, 넘친 만큼(0.08em 미만 + 줄 상자 높이 반올림 몫 — 360×800 폰 0.94dp·800×1280 태블릿
  //   글자 배율 1.3에서 1.20dp)만 올라가고 `dx`·아래 끝 칸이 키캡 위끝에 닿아 있었다(이웃 기준선보다 한 줄 상자 깊이 약
  //   0.215em 아래). 지금은 넘치는 각인의 잉크 아래끝이 띠 기준선(이웃 각인 기준선)에 오게, 같은 키의 짝 각인(∫ 키의 `:`)과
  //   함께 올린다(`KeyLegendView.bandLifts`, 키 버튼의 각인 줄). `:`은 `d/dx◼`의 잉크 깊이(0.278em — 사진 0.27em)만큼
  //   올라간다. 칸 ◼ 아래끝은 사진(0.40em)보다 낮은 0.278em 위다 — 사진의 분수가 앱보다 커서다(1.22em 대 1.116em, 높이 예산).
  //   근접 사진(EN판이 아닌 모델)의 x 키에는 EN판에 없는 분홍 `∏` 각인도 ∑와 같은 높이로 올라가 있다.
  //   올리는 거리는 띠 위쪽 여유까지다 — 띠 높이·각인 글자 크기는 그대로 둔다(실물은 (각인 띠 + 키 사이)가 앱보다 높다 — "키캡
  //   크기 (#220)" 절. 올릴 자리를 `KeypadMetrics`의 높이 기준에 미리 떼어 두면 글자 배율을 키운 사용자의 SHIFT·ALPHA 각인이
  //   모두 그만큼 작아진다). 사진과 같은 자리가 되려면 여유가 한 줄 상자 깊이(약 0.215em — 그린 크기에서는 줄 상자 높이를 정수
  //   dp로 반올림해 0.15~0.27em) 이상이어야 한다. 실제 앱에서 잰 `d/dx◼` 잉크 아래끝(띠 기준선 아래, 글자 배율 1.0 · 1.3):
  //     사진과 같은 자리(0)     800×1280·1024×1366·1280×800(두 배율 모두), 600×960(배율 1.0)
  //     여유만큼만              360×800 0.98 · 1.18dp, 320×568 0.19 · 1.47dp, 412×915 0.77 · 2.00dp, Fold 841×701 0.66 · 1.99dp,
  //                             673×841 0.70dp(배율 1.0), 800×360 1.16dp·915×412 1.35dp(배율 1.0), 600×960 2.75dp(배율 1.3)
  //     여유 없음(아래 정렬 그대로) 800×360·915×412·673×841의 배율 1.3 — 한 줄 상자 깊이만큼(2.2~2.8dp) 아래, #260 전과 같다
  //   각인 글자가 띠 높이의 0.8배인 창(폰)은 배율 1.0에서 여유가 약 0.13em이라 잉크 아래끝이 띠 기준선보다 0.03~0.14em 아래다 —
  //   사진의 넘치지 않는 분수가 내려간 깊이와 비슷하다. 글자 배율을 키우면 각인이 띠를 채워 여유가 줄거나 없어진다.
  //   `test/widget/legend_band_baseline_test.dart`가 창별 결과(사진과 같은 자리·여유만큼·여유 없음)와 그린 픽셀을 고정한다.

  /// 위첨자·아래첨자 글자 크기 비율
  static const double keyLegendScriptScale = 0.66;

  /// 위첨자 기준선 기본 올림 (`x²`·`x^◼`·`e^◼`·`sin⁻¹`·`cos⁻¹`·`tan⁻¹`은 이 높이 — −1이 같은 높이다).
  /// 이 높이에서 위첨자 위끝이 바탕 잉크 위끝보다 낮으면 바탕 위끝까지 올린다(`10^◼`·`×10ˣ`·∫의 위 끝 칸).
  static const double keyLegendSuperscriptRaise = 0.36;

  /// 아래첨자 기준선 기본 내림. 이 깊이에서 아래첨자 아래끝이 바탕 잉크 아래끝보다 높으면 바탕 아래끝까지
  /// 내린다(∫의 아래 끝 칸). `log`의 밑 칸은 내리지 않고 아래끝을 기준선에 둔다(`subscriptOnBaseline`, #169 사진 대조).
  static const double keyLegendSubscriptDrop = 0.22;

  /// 바탕 글자와 첨자 사이 간격
  static const double keyLegendScriptGap = 0.03;

  /// ∑ 각인(`LegendLimits` + `LegendBox`)의 ∑ 글자 크기 비율 (#169, 사용자 결정 "사진 비율을 높이 예산 안에서").
  ///
  /// 실물(Quick Start Guide 1쪽 제품 사진, 원본 픽셀로 잼)의 ∑ 각인: ∑ 잉크 7×7px, 위·아래 끝 칸 9×4px(빈 칸),
  /// 오른쪽 본문 칸 8×4px(채운 칸, 세로 가운데가 ∑와 같다), 칸과 ∑ 사이 약 1px. 쌓은 높이 17px는 가장 높은 각인
  /// `d/dx◼`(15px)보다 높다. 앱은 쌓은 높이를 `d/dx◼`(약 1.14em) 안에 두어 키패드 통일 각인 크기를 지키고, 그 안에서
  /// 사진의 칸 비율(아래 `keyLegendSum*Ratio`)을 그대로 쓴다 — 그래서 ∑는 작아진다(잉크 0.954em × 0.5 ≈ 0.48em, x높이
  /// 0.54em 정도). 쌓은 높이 ≈ 0.48 + 2 × 0.27 + 2 × 0.04 ≈ 1.10em(테스트로 고정).
  static const double keyLegendLimitBaseScale = 0.5;

  /// ∑ 각인 칸(위·아래 끝, 오른쪽 본문)의 높이 (∑ 잉크 높이 대비) — 사진 4px / 7px (#169)
  static const double keyLegendSumBoxHeightRatio = 4 / 7;

  /// ∑ 위·아래 끝 칸의 폭 (∑ 잉크 높이 대비 — ∑ 잉크는 거의 정사각형) — 사진 9px / 7px (#169)
  static const double keyLegendSumLimitWidthRatio = 9 / 7;

  /// ∑ 오른쪽 본문 칸의 폭 (∑ 잉크 높이 대비) — 사진 8px / 7px (#169)
  static const double keyLegendSumOperandWidthRatio = 8 / 7;

  /// ∑ 위·아래 끝 칸과 ∑ 잉크 사이 간격, ∑ 덩어리와 본문 칸 사이 간격 (#169). 사진은 약 1px(∑ 높이의 약 1/7)이지만,
  /// 1/7(약 0.068em)이면 쌓은 높이가 약 1.16em으로 `d/dx◼`(약 1.14em)를 넘으므로 높이 예산 안에서 약 1/12로 둔다.
  static const double keyLegendLimitGap = 0.04;

  /// 직접 그리는 빈 칸(`LegendBox`)의 테두리 두께 (칸의 짧은 변 대비, #206). 근접 사진의 빈 칸 테두리는 칸 짧은 변의
  /// 0.24~0.31이다("2차원 각인 배치" 절). 테두리는 칸 안쪽에 칠하므로 구멍은 칸의 `1 − 2 × 이 값`이다 — 1/4이면 구멍이 칸의
  /// 절반으로, #169 R2의 규칙(구멍이 칸의 절반 이상 남아 작은 각인에서도 빈 칸이 채운 칸처럼 메워지지 않는다)의 경계에
  /// 맞다. 칸 크기에 비례하므로 글자 크기와 상관없이 모양이 같다(최소 선 두께 [keyLegendMinStroke]를 쓰지 않는다 — 1/4보다
  /// 굵게 칠하면 구멍이 절반보다 작아진다. #206 전에도 작은 각인에서는 이 1/4 상한이 두께를 정했다).
  static const double keyLegendBoxStrokeRatio = 0.25;

  /// 직접 그리는 칸(`LegendBox`)의 가로/세로 비 — 자리마다 실물 사진에서 잰 원본 픽셀 비 (#186, ∑ 칸은 #169).
  ///
  /// 픽셀 값의 출처는 `LegendBoxShape` 각 값의 설명이다. 정사각형에 가까운 칸도 잰 비를 그대로 쓴다(사용자 결정
  /// "모든 칸 사진 비율로"). 칸의 높이는 `KeyLegendView`가 정한다 — ∑ 칸은 ∑ 잉크 기준([keyLegendSumBoxHeightRatio]),
  /// log 진수 칸은 `l` 윗끝, ∫ 본문 칸은 [keyLegendIntegralOperandHeight], 나머지는 글꼴 `◼`의 잉크 높이(그 자리 글자
  /// 크기 대비)다.
  static double keyLegendBoxAspectRatio(LegendBoxShape shape) =>
      switch (shape) {
        LegendBoxShape.sumLimit =>
          keyLegendSumLimitWidthRatio / keyLegendSumBoxHeightRatio, // 9×4
        LegendBoxShape.sumOperand =>
          keyLegendSumOperandWidthRatio / keyLegendSumBoxHeightRatio, // 8×4
        LegendBoxShape.integralLimit => 27 / 26, // 위 14×13·아래 13×13의 평균
        LegendBoxShape.integralOperand => 25 / 12,
        LegendBoxShape.derivativeOperand => 14 / 10,
        LegendBoxShape.fractionPart => 25 / 14,
        LegendBoxShape.mixedWhole => 14 / 11,
        LegendBoxShape.mixedFractionPart => 18 / 11,
        LegendBoxShape.squareRootRadicand => 16 / 15,
        LegendBoxShape.cubeRootRadicand => 12 / 11,
        LegendBoxShape.rootIndex => 12 / 10,
        LegendBoxShape.rootRadicand => 14 / 11,
        LegendBoxShape.powerExponent => 14 / 14,
        LegendBoxShape.tenPowerExponent => 11 / 10,
        LegendBoxShape.ePowerExponent => 10 / 9,
        LegendBoxShape.logBase => 11 / 13,
        LegendBoxShape.logArgument => 13 / 26,
      };

  /// 직접 그리는 칸(∑ 칸 제외)의 좌우 여백 (그 자리 글자 크기 대비) — 글꼴 `◼`·`◻`의 좌우 여백(번들 Noto Sans Mono
  /// 0.059em, 글자 폭 0.6em − 잉크 폭 0.482em의 절반)과 같게 해, 비가 1인 칸은 글꼴 칸과 같은 자리·폭을 차지한다(#186).
  /// 앞에 칸이 붙는 자리(log 진수 칸, ∫ 본문 칸)는 왼쪽 여백을 두지 않는다 — 사진에서 앞 칸과 0~1px로 맞닿는다.
  static const double keyLegendBoxSideBearing = 0.059;

  /// `∫` 본문 칸의 높이 (글자 크기 대비, #186 R1·R2). 근접 사진의 본문 칸 25×12px(채운 부분 — 번진 가장자리까지 넣으면
  /// 27×14px)의 높이 12px ÷ 메인 각인 글자 크기 약 33px(`l` 잉크 0.76em = 25px) ≈ 0.36em. 비(25/12)와 같은 경계에서 쟀다.
  /// 글꼴 칸 높이(0.482em)로 두면 ∫ 끝 칸보다 1.5배 높고 각인 전체가 사진(약 1.94em)보다 24% 넓어진다(2.40em) — 이
  /// 높이면 약 2.08em이다.
  static const double keyLegendIntegralOperandHeight = 0.36;

  /// `∫` 아래 끝 칸을 위 끝 칸보다 왼쪽으로 당기는 길이 (`subscriptFollowsSlant`, #186). 근접 사진에서 아래 칸이 위 칸보다
  /// 9px 왼쪽이다(왼쪽·오른쪽 테두리 모두) — 메인 각인 글자 크기 약 33px로 나누면 약 0.27em. 사진의 ∫ 꼬리와 아래 칸
  /// 사이는 약 5px(0.15em)인데, 번들 ∫ 글리프는 아래쪽이 좁아 같은 길이를 당겨도 그 사이가 약 0.28em으로 더 넓다
  /// (R2에서 확인 — 칸끼리의 어긋남을 사진에 맞추고, 꼬리 간격 차이는 "2차원 각인 배치" 절에 적었다).
  static const double keyLegendIntegralSubscriptShift = 0.27;

  /// 분자·분모 글자 크기 비율 (다른 조각 사이의 분수 — `d/dx◼`, `a b/c⇔d/c`, 대분수)
  static const double keyLegendFractionScale = 0.65;

  /// 각인 전체가 분수 하나일 때(분수 키 `◼/◻`)의 분자·분모 글자 크기 비율 — 한 줄 높이를 채운다.
  /// 칸 높이는 글꼴 `◼` 잉크 0.482em × 0.87 ≈ 0.42em으로 근접 사진(14px ÷ 33.5px)과 같다 — 굵어진 가로줄·간격(#206)과
  /// 합친 각인 높이 ≈ 0.42 × 2 + 2 × 0.073 + 0.146 ≈ 1.1307em이 사진(37.9px ≈ 1.13em)과 같고, 가장 높은 메인 각인
  /// `∫◻◻◼`(1.1310em)를 넘지 않아 메인 라벨의 높이 맞춤(키패드 통일 메인 글자 크기)이 그대로다(테스트로 고정 — 여유가
  /// 0.0003em뿐이라 가로줄·간격·배율을 늘리면 메인 라벨이 작아진다). #206 전에는 0.95(가로줄 0.06em·간격 0.04em,
  /// 각인 약 1.06em)였다.
  static const double keyLegendDisplayFractionScale = 0.87;

  /// 분수 가로줄 가운데 높이 (기준선 위)
  static const double keyLegendFractionAxis = 0.28;

  /// 다른 조각 사이의 작은 분수(`d/dx◼`, `a b/c⇔d/c`, 대분수) 가로줄 두께. 분수 키는
  /// [keyLegendDisplayFractionBarThickness]를 쓴다 — 이 값은 각인 높이 예산 때문에 사진보다 가늘게 둔다("2차원 각인 배치" 절).
  static const double keyLegendFractionBarThickness = 0.06;

  /// 작은 분수의 가로줄과 분자·분모 잉크 사이 간격 (분수 키는 [keyLegendDisplayFractionGap])
  static const double keyLegendFractionGap = 0.04;

  /// 분수 가로줄이 분자·분모 조각보다 좌우로 더 나가는 길이
  static const double keyLegendFractionOverhang = 0.06;

  /// 분수 키 각인(`◼/◻`, 디스플레이 분수)의 가로줄이 분자·분모 조각보다 좌우로 더 나가는 길이 (#186 R1).
  /// 근접 사진은 가로줄 37~38px, 칸 25~26px로 가로줄/칸 잉크 폭 ≈ 1.46이다. 칸 조각 폭에는 좌우 여백
  /// ([keyLegendBoxSideBearing] × [keyLegendDisplayFractionScale])이 들어 있어, 이 값과 합쳐 약 1.46이 되도록 정했다
  /// (칸 잉크 0.749em → 가로줄 0.851 + 2 × 0.121 ≈ 1.093em, #206에서 칸 배율 0.95 → 0.87로 다시 맞춤 — 전에는 0.13).
  /// 여백이나 칸 배율을 바꾸면 이 값도 다시 맞춘다(테스트로 고정).
  static const double keyLegendDisplayFractionOverhang = 0.121;

  /// 분수 키 각인(`◼/◻`)의 가로줄 두께 (#206). 근접 사진 4.9px ÷ 메인 각인 글자 크기 33.5px ≈ 0.146em — 칸 높이(0.42em)의
  /// 약 0.35다. 작은 분수는 [keyLegendFractionBarThickness].
  static const double keyLegendDisplayFractionBarThickness = 0.146;

  /// 분수 키 각인(`◼/◻`)의 가로줄과 분자·분모 칸 사이 간격 (#206). 근접 사진 2.4~2.5px ≈ 0.073em.
  static const double keyLegendDisplayFractionGap = 0.073;

  /// 거듭제곱근 지수(`∛`의 3, `◼√◻`의 ◼) 글자 크기 비율
  static const double keyLegendRadicalIndexScale = 0.6;

  /// 근호 선 두께 (#206). 근접 사진의 `√◼` 가로줄 4.8px·비스듬한 획 약 4.6px ÷ 33.5px ≈ 0.14em — 피개법수 칸 높이(글꼴
  /// `◼` 0.482em)의 약 0.29로, 사진(4.7px ÷ 칸 15.7px ≈ 0.30)과 같다. #206 전에는 0.07이었다.
  static const double keyLegendRadicalStroke = 0.14;

  /// 근호 가로줄과 피개법수 잉크 위끝 사이 간격
  static const double keyLegendRadicalGap = 0.10;

  /// 근호 왼쪽 부분(가로줄 앞까지) 폭
  static const double keyLegendRadicalSignWidth = 0.46;

  /// 분수 가로줄·근호 선의 최소 두께 (dp) — 작은 각인에서도 선이 사라지지 않게 한다
  /// 0.5dp는 기기 배율 2~3에서 1~1.5 물리 픽셀이다. 더 굵게 하면 작은 각인(글자 5~7dp)에서 굵어진 만큼이
  /// 분수 가로줄·근호 가로줄 옆 여백을 다 덮는다(#155 R2 — 0.75dp일 때 5.7dp 글자의 분수 여백 0.02dp).
  static const double keyLegendMinStroke = 0.5;

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

  /// 상태 표시 슬롯 사이 최소 간격 (상태 표시 글자 크기 대비).
  /// 실물 세그먼트는 거의 붙어 있다(D·R·G 사이 0도트, FIX·SCI 사이 2도트 — #58). 그래서 글자가 실물보다 넓어
  /// 밀어낼 때 남기는 간격만 작게 둔다. 크면 큰 글자 배율에서 실물 위치를 버리고 줄 전체를 축소하게 된다.
  static const double lcdStatusSlotGapRatio = 0.2;

  /// 상태 표시 글꼴(Noto Sans Mono SemiBold)의 대문자 높이 (글자 크기 대비, OS/2 sCapHeight 714/1000).
  /// 직접 그리는 상태 아이콘(#57)이 글자와 같은 높이가 되도록 쓴다(테스트가 글꼴 파일 값과 대조).
  static const double lcdStatusCapHeightRatio = 0.714;

  /// 상태 표시 글꼴의 x높이 (글자 크기 대비, OS/2 sxHeight 542/1000) — `→x` 상자 안 x의 잉크를 상자 가운데에 맞춘다
  static const double lcdStatusXHeightRatio = 0.542;

  /// 상태 아이콘 선 굵기 (글자 크기 대비) — SemiBold 글자 획 굵기와 비슷하게.
  /// `‖`의 밝은 두 획(칸의 37%·63% 위치) 사이에 어두운 부분이 남도록 칸 폭의 26%보다 가늘어야 한다(테스트로 검증, #160).
  static const double lcdStatusIconStrokeRatio = 0.1;

  /// 상자 안 글자 크기 (상자 높이 = 대문자 높이 대비) — 반전 상자 글자(S·A·D·R·G)와 `→x`의 x (#160).
  /// 실물은 7도트 높이 상자 안에 위아래 1도트를 남긴 5도트 글자다(User's Guide 표시기 표·스프라이트·사진의 D).
  static const double lcdStatusBoxedLetterRatio = 5 / 7;

  /// `→x` 상자 안 x의 글자 크기 (옆 글자 크기 대비). 상자 안쪽 폭(한 칸 0.6em − 테두리 2×0.1em = 0.4em)에서
  /// x 잉크 폭(약 0.52em × 이 값)이 양쪽 테두리와 떨어지도록 [lcdStatusBoxedLetterRatio]보다 작게 둔다 —
  /// 5/7이면 작은 크기(10dp·3x)에서 x 팔 끝이 테두리에 붙어 ⊠처럼 보인다(#160 리뷰 R1). 같은 이유로 x는 굵은 글씨
  /// 설정을 따르지 않는다(굵게 그리면 8dp×1.3에서 다시 붙는다, 리뷰 R2).
  static const double lcdStatusStoreXRatio = 0.55;

  /// `→x` 잉크 전체 폭 (한 칸 글리프 폭 대비) — x 상자 한 칸 + 상자 밖 화살표 반 칸. 2칸 슬롯 가운데에 놓는다 (#183).
  /// 근거는 스프라이트 잉크 폭(#58 표): →x 8도트, S 상자 7도트(높이도 7도트)다. 모든 세그먼트가 켜진 진단 화면
  /// 영상도 흐림 범위(±1도트) 안에서 이와 모순되지 않는다. 앱은 x를 알아볼 수 있게 x 상자를 한 칸(S 상자와 같은 폭)으로
  /// 두고 상자 밖 화살표만 줄였다. 남은 차이는 척도마다 다르다:
  /// - 대문자 높이 대비: 앱 1.26배(1.5 × 0.6em ÷ 0.714em) 대 실물 8/7 = 1.14배 → 약 10% 넓다.
  /// - 옆 반전 상자(S) 대비: 앱 1.5배 대 실물 1.14배 → 약 31% 넓다. 앱 S 상자(0.6em)가 실물(정사각형 7×7도트)보다
  ///   좁아서 생기는 몫이 크다. 이전(#160)은 1.88칸 + 자간(S 대비 약 1.88배)이었다.
  static const double lcdStatusStoreInkCells = 1.5;

  /// `→x` 화살표 머리 길이 (한 칸 글리프 폭 대비) — 대문자 높이의 약 0.27(가이드 실측, #160)
  static const double lcdStatusStoreHeadCells = 0.32;

  /// `→x` 화살표 머리 끝이 x 상자 왼쪽 끝에서 상자 안으로 들어간 깊이 (한 칸 글리프 폭 대비, #160)
  static const double lcdStatusStoreTipDepthCells = 0.12;

  /// `√▭✎` 잉크 전체 폭 (한 칸 글리프 폭 대비) — 근호 시작부터 연필 위 끝까지. 3칸 슬롯 가운데에 놓는다 (#217).
  /// 근거는 스프라이트 잉크 폭(#58 표): √▭✎ 14도트 = 대문자 높이(7도트)의 2.0배, S 상자(7도트)의 2.0배다.
  /// 이 값은 대문자 높이 대비 2.02배(2.4 × 0.6em ÷ 0.714em)로 스프라이트에 맞춘다. 옆 반전 상자(S, 앱 0.6em) 대비로는
  /// 2.4배 대 스프라이트 2.0배(약 20% 넓다) — 앱 S 상자가 실물(정사각형)보다 좁은 몫이다(`→x`와 같은 이유,
  /// [lcdStatusStoreInkCells]).
  /// 다른 자료는 더 좁다: User's Guide 4쪽 표시기 표의 인쇄 아이콘은 S 상자(대문자 높이에 해당)의 1.86배(아이콘 자기
  /// 높이의 1.70배)이고, #183 진단 화면 영상은 약 12도트(대문자 높이의 약 1.7배, 흐림 ±1~2도트)였다. 스프라이트를 택한 것은 도트 단위로 정확한 LCD 세그먼트
  /// 그림이기 때문이다 — 인쇄 아이콘은 LCD와 비율이 다르고(#160), 영상은 흐림 범위가 2.0배까지 걸친다. 이 판단은
  /// 선명한 실물 사진 대조(#216)에서 다시 확인한다.
  /// 이전(#160)은 3칸 슬롯 전체였다: 3칸만으로 대문자 높이의 2.52배이고, 자간 2개를 더하면 상태 글자 10dp에서 약
  /// 2.66배다(자간은 dp 고정이라 글자가 작을수록 비율이 커진다).
  /// 내부 배치(근호 : 틈 : 칸 : 연필, #160 사진 측정)는 그대로 두고 가로로만 이 폭에 맞춰 줄인다(`LcdStatusIcon`).
  static const double lcdStatusMathInkCells = 2.4;

  /// `👁`(화면 켜짐 유지, 앱 고유 — #233) 잉크 전체 폭 (한 칸 글리프 폭 대비). 2칸 슬롯 가운데에 놓는다.
  /// 근거: 눈이 가로:세로 약 1.9:1로 가로로 길어야 작은 크기에서 원(⊙ — ☉ = 해)으로 뭉개지지 않는다(#233 리뷰 R1 —
  /// 한 칸이면 1.1:1이었다). 그래서 다른 아이콘이 쓰는 척도(대문자 높이 대비 폭)로는 실물 그 자리 ☀ 잉크(6도트 ÷ 대문자
  /// 높이 7도트 = 0.86배, #58 스프라이트 표)보다 약 37% 넓다(1.4 × 0.6em ÷ 0.714em = 1.18배) — 의도한 차이다.
  /// 표시줄 폭 대비로는 LCD마다 다르다: 폭이 상태 글자 크기를 정하는 폰 세로 LCD에서는 한 칸 진행 폭이 실물 약
  /// 4.3~5.5도트(글자 배율 1~1.3)라 1.4칸이 대략 ☀ 잉크 폭이고, 넓은 가로 LCD에서는 그 절반쯤이다(#233 리뷰 R2 실측).
  static const double lcdStatusEyeInkCells = 1.4;

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
  // LCD가 그 줄 글자에 필요한 높이보다 높으면(줄 글자가 폭이나 상한 [lcdLineMaxFontSize]에 묶인 LCD — 키패드가 쓰지 못한 높이를
  // 받은 세로로 긴 폰·가로형 위 띠, #232) 남는 높이는 입력 줄과 결과 줄이 같은 비율([lcdInputLineFlex] : [lcdResultLineFlex])로
  // 나눠 받는다. 입력은 입력 줄 왼쪽 위, 결과는 결과 줄 오른쪽 아래에 붙으므로(`LcdDisplay` 줄 내용 계약) 식은 상태 표시줄 바로
  // 아래, 답은 LCD 아래 끝에 남고 둘 사이만 벌어진다 (#232, 비교한 다른 방법과 함께 정했다):
  // - 실물 fx-991EX처럼 식은 위, 답은 아래 오른쪽이라는 자리가 LCD 높이와 무관하게 같다 — 창 크기가 바뀌어도 식·답 위치가
  //   LCD 가장자리 기준으로 고정이다(가로형 창 높이를 늘이면 답이 키패드 쪽으로 따라 내려온다).
  // - 높아진 줄은 M2의 2차원 수식(정적분·시그마·겹분수처럼 분수 1단보다 높은 템플릿, #36)이 잘리지 않고 담길 높이가 된다.
  //   그 템플릿을 줄일지·세로로 스크롤할지 정할 때 이 높이를 쓸 수 있다.
  //   단, 줄 하나의 높이는 기기마다 다르다(행 = 줄 글자 × 1.3 + 1 기준, 배율 1) — 390×844 iPhone 약 2.6행, 세로로 긴 폰 411×960
  //   약 3.9행, 12.9인치 iPad 가로 활성 LCD 약 4.5행, 데스크톱 2000×1400 약 6.5행, 세로 창 2160×3800 약 8.3행. 그래서 같은 식이
  //   어떤 기기에서는 잘리고 어떤 기기에서는 다 보일 수 있다.
  //   #36(M2)이 정할 것: 이 차이를 받아들일지(기기마다 `LcdLineScope.size` 기준) 분수 1단 높이를 기준으로 맞출지, 긴 식을 높아진
  //   줄에서 줄바꿈할지 실물처럼 한 줄 가로 스크롤로 둘지, 늘어난 높이를 기록(#145)에 쓸지 (#232 이슈의 사용자 요청 — "화면이
  //   넓어진 만큼 실제 글자를 어떻게 표시할지").
  // - ◄/►(줄이 넘칠 때의 스크롤 표시)도 줄 내용과 같은 쪽 — 입력 줄은 위, 결과 줄은 아래의 2행 높이 안 가운데에 둔다(#232 R1).
  //   줄 높이 가운데에 두면 높은 LCD에서 화살표가 식·답에서 멀어진다(12.9인치 iPad 가로: 입력 글자 32.5~84.5dp, ◄ 141~163dp).
  //   띠 가운데는 분수 막대 높이다 — 2행 내용(분수)이면 막대 옆이고, 한 행짜리 식·답이면 화살표가 글자보다 반 행 아래(입력)·
  //   위(결과)에 온다(12.9인치 iPad 가로: ◄ 79.7~101.3dp). 줄 높이가 띠와 같던 #232 전과 같은 위치라 그대로 둔다(#232 R2).
  //   한 행 내용에서 화살표를 글자 행에 맞출지는 #36(◄/► 자동 판정)에서 실물과 견줘 정한다.
  // - 비교: 글자 블록(상태 표시줄 + 4행)을 LCD 가운데나 아래에 모아 두면 식과 답은 가깝지만 LCD 안에 빈 띠가 생기고(#232가
  //   없앤 빈 곳이 LCD 안으로 옮겨 갈 뿐이다), 높이마다 식 위치가 움직인다. 결과 줄만 키우면 식이 높은 템플릿을 담을 자리가 없다.

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

  /// LCD 입력·결과 줄 글자 크기 상한 (dp, 시스템 글자 배율 반영 후) — #189, 사용자 결정 "글자 + LCD 높이 상한, 40dp".
  ///
  /// 줄 글자는 LCD 크기에 비례한다(`LcdFontSizes.forSize`). 상한이 없으면 큰 창에서 키 각인 상한
  /// ([keyMainLabelMaxFontSize] 16.5dp)의 5~8배가 됐다(가로형 2000×1400 활성 LCD 963×550 82dp, 4K 데스크톱 3840×2160
  /// 133dp, 세로 창 2160×3800 164dp). 상한은 키 각인 상한과 같은 기준이다 — 실물 크기 LCD(폭 480dp ≈ 76mm, 실물 본체 폭
  /// 약 77mm. 예전 LCD 최대 크기 480×274dp, #24·#92)의 줄 글자 39.1dp를 올림했다. 폰의 줄 글자 / 키 메인 각인 비(390×844
  /// 29.8 / 12.8 ≈ 2.3배, 440×956 2.35배)와 비슷한 2.4배에서 멈춘다.
  /// - 폰·iPad 768×1024(38.9dp)는 걸리지 않는다. 10인치 태블릿 세로(49dp)·12.9인치 iPad(세로 54.1, 가로 54.7dp)부터 걸린다.
  /// - 화면 배치는 LCD가 **목표로 가져가는** 높이도 이 글자에 필요한 높이(`LcdFontSizes.heightAtMaxLineFont`, 약 273.5dp)까지로
  ///   둔다 — 그보다 남는 높이는 키패드가 쓸 수 있으면 키패드가 받는다(태블릿 세로). 키패드도 쓰지 못한 높이는 LCD가 받아 그보다
  ///   높아진다(#232 — LCD 위에 빈 곳을 두지 않는다). 그때 글자는 커지지 않고 식(왼쪽 위)과 답(오른쪽 아래) 사이만 벌어진다
  ///   (위 "LCD 내부 구성" 절). 자세한 규칙은 "화면 배치"·"가로형 배치"·"접힘선 기준 배치" 절.
  /// - 배율 반영 **후** 크기의 상한이다. 줄 글자는 원래 배율과 무관하게 LCD를 채우는 크기라([lcdMaxTextScaleFactor]) 배율로
  ///   이 상한을 넘지 않는다. 배치의 LCD 높이 상한은 배율 1 기준이므로, 큰 배율에서는 상태 표시줄이 커진 만큼 줄 글자가 상한보다
  ///   조금 작다(배율 1.3: 38.9dp, 약 3% — LCD가 상한 높이에서 멈춘 배치(태블릿 세로)의 값이다. 키패드가 쓰지 못한 높이를 받아
  ///   그보다 높아진 LCD는 상태 표시줄 몫의 제약이 풀려 상한까지 커질 수 있다, #232 R1). 화면 배치는 글자 배율과 무관하게 정한다.
  static const double lcdLineMaxFontSize = 40.0;

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
  // 키패드 배치 (Keypad Layout)
  // ───────────────────────────────────────────

  /// 숫자부 행 높이 (함수부·상단 조작부 행 높이 대비) — 실물처럼 숫자 키가 더 크다.
  static const double keypadNumberRowHeightRatio = 1.2;

  /// 함수부와 숫자부 사이 간격 (키패드 높이 대비)
  static const double keypadSectionGapRatio = 0.02;

  /// 키패드 최소 가로/세로 비 — 세로로 긴 화면에서 키가 세로로 길어지지 않게 높이를 제한한다.
  /// 키패드 최대 높이는 키패드 폭 / 이 값이다(넓은 배열은 블록 폭 기준, `KeypadMetrics.fitSize`).
  ///
  /// 가로 쪽에는 상한이 없다 (#141, 사용자 결정 "가로로는 구역을 끝까지 채운다"). 예전에는 최대 가로/세로 비 1.25와
  /// 최대 폭 480dp(#24)로 키패드를 줄여 태블릿에서 양옆이 비었다. 이제 키패드는 받은 폭을 다 쓰고, 키가 가로로
  /// 넓어져도 각인 글자는 [keyMainLabelMaxFontSize]·[keyLegendMaxFontSize]에서 멈춘다.
  static const double keypadMinAspectRatio = 0.75;

  /// 키캡 메인 라벨 글자 크기 상한 (dp, 시스템 글자 배율 반영 전) — #141, 사용자 결정 "각인 글자 크기에만 상한".
  ///
  /// 폭 상한을 푼 키패드(#141)는 태블릿 세로에서 함수 키가 약 121~156×69~76dp(숫자 키 약 147~190×85~94dp)까지
  /// 커진다(10인치~12.9인치). 글자는 키 높이에 비례하므로(`KeypadMetrics.compute`) 상한이 없으면 메인 라벨이 약
  /// 21~23dp가 된다. 상한은 예전 키패드 최대 크기 480×640dp
  /// (#24 — 480dp ≈ 76mm로 실물 fx-991EX 본체 폭 약 77mm와 비슷하다)의 글자 크기 16.45dp를 올림한 값이다.
  /// 그래서 큰 화면의 글자는 실물 크기 키패드의 글자에서 멈추고, 키가 그보다 커진 몫은 키캡 안 여백이 된다.
  /// 폰(본체 폭 424dp 이하)은 이보다 작아 걸리지 않는다(불변식 테스트).
  static const double keyMainLabelMaxFontSize = 16.5;

  // ── 숫자부 메인 각인 크기 (#225) ──
  // 실물 키패드 근접 사진(가이드 폴더의 키패드 사진, 2048×1363 — 저장소에는 넣지 않는다)에서 잰 잉크 크기(px, 어두운 잉크
  // 문턱 110/255 — 문턱 70~150에서 ±1~2px):
  //   숫자부  | 키캡 면 120×80 | 숫자 0~9 높이 45(윗변이 평평한 1·4·7)~46(둥근 숫자)              → 숫자 / 숫자 키캡 ≈ 0.57
  //   함수부  | 키캡 면 102×55 | 대문자 높이 26(STO·ENG·M+ — 평평한 윗변)~27(OPTN·CALC — 둥근 O·C) → 대문자 / 함수 키캡 ≈ 0.48
  //   숫자부 글자 각인 | Ans의 A 38·×10ˣ의 10 38·AC 37(DEL은 흰 글자가 번져 41) → 숫자의 약 0.83
  //   연산 기호 | × 39×41·÷ 43×43·+ 41×43·− 42×9·= 43×23 → 높이·폭이 평평한 숫자 높이(45)의 0.87~0.96(=의 높이는 0.51),
  //             획 두께(7~9)는 숫자 획(7~8)과 같다
  //
  // 1. 숫자 크기: #156은 숫자를 "함수부 메인 라벨 × 1.5"로 정했다. 근거로 든 "숫자 높이 ≈ 숫자 키캡의 0.69"는 숫자 키캡을
  //    실제(80px)보다 낮게(약 67px) 잰 값이다. #220에서 숫자 키캡이 함수 키캡보다 더 높아지자(약 1.2 → 1.28배) 숫자가 키캡에
  //    비해 약 7% 작아 보였다. 그래서 숫자도 함수부처럼 **자기 키캡 높이의 비율**([keyNumberMainLabelFontRatio])로 정한다 —
  //    키캡 비율이 다시 바뀌어도 어긋나지 않는다. 비율은 두 구역의 글자/키캡 비가 실물과 같은 배수가 되게 잡았다: 앱의 함수부
  //    대문자는 키캡의 약 0.30(키캡 높이 × [keyMainLabelFontRatio] × Saira 대문자 잉크 0.688em)으로 실물 0.48의 약 0.62배다
  //    (#141 글자 크기 계산 그대로). 숫자도 실물 0.57의 같은 배수가 되면 구역 사이 크기 차가 실물과 같다. Saira의 숫자와
  //    대문자는 잉크 높이가 같으므로(평평한 윗변 0.688em, 둥근 글자 0.696em — 사진도 같은 모양끼리 45:26·46:27로 비가 같다)
  //    → 0.42 × (45/80) / (26/55) ≈ 0.42 × 0.57 / 0.48 ≈ 0.50.
  //    숫자만 실물 비(0.57) 그대로 키우면 숫자부만 실물 크기에 가까워져 함수부와의 차가 실물보다 커진다(#156과 같은 이유로 하지
  //    않는다). 결과(배율 1.0, 숫자 글자 dp — 함수부 글자 대비): 360×800 폰 17.68 → 18.62(1.50 → 1.58배), Fold 내부 841×701
  //    20.59 → 23.01(1.68배 — 넓은 배열은 숫자 행이 함수 행보다 더 높다), 800×1280 태블릿 24.75 → 26.0(상한). 숫자 / 숫자
  //    키캡은 폰 0.34 → 0.35(평평한 숫자 잉크 0.688em 기준, 실물 0.57의 0.62배 — 함수부 0.30 / 0.48과 같다).
  // 2. 글자 각인(DEL·AC·Ans·×10ˣ): 실물은 숫자의 약 0.83으로 인쇄한다([keyNumberWordLabelScale]). #225 전에는 숫자와 같은
  //    크기여서, 키캡 폭에 가장 빠듯한 이 각인들이 숫자까지 함께 줄였다(배율 1.3의 360×800 폰 숫자부 약 5.5% — #220 R2).
  //    이제 글자 각인은 따로 폭에 맞추고 숫자는 폭에 묶이지 않는다. 360×800 폰의 글자 각인은 17.68 → 15.46dp로 작아진다.
  // 3. 연산 기호(× ÷ + − =): Noto Sans Mono Medium 기호는 숫자 대비 실물의 약 0.71배다(높이·폭이 평평한 Saira 숫자 높이
  //    0.688em의 0.63~0.69). 글리프마다 실물/앱 비(같은 모양 숫자끼리 짝지은 높이·폭 여덟 값)가 1.38~1.47로 고르므로 다섯 기호를
  //    평균 1.41의 한 배율([keyNumberOperatorLabelScale])로 키운다. `=`의 두 줄 사이는 Mono가 실물보다 넓어 높이만 실물보다
  //    약 16% 크다(숫자의 0.59 대 0.51) — 폭과 획을 맞추는 쪽을 택하고 `=`만 따로 찌그러뜨리지 않는다. 다른 글꼴의 기호는 쓰지
  //    않는다 — 번들 Saira의 기호는 x높이 안의 더 작은 기호이고(`assets/fonts/README.md`), Noto Sans Math는 Mono와 같은 크기다.
  //    키우면 획도 굵어지므로 한 단계 가는 Medium(w500)으로 그린다([keyNumberOperatorLabelStyle]) — 키운 − 의 획 약 0.13em이
  //    Saira 숫자 가로 획(약 0.12em)에 가깝다(약 10% 굵다. 실물은 같은 굵기이고, SemiBold면 0.15em로 Medium의 1.15배다). 실물의 기호는 숫자와 잉크
  //    가운데 높이가 같다. #225는 줄 상자를 키캡 가운데에 둔 채 키운 기호만 내려 숫자에 맞췄다. #230부터는 모든 메인 각인을
  //    잉크 가운데로 세로 맞춤하고(아래 "메인 각인 세로 위치" 절) 기호는 자기 잉크 가운데를 쓰므로, 숫자와 기호가 함께 키캡
  //    면 가운데에 놓인다.
  // 4. 큰 키와 글자 배율: 상한([keyNumberMainLabelMaxFontSize])은 함수부 상한(#141)처럼 실물 크기 키패드(480×640dp)의 숫자
  //    글자다. 글자 배율 1.3·2.0(키 글자 배율 상한 1.3)에서 숫자는 키캡 높이에 묶이기 전에는 줄지 않는다 — 폭에 묶이던 글자
  //    각인을 숫자와 떼어 놓았기 때문이다(실측한 모든 창에서 배율 1.0과 같은 크기다). 연산 기호는 작은 창에서 키캡 높이에
  //    묶여 배율보다 덜 커진다(배율 1.3의 360×800 폰 1.40배·320×568 폰 1.36배, 넓은 배열의 낮은 키패드 320×103.6 1.21배 — 숫자보다는 크다).
  //    함수부 메인 라벨은 배율 1.3에서 좁아진 키캡 폭(#220)에 여전히 묶인다(360×800 폰 약 1.7%, 넓은 배열의 낮은 키패드
  //    320×103.6~400×129.4 8~12%). 그래서 배율 1.3에서는 숫자 / 함수부 글자 비가 배율 1.0보다 커진다(360×800 1.58 → 1.61,
  //    320×568 1.58 → 1.63, 320×103.6 1.68 → 1.91). 숫자를 함수부만큼 함께 줄이지는 않는다 — 큰 글자를 고른 사용자에게 숫자는
  //    들어가는 만큼 크게 보이는 편이 낫고, 1번의 "같은 배수"는 키캡 비율로 정한 배율 1.0의 기준이다. 배율이 클 때 키캡 폭
  //    하한·비 상한을 풀면 함수부의 손해는 없어지지만, 글자 배율에 따라 키캡 모양이 바뀌고 키 사이(실물 비율, #220)가 좁아진다.
  //    배율 1.3의 함수부 글자는 그래도 배율 1.0보다 1.14배 이상 크므로(320×103.6 4.67 × 1.3 / 5.32) 풀지 않는다. 넘침·하한과 이
  //    1.14배 근거는 `test/widget/number_label_size_test.dart`가 고정한다(나머지 수치는 #225 당시 실측이다).

  /// 숫자부 숫자(0~9·소수점) 메인 라벨 글자 크기 목표 — 숫자부 키캡 높이 대비 (#225, 위 "숫자부 메인 각인 크기" 절).
  /// 함수부 메인 라벨([keyMainLabelFontRatio])처럼 키캡 높이(눌림 여유 포함)에 곱한다. 함수부 메인 라벨보다 작아지지 않고,
  /// 키캡 높이·폭이 모자라면 줄어든다(`KeypadMetrics.numberMainLabelFontSize`).
  static const double keyNumberMainLabelFontRatio = 0.5;

  /// 숫자부 숫자 글자 크기 상한 (dp, 배율 반영 전, #225) — [keyMainLabelMaxFontSize]처럼 실물 크기 키패드 480×640dp의 숫자
  /// 글자 크기(25.99dp)를 올림한 값이다. 큰 화면에서 숫자는 실물 크기 키패드의 숫자에서 멈춘다.
  static const double keyNumberMainLabelMaxFontSize = 26.0;

  /// 숫자부 글자 각인(DEL·AC·Ans·×10ˣ — 두 글자 이상인 숫자부 메인 각인)의 크기 — 숫자 글자 크기 대비 (#225, 실물 약 0.83)
  static const double keyNumberWordLabelScale = 0.83;

  /// 숫자부 연산 기호(× ÷ + − =) 글자 크기 — 숫자 글자 크기 대비 (#225). 근접 사진의 기호/숫자 비 ÷ Noto Sans Mono Medium의
  /// 기호/숫자 비(같은 모양 숫자끼리 — 평평한 윗변)의 평균이다(×·÷·+ 높이·폭, −·= 폭 여덟 값 1.38~1.47 → 1.415, 테스트로 고정).
  static const double keyNumberOperatorLabelScale = 1.41;

  /// [legend]가 숫자부 연산 기호 메인 각인(× ÷ + − = 한 글자)인지 (#225) — [keyNumberOperatorLabelStyle]·
  /// [keyNumberOperatorLabelScale]로 그린다. 메인 각인이 이 한 글자인 키는 숫자부의 다섯 키뿐이다(불변식 테스트).
  /// SHIFT·ALPHA 각인(CALC 키 ALPHA `=`)과 다른 글자 사이의 기호(`M+`·`(−)`·`×10ˣ`)는 바꾸지 않는다.
  static bool isKeyOperatorLegend(KeyLegend legend) =>
      legend is LegendText && _keyOperators.contains(legend.text);

  static const Set<String> _keyOperators = {'×', '÷', '+', '−', '='};

  /// 숫자부 연산 기호 메인 각인 스타일 (#225) — Noto Sans Mono Medium. 크기는 키패드가 주입한다(숫자 × [keyNumberOperatorLabelScale]).
  /// 줄 상자(strut)는 다른 각인처럼 [keyStrutFontFamily]다(같은 글꼴이다).
  static const TextStyle keyNumberOperatorLabelStyle = TextStyle(
    fontFamily: monoFontFamily,
    fontFamilyFallback: monoFontFallback,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.0,
  );

  // ── 메인 각인 세로 위치 (#230) ──
  // 실물 키패드 근접 사진(가이드 폴더의 키패드 사진)에서 키캡 면 위끝(윗테두리)부터 잉크 가운데까지를 면 높이(옆면 앞까지)로
  // 나눈 값 — 숫자부 숫자 0.47~0.53(평균 약 0.495), 연산 기호 0.49~0.53, DEL·AC 0.49·0.52, 함수부 대문자·높은 소문자 각인
  // (ENG·tan·ln·sin) 0.50~0.52다. 사진 아래쪽 행일수록 조금 커지는(카메라 각도) 것을 빼면 실물은 대문자·숫자의 잉크 가운데를
  // 키캡 면 가운데에 둔다. #230 전 앱은 줄 상자(Noto Sans Mono strut)를 면 가운데에 두었다. 줄 상자 안 기준선은 글자 스타일만
  // 보면 위에서 0.785em이지만, 앱 테마(Material 3)의 기본 글자 스타일이 줄 간격을 위아래로 고르게 나눠(`TextLeadingDistribution
  // .even`) `Text` 각인은 0.888em이고, 글자 배치 엔진은 그 거리를 정수 dp로 반올림한 곳에 글자를 그린다. 그래서 그린 픽셀의 잉크
  // 가운데 / 면 비가 360×800 폰에서 숫자 약 0.528(1.0dp 아래)·연산 기호 약 0.541(1.5dp 아래)이었고, 함수부는 반올림에 따라
  // STO 0.499·x 0.527로 제각각이었다. 2차원 각인(`KeyLegendView` — 테마 글자 스타일을 받지 않아 0.785em)은 `Text`보다 기준선이
  // 약 0.1em 높아 log◼▯가 같은 행 ln보다 약 1dp 위였다. (#252부터는 각인 줄 상자(`keyLabelStrut`)가 줄 간격 배분을 고정해
  // 두 위젯 모두 0.785em을 보고하고, 각인 띠의 `Text`는 `DrawnBaselineLabel`이 반올림 차(최대 0.5dp)를 옮겨 보고한 기준선에
  // 그린다. 그래서 아래 정렬한 SHIFT·ALPHA 각인 띠의 기준선이 같다 — 한 줄 아래로 넘치는 2차원 각인(`d/dx◼`·`∑◻◻◼`)만
  // 실물처럼 짝 각인과 함께 더 올려 잉크 아래끝을 띠 기준선에 둔다(#260 — "2차원 각인 배치" 절의 사진 실측).)
  //
  // 실물은 각인마다 잉크를 가운데에 두지 않고 **기준선을 함께 쓴다** — 같은 행의 sin·cos·tan은 기준선이 같고(x높이뿐인 cos의
  // 잉크 가운데는 면의 0.565로 아래에 있다), log◼▯(내림 글자 g)와 ln도 기준선이 같다(log 0.546·ln 0.500). x²(0.482)처럼
  // 위첨자가 있는 각인은 그만큼 잉크 가운데가 위에 있다. 그래서 메인 각인은 두 가지로 맞춘다
  // (`calc_key_button.dart`의 `mainLegendInkCenter`):
  // 1. 기준선 글자가 있는 각인([hasKeyBaselineText] — 로마자·숫자·소수점, 변수 x 포함): 대문자·숫자 잉크 가운데
  //    ([keyMainLegendInkCenter], 기준선 위)를 면 가운데에 둔다. 모든 각인의 기준선이 줄 상자 기준선에서 같은 거리라 실물처럼
  //    기준선이 맞는다 — 같은 행의 x²·x^◼·log◼▯·ln, x⁻¹·sin·cos·tan의 기준선이 같다.
  // 2. 기준선 글자가 없는 각인(연산 기호 × ÷ + − =, 방향 키 ▲▼◄►, (−)·( )·°'", 분수·근호·적분)과 변수 x 하나만 있는 x 키:
  //    자기 잉크(`KeyLegendView.glyphInk` 표로 잰 범위)의 가운데를 면 가운데에 둔다. 연산 기호(Noto Sans Mono Medium, 잉크
  //    가운데 0.346~0.354em)는 그래서 숫자와 같은 높이에 놓인다(#225의 내려 그리기를 대신한다). 분수 키(사진 0.509)는 맞출
  //    기준선이 없다. x 키는 키 안에 기준선을 함께 쓸 글자가 없고 사진도 잉크가 가운데(0.509)라 자기 잉크로 맞춘다 — 그래서
  //    x 키의 기준선은 같은 행 OPTN·CALC보다 약 0.08em(360×800 폰 약 1dp) 높다(의도한 결과다). 괄호·°'"는 사진(0.527~0.536)이
  //    측정 잡음(같은 행 숫자끼리도 ±0.02) 안이라 두 규칙이 구별되지 않아, 글자가 없는 각인의 규칙(자기 잉크)을 따른다.
  //    방향 키(커서 패드 반쪽 키캡의 라벨 자리, #65)도 같은 규칙으로 라벨 자리 가운데에 잉크를 둔다 — #230 전에는 줄 상자
  //    기준선(0.888em) 때문에 잉크가 라벨 자리 가운데보다 약 0.1em(태블릿 약 1.9dp) 아래였다.
  // 줄 상자 높이·줄 간격 배분·엔진의 기준선 반올림·2차원 각인의 큰 상자에 상관없이 **그린 기준선**에서 맞추므로(`InkCenteredLabel`)
  // 기준 높이가 면 가운데와 0.01dp 안이다(그린 픽셀로 재면 대문자·숫자·기호 약 0.49~0.51 — 1 물리 픽셀 안). 내림 글자(g)·분수·∫도 키캡 면 안에
  // 그려진다(`test/widget/main_legend_ink_center_test.dart`). `Text`의 반올림 보정은 엔진(SkParagraph) 동작에 기대므로, Flutter SDK를
  // 올릴 때 그 동작이 바뀌면 같은 테스트의 픽셀 측정("실물 사진 대조")이 잡는다.

  /// 메인 각인을 기준선으로 맞출 때 키캡 면 세로 가운데에 두는 높이 — 각인 글꼴 Saira 대문자·숫자의 잉크 가운데 (기준선 위,
  /// 글자 크기 대비, #230). 윗변이 평평한 글자(E·7, 0~0.688em)와 둥근 글자(S·0, −0.008~0.696em)가 같다. 위 "메인 각인 세로
  /// 위치" 절의 1이다.
  static const double keyMainLegendInkCenter = 0.344;

  /// 메인 각인 [legend]에 기준선 글자가 있는지 (#230, 위 "메인 각인 세로 위치" 절) — 로마자·숫자·소수점이다. 변수 이탤릭
  /// 글자([isKeyVariableLetter])도 센다(x²·x⁻¹·x^◼의 x는 이웃 각인과 기준선을 함께 쓴다). 단 변수 글자만 있는 글자 각인
  /// (x 키)은 키 안에 기준선을 함께 쓸 글자가 없어 기준선 각인이 아니다.
  static bool hasKeyBaselineText(KeyLegend legend) {
    if (legend case LegendText(:final text)) {
      final onlyVariables = Iterable.generate(text.length)
          .every((i) => isKeyVariableLetter(text, i));
      if (onlyVariables) return false;
    }
    return legend.texts.any((piece) => _keyBaselineChar.hasMatch(piece.text));
  }

  static final RegExp _keyBaselineChar = RegExp(r'[A-Za-z0-9.]');

  /// 메인 각인 [legend]를 그리는 기준 스타일 — 숫자부 연산 기호는 [keyNumberOperatorLabelStyle], 나머지는 [keyMainLabelStyle]
  static TextStyle keyMainLabelStyleFor(KeyLegend legend) =>
      isKeyOperatorLegend(legend)
      ? keyNumberOperatorLabelStyle
      : keyMainLabelStyle;

  /// SHIFT·ALPHA 각인 글자 크기 상한 (dp, 시스템 글자 배율 반영 전) — [keyMainLabelMaxFontSize]와 같은 기준.
  /// 키패드 480×640dp의 각인은 폭에 묶여 10.69dp였다(긴 각인이 셀 폭에 들어가는 크기). 키가 넓어지면 폭 제한이 풀려
  /// 높이 기준(각인 띠 높이 비례, 태블릿 세로 약 16dp)까지 커진다. 상한은 그 480×640의 10.69dp를 올림한 값이다.
  static const double keyLegendMaxFontSize = 11.0;

  /// 넓은 키패드 배열(`KeypadArrangement.wide`, #80)의 함수부 블록과 숫자부 블록 사이 간격 (블록 폭 대비).
  /// 블록 폭 400dp(Fold 가로 반 접힘)에서 24dp — 키 사이 가로 간격(블록 폭 × [keyHorizontalGapRatio], 약 5dp)보다
  /// 넓어 두 구역이 갈라져 보이고, 블록 경계의 키를 옆 구역 키로 잘못 누르지 않게 한다.
  static const double keypadWideSectionGapRatio = 0.06;

  /// 키캡 터치 영역 최소 높이 (dp). 키캡이 이보다 낮으면 각인 띠까지, 그리고 셀 둘레 키 사이 간격 몫(간격의 절반씩)까지
  /// 터치 영역을 넓힌다 (#236, `CalcKeyButton.gapInsets`). 의미 노드(접근성 검사기가 재는 터치 대상)도 같은 영역이다.
  /// (Material·Android 접근성 권장 터치 대상 48dp)
  ///
  /// ## 폰 세로 화면에서 48dp에 못 미치는 키 (#236, 사용자 결정 — 간격을 터치에 넣고 나머지는 받아들인다)
  /// 실물 배열 50키를 한 화면에 담으면 가장 낮은 함수부 키 셀은 폰에서 48dp보다 낮다. 키 사이 간격 몫을 더한 터치 높이
  /// (= 행 간격, 의미 노드 높이)는 다음과 같다 (함수부 터치 높이, dp, 창 크기와 위/아래 인셋).
  ///   48dp 미만: 320×568 (20/0) 37.5 · 360×640 (24/48) 38.9 · 375×667 (20/0) 44.6 · 411×731 (24/48) 45.5 ·
  ///              360×800 (24/24) 45.9 · 375×812 (50/34) 47.9
  ///   48dp 이상: 411×772 (24/48) 48.45 · 380×800 (24/24) 48.53 · 390×844 (47/34) 49.9 · Fold 커버 411×797 (41.9/24) 50.7 ·
  ///              411×914 (52.6/24) 52.7 · 430×932 (59/34) 55.2
  /// 행 간격은 키패드 높이가 정하고, 키패드 높이는 창 폭(키패드 가로/세로 비 하한, #141)과 인셋을 뺀 창 높이에 모두 묶인다.
  /// 그래서 둘 다 넉넉해야 48dp를 넘는다 — 높이가 넉넉하면 폭 약 377dp, 폭이 넉넉하면 인셋을 뺀 높이 약 695dp가 경계다
  /// (#236 R2 실측, 경계 양쪽의 사례를 위 표에 둔다).
  /// 48dp를 넘는 폰은 Accessibility Scanner "Touch target" 지적이 없어진다(Medium Phone 411×914 에뮬레이터에서 확인).
  /// 그보다 작은 폰은 키를 더 키울 자리가 없어 48dp 미만을 받아들인다 — LCD를 줄여 키패드를 키우는 것은 화면 배치
  /// 규칙(#141)과 맞지 않는다. 키 폭(셀 폭 + 좌우 간격 몫)은 표의 모든 폰에서 48dp 이상이다. 쓸 수 있는 크기의 하한은
  /// 짧은 창 판정(#38)이 지킨다. 표의 값과 48dp 이상/미만, 키 폭은 `calculator_screen_test.dart`의 "폰 세로 화면의 터치
  /// 대상 높이"가 고정한다.
  static const double keyMinTouchTargetHeight = 48.0;

  /// 키패드 통일 글자 크기 하한 (높이 기준 크기 대비). 이보다 긴 라벨은 키마다 따로 줄어든다.
  static const double keypadUniformFontMinRatio = 0.75;

  /// 커서 패드 X자 홈·외곽선·허브 테두리 두께 (dp) — 그림의 최소 두께이자 방향 키 라벨 여백의 기준. 색은 [CalcPalette.cursorPadGroove].
  static const double cursorPadDividerWidth = 2.0;

  /// 커서 패드 X자 홈을 그리는 두께 (패드 높이 대비, #156) — 실물 홈은 패드 높이의 약 9%인 어두운 틈이다(#65). 터치 경계는
  /// 선 그대로이고(틈 없이 맞닿는다) 그림만 넓힌다. 9%로 그리면 ▲·▼ 키의 화살표 자리가 좁아져 약 6%로 둔다. 이 두께가
  /// [cursorPadDividerWidth]보다 가늘면 그 두께로 그린다.
  static const double cursorPadGrooveWidthRatio = 0.06;

  /// 커서 패드 홈·외곽선·허브 둘레 색 (#156) — 은색 방향 키 사이의 어두운 틈. 은색 키캡([keyCursor])과 10:1 이상이라
  /// 방향 키 경계가 또렷하다. #156 전에는 키캡 테두리 색([keyBorder])이었다 — 회색 키캡 사이에서는 밝은 선이 경계였지만,
  /// 은색 키 사이에서는 실물처럼 어두운 틈이 더 또렷하다. 고대비는 [cursorPadGrooveHighContrast].
  static const Color cursorPadGroove = Color(0xFF08090A);

  /// 고대비 커서 패드 홈 색 — 검정 (은색 키캡과 11:1)
  static const Color cursorPadGrooveHighContrast = Color(0xFF000000);

  // 커서 패드 모양 (#43) — 실물 fx-991EX처럼 가로로 긴 둥근 마름모를 X자 홈으로 4분할하고,
  // 가운데에 누를 수 없는 검은 허브를 둔다. 치수는 패드 크기 비례이고,
  // 패드 상자의 가로/세로 비는 [cursorPadMinAspectRatio]~[cursorPadMaxAspectRatio]로 제한해
  // 폰·폴더블·태블릿 어디서나 "가로로 긴" 모양을 유지한다(셀이 범위를 벗어나면 가운데에 줄여 놓는다).
  //
  // 실측 (#65): Wikimedia Commons의 fx-991EX 정면 사진 두 장(서로 다른 기기·촬영자)에서 네 방향 키 윗면이 이루는
  // 외곽에 모델을 겹쳐 맞췄다. 두 사진의 값이 서로 맞았다. 사진 픽셀 기준 정밀도는 대략 ±2px(패드 높이의 약 1~2%)이다.
  // - "File:Fx-991EX.jpg"(932×1920, 정면 오려낸 사진): 패드 268×172px
  // - "File:Casio fx-991EX Scientific Calculator.jpg"(3120×4160): 패드 534×349px
  // 실물에서 키 사이 홈은 폭이 패드 높이의 약 9%인 어두운 틈이고, 허브는 별도 부품이 아니라 그 틈과 같은 어두운 바닥이다.
  // 터치 경계는 틈 없이 맞닿는 선이고, 그림만 패드 높이의 [cursorPadGrooveWidthRatio] 두께로 넓혀 그린다(#156).

  /// 커서 패드 상자 최소 가로/세로 비 — 세로로 긴 셀(일반 폰 약 1.3)에서도 납작한 마름모를 유지한다.
  static const double cursorPadMinAspectRatio = 1.4;

  /// 커서 패드 상자 최대 가로/세로 비 — 가로로 긴 셀에서 지나치게 납작해지지 않게 한다. #141 전에는 셀이 약 2.2까지였다.
  /// 폭 상한을 풀고 가로형(#142)을 넣은 뒤 실제 창의 셀 비(측정)는 다음과 같다.
  /// - 폰, 보통 가로형: 1.3~1.6
  /// - 태블릿·폴더블 내부 세로: 1.85~2.0. 예: 600×800 1.85, 768×1024 1.92, 673×841 1.98
  /// - 2.0~2.2: 1280×400 가로형 2.12, 700×800 2.17, 800×900 2.20
  /// - 정사각형에 가까운 창(위아래 배치): 2.3~2.65, 인셋이 있으면 더 크다. 예: 412×450 2.32, 768×768 2.49, 400×400 2.65
  /// - 낮고 넓은 데스크톱 창(가로형): 2000×400 3.3, 2000×300 5.5
  /// 셀 비가 이 값을 넘으면 패드는 이 비율에서 멈추고, 남는 폭은 ◀·▶ 터치 영역이 받는다.
  ///
  /// 넓은 셀에서도 이 상한을 유지한다(#159, 사용자 결정). 터치 경계도 그대로 둔다.
  /// - 손가락이 들어가는 크기(▲·▼ 터치 영역의 내접원)는 셀 높이가 정한다. 함수 키 터치 높이와 견준 값은 다음과 같다.
  ///   넓은 셀은 0.98배 안팎이고, 보통 셀은 0.956~0.98배다. 큰 키(함수 키가 각인 띠까지 넓히지 않는 키캡 48dp 이상)는 1.33~1.36배다.
  ///   그래서 넓은 셀의 ▲·▼가 보통 셀보다 누르기 어려워지지 않는다. ▲·▼ 터치 넓이도 #141 전 폭보다 줄지 않는다.
  /// - 함수 키는 옆으로만 넓어진다. 그래서 함수 키 셀과 견준 ▲·▼ 넓이 비율만 보통 셀(1.05~1.11배)보다 낮다.
  ///   이 비율은 셀 비가 커질수록 계속 내려가며 바닥이 없다.
  ///   측정: 600×610 창 0.88배, 768×768 창 0.87배, 2000×400 창 0.76배, 2000×300 창 0.62배, 키패드 1600×300 0.54배.
  /// - 상한을 2.5로 올리면 600×610·768×768의 비율은 1.06배(2000×400은 0.90배)로 돌아온다. 하지만 내접원은 거의 그대로다
  ///   (600×610 34.0 → 34.4dp). 대신 패드가 실측 1.53보다 훨씬 납작해진다. 그래서 올리지 않는다.
  /// - 테스트에 고정한 기준(`test/support/touch_metrics.dart`)은 다음과 같다.
  ///   - 내접원: ▲·▼는 함수 키 터치 높이 × 0.95 이상, ◀·▶는 × 1.0 이상. 보통 셀과 넓은 셀에 같은 기준이다.
  ///   - ▲·▼ 넓이 비율: 넓은 셀이 생기는 크기마다 지금 값보다 약 0.02 아래를 하한으로 둔다.
  /// 실측(#65)은 약 1.53이다. 큰 사진(534×349px)에서 1.53이 나왔다. 오려낸 사진(268×172px)은 보정 전 1.56이고,
  /// 본체 가로세로비가 실물(77×165.5mm)보다 약 4% 가로로 늘어나 있어 보정하면 약 1.50이다.
  /// 범위 안이면 셀을 그대로 써서 터치 넓이를 잃지 않는다.
  static const double cursorPadMaxAspectRatio = 1.8;

  /// 커서 패드 외곽 지수 p — 패드 반폭·반높이로 정규화한 좌표 (u, v)에서 |u+v|ᵖ + |u−v|ᵖ = 2
  /// (45° 돌린 Lamé 곡선). 2이면 타원, 클수록 마름모에 가까워진다. 2보다 크면 꼭짓점 곡률이 유한해
  /// 꼭짓점이 둥글다(|u|ⁿ + |v|ⁿ 초타원은 1 < n < 2에서 꼭짓점이 뾰족해진다).
  /// 실측(#65): 두 사진의 외곽(▲ 윗변 호, ◀·▶ 끝의 뭉툭한 꼭짓점)이 p = 3 곡선과 2px 이내로 겹친다.
  static const double cursorPadOutlineExponent = 3.0;

  /// 커서 패드 X자 홈의 기울기 k — 정규화 좌표에서 |u| ≤ k·|v|이면 ▲·▼, 아니면 ◀·▶ 구역이다.
  /// 1이면 홈이 패드 상자의 대각선이다. 1보다 작으면 홈이 대각선보다 가파르다. 그러면 ▲·▼는 위·아래 호를 따라
  /// 휜 띠, ◀·▶는 옆으로 뭉툭한 넓은 구역이 된다.
  /// 실측(#65) k ≈ 0.9: 홈이 외곽과 만나는 점이 두 사진 모두 정규화 좌표 (±0.57, ±0.64) 부근이다.
  /// ▲ 윗면 폭은 패드 폭의 약 47%, ◀ 바깥 높이는 패드 높이의 약 57%이다.
  /// 실물 홈은 중심을 지나지 않고 허브 가장자리 쪽으로 조금 가파르게 꺾인다. 직선 모델은 외곽 쪽 끝을 맞췄다.
  /// 그려지는 홈은 허브 가장자리에서 시작하므로 차이는 허브 근처의 몇 dp뿐이다.
  /// (가운데 원은 화면 좌표의 원이라 가로로 긴 패드에서는 ▲·▼ 쪽을 더 깎는다 — 넓이 비는 k만으로 정해지지 않는다.)
  static const double cursorPadGrooveSlope = 0.9;

  /// 커서 패드 가운데 허브(검은 원) 반지름 — 패드 반높이·반폭 중 짧은 쪽 대비.
  /// 실측(#65) 약 0.5: ▲·▼ 키 안쪽 끝(가운데로 오목한 V자)이 두 사진 모두 중심에서 반높이의 약 50~51%에 있다.
  /// 그래서 허브 지름이 패드 높이의 약 1/2이다. 실물의 어두운 가운데는 가로로 조금 더 넓다.
  /// ◀·▶ 안쪽 끝이 반폭의 약 44%, 즉 반높이의 약 67%다. 그 차이는 홈이 메워 원 하나로 근사한다.
  static const double cursorPadHubRadiusRatio = 0.5;

  /// 커서 패드 데드존(누를 수 없는 가운데 원) 반지름 — 패드 반높이·반폭 중 짧은 쪽 대비.
  /// 허브보다 작게 두어, 방향이 가장 모호한 한가운데만 무시하고 허브 바깥 고리는 방향 키에 준다.
  /// 허브를 실측대로 키운 뒤(#65)에도 그대로 둔다. 키울 여유가 거의 없다(320×568·상태바 20dp, ▲ 터치 내접원 측정).
  /// - 0.1~0.12: 29.8dp로 같다. 이 범위에서는 홈 사이 쐐기와 셀 변이 내접원을 정한다.
  /// - 0.2: 27.2dp로 터치 하한 28dp 아래다.
  /// - 0.3: 25.0dp, 그려진 허브 전체(0.5): 21.0dp. 둘 다 ▲·▼ 하한(28dp의 95%) 아래다.
  /// 그래서 그려진 허브의 약 96%는 누르면 입력된다. 허브 안에는 홈 선이 없어, 대각선 가까이를 누르면
  /// 보이지 않는 홈 연장선(k)에 따라 방향이 갈린다.
  static const double cursorPadDeadZoneRadiusRatio = 0.1;

  /// 커서 패드 허브 색 — 실물의 어두운 가운데(홈 바닥과 같은 색). 방향 키캡([keyCursor])보다 어둡고(10:1 이상),
  /// 둘레는 홈 색([CalcPalette.cursorPadGroove])으로 긋는다. 사진(#65)에서도 가운데는 주변 본체보다 어둡고 홈과 같은 밝기였다.
  /// 색 값은 사진 노출에 따라 달라 실측하지 않는다.
  static const Color cursorPadHub = Color(0xFF0E0F11);

  // ───────────────────────────────────────────
  // 화면 배치 (Screen Layout) — 세로형(세로 폰·태블릿 세로)의 LCD : 키패드 기준 (#23, #141)
  // ───────────────────────────────────────────
  // 광고 없는 배치가 기준이다 (#141, 사용자 결정 — 과금 사용자가 가장 쾌적해야 한다). 화면 맨 아래 광고 슬롯은 없고,
  // 무과금 사용자의 광고는 이 배치에서 LCD 쪽 한 영역을 줄여 넣는다(화면 맨 위·기록 영역, #18).
  // - 본체: 시스템 인셋(SafeArea) 안에서 화면 가장자리 여백([screenPadding])을 위·왼쪽·오른쪽에서, 아래 여백
  //   ([screenBottomMargin] — 보통 같은 값, #63)을 아래에서 뺀 영역이다.
  //   본체를 LCD와 키패드가 나눈다. LCD는 본체 윗변부터다 — LCD 위 상단 띠(장식·설정 버튼, #41)는 #190에서 없앴다
  //   (사용자 결정). 설정은 키패드의 ON 키로 연다(`settingsKey`).
  // - 폭: LCD와 키패드 모두 본체 폭 전체다 (#141). 예전에는 둘 다 480dp에서 멈춰(#24·#92) 태블릿 세로에서 가운데에
  //   놓이고 양옆이 비었다. 키가 가로로 넓어지는 것은 받아들이고 각인 글자 크기에만 상한을 둔다
  //   ([keyMainLabelMaxFontSize], 사용자 결정).
  // - LCD: 본체 높이의 [screenLcdHeightRatio]를 목표로 하되
  //   [screenLcdMinHeight] ~ 최대 높이 범위로 제한한다. 최대 높이는 (LCD 폭 / [screenLcdMinAspectRatio])와 줄 글자 상한
  //   높이(`LcdFontSizes.heightAtMaxLineFont` 약 273.5dp — [lcdLineMaxFontSize], #189) 중 낮은 쪽이다. 어느 쪽이든 그보다
  //   높여도 글자는 커지지 않고 줄 사이만 벌어진다. 폭 478.7dp 이상의 LCD가 상한 높이에 걸린다(폰은 걸리지 않는다).
  // - 키패드: 나머지 높이. 단 키패드 가로/세로 비 하한([keypadMinAspectRatio] — 키가 세로로 길어지지 않게) 때문에
  //   키패드가 다 쓰지 못하는 높이는 LCD가 모두 받는다 — 폭 기준 최대 높이와 줄 글자 상한 높이를 넘을 수 있다(세로로 긴 폰은
  //   줄 글자가 폭에 묶여 줄 사이만 넓어진다 — "LCD 내부 구성" 절). LCD는 본체 윗변부터 키패드 바로 위까지이고, 키패드는 항상
  //   본체 아래에 붙어 엄지가 닿기 쉽다. **LCD 위에 본체만 보이는 빈 곳은 없다**(#232, 2026-11-27 사용자 결정 — 쓸모없는 자리다).
  //   무과금 광고(#18)와의 경계: LCD가 목표 최대 높이([_lcdMaxHeightOf] 몫 — 폭 / [screenLcdMinAspectRatio]와 줄 글자 상한 높이
  //   중 낮은 쪽)를 넘어 받은 높이는 빈 곳 대신 LCD에 준 여분이다(390×844 인셋 0: LCD 321.3 중 약 107dp). 화면 맨 위 배너가 이
  //   여분을 먼저 가져가면 줄 글자가 줄지 않는다(폭에 묶인 글자) — "활성 LCD는 줄이지 않는다"(CLAUDE.md 1절)를 이 여분에도
  //   적용할지는 #18에서 정한다(#232 R1, #18 코멘트).
  //   (#232 전에는 LCD가 줄 글자 상한 높이까지만 받고 그 위가 빈 곳으로 남았다 — "계산 기록 #145의 자리"로 적었지만 기록은 LCD
  //   안·기록 영역에 두고, 무과금 광고(#18)는 LCD 쪽 영역을 줄여 넣는다(CLAUDE.md 1절). #190 전에는 LCD 위 상단 띠가 최소
  //   12dp와 LCD 최대 높이를 넘는 몫을 받았다.)
  // - 큰 세로 창: 폭 상한이 없으니 키패드 최대 높이(폭 / [keypadMinAspectRatio])가 태블릿 세로 본체보다 높아 남는 높이가 생기지
  //   않는다 — LCD는 목표 비율(상한 높이까지), 키패드는 나머지 전부다. 태블릿 세로는 LCD 목표 높이가 상한 높이보다 높아 LCD가
  //   상한 높이에서 멈추고 남는 높이를 키패드가 받는다(#189 — 줄 글자는 상한 40dp, 키가 커진다).
  //   실측(인셋 위/아래, 본체 → LCD·키패드 높이, 가장 낮은 키 셀, LCD 줄 글자. #190 뒤):
  //   · 10인치 Android 800×1280(24/48, 본체 784×1192): LCD 784×273.5·키패드 784×910.5, 셀 77.4dp, 줄 글자 40.0dp
  //     (#141 전: LCD 480×274·키패드 480×640 가운데, 띠 약 208dp / #189 뒤·#190 전: 띠 40·LCD 273.5·키패드 870.5)
  //   · 12.9인치 iPad 1024×1366(24/20, 본체 1008×1306): LCD 273.5·키패드 1024.5, 셀 87.1dp, 줄 글자 40.0dp
  //   · iPad 768×1024(24/20, 본체 752×964): LCD 269.9·키패드 686.1, 셀 58.3dp, 줄 글자 39.4dp(상한에 닿지 않는다)
  //   · 정사각형 창 768×768(본체 752×752): LCD 210.6·키패드 533.4, 셀 45.3dp
  //   태블릿 세로의 키는 폭 약 116~190dp(함수부~숫자부)까지 넓어지고, 메인 라벨·각인 글자는 상한(16.5·11dp)에서 멈춘다.
  //   폰은 대부분 키패드가 폭 기준 최대 높이에 닿고 나머지는 LCD가 받는다(괄호는 #190 전 — 상단 띠 최소 12dp가 있었다):
  //   · 320×568 상태바 20(iPhone SE 1세대): 셀 31.9dp(31.1), LCD 149.0dp·줄 글자 20.2dp(19.7). 인셋 0: 셀 33.1dp.
  //     360×640(24/48)도 본체 높이가 같아 33.1dp다.
  //   · 390×844(47/34): LCD 240.3dp(띠 26.6·LCD 214)·줄 글자 29.8dp·셀 42.4dp 그대로(이미 폭 기준 최대 높이)
  //   · 360×800(24/48): 셀 39.0dp 그대로, LCD 245.3dp(띠 48.8·LCD 197)
  //   · 412×915(24/48): 셀 44.9dp, LCD 291.0dp(#232 전 273.5·위 빈 곳 17.5 / #190 전 띠 64.7·LCD 226). 440×956(62/34): 셀 48.1dp,
  //     LCD 270.7dp
  // LCD 위 빈 곳을 없앤 배치(#232 — 측정: 배치 계산(`CalcScreenLayout`·`CalcLandscapeLayout`·`CalcHingeSplitLayout`·
  // `CalcTabletopLayout`)을 창·인셋으로 잰 값. 빈 곳 → LCD 높이 변화. 키 셀은 모든 경우 그대로다. 줄 글자는 글자 배율 1에서 모든
  // 경우 그대로다 — 큰 배율(1.3)에서는 상태 표시줄이 커져 높이가 줄 글자를 묶던 LCD가 높아지며 그 제약이 풀려, 줄 글자가 최대
  // 약 2.8% 커진다(상한 이하, 예: 세로형 본체 490×950 38.9 → 40.0dp, #232 R1):
  //   · 세로형, 키패드가 폭 기준 세로 한계에 닿고 남는 높이가 상한 높이(273.5)를 넘는 창: 390×844 인셋 0 위 47.8 → LCD 321.3,
  //     412×915(24/48) 17.5 → 291.0, 412×915(24/24) 41.5 → 315.0, 411×960(24/24) 87.8 → 361.3, 세로 창 2160×3800 643.8 → 917.3.
  //     iPhone 390×844(47/34, LCD 240.3)·360×800·440×956·태블릿 세로(키패드가 남는 높이를 받는다)는 원래 빈 곳이 없다.
  //   · 가로형, 기록 영역 있음(활성 LCD 위 → 위 띠 전체): 10인치 1280×800 21.4 → 294.9, iPad 1024×768 100.3 → 373.8, 데스크톱
  //     1000×800 184.6 → 457.6, 12.9인치 iPad 245.6 → 519.1, 데스크톱 2000×1400 460.4 → 733.9. 위 띠가 상한 높이보다 낮은
  //     창(1280×600 등)은 원래 빈 곳이 없다.
  //   · 가로형, 기록 영역 없음: 본체 729×678 160.6 → 활성 LCD 729×434.1. 가로 폰(위 띠 112dp)은 원래 빈 곳이 없다.
  //   · 책 자세 손 쪽 패널(세로형과 같다): Galaxy Z Fold 내부 673×841(32/24) 60.1 → LCD 320.5×333.7. Pixel Fold 841×701·두 화면
  //     기기는 원래 빈 곳이 없다.
  //   · 짧은 손 쪽 패널의 책 자세, 반대쪽 패널에 기록 없음(LCD 아래 빈 곳): 841×340(24) 26.5 → LCD 404.5×300.
  //   · 가로 접힘선·넓은 배열(활성 LCD 위 → 위 패널 전체): Fold 가로 841×673 67.7 → 400.5×296.5, 화면 크기를 키운 Fold
  //     673×539 47.3 → 318.9×229.5, 세로로 돌린 Pixel Fold 701×841(기록 없음) 99.0 → 685×372.5.
  //   · 가로 접힘선·실물 배열, 기록 없음(LCD 아래 빈 곳): Fold 분할 창 420×673 23.0 → LCD 404×296.5. Flip 내부(기록 있음)는
  //     그대로다.
  // 짧은 창(분할 화면 등)에서도 LCD는 최소 높이 아래로 줄이지 않는다 — 대신 가로형으로 바꾼다(아래 "가로형 배치", #142).
  // 가로로 넓은 창의 배치는 아래 "가로형 배치"(#142), 폴더블 접힘선 기준 배치는 "접힘선 기준 배치"(#25, #143) — 책 자세의 손 쪽
  // 패널도 이 세로형이다.

  /// 화면 가장자리 여백 (dp)
  static const double screenPadding = 8.0;

  /// 본체 아래 여백 (dp) — 본체 아래를 가리는 것(시스템 인셋·키보드) 위에 두는 여백 (#63).
  ///
  /// [bottomInset]은 본체 아래를 실제로 가리는 높이다 — `max(MediaQuery.viewPadding.bottom, MediaQuery.viewInsets.bottom)`.
  /// 키보드가 없으면 아래 시스템 인셋이다. `padding.bottom`은 키보드가 뜨면 0이 되지만 그때 본체는 Scaffold가 키보드 위로
  /// 줄이므로, 그 값을 쓰면 키보드가 떠 있는 동안 여백만 커진다(이 앱은 키보드를 띄우지 않지만 규칙의 뜻을 맞춘다).
  ///
  /// 보통은 [screenPadding]이다. 아래 시스템 제스처 영역([bottomGestureInset], `MediaQuery.systemGestureInsets.bottom`,
  /// Android 홈 제스처)이 [bottomInset]보다 [screenPadding] 넘게 깊으면, 그 초과분만큼 넓혀 본체가 영역에 닿지 않게 한다.
  /// - 이유: 맨 아래 광고 슬롯이 없어져(#141) 키패드 맨 아래 행이 본체 아래 끝까지 내려온다. 그 행이 제스처 영역에 걸리면
  ///   `CalcKeyButton`이 그 영역에서 시작한 터치를 손을 뗄 때 확정해(#50) 맨 아래 행만 누름 감각이 달라진다.
  ///   아래 영역을 보류 대상에서 빼면, 키 위에서 시작한 홈 스와이프가 키를 먼저 입력해 버린다.
  /// - 좌우 뒤로가기 영역은 이렇게 피하지 않는다 — 폭(감도 기본값 30dp, 가장 높으면 49.5dp — #118 실측)만큼 여백을 두면
  ///   모든 폰에서 키패드가 좁아진다
  ///   (`CalculatorScreen` 문서). 아래는 차이가 작고(아래 실측) 대부분 0이다.
  /// - 실측(Android 에뮬레이터, dp — 인셋 / 제스처 영역 → 넓히는 양. #63은 Debug 빌드, #118은 Release 진단 빌드):
  ///   · API 36 폰 411×914, 제스처 내비게이션(edge-to-edge 강제): 24 / 32 → 0 (본체 아래 끝 = 제스처 영역 윗변)
  ///   · 같은 폰, 3버튼: 48 / 48 → 0
  ///   · API 36 Pixel Fold 내부 841×701(임시 작업 표시줄): 32 / 32 → 0, 상시 작업 표시줄: 56 / 56 → 0 (#118)
  ///   · API 36 Pixel Fold 커버 411×797, 제스처 내비게이션: 24 / 32 → 0 (#118)
  ///   · API 36 Pixel Tablet 1280×800·800×1280, 제스처 내비게이션 임시 작업 표시줄: 32 / 32 → 0, 상시 작업 표시줄(1280×800): 56 / 56 → 0 (#118)
  ///   · API 33 폰, 제스처 내비게이션(edge-to-edge 아님 — 창이 내비게이션 바 위에서 끝난다): 0 / 8 → 0
  ///   맨 아래 행 키캡 아래 끝은 본체 아래 끝보다 키패드 셀 안 세로 간격의 절반(키패드 높이의 0.75%)만큼 위다 —
  ///   위 폰들에서 약 5dp이고, 키패드가 낮은 배치(테이블톱 아래 절반, 짧은 창)에서는 2~3dp로 줄어든다. 그래서 위 폰들의
  ///   제스처 영역까지의 여유는 제스처 내비게이션(24/32, 0/8)에서 약 5dp, 3버튼·작업 표시줄(제스처 영역이 시스템 바 안)에서
  ///   약 13dp다. 제스처 영역이 인셋보다 [screenPadding] 넘게 깊은 기기에서만 넓어진다. 그런 구성은 에뮬레이터에서
  ///   안정된 상태로 만들 수 없어 **실측하지 못했다**(내비게이션 힌트를 숨긴 제스처 내비게이션 등으로 추정 — 실기기 확인은 #177).
  /// - 넓어지면 본체가 그만큼 낮아져 짧은 창 판정(#38, 아래 "짧은 창")에도 그 높이로 들어간다. 상한은 두지 않는다 —
  ///   넓어지는 구성은 실측하지 못해 그 양을 모르지만, 상한을 두면 맨 아래 행이 다시 제스처 영역에 걸린다.
  ///   상한이 필요한지는 #177 실기기 실측 뒤에 다시 판단한다.
  /// - 배치 종류와 무관하게 화면 전체 본체에 적용한다 — 키패드가 맨 아래에 오는 모든 배치(위아래·가로형·접힘선·
  ///   가로형 #142·접힘선 기준 배치 #143)가 같은 본체 안에 있다.
  static double screenBottomMargin({
    required double bottomInset,
    required double bottomGestureInset,
  }) => math.max(screenPadding, bottomGestureInset - bottomInset);

  /// 위 시스템 제스처 영역이 본체 윗변 아래로 들어오는 깊이 (dp, #172) — 0이면 본체가 영역 밖이다.
  ///
  /// [topInset]은 본체 위를 가리는 시스템 인셋(`MediaQuery.padding.top`, SafeArea가 빼는 값), [topGestureInset]은 위 시스템
  /// 제스처 영역(`MediaQuery.systemGestureInsets.top` — Android 알림창 끌어내리기)이다. 본체는 인셋 아래 [screenPadding]부터라,
  /// 영역이 인셋보다 [screenPadding] 넘게 깊을 때만 0보다 크다.
  /// - 쓰는 곳: 키패드가 본체 윗변 가까이 올 수 있는 배치의 키패드 윗변 하한이다 — 지금은 손 쪽 패널이 짧은 책 자세
  ///   (`CalcHingeSplitLayout.shortHandPanel`)뿐이다. 그 밖의 배치는 본체 위에 활성 LCD(최소 [screenLcdMinHeight])나 위 띠·위
  ///   패널이 있어 키패드 윗변이 본체 윗변에서 120dp(활성 LCD 최소 높이 + 간격) 이상 떨어진다 — 실측한 가장 깊은 차이(12.2dp)의
  ///   깊이 4.2dp보다 훨씬 아래다. 깊이가 120dp 이상인 기기는 없다고 본다(그런 기기는 세로형으로 돌아간 책 자세의 첫 행도 영역에
  ///   든다).
  /// - 이유: 그 영역에서 시작한 터치는 `CalcKeyButton`이 손을 뗄 때 확정한다(#50). 첫 행(SHIFT·ALPHA·커서 패드·MENU·ON)
  ///   위쪽이 영역에 들면 그 부분만 누름 감각이 달라지고, 각인 띠까지 넓힌 터치 영역(키캡 48dp 미만)도 그렇다.
  /// - 본체 위 여백을 넓히지 않는 이유(아래 여백 [screenBottomMargin]과 다르다): 대부분의 배치는 본체 윗변에 키가 아니라 활성
  ///   LCD나 계산 기록 영역(지금은 누르지 않는 영역 — 기록을 누르게 되면 #145에서 다시 본다)이 온다. 여백을 넓히면 키패드가
  ///   위에 없는 커버 화면(Pixel Fold 커버 41.9 / 54.1 → 4.2dp)에서도 본체가 낮아지고, 본체 원점·접힘선 좌표 변환
  ///   (`CalculatorScreen`)도 함께 바뀌어야 한다. 키패드만 물리면 비용은 그 배치의 키 높이(깊이만큼 낮아진 키패드)다. 깊이만큼
  ///   비우면 키가 쓸 수 있는 크기([keyTouchHeightUsableMin])보다 작아지는 창은 그 크기를 지키는 만큼만 비운다(#172 R1) — 쓸 수
  ///   있는 크기 경계(안내 화면이 뜨는 창)가 깊이와 무관하다. 그런 창에서는 첫 행 위쪽이 영역에 남아 손을 뗄 때 입력된다(#50).
  /// - 실측(Android 에뮬레이터 Release 진단 빌드, dp — 인셋 / 위 제스처 영역 → 깊이):
  ///   · API 36 Pixel Tablet 가로·세로, Pixel Fold 내부(책 자세): 24 / 24, 28.2 / 28.2 → 0 (#118)
  ///   · API 36 Pixel Fold 커버(카메라 구멍, 위아래 배치): 41.9 / 54.1 → 4.2 (#118)
  ///   · API 33 폰(edge-to-edge 아님): 48.8 / 61.0 → 4.2 (#63)
  ///   · API 36 Pixel Fold, 접힘선을 흉내 낸 짧은 창 640×360(`wm size`·`display_features`, 접힘선 x=320 — 손 쪽 패널이 짧은
  ///     책 자세): 28.19 / 28.19 → 0. 키패드 윗변 화면 y 36.19 = 영역 아랫변 + 화면 여백 8 (#172)
  ///   · API 33 폰 640×336 창(같은 흉내): 24 / 31.24 → 0. 이 이미지는 흉내 낸 접힘선을 앱에 알리지 않아(창 배치 정보 없음)
  ///     API 33의 접힘선 기준 배치는 잴 수 없었다 (#172)
  ///   깊은 위 영역(인셋 + 12.2)은 실측한 두 경우 모두 상태 표시줄의 카메라 구멍과 함께 나왔고, 위아래 배치(키패드가 위에 없음)
  ///   였다. 접힘선 기준 배치에서 깊이가 0보다 큰 구성은 에뮬레이터에서 만들지 못했다 — 위 규칙은 그런 기기(위쪽 카메라 구멍이
  ///   있는 폴더블 내부 화면 등)를 위한 대비다. 실기기(제조사 태블릿·폴더블)는 #177에서 잰다.
  static double screenTopGestureDepth({
    required double topInset,
    required double topGestureInset,
  }) {
    final depth = topGestureInset - topInset - screenPadding;
    // 비유한 값(NaN 등)은 0으로 본다 — `math.max(0, NaN)`은 NaN이다.
    return depth.isFinite ? math.max(0.0, depth) : 0.0;
  }

  /// LCD와 키패드 사이 간격 (dp)
  static const double screenLcdKeypadGap = 8.0;

  /// LCD 목표 높이 (본체 높이 대비). 실물 fx-991EX 앞면의 LCD 창 : 키 영역 높이(대략 1 : 3, 정밀
  /// 실측값 아님)보다 조금 크게 잡았다 — 앱 LCD는 입력·결과 줄이 각각 분수를 담는 4행 구성이고,
  /// 16:9 소형 폰(320×568)에서도 줄 글자 약 20dp를 확보한다. 그보다 크게 잡으면 소형 폰 키 각인 글자가
  /// 키 크기 하한(calculator_screen_test) 아래로 내려간다. 세로로 긴 폰에서는 LCD 최대 높이에 먼저 걸린다.
  static const double screenLcdHeightRatio = 0.28;

  /// LCD 최소 높이 (dp). 이 높이에서도 상태 표시줄 + 입력 2행 + 결과 2행이 줄 글자 약 14dp로 들어간다.
  static const double screenLcdMinHeight = 112.0;

  /// LCD 최소 가로/세로 비 — LCD 최대 높이는 LCD 폭 / 이 값이다.
  /// 폰 폭(304~424dp)에서 폭 기준([lcdLineColumns])으로 정해진 줄 글자로 내부 구성 전체(상태 표시줄 +
  /// 4행 + 분수 막대)를 담는 높이다. 이보다 높여도 글자는 커지지 않고 빈 줄 여백만 늘어난다.
  static const double screenLcdMinAspectRatio = 1.75;

  // ── 가로형 배치 (#142, 사용자 결정) ──
  // 접힘선 없는 가로로 넓은 창(태블릿 가로, 가로로 돌린 폰, 분할 화면·데스크톱의 가로 창)은 "가로형"으로 그린다
  // (`CalcLandscapeLayout`). 예전 좌우 분할(#24 — LCD 옆에 실물 배열 키패드)을 대체했다.
  // - 아래: 넓은 키패드 배열(`KeypadArrangement.wide` — 함수부 옆에 숫자부). 본체 폭 전체를 쓰고, 행이 5개라 낮은 창에서도
  //   10행인 실물 배열보다 키가 크다. 숫자부는 주로 쓰는 손 쪽이다(왼손잡이면 좌우 대칭).
  // - 위 띠: 키패드 블록에 맞춰 둘로 나눈다. 숫자부 위가 활성 LCD, 함수부 위가 계산 기록 영역(M1에서는 비어 있다, 내용은
  //   #145). LCD 하나를 전체 폭으로 늘이면 식은 왼쪽 끝, 답은 오른쪽 끝으로 멀어진다.
  // - 높이 나누기는 세로형("화면 배치" 절)과 같은 규칙을 위 띠 폭 전체(본체 폭)로 쓴다. 위 띠는 본체 윗변부터이고, 키패드가
  //   넓은 배열의 세로 한계에 닿아 남는 높이는 모두 위 띠가 받는다(#190 — 상단 띠가 없다). 위 띠 높이는 기록 영역 유무와 무관하다 — 기록 영역이 생기고 없어지는 경계에서
  //   높이가 튀지 않는다(#142 R1: 블록 폭으로 위 띠 최대 높이를 정했을 때는 본체 폭 461 → 461.5dp(창 477 → 477.5dp)에서 활성
  //   LCD가 228.8 → 128dp로 줄고 빈 띠가 약 100dp 생겼다).
  // - 활성 LCD와 기록 영역은 둘 다 위 띠 높이 전체다(#232 — 활성 LCD 위에 빈 곳이 없다). 활성 LCD가 그 폭의 최대 높이(폭 /
  //   [screenLcdMinAspectRatio](#142 R2)와 줄 글자 상한 높이 `LcdFontSizes.heightAtMaxLineFont` 약 273.5dp — [lcdLineMaxFontSize],
  //   #189 중 낮은 쪽)보다 높으면 글자는 커지지 않고 식과 답 사이만 벌어진다("LCD 내부 구성" 절). #232 전에는 활성 LCD를 그 최대
  //   높이까지만 위 띠 아래쪽에 두어 그 위가 비었다(12.9인치 iPad 가로 약 245.6dp, 기록 영역이 없는 본체 729×678 160.6dp).
  //   기록 영역이 없으면 활성 LCD는 띠 폭 전체다.
  // - 기록 영역은 위 띠가 [screenLandscapeHistoryMinHeight] 이상이고, 블록이 [screenLandscapeHistoryMinLcdWidth] 이상이고, 블록
  //   폭 활성 LCD의 줄 글자가 띠 폭 전체 LCD의 [screenLandscapeHistoryMinLcdFontRatio]배 이상일 때만 둔다. 없으면 활성 LCD가
  //   띠 폭 전체를 쓴다. 기록 영역이 생기고 없어지는 경계에서 활성 LCD 줄 글자는 30%보다 많이 줄지 않는다(landscape_layout_test가
  //   폭·높이 0.5dp 간격으로 고정). 기록 영역이 없는 가로형의 무과금 광고 자리는 #18에서 정한다.
  // - 스크린리더 읽기 순서: 활성 LCD → 기록 → 키패드(함수부 → 숫자부). 설정 키(ON)는 함수부 구역(상단 조작부)에 있다.
  //   화면 위치와 무관하다.
  //
  // 접힘선 없는 창은 세로형과 가로형 중 키가 큰 쪽으로 그린다(`CalculatorScreen`, `FormFactor.picksFormByKeySize`).
  // 키 크기는 가장 낮은 키의 셀 높이(`KeypadMetrics.minKeyCellHeightOf` — 각인 띠 + 키캡)로 비교하고, 같으면 키가 더
  // 넓은 세로형이다. 터치 높이(`minKeyTouchHeightOf`)는 키캡이 48dp를 넘으면 각인 띠를 빼며 줄어 큰 화면에서
  // 비교가 뒤집힌다(#220 뒤 창 920×1100, 인셋 없음: 세로형 셀 68.2·터치 49.1dp, 가로형 셀·터치 49.7dp).
  // 두 셀 높이가 창 크기에 따라 연속으로 변하므로, 배치가 바뀌는 경계에서 키가 튀지 않는다(short_window_test가 높이 1000dp·
  // 폭 1400dp까지 고정 — 예전 좌우 분할은 짧은 변 600dp에서 비교를 멈춰 폭 601dp 창의 키가 6% 줄었다).
  // LCD는 이 경계에서 바뀐다: 폭에 묶인 넓은 배열이 남긴 높이를 가로형은 위 띠가 받고 세로형은 키패드가 받으므로, 세로형으로
  // 넘어가면 LCD가 최소 높이로 돌아간다(본체 400×390 → 392: 400×212.6 → 400×112, 줄 글자 30.3 → 14.3dp). 키 크기를 우선하는
  // 비교(사용자 결정 "키가 큰 쪽")의 결과이고, 가로형의 남는 높이를 빈 띠로 두면(경계는 매끄러워지지만) 짧은 창의 LCD가 늘 최소
  // 높이가 된다 — 키·위 띠 연속성을 지키고 LCD 크기의 바뀜은 받아들인다(#142 R2). 세로형 자체는 폭에 대해 단조다 — #189
  // 전에는 키패드가 실물 크기(640dp)를 넘는 세로 창에서 폭이 늘면 LCD가 폭 기준 최대 높이까지 자라는 몫을 키패드가 내줘 키
  // 셀이 약 1.2% 줄었다(#188). 지금은 LCD가 그 전에 줄 글자 상한 높이에서 멈춘다("화면 배치" 절).
  // 실측 (창, 인셋 위/아래 — 가장 낮은 키 셀 높이 세로형 → 가로형, 그린 배치, 활성 LCD, LCD 줄 글자. 위 띠는 #190 상단 띠 제거 뒤):
  //   · 10인치 Android 1280×800(24/48, 본체 1264×712): 셀 → 69.5dp, 가로형(키 터치 50.1dp). 위 띠 294.9·기록 614×294.9, 활성
  //     LCD 613.6×294.9(줄 글자 상한 40dp, #232 전 높이 273.5), 키패드 1264×409.1(세로 한계)
  //   · 12.9인치 iPad 1366×1024(24/20): 셀 → 74.3dp, 가로형. 키패드 1350×436.9(세로 한계), 위 띠 519.1(기록 영역),
  //     활성 LCD 655.3×519.1(줄 글자 40dp — 띠 폭 전체여도 상한이라 비율 1.0). iPad 1024×768: 셀 → 55.5dp, 위 띠 373.8,
  //     활성 LCD 489.3×373.8(줄 글자 40.0dp)
  //   · 데스크톱 창 1000×800: 셀 → 54.1dp 가로형, 기록 있음 — 위 띠 457.6, 활성 LCD 477.7×457.6(줄 글자 38.9dp)
  //   · 데스크톱 창 2000×1400(미리보기 "데스크톱 큰 창"): 위 띠 733.9, 기록 영역·활성 LCD 963.1×733.9(줄 글자 40dp)
  //   · 데스크톱 창 1280×600: 셀 → 69.5dp, 기록 있음(위 띠 166.9dp). 1280×500: 57.9dp, 위 띠 135.5dp로 기록 있음.
  //     1280×400: 42.8dp, 위 띠 112dp(LCD 최소 높이)라 기록 없음 — 활성 LCD 1264×112
  //   · 정사각형 창 768×768: 셀 44.6 > 41.4dp라 세로형. 600×610: 34.9 > 32.1dp 세로형. 700×599.9: 34.3 → 37.6dp 가로형
  //   · 태블릿 세로 800×1280·iPad 세로: 세로형 그대로(셀 74.0 > 43.1dp, 83.7 > 55.5dp — #189로 LCD가 낮아져 키가 커졌다)
  //   · 가로 폰 844×390(좌우 47·아래 21): 셀 18.8 → 37.6dp(예전 좌우 분할 30.0dp), 기록 없음. 활성 LCD가 띠 폭 전체이고
  //     LCD 최소 높이(112dp)라 줄 글자가 14.3dp다(좌우 분할 28.4dp) — 높이를 키에 준 결과다. 932×430(좌우 59)도 112dp
  //   · 짧은 창은 아래 "짧은 창" 절
  // 기록 영역 안의 무과금 광고는 #18에서 다룬다.

  /// 가로형 배치에서 계산 기록 영역을 두는 위 띠 최소 높이 (dp, #142) — 위 띠가 이보다 낮으면 기록 영역을 두지 않고 활성
  /// LCD가 띠 폭 전체를 쓴다.
  ///
  /// LCD 최소 높이([screenLcdMinHeight]) + 16dp다. 가로 폰은 키패드가 높이를 다 가져가 위 띠가 LCD 최소 높이에 묶인다
  /// (본체 높이 약 412dp 미만 — 844×390·932×430·915×412 모두 112dp) — 기록을 두면 활성 LCD가 좁아질 뿐 기록은 두세 줄이라
  /// 두지 않는다. 문턱을 LCD 최소 높이 바로 위에 두지 않는 것은 창 높이가 조금 늘 때(위 띠 16dp ≈ 본체 높이 57dp)마다
  /// 기록이 생겼다 없어지지 않게 하려는 여유다. 데스크톱 낮은 창 1280×500(위 띠 132dp)부터 기록을 둔다.
  /// 위 띠 높이는 기록 영역과 무관하게 정하므로, 이 경계에서 바뀌는 것은 활성 LCD 폭뿐이다.
  static const double screenLandscapeHistoryMinHeight =
      screenLcdMinHeight + 16.0;

  /// 가로형 배치에서 계산 기록 영역을 두는 블록(활성 LCD) 최소 폭 (dp, #142 R1) — 숫자부 블록이 이보다 좁으면 기록 영역을
  /// 두지 않고 활성 LCD가 띠 폭 전체를 쓴다. 가장 좁은 폰(320dp)의 LCD 폭(304dp)이다 — 기록 영역 때문에 활성 LCD가 어느
  /// 폰보다도 좁아지지 않게 한다(블록 304dp = 본체 폭 약 626dp). 이 경계에서 줄 글자가 크게 줄 창은
  /// [screenLandscapeHistoryMinLcdFontRatio]가 걸러 블록이 더 넓어질 때까지 기록 영역을 미룬다.
  static const double screenLandscapeHistoryMinLcdWidth =
      320.0 - 2 * screenPadding;

  /// 가로형 배치에서 기록 영역을 둘 때 활성 LCD 줄 글자가 지켜야 하는 비율 (기록 영역 없이 띠 폭 전체일 때 줄 글자 대비, #142 R2).
  /// 기록 영역을 두면 활성 LCD가 블록 폭으로 좁아진다. 위 띠가 높은 창에서는 블록 폭 LCD의 글자가 폭에 묶여 크게 줄어드는데
  /// (#142 R2 당시 본체 폭 626 → 626.5, 높이 584: 49.5 → 23.6dp), 그런 창에서는 블록이 더 넓어질 때까지 기록 영역을 미룬다. 그래서
  /// 기록 영역이 생기고 없어지는 경계에서 활성 LCD 줄 글자는 이 비율보다 많이 줄지 않는다(30% 이내).
  /// 띠 폭 전체 LCD의 글자는 상한([lcdLineMaxFontSize], #189)을 반영한 값이다 — 상한 40dp에 묶인 창은 블록 폭 LCD 글자가 28dp
  /// 이상이면 기록 영역을 둔다. #190에서 상단 띠가 빠져 위 띠가 높아져도(12.9인치 iPad 가로 479.1 → 519.1dp) 띠 폭 전체 LCD
  /// 글자가 상한에 묶여 비율이 바뀌지 않는다.
  static const double screenLandscapeHistoryMinLcdFontRatio = 0.7;

  /// 화면 안내(창이 너무 작다는 안내, #38) 글자·아이콘 색 — 본체 배경([bodyBackground]) 대비 4.5:1 이상, 키 각인보다 눈에
  /// 덜 띄게 회색. 고대비는 [noticeForegroundHighContrast].
  static const Color noticeForeground = Color(0xFFB0B0B0);

  // ── 접힘선 기준 배치 (#25, #143 — 2026-11-26 사용자 결정) ──
  // 폴더블 내부 화면처럼 접힘선(fold·hinge)이 창을 가로지르면 접힘선을 경계로 나눈다(`FormFactor.arrangementOf`).
  // 가로지르는 접힘선이 둘 이상이면(펼친 트라이폴드) 나누지 않고 접힘선 없는 창과 같게 그린다(#144, 사용자 결정 — 태블릿).
  // - 접힘선 1개는 **각도와 무관하게 언제나 경계**다(#143). 폴더블은 살짝 꺾어 쓸 수 있는데 시스템은 펼침·반 접힘만 알려 주고
  //   살짝 꺾은 각도는 대개 펼침으로 들어온다 — 앱은 둘을 구분할 수 없으므로, 완전히 펼친 Flip·Fold 가로도 나눈다. 그래서
  //   펼침·살짝 꺾음·반 접음이 같은 배치다(#143 전에는 펼친 폭 0 가로 접힘선을 나누지 않아, 꺾으면 키패드가 접힘선에 걸쳤다).
  // - 세로 접힘선 = 책 자세(`CalcHingeSplitLayout`): 주로 쓰는 손 쪽 패널은 세로형("화면 배치" 절)을 그 패널 크기로 그대로
  //   쓴다(위 활성 LCD, 아래 실물 배열 키패드 — 커버 화면과 키 위치가 같다). 반대쪽 패널 전체가 계산 기록이다(내용은 #145).
  //   #143 전에는 키패드가 손 쪽 절반 높이를 다 쓰고 LCD가 반대쪽 절반에 있었다 — 패널이 길쭉해 키가 세로로 길어지거나
  //   (키패드를 끝까지 채우면 약 349×820dp, 키 어림 58×81dp) LCD 아래가 비었다.
  //   손 쪽 패널이 짧은 창(분할 화면 등)은 세로형의 키가 일반 하한([keyTouchHeightFloor])보다 낮으면 활성 LCD를 반대쪽 패널 맨
  //   위로 옮기고(그 아래 기록) 키패드가 손 쪽 패널 높이를 다 쓴다(#143 R1, 2026-11-27 사용자 결정). 세로형 그대로면 LCD 최소
  //   높이가 패널 높이를 먼저 가져가 키가 위아래 배치와 같고, 쓸 수 있는 크기 경계에서 접힘선을 가로지르는 가로형과 키가 2배로
  //   튀었다(841×350 → 355: 31.6 → 16.2dp). 키패드는 키가 일반 하한을 넘지 않는 높이까지만 써서(R2), 창을 키워 세로형으로
  //   돌아오는 경계에서도 키가 줄지 않는다(그 사이 키패드 위가 빈다). 패널 폭에 묶여 키가 커지지 않거나 반대쪽 패널이
  //   [screenShortBookLcdMinWidth]보다 좁으면 세로형 그대로다. 반대쪽 패널의 기록이 [screenHistoryBelowLcdMinHeight]에 못 미치면
  //   기록 없이 LCD가 반대쪽 패널 전체로 커진다(Flip과 같은 규칙 — 그 경계에서 LCD 높이가 바뀐다, 글자는 폭에 묶여 거의 그대로.
  //   #232 전에는 상한 높이까지만 커져 그 아래가 비었다).
  // - 가로 접힘선(`CalcTabletopLayout`): 키패드는 아래 패널 폭 전체이고 본체 아래에 붙는다. 배열은 아래 패널에서 키가 큰
  //   쪽(넓은 배열 `KeypadArrangement.wide`과 실물 배열 중 가장 낮은 키 셀이 높은 쪽, #80)이다.
  //   · 넓은 배열(Fold 가로·Pixel Fold 세로): 가로형("가로형 배치" 절)과 같은 구성이고 위 띠와 키패드의 경계가 접힘선이다 —
  //     위 패널 = 기록(함수부 위) | 활성 LCD(숫자부 위) — 둘 다 위 패널 높이 전체다(#232). 숫자부·활성 LCD는 주로 쓰는 손 쪽이다. 기록을 둘지는
  //     가로형과 같은 문턱이다(Pixel Fold 세로는 블록 폭 LCD의 줄 글자가 폭 전체 LCD의 0.7배에 못 미쳐 기록이 없다).
  //   · 실물 배열(Flip 내부): 위 패널 맨 위가 활성 LCD(폭 전체, 폭 / [screenLcdMinAspectRatio] 높이)이고 그 아래가 기록이다
  //     (최근 것부터 아래로). 기록이 [screenHistoryBelowLcdMinHeight]보다 낮으면 두지 않고 LCD가 위 패널 전체를 쓴다(#232 —
  //     전에는 줄 글자 상한 높이까지만 써서 그 아래가 비었다). 손잡이와 무관하다.
  //   #141의 테이블톱 임시 폭 상한(키패드 블록 480dp·가로/세로 비 1.25, LCD 480dp)은 없앴다 — Flip 키패드가 약 322dp로 줄어
  //   옆이 비고, Fold 가로 LCD가 키패드보다 좁게 한쪽에 붙던 것이 없어졌다.
  // - 접힘선 양쪽에 [screenHingeMargin]씩 비운다. 어느 영역도 접힘선 위에 놓이지 않는다.
  // - 쓸 수 있는지(`CalculatorScreen`, 본체 크기로): 가장 낮은 키가 [keyTouchHeightUsableMin] 이상이고 활성 LCD가
  //   [screenLcdMinHeight] 이상이면 접힘선 기준 배치를 쓴다 — 접힘선을 가로지르는 배치(위아래·가로형)의 키가 더 커도 그렇다.
  //   #143 전에는 세로 접힘선은 일반 하한([keyTouchHeightFloor]) 이상이거나 위아래 배치보다 키가 클 때, 반 접은 테이블톱은
  //   완화된 하한(16dp, "사용자가 일부러 세워 둔 자세")일 때 썼다. 각도와 무관하게 나누면 "일부러 세운 자세"라는 근거가
  //   모든 접힘선에 해당하므로(살짝 꺾어 쓰는지 모른다) 두 방향을 그 완화된 하한 하나로 합쳤다. 그 하한이 안내 기준과
  //   같아, 쓰기로 한 접힘선 기준 배치가 "창이 너무 작다" 안내가 되는 일은 없다.
  //   쓸 수 없으면(손 쪽 패널이 약 141dp보다 좁음, 위 패널이 활성 LCD 최소 높이보다 낮음 등) 접힘 정보가 오기 전과 같은 위아래
  //   배치로 물러서고, 짧은 창이면 가로형과 비교한다(아래 "짧은 창" 절). 깜빡임이 없도록 물러설 배치를 접힘 정보 전과 같게 둔다.
  //   세로 접힘선은 손잡이마다 손 쪽 패널 폭이 달라, 한 손잡이만 물러설 수 있다(`SettingsLauncher` 문서).
  // - 패널 최소 길이 사전 판정(`FormFactor.hingeMinPanelExtent`)은 128dp다 — 창 좌표의 거친 판정이고 실제 판정은 위 본체
  //   크기 판정이다. #143 전 280dp에서는 "화면 크기"를 키운 Fold 673×539(절반 269.5dp)가 넓은 배열이면 키 36.1dp인데도
  //   떨어졌다(#139).
  // 계산값 (위젯 테스트로 잰 값 — 창 크기·인셋은 공개 사양·가정값이고, 에뮬레이터 실측은 아래 #140 블록. 가장 낮은 키 터치 높이,
  // 활성 LCD, 기록 영역. 인셋 위/아래 dp. #143 전 값은 화살표 앞):
  //   · Galaxy Z Fold 내부 세로 673×841(32/24, 접힘선 x=336.5) 책 자세: 손 쪽 패널 320.5×769 — 키패드 320.5×427.3(폭에 묶임),
  //     키 셀 36.3dp(함수 키 폭 약 53dp), LCD 320.5×333.7(줄 글자 25.0dp — #232 전 273.5로 그 위 약 60dp가 비었다), 기록 320.5×769
  //   · Pixel Fold 내부 가로 841×701(28.2/32, x=420.5) 책 자세: 패널 404.5×624.8 — 키 37.6dp(높이에 묶임), LCD 404.5×174.9
  //   · 두 화면 기기 1114×720(24/24, 폭 34 힌지) 책 자세: 패널 524×656 — 키 39.5dp, LCD 524×183.7
  //   · Galaxy Z Fold 가로 841×673(24/24, y=336.5): 넓은 배열 825×267, 키 45.4dp(3버튼 48도 같다 — 폭에 묶인다). 활성 LCD
  //     400.5×296.5(줄 글자 32.1dp, #232 전 400.5×228.8 — 그 위 67.7dp 빈 곳, #143 전 480×273.5·39.1dp가 손 쪽 끝), 기록
  //     400.5×296.5. 펼침은 #143 전 위아래 배치 32.1dp
  //   · Pixel Fold 세로 701×841(32/24, y=420.5): 넓은 배열 685×221.7, 키 37.7dp. 기록 없음 — 활성 LCD 685×372.5(줄 글자 40dp,
  //     #232 전 685×273.5 — 그 위 99dp 빈 곳)
  //   · Galaxy Z Flip 내부 411×1006(32/24, y=503): 실물 배열 395×463, 키 39.4dp / 3버튼 37.3dp(#143 전 반 접힘은 폭 상한으로
  //     키패드 약 322dp). 활성 LCD 395×225.7(줄 글자 31.6dp), 기록 395×221.3. **완전히 펼친 Flip**은 #143 전 위아래 배치(키패드가
  //     폭에 묶인 395×526.7, 키 44.8dp)에서 약 12% 낮아졌다 — 일반 바형 폰(390×844 42.4dp, 360×800 39.0dp)과 비슷하다.
  //   · 화면 크기를 키운 Fold 가로 673×539(24/24, y=269.5): 넓은 배열 키 36.1dp, 활성 LCD·기록 318.9×229.5(#232 전 활성 LCD
  //     318.9×182.2)
  //     (#143 전에는 사전 판정에서 떨어져 위아래 배치)
  //   · Fold에 앱 두 개를 좌우로 띄운 분할 창 약 420×673(24/24, y=336.5): 실물 배열 키 25.2dp(위아래 배치 약 32.7dp보다 작아도
  //     접힘선 기준 배치 — #80 R1 사용자 결정, 이제 펼친 창도 같다). 위 패널 296.5dp가 활성 LCD(230.9)와 기록을 함께 담지
  //     못해 LCD가 위 패널 전체 404×296.5이고 기록이 없다(#232 전 404×273.5).
  //   · 짧은 창의 책 자세(손 쪽 패널이 짧음 — LCD가 반대쪽 패널로): 640×360(상태바 24, x=320) 키 27.2dp(세로형 그대로면 17.0dp,
  //     접힘선을 가로지르는 가로형 34.0dp), 700×392(24/24) 27.9dp(세로형 17.7dp). 높이를 키우면 세로형 키가 일반 하한에 닿는
  //     곳에서 LCD가 손 쪽 패널로 돌아온다 — 키는 그 전부터 하한(28dp)에 머물러 이어진다(short_window_test가 높이·폭을 키울 때
  //     키가 줄지 않음을 양손으로 고정).
  //   · 접힘선이 치우친 창: Fold 세로 673×841, x=200(왼손잡이 손 쪽 패널 184dp)은 책 자세 키 20.9dp(위아래 배치 46.4dp) —
  //     패널 폭에 묶여 LCD를 옮겨도 커지지 않는다. 841×360, x=280은 두 손잡이 모두 LCD를 옮겨 27.2dp다(반대쪽 패널
  //     264·537dp). 트라이폴드 두 장 창 548.5×603(장 폭 274.5)도 책 자세 29.2dp(위아래 배치
  //     32.3dp, #143 전에는 사전 판정 280dp에 걸려 위아래 배치였다).
  // 에뮬레이터 실측 (#140 — Android 16 Google Play 이미지, 진단 릴리스 빌드 `LayoutLog`). 시스템 영역·배치 줄(키패드 영역 포함)은
  // `test/widget/foldable_emulator_layout_test.dart`가 같은 창·인셋·접힘 정보로 그대로 재현하고, 에뮬레이터 uiautomator의 가장 낮은
  // 키 노드 높이(px)와 1px 안에서 맞는지도 본다. 키는 가장 낮은 키 터치 높이다 — #140 측정 당시 키 노드 = 셀 기준 터치 높이였다.
  // #236부터 셀 전체를 터치하는 키의 노드·터치 높이는 셀 둘레 키 사이 간격 몫을 더한 행 간격이다([keyMinTouchTargetHeight]).
  //   · Pixel Fold 내부 2208×1840px(밀도 2.625 → 841.1×701, 인셋 28.19/32, 접힘선 x=420.6) 책 자세: 손 쪽 키패드 404.6×441.8,
  //     키 37.6dp. LCD·기록·키패드가 모두 접힘선 양쪽 8dp 밖이다. 손잡이를 바꾸면 패널이 맞바뀐다(키패드 x 428.6 ↔ 8). 반 접힘도
  //     같은 영역이다.
  //   · 세로로 돌린 Pixel Fold 701×841.1(y=420.6): 넓은 배열 685×221.7, 키 37.7dp, 숫자부가 손잡이 쪽. 기록 없음 — 아래 패널은
  //     접힘선과 키패드 사이 약 150dp가 빈다(키패드가 세로 한계에 묶여 본체 아래에 붙는다). 위 패널의 본체 윗변과 활성 LCD 사이
  //     약 103dp 빈 곳은 #232에서 없앴다(활성 LCD가 위 패널 전체 — 위젯 테스트 계산값, 에뮬레이터에서는 다시 재지 않았다).
  //   · 7.6" Foldable(`7.6in Foldable` 1768×2208px, 밀도 2.625 → 673.5×841.1, 인셋 24/32, 힌지 x=336.8~337.1 — Galaxy Z Fold형)
  //     책 자세 키 36.3dp. 가로로 돌리면(841.1×673.5) 넓은 배열 키 45.4dp, 함수부 위 기록 + 숫자부 위 활성 LCD(오른손잡이)다. 가로
  //     화면을 좌우로 나눈 실제 분할 창 415.6×673.5(인셋 24/32, 가로 접힘선)는 실물 배열 키 24.6dp, 기록 없음 — 위 24/24 계산의
  //     420×673 25.2dp보다 조금 낮다.
  //   · 6.7" Flip(`6.7in Foldable` 1080×2636px, 밀도 3 → 360×878.7, 24/24, 힌지 y=439.3~439.7) 반 접힘: 실물 배열 344×399,
  //     키 33.9dp — 위아래 배치(39.0dp)보다 약 13% 낮다.
  //   · 에뮬레이터 한계: 7.6"·6.7" 에뮬레이터는 접은 자세(`emu posture 2`·`1`)에서만 폭 1px `hinge`를 보고하고, 반 접힘 자세에서도
  //     상태가 `postureFlat`로 온다(닫힘 자세 `1`에서는 `postureHalfOpened`). 완전히 펼치면(`posture 3`) 보고하지 않아 위아래
  //     배치가 된다. 커버 화면도 없다(`emu fold`가 화면을 바꾸지 않는다). 실기기가 완전히 펼친 상태에서도 접힘선을 보고하는지는
  //     **가정**이다 — 보고하지 않으면 #143의 "펼침·살짝 꺾음·반 접음이 같은 배치"가 깨져 꺾을 때마다 위아래 배치와 접힘선 기준
  //     배치가 오간다(Flip 39.0 ↔ 33.9dp). 실기기 확인은 #180. Pixel Fold에 Flip 크기·접힘선을 흉내 내면(`wm size`·
  //     `display_features`) 펼침(`postureFlat`)과 반 접힘(`postureHalfOpened`)이 같은 배치·같은 키(33.9dp)다.
  //   · 손 쪽 패널이 짧은 책 자세(Pixel Fold 자유 형식 창 841.1×354.3, 인셋 0): 활성 LCD가 반대쪽 패널로 가고 기록은 없다. 키 28.0dp
  //     (일반 하한에서 멈춤). 대화상자는 ON 키 쪽 절반에 뜬다. Pixel Fold의 실제 분할 화면은 접힘선을 창 경계에 둔다 — 가로 화면은
  //     좌우(415.6×701, 위아래 배치), 세로 화면은 위아래(701×415.6, 가로형 37.7dp) — 그래서 자유 형식 창으로 만들었다. 같은 방법의
  //     420.2×673.1 창(인셋 0, 가로 접힘선 y=336.4)은 실물 배열 키 27.3dp다.
  //   · 회전(Pixel Fold): 18번 중 7번은 접힘 정보가 창 크기보다 먼저 새 방향으로 와(접힘선이 창을 가로지르지 않음) 이전 창 크기의
  //     위아래 배치를 그렸고(배치 로그 한 줄), 그 배치가 약 0.2~0.36초(60Hz로 12~22프레임, 화면 캡처를 이어 찍어 부하가 걸린 한 번은
  //     2.3초) 이어진 뒤 접힘선 기준 배치가 됐다. 나머지 11번은 중간 배치 없이 바로 바뀌었다(창 크기가 먼저 오는 #25 R2 순서는 보지 못했다). 위아래 배치 프레임이 생긴
  //     회전 3번에서 화면 캡처를 이어 찍었는데 그 위아래 배치는 한 번도 나오지 않았다(이전 배치 → 회전 애니메이션 → 새 배치).
  //   · 접기·펴기(Pixel Fold `adb emu fold`·`unfold`)와 자세 전환(`emu posture`, 7.6"·Flip)은 중간 배치 없이 바로 바뀌었다. 상태는
  //     SHIFT 대기(S)와 마지막 입력(LCD 입력 줄 — 7.6"에서 sin⁻¹)이 자세 전환 4번·회전 2번 뒤에도 남았다.
  //   · TalkBack 쓸어 넘기기(확인한 경우만): Pixel Fold 책 자세(오른손잡이)는 활성 LCD(상태 줄·입력·결과) → 기록 → 함수부 →
  //     숫자부, 세로로 돌린 Pixel Fold는 LCD → 함수부 → 숫자부(왼손잡이는 숫자부가 왼쪽이어도 함수부 다음), 7.6" 가로(넓은 배열)는
  //     LCD(오른쪽) → 기록(왼쪽) → 함수부 → 숫자부, Flip 반 접힘은 LCD → 기록 → 함수부(숫자부까지 쓸지 않았다).
  // 무과금 광고(#18): 접힘선 기준 배치의 기록 영역은 키패드와 접힘선만 사이에 두고 맞닿을 수 있다(책 자세의 반대쪽 패널, Flip의
  // 위 패널 아래쪽). 광고는 키패드 바로 옆에 두지 않으므로(CLAUDE.md) 기록 영역에서 키패드와 먼 끝(책 자세는 위쪽, Flip은 활성 LCD
  // 바로 아래가 아닌 쪽 — #18에서 정한다)을 쓴다. 기록 영역이 없는 접힘선 기준 배치(Pixel Fold 세로, 분할 창 420×673)의 광고 자리도
  // #18에서 정한다.

  /// 키 터치 높이 하한 (dp, 커서 패드 제외). 세로 폰 화면과 전체 화면 폴더블의 접힘선 기준 배치(책 자세·가로 접힘선 — 위
  /// 실측) 키 크기 하한 테스트가 이 값을 쓴다. 위아래 배치의 키가 이보다 낮은 창은 "짧은 창"이다(아래 "짧은 창" 절, #38).
  /// 접힘선 기준 배치를 쓸지는 이 값이 아니라 [keyTouchHeightUsableMin]으로 판정한다(#143, 위 "접힘선 기준 배치" 절 — #143
  /// 전에는 세로 접힘선 판정에 이 값을 썼다).
  static const double keyTouchHeightFloor = 28.0;

  /// 접힘선(주름)과 내용 사이 간격 (dp, 접힘선 한쪽마다). 폭이 0인 접힘선이면 양쪽 내용 사이가 이 값의 두 배(16dp)다.
  static const double screenHingeMargin = 8.0;

  /// 손 쪽 패널이 짧은 책 자세에서 활성 LCD를 옮겨 갈 반대쪽 패널의 최소 폭 (dp, #143 R2, `CalcHingeSplitLayout`).
  /// 이 폭의 LCD 줄 글자(14.3dp)가 LCD 최소 높이의 줄 글자(가로 폰 등, [screenLcdMinHeight])와 같다 — 그보다 좁은 LCD는
  /// 어떤 배치보다도 글자가 작아진다. R1에서는 가장 좁은 폰의 LCD 폭(304dp)을 빌려 썼는데, 본체 폭 624dp 미만의 짧은 창
  /// (화면 크기를 키운 Fold의 분할 화면 등)이 변형을 쓰지 못해 쓸 수 있는 크기 경계에서 키가 2배로 튀었다(560×348 → 350:
  /// 29.9 → 16.1dp).
  static const double screenShortBookLcdMinWidth = 200.0;

  /// 활성 LCD와 그 아래 계산 기록 영역 사이 간격 (dp, #143) — 가로 접힘선 기준 배치의 실물 배열(Flip 내부) 위 패널.
  /// LCD와 키패드 사이 간격([screenLcdKeypadGap])과 같다.
  static const double screenLcdHistoryGap = screenLcdKeypadGap;

  /// 활성 LCD 아래에 계산 기록 영역을 두는 최소 높이 (dp, #143) — 가로 접힘선 기준 배치의 실물 배열(Flip 내부)에서 위 패널이
  /// 활성 LCD와 간격을 빼고 이보다 낮게 남기면 기록 영역을 두지 않고 활성 LCD가 위 패널을 쓴다. LCD 최소 높이
  /// ([screenLcdMinHeight])와 같다 — 그보다 낮은 기록은 두세 줄이라 두지 않는다(가로형의 [screenLandscapeHistoryMinHeight]와
  /// 같은 생각). Flip 내부(위 패널 약 463dp)는 기록이 약 229dp다.
  static const double screenHistoryBelowLcdMinHeight = screenLcdMinHeight;

  // ── 짧은 창 (#38, 사용자 결정 — 비교 대상은 #142에서 가로형으로 바꿨다) ──
  // 분할 화면·팝업 창·가로로 돈 폰처럼 창이 낮으면 위아래 배치의 키패드가 LCD에 높이를 뺏겨 아주 작아진다.
  // - 배치: 접힘선 없는 창은 크기와 무관하게 위아래 배치와 가로형 중 키가 큰 쪽으로 그린다(위 "가로형 배치" 절).
  //   가로형은 넓은 배열(5행)이라 낮은 창일수록 이득이 크다. 세로로 긴 창(세로 폰 등)은 가로형이 늘 더 작아 위아래 배치
  //   그대로다. 예전 좌우 분할은 짧은 변 600dp에서 비교를 멈춰(정사각형 대화면 768×768이 좌우 분할이 되지 않게) 경계에서
  //   키가 줄었다(#38 R2 — 폭 601dp 창 34.3 → 32.2dp). 가로형은 정사각형 창에서 세로형보다 작아(768×768: 41.4 < 44.6dp)
  //   경계가 필요 없다.
  //   폴더블 기기이거나 접힘 정보가 있어 위아래 배치로 그리는 창(접힘선 기준 배치를 쓸 수 없는 창 포함)은 창의 짧은 변이
  //   `FormFactor.largeScreenMinShortestSide`(600dp) 미만이거나(#38 R1) 위아래 배치의 키가 [keyTouchHeightFloor] 미만일
  //   때만 비교한다 — 접힘 정보가 늦게 오는 폴더블 내부 화면을 가로형으로 그렸다가 바꾸지 않게 한다(#25). 접힘선 기준 배치를
  //   쓸 수 없어 물러선 창도 같다(#143 — 접힘 정보 전과 같은 배치). 접힘선이 둘 이상 가로지르는 창(펼친 트라이폴드, #144)은 접힘선 없는 창과
  //   같다. 이 범위 안에서도 두 키 크기는 연속이라 창을 키울 때 키가 줄지 않는다(#38 R1 — 처음 정한
  //   "위아래 배치의 키가 [keyTouchHeightFloor] 미만일 때만 비교"는 가로 창 844×548 → 549에서 키가 40.8 → 28.0dp로 줄었다).
  //   본체 크기(인셋·화면 여백을 뺀 크기)로 판정하며 `CalculatorScreen`이 한다 — `FormFactor.arrangementOf`는 창
  //   크기만 본다.
  // - 접힘선: 접힘선 기준 배치는 키가 [keyTouchHeightUsableMin] 이상이면 쓴다(#143 — 위 "접힘선 기준 배치" 절). 쓸 수 없어
  //   위아래 배치로 대체할 때도 위 비교를 한다 — 위아래 배치도 접힘선을 가로지르므로 가로형만 뺄 이유가 없다(#38 R1).
  // - 안내: 그린 배치의 키가 [keyTouchHeightUsableMin](16dp) 미만이면 계산기 대신 창을 키워 달라는 안내를 띄운다.
  // - 글자 하한: 따로 두지 않는다. 키 글자는 키 크기에 비례해 정해지므로(`KeypadMetrics`) 터치 높이 하한이 글자 하한을
  //   겸한다. 안내 직전(키 약 16dp)의 글자 크기는 short_window_test가 실제 글꼴로 고정한다. 사용자가 받아들인 접힘선 기준
  //   배치의 하한(#25·#80 R1의 테이블톱 하한)과 같은 키 크기이고, 각인은 읽기 어려운 크기라 이 크기의 창은 "급히 쓸 수는
  //   있는" 최소로 본다.
  // 실측 (키 셀 높이, LCD 줄 글자 — 위아래 배치 → 그린 배치. 인셋은 괄호. #190에서 상단 띠 최소 높이 12dp가 빠진 뒤의 값):
  //   · 폰 분할 화면 — 아래 "에뮬레이터 실측"
  //   · 가로 폰 844×390(좌우 47·아래 21): 키 19.8 → 39.6dp, LCD 14.3dp(최소 높이)
  //   · 640×360(상태바 24): 키 17.0 → 34.0dp / 568×320: 15.6 → 30.4dp / 700×392(24/24): 17.7 → 35.4dp
  //   · 360×300: 키 13.9 → 18.9dp, LCD 14.3 → 22.7dp
  //   · 412×520(상태바 24): 키 28.7dp로 일반 하한 이상 — 짧은 창이 아니다(#190 전 27.96dp). 320×480(상태바 20)은 위아래 배치로
  //     남는 짧은 창이다.
  //   · 세로 폰은 위아래 배치 그대로다 — 390×844(47/34): 42.4dp, 가로형 20.6dp.
  //   · 320×240: 가로형 16.7dp라 계산기(#190 전 15.6dp로 안내). 300×240은 안내. 미리보기 "작은 팝업 창" 320×200: 가로형 10.9dp로 안내
  // 에뮬레이터 실측 (#137 — Android 16 Google Play 이미지 폰 1080×2400·420dpi = 411.43×914.29dp, 진단 빌드 로그 `LayoutLog`).
  // 분할 화면 경계는 1/3·1/2·2/3에서만 멈춘다. 창 크기는 제스처 내비게이션·3버튼이 같고 인셋만 다르다 — 위 창은 상태바 24,
  // 아래 창은 제스처 24(제스처 영역 32)·3버튼 48. 그린 배치와 가장 낮은 키 터치 높이:
  //   · 1/2 411.43×452.19: 위아래 배치 — 위 창·아래 창(제스처) 24.5dp, 아래 창(3버튼) 22.8dp. 가로형보다 커 위아래 배치다
  //     (#38에서 가정한 411×420·411×440보다 높다).
  //   · 1/3 411.43×304.76: 가로형 21.8dp / 아래 창(3버튼) 20.5dp. 2/3 411.43×599.62: 위아래 배치 33.6dp / 3버튼 32.1dp
  //   · 폰을 가로로 돌린 좌우 분할(창 높이 411.43, 위·아래 인셋 24): 1/2 폭 452.19 가로형 24.0dp, 2/3 폭 607.62 가로형
  //     32.5dp, 1/3 폭 296.76 위아래 배치 19.3dp
  //   · 화면을 320×568dp로 줄인(`wm size 840x1491`) 1/2 분할 320×278.9: 가로형 16.7dp — 안내 바로 위
  //   · 자유 형식 창(`enable_freeform_support`, 캡션 없음): 최소 크기 219.81×219.81dp는 안내, 381×285 가로형 20.1dp,
  //     381×219.81 안내, 기본 296×658.29 위아래 배치 31.7dp. 안내 중 창을 다시 키우면 LCD 입력이 그대로다.
  //   · TalkBack: 안내가 나타날 때 문구를 한 번 읽고(TalkBack "음성 출력 표시"로 확인), 안내 중 의미 트리에는 안내 노드만
  //     있다(키 50개가 빠져 포커스가 갈 수 없다). 창을 다시 키우면 키 노드가 돌아온다.
  //   · Android 14 폰 에뮬레이터(`AltCalc_Phone_API34`, google_apis 1080×2400·420dpi, 제스처 내비게이션 — #137 R1): 앱 창이
  //     시스템 바를 빼고 와 인셋이 0이다. 아래 창 1/2 411.43×428.19 위아래 배치 24.5dp, 가장 작게 멈춘 창 411.43×235.43
  //     가로형 16.9dp(레터박스 없음, 수정 뒤), 큰 창 411.43×620.95 위아래 배치 36.3dp — 멈추는 자리가 Android 16과 다르다.
  //   방향 고정(#24)을 여러 창 모드에서도 요청하던 동안은 가로로 긴 분할 창이 Android 레터박스(`FIXED_ORIENTATION`)로
  //   줄어 안내가 나왔다 — 1/3 411.43×304.76 → 301.71×304.76, 320×278.9 → 레터박스(#173 관찰). 지금은 여러 창 모드에서
  //   방향을 고정하지 않는다(`FormFactor.queryMultiWindowMode`). 폰을 가로로 돌린 좌우 분할은 그때도 레터박스가 없었다.
  // LCD는 짧은 창에서도 [screenLcdMinHeight] 아래로 줄이지 않는다(#38 당시 측정): 411×420에서 위아래 배치의 LCD를
  // 112 → 72dp로 줄여도 키는 약 3.4dp만 커지고 LCD 줄 글자는 14.3 → 8.0dp가 된다.
  //
  // 네이티브 설정 — 창 크기는 시스템에 맡기고, 앱은 위 규칙으로 맞추거나 안내한다:
  // - Android: `resizeableActivity="false"`(분할 화면·팝업 창 금지)는 사용자에게 불리한 제한이라 쓰지 않는다.
  //   `<layout android:minWidth/minHeight>`(최소 창 크기)도 선언하지 않는다. 데스크톱·팝업 창에서는 그보다 작게 줄이지
  //   못하게 막아 주지만, 분할 화면에서 사용자가 경계를 그보다 작게 옮기면 시스템이 앱을 최소 크기로 그린 뒤 잘라
  //   보여 줘 키 일부가 화면 밖으로 잘린다 — 잘린 계산기보다 안내가 낫다(`AndroidManifest.xml` 주석).
  // - iOS: iPhone은 앱 창이 화면 전체라 짧은 창이 생기지 않는다. iPad의 Split View·Slide Over·Stage Manager 창 최소
  //   크기(`UISceneSizeRestrictions.minimumSize`)도 지정하지 않는다 — 사용자가 고른 창 크기를 앱이 제한하지 않는다는
  //   Android와 같은 방침이고, 작게 줄인 창은 위 규칙으로 맞추거나 안내한다.

  /// 키를 쓸 수 있는 터치 높이 최소 (dp, 커서 패드 제외, 사용자 결정 #38). 그린 배치의 가장 낮은 키
  /// (`KeypadMetrics.minKeyTouchHeightOf`)가 이보다 낮으면 계산기 대신 창을 키워 달라는 안내를 띄운다.
  /// 접힘선 기준 배치를 쓸지 정하는 하한이기도 하다(#143 — 위 "접힘선 기준 배치" 절). #25·#80 R1에서 사용자가 반 접은
  /// 테이블톱에 받아들인 가장 작은 키이고, #143에서 각도와 무관하게 모든 접힘선 기준 배치로 넓혔다.
  static const double keyTouchHeightUsableMin = 16.0;

  /// 창이 너무 작다는 안내의 아이콘 크기 (dp)
  static const double windowTooSmallIconSize = 32.0;

  /// 창이 너무 작다는 안내 문구 글자 크기 (dp, 배율 반영 전). 글자 배율을 그대로 반영하고, 본체보다 높으면 스크롤한다.
  static const double windowTooSmallFontSize = 16.0;

  /// 창이 너무 작다는 안내의 안쪽 여백 (dp)
  static const double windowTooSmallPadding = 8.0;
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
    KeyCategory.operator ||
    KeyCategory.equals ||
    KeyCategory.cursor ||
    KeyCategory.shift => CalcTheme.keyPressedDarkenOverlay,
    KeyCategory.ac ||
    KeyCategory.del ||
    KeyCategory.alpha => CalcTheme.keyPressedDeepDarkenOverlay,
    KeyCategory.function ||
    KeyCategory.menu ||
    KeyCategory.on => CalcTheme.keyPressedLightenOverlay,
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

/// 기기의 대비 설정에 따라 바뀌는 색 묶음 (#54).
///
/// [standard]는 일반 모드([CalcTheme] 상수·[KeyCategoryColors] 그대로), [highContrast]는 고대비 모드
/// ([CalcTheme] "고대비 모드" 주석 참조)다. 화면은 [CalcPalette.of]로 기기 설정에 맞는 쪽을 고른다.
/// 여기 없는 색(본체·LCD 배경·글자 등)은 두 모드가 같다.
@immutable
final class CalcPalette {
  /// 고대비 팔레트인지 여부
  final bool isHighContrast;

  /// 키캡·원형 버튼 고리 테두리 (커서 패드 홈은 [cursorPadGroove], #156)
  final Color keyBorder;

  /// 눌린 키캡 테두리
  final Color keyPressedBorder;

  /// SHIFT 각인 색
  final Color shiftLabel;

  /// ALPHA 각인 색
  final Color alphaLabel;

  /// LCD 비활성 상태 표시기 색
  final Color lcdStatusInactive;

  /// 화면 안내(창이 너무 작다는 안내) 글자·아이콘 색
  final Color noticeForeground;

  /// 본체에 인쇄된 흰 글자 색 — MENU·ON 자리(`SETUP`) 원형 버튼 위 이름 (#190, #156, #253). SHIFT·ALPHA 버튼 위 이름은
  /// 각인 색이다 — 원형 버튼 인쇄 색은 [bodyPrintOf]로 고른다.
  final Color bodyPrint;

  /// `FocusRing`이 그리는 키보드 포커스 테두리 색 (#97, 일반 모드는 #106)
  final Color materialFocusRing;

  /// 커서 패드 홈·외곽선·허브 둘레 색 (#156)
  final Color cursorPadGroove;

  /// 입체 장식(본체 잔무늬·그라데이션·가장자리 선, 키캡 윗면 광택·옆면, LCD 유리 그늘)을 그리는지 (#156) — 고대비 모드에서는
  /// 그리지 않는다([CalcTheme] "고대비 모드" 주석).
  bool get drawsRelief => !isHighContrast;

  const CalcPalette._({
    required this.isHighContrast,
    required this.keyBorder,
    required this.keyPressedBorder,
    required this.shiftLabel,
    required this.alphaLabel,
    required this.lcdStatusInactive,
    required this.noticeForeground,
    required this.bodyPrint,
    required this.materialFocusRing,
    required this.cursorPadGroove,
  });

  /// 일반 팔레트
  static const CalcPalette standard = CalcPalette._(
    isHighContrast: false,
    keyBorder: CalcTheme.keyBorder,
    keyPressedBorder: CalcTheme.keyPressedBorder,
    shiftLabel: CalcTheme.shiftLabel,
    alphaLabel: CalcTheme.alphaLabel,
    lcdStatusInactive: CalcTheme.lcdStatusInactive,
    noticeForeground: CalcTheme.noticeForeground,
    bodyPrint: CalcTheme.bodyPrint,
    materialFocusRing: CalcTheme.materialFocusRingStandard,
    cursorPadGroove: CalcTheme.cursorPadGroove,
  );

  /// 고대비 팔레트
  static const CalcPalette highContrast = CalcPalette._(
    isHighContrast: true,
    keyBorder: CalcTheme.keyBorderHighContrast,
    keyPressedBorder: CalcTheme.keyPressedBorderHighContrast,
    shiftLabel: CalcTheme.shiftLabelHighContrast,
    alphaLabel: CalcTheme.alphaLabelHighContrast,
    lcdStatusInactive: CalcTheme.lcdStatusInactiveHighContrast,
    noticeForeground: CalcTheme.noticeForegroundHighContrast,
    bodyPrint: CalcTheme.bodyPrintHighContrast,
    materialFocusRing: CalcTheme.materialFocusRingHighContrast,
    cursorPadGroove: CalcTheme.cursorPadGrooveHighContrast,
  );

  /// 기기의 고대비 설정에 맞는 팔레트. [MediaQuery.highContrastOf]나 Android "고대비 텍스트"([HighTextContrastScope])
  /// 중 하나라도 켜져 있으면 고대비다(플랫폼별 의미는 [CalcTheme] "고대비 모드" 주석).
  /// 두 설정에만 의존하므로 다른 MediaQuery 값(크기·인셋 등)이 바뀌어도 다시 빌드되지 않는다.
  static CalcPalette of(BuildContext context) =>
      MediaQuery.highContrastOf(context) || HighTextContrastScope.of(context)
      ? highContrast
      : standard;

  /// 이 팔레트와 짝인 Material 테마 (대화상자·SnackBar, #97) — 지금 플랫폼([defaultTargetPlatform])의 테마다
  /// ([CalcTheme.materialTheme] 위 #130 주석).
  ThemeData get materialTheme => isHighContrast
      ? CalcTheme.materialHighContrastTheme
      : CalcTheme.materialTheme;

  /// [category] 키캡 배경색
  Color keyBackground(KeyCategory category) {
    if (!isHighContrast) return category.background;
    return switch (category) {
      KeyCategory.ac || KeyCategory.del => CalcTheme.keyACHighContrast,
      KeyCategory.alpha => CalcTheme.keyAlphaHighContrast,
      // 일반 모드에서 이미 라벨 7:1 이상인 키
      KeyCategory.number ||
      KeyCategory.operator ||
      KeyCategory.equals ||
      KeyCategory.function ||
      KeyCategory.shift ||
      KeyCategory.cursor ||
      KeyCategory.on ||
      KeyCategory.menu => category.background,
    };
  }

  /// [category] 키캡 메인 라벨색 (두 모드가 같다)
  Color keyForeground(KeyCategory category) => category.foreground;

  /// [category] 원형 버튼(#190) 위 본체에 인쇄한 이름의 색 (#156) — 실물처럼 SHIFT는 금색([shiftLabel]), ALPHA는
  /// 자홍색([alphaLabel]), 나머지(MENU·ON 자리의 SETUP)는 흰색([bodyPrint])이다.
  Color bodyPrintOf(KeyCategory category) => switch (category) {
    KeyCategory.shift => shiftLabel,
    KeyCategory.alpha => alphaLabel,
    _ => bodyPrint,
  };

  /// [category] 키가 눌릴 때 배경과 라벨을 반전하는지 여부 — 고대비 모드의 흰 라벨 키
  bool invertsOnPress(KeyCategory category) =>
      isHighContrast &&
      switch (category) {
        KeyCategory.number ||
        KeyCategory.operator ||
        KeyCategory.equals ||
        KeyCategory.cursor ||
        KeyCategory.shift => false,
        KeyCategory.function ||
        KeyCategory.ac ||
        KeyCategory.del ||
        KeyCategory.alpha ||
        KeyCategory.on ||
        KeyCategory.menu => true,
      };

  /// 눌린 [category] 키캡 배경색 — 반전하면 [CalcTheme.keyPressedInvertedBackground],
  /// 아니면 평소 색 + [KeyCategoryColors.pressedOverlay]
  Color keyPressedBackground(KeyCategory category) => invertsOnPress(category)
      ? CalcTheme.keyPressedInvertedBackground
      : Color.alphaBlend(category.pressedOverlay, keyBackground(category));

  /// 눌린 [category] 키캡 메인 라벨색 — 반전하면 [CalcTheme.keyPressedInvertedText], 아니면 평소와 같다
  Color keyPressedForeground(KeyCategory category) => invertsOnPress(category)
      ? CalcTheme.keyPressedInvertedText
      : keyForeground(category);
}
