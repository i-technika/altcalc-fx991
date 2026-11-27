import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show DisplayFeature;

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/key_definitions.dart';
import '../../core/layout/form_factor.dart';
import '../../core/layout/layout_log.dart';
import '../../core/theme/calc_theme.dart';
import '../../domain/models/calc_state.dart';
import '../../domain/models/handedness.dart';
import '../l10n/calc_semantic_strings.dart';
import '../l10n/settings_strings.dart';
import '../providers/calc_provider.dart';
import '../providers/device_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/calc_body_background.dart';
import '../widgets/calc_keypad.dart';
import '../widgets/history_panel.dart';
import '../widgets/lcd_display.dart';
import '../widgets/screen_coordinate_root.dart';
import '../widgets/settings_launcher.dart';

/// 본체 영역의 세로 배치 (위 → 아래: (빈 곳) · LCD · 간격 · 키패드) — 접힘선 없는 세로로 긴 창의 "세로형" 배치 (#141).
///
/// 기준은 [CalcTheme]의 "화면 배치" 절을 따른다 (#23, #141, #190).
/// - 폭: LCD와 키패드 모두 본체 폭 전체를 쓴다 (#141 — 폭 상한 없음, 태블릿 세로에서도 양옆이 비지 않는다).
/// - LCD 높이: [CalcTheme.screenLcdHeightRatio] 목표, [CalcTheme.screenLcdMinHeight] ~ 최대 높이 범위. 최대 높이는
///   (본체 폭 / [CalcTheme.screenLcdMinAspectRatio])와 줄 글자 상한 높이([LcdFontSizes.heightAtMaxLineFont], #189) 중 낮은 쪽
///   ([_lcdMaxHeightOf]) — 태블릿 세로는 상한 높이에서 멈추고 남는 높이를 키패드가 받는다.
/// - 키패드: 나머지 높이 중 가로/세로 비 하한([CalcTheme.keypadMinAspectRatio] — 키가 세로로 길어지지 않게)이
///   허용하는 만큼.
/// - 키패드가 쓰지 못하는 높이(#190): LCD가 줄 글자 상한 높이([_lcdAbsorbMaxHeight] — [LcdFontSizes.heightAtMaxLineFont],
///   #189)까지 받는다 — 폭 기준 최대 높이를 넘을 수 있다(세로로 긴 폰은 줄 글자가 폭에 묶여 줄 사이만 넓어진다). 그래도
///   남으면 LCD 위([top])가 빈다 — LCD 쪽 영역으로, 계산 기록(#145)이 쓸 자리다. LCD는 키패드 바로 위에 붙는다.
///   (#190 전에는 LCD 위 상단 띠(장식·설정 버튼, #41)가 최소 12dp와 남는 높이를 받았다. 최소 12dp였던 몫은 이제 위 목표
///   비율대로 LCD와 키패드가 나눈다 — 작은 폰·짧은 창은 키가 조금 커진다.)
/// - 본체가 아주 낮으면 키패드 높이가 0이 될 때까지만 LCD를 최소 높이로 지킨다. 우선순위는 LCD 최소 높이 > 키패드다
///   (#38에서 유지하기로 정함). 키가 작아지는 짧은 창은 이 배치 안에서 높이를 나누는 대신 화면이 가로형
///   ([CalcLandscapeLayout])으로 바꾸거나 안내를 띄운다([CalculatorScreen], [CalcTheme] "짧은 창" 절).
///   본체가 간격보다 낮으면 간격은 본체 높이까지만 받아, 어떤 경우에도 합계가 본체 높이를 넘지 않는다.
@immutable
class CalcScreenLayout {
  /// LCD 위 빈 높이 (dp) — LCD가 줄 글자 상한 높이까지 받고도 남는 높이다(#190). 계산 기록(#145)이 쓸 LCD 쪽 자리이고,
  /// 큰 세로 창에서만 생긴다(폰은 대부분 0, 21:9 폰 412×915에서 약 17.5dp).
  final double top;

  /// LCD 높이 (dp) — LCD 폭은 본체 폭이다 (#141)
  final double lcdHeight;

  /// LCD와 키패드 사이 간격 (dp) — [CalcTheme.screenLcdKeypadGap], 본체가 그보다 낮으면 본체 높이
  final double gap;

  /// 키패드 영역 높이 (dp) — 키패드 폭은 본체 폭이다 (#141)
  final double keypadHeight;

  const CalcScreenLayout._({
    required this.top,
    required this.lcdHeight,
    required this.gap,
    required this.keypadHeight,
  });

  /// [body] (시스템 인셋·화면 여백을 뺀 본체 영역)의 세로 배치.
  /// `top + lcdHeight + gap + keypadHeight`는 본체 높이와 같다 (음수·비유한 크기는 0으로 본다).
  factory CalcScreenLayout.of(Size body) {
    double finite(double v) => v.isFinite ? math.max(0.0, v) : 0.0;
    final width = finite(body.width);
    final divided = _divideBodyHeight(
      finite(body.height),
      lcdMaxHeight: _lcdMaxHeightOf(width),
      keypadMaxHeight: KeypadMetrics.fitSize(Size(width, double.infinity))
          .height,
    );
    final lcd = math.min(divided.lcd, _lcdAbsorbMaxHeight);
    return CalcScreenLayout._(
      // 남는 높이를 먼저 구한 뒤 위에 둔다 — 부동소수점 오차로 합이 본체 높이와 어긋나지 않게.
      top: divided.lcd - lcd,
      lcdHeight: lcd,
      gap: divided.gap,
      keypadHeight: divided.keypad,
    );
  }

  @override
  String toString() =>
      'CalcScreenLayout(top: $top, lcd: $lcdHeight, gap: $gap, '
      'keypad: $keypadHeight)';
}

/// 본체 높이 [bodyHeight](유한한 0 이상 값)를 위 → 아래 (LCD · 간격 · 키패드)로 나눈다 — 세로형([CalcScreenLayout])과
/// 가로형([CalcLandscapeLayout])이 같이 쓰는 규칙이다 (#23, #142, #190).
/// - LCD: 목표 높이(= 본체 높이 × [CalcTheme.screenLcdHeightRatio])를 [CalcTheme.screenLcdMinHeight] ~
///   [lcdMaxHeight] 범위로 제한한다(최대 높이가 최소 높이보다 낮으면 최소 높이). 최대 높이는 세로형이 [_lcdMaxHeightOf]
///   (줄 글자 상한 #189 포함), 가로형의 위 띠가 본체 폭 / [CalcTheme.screenLcdMinAspectRatio]다.
/// - 키패드: 나머지 높이, [keypadMaxHeight]까지. 키패드가 세로 한계에 닿아 쓰지 못하는 높이는 모두 LCD 쪽([lcd] —
///   세로형은 LCD와 그 위 빈 곳, 가로형은 위 띠)이 받는다(#190 전에는 최대 높이를 넘는 몫이 LCD 위 상단 띠였다).
/// - 본체가 아주 낮으면 키패드 높이가 0이 될 때까지만 LCD를 최소 높이로 지킨다. 간격은 본체 높이까지만 받아 합계가
///   본체 높이를 넘지 않는다.
({double lcd, double gap, double keypad}) _divideBodyHeight(
  double bodyHeight, {
  required double lcdMaxHeight,
  required double keypadMaxHeight,
}) {
  final gap = math.min(CalcTheme.screenLcdKeypadGap, bodyHeight);
  final available = bodyHeight - gap;
  final lcdMax = math.max(CalcTheme.screenLcdMinHeight, lcdMaxHeight);
  final lcdBase = math.min(
    (bodyHeight * CalcTheme.screenLcdHeightRatio).clamp(
      CalcTheme.screenLcdMinHeight,
      lcdMax,
    ),
    available,
  );
  final keypad = math.min(available - lcdBase, keypadMaxHeight);
  return (lcd: available - keypad, gap: gap, keypad: keypad);
}

/// 폭 [lcdWidth] LCD의 최대 높이 (dp) — 폭 기준 최대 높이(폭 / [CalcTheme.screenLcdMinAspectRatio])와 줄 글자 상한
/// 높이([LcdFontSizes.heightAtMaxLineFont], #189) 중 낮은 쪽. 어느 쪽이든 그보다 높이면 줄 글자는 커지지 않고 입력·결과
/// 줄 사이만 벌어진다. 최소 높이([CalcTheme.screenLcdMinHeight])는 호출하는 배치가 따로 지킨다.
double _lcdMaxHeightOf(double lcdWidth) => math.min(
  lcdWidth / CalcTheme.screenLcdMinAspectRatio,
  LcdFontSizes.heightAtMaxLineFont,
);

/// 키패드가 쓰지 못해 남는 높이를 LCD가 받을 수 있는 최대 높이 (dp, #190) — 줄 글자 상한 높이([LcdFontSizes.heightAtMaxLineFont],
/// #189)다(LCD 최소 높이가 더 높으면 최소 높이). 폭 기준 최대 높이([_lcdMaxHeightOf])는 목표 높이를 정할 때만 쓰고, 남는 높이는
/// 그보다 높게 받는다 — 상단 띠(#41)를 없앤 자리를 LCD가 쓰게 한다. 그보다 남으면 LCD 위가 빈다(계산 기록 #145의 자리).
final double _lcdAbsorbMaxHeight = math.max(
  CalcTheme.screenLcdMinHeight,
  LcdFontSizes.heightAtMaxLineFont,
);

/// 접힘선 없는 가로로 넓은 창의 "가로형" 배치 (#142, [ScreenArrangement.landscape]). 기준은 [CalcTheme]의 "가로형 배치"
/// 절을 따른다.
///
/// 오른손잡이([Handedness.right]) 기준 (왼손잡이는 좌우 대칭 — 숫자부와 활성 LCD가 왼쪽):
/// ```
///  ┌────────────────────┐  ┌──────────────────────┐ ← 본체 위
///  │ 계산 기록 [history] │  │    활성 LCD [lcd]     │ ← 위 띠 ([band])
///  ├────────────────────┘  └──────────────────────┤
///  │ 상단 조작부 + 함수부 │  │       숫자부          │ ← 넓은 배열 키패드 [keypad]
///  │      5행 × 6열      │  │      4행 × 5열        │
///  └────────────────────┴──┴──────────────────────┘ ← 본체 아래
///   └──── 블록 ────────┘ 간격 └──── 블록 ─────────┘
/// ```
/// - 키패드: 넓은 배열([KeypadArrangement.wide])로 본체 폭 전체를 쓰고 본체 아래에 붙인다. 높이는 넓은 배열의 세로 한계
///   ([KeypadMetrics.fitSize])까지다. 숫자부는 주로 쓰는 손 쪽 블록이다([numbersOnLeft]).
/// - 높이 나누기: 세로형([CalcScreenLayout])과 같은 규칙을 위 띠 폭 전체(본체 폭)로 쓴다 — LCD 목표 비율
///   ([CalcTheme.screenLcdHeightRatio]) · 최소 높이 · 최대 높이(본체 폭 / [CalcTheme.screenLcdMinAspectRatio] — 세로형과 달리
///   줄 글자 상한 높이로 줄이지 않는다, #189) 안에서 위 띠,
///   나머지는 키패드가 세로 한계까지 받고, 키패드가 쓰지 못하는 높이는 모두 위 띠가 받는다(#190 — 상단 띠가 없다). 위 띠의 높이는 기록 영역 유무와 무관하다 — 그래서 기록 영역이 생기고
///   없어지는 경계(창 높이·폭 어느 쪽으로 넘어도)에서 키·위 띠 높이가 튀지 않는다(#142 R1: 블록 폭으로 위 띠 최대 높이를
///   정하면 본체 폭 461 → 461.5에서 LCD가 228.8 → 128dp로 줄고 빈 띠가 생겼다).
/// - 기록 영역이 있을 때: 기록 영역은 위 띠 전체이고, 활성 LCD는 블록 폭의 최대 높이([_lcdMaxHeightOf] — 블록 /
///   [CalcTheme.screenLcdMinAspectRatio](#142 R2)와 줄 글자 상한 높이(#189) 중 낮은 쪽, 하한 [CalcTheme.screenLcdMinHeight])까지만
///   위 띠 아래쪽(키패드 바로 위)에 둔다 — 그보다 높이면 글자는 커지지 않고 식과 답만 세로로 멀어진다. 위 띠가 그보다 높으면
///   활성 LCD 위가 빈다(12.9인치 iPad 가로: 위 띠 519.1, 활성 LCD 655×273.5 — 기록 영역은 위 띠 전체를 쓴다).
///   기록 영역이 없으면 활성 LCD는 띠 폭 전체이고 높이는 같은 최대 높이까지다 — 위 띠가 그보다 높으면 활성 LCD 위가 빈다.
/// - 위 띠: 키패드 블록에 맞춰 둘로 나눈다. 숫자부 위가 활성 LCD, 함수부 위가 계산 기록 영역(`HistoryPanel`, 내용은 #145)이고
///   둘 사이는 키패드의 블록 사이 간격과 같다. LCD 하나를 전체 폭으로 늘이면 식은 왼쪽 끝, 답은 오른쪽 끝으로 멀어진다
///   (사용자 결정). 다음 중 하나면 기록 영역을 두지 않고([history]가 `null`) 활성 LCD가 띠 폭 전체를 쓴다.
///   - 위 띠가 [CalcTheme.screenLandscapeHistoryMinHeight]보다 낮다 (가로 폰 등 — 띠가 LCD 최소 높이에 묶인 창)
///   - 블록이 [CalcTheme.screenLandscapeHistoryMinLcdWidth]보다 좁다 (좁은 창)
///   - 블록 폭 활성 LCD의 줄 글자가 띠 폭 전체 LCD의 [CalcTheme.screenLandscapeHistoryMinLcdFontRatio]배보다 작다 (#142 R2 —
///     위 띠가 높은데 블록이 좁은 창. 경계에서 줄 글자가 30%보다 많이 줄지 않게 한다)
///   기록 영역이 없는 가로형의 무과금 광고 자리는 #18에서 정한다(기록 영역을 줄여 넣을 곳이 없다).
/// - 모든 영역은 본체 안에 있다 (음수·비유한 크기는 0으로 본다).
@immutable
class CalcLandscapeLayout {
  /// 활성 LCD 영역 (본체 좌표, dp)
  final Rect lcd;

  /// 계산 기록 영역 (본체 좌표, dp). 위 띠가 낮거나 좁아 두지 않으면 `null`.
  final Rect? history;

  /// 키패드 영역 (본체 좌표, dp) — [KeypadArrangement.wide] 배열
  final Rect keypad;

  /// 숫자부(와 활성 LCD)를 왼쪽에 두는지 — 왼손잡이
  final bool numbersOnLeft;

  /// 위 띠 전체 (본체 윗변 ~ 키패드 위 간격, 본체 폭 전체, 본체 좌표) — 활성 LCD와 기록 영역이 이 안에 있다. 높이는 기록
  /// 영역 유무와 무관하다. 활성 LCD가 이보다 낮으면(블록 폭 실물 비율 #142 R2, 줄 글자 상한 #189) 활성 LCD 위가 빈다.
  final Rect band;

  const CalcLandscapeLayout._({
    required this.lcd,
    required this.history,
    required this.band,
    required this.keypad,
    required this.numbersOnLeft,
  });

  /// [body] (시스템 인셋·화면 여백을 뺀 본체 영역)의 가로형 배치. [handedness]가 숫자부·활성 LCD 쪽을 정한다.
  factory CalcLandscapeLayout.of(Size body, Handedness handedness) {
    double finite(double v) => v.isFinite ? math.max(0.0, v) : 0.0;
    final width = finite(body.width);
    final height = finite(body.height);
    final numbersOnLeft = !handedness.keypadOnRight;
    final block = KeypadMetrics.wideBlockWidthOf(width);
    final keypadMaxHeight = KeypadMetrics.fitSize(
      Size(width, double.infinity),
      KeypadArrangement.wide,
    ).height;
    // 위 띠의 높이는 띠 폭 전체로 정한다 — 기록 영역 유무와 무관하다. 위 띠는 본체 윗변부터다(#190).
    final base = _divideBodyHeight(
      height,
      lcdMaxHeight: width / CalcTheme.screenLcdMinAspectRatio,
      keypadMaxHeight: keypadMaxHeight,
    );
    final band = Rect.fromLTWH(0, 0, width, base.lcd);
    // 남는 높이(반올림 오차 등)는 키패드가 받는다 (세로형 [_stackedRectsOf]와 같다).
    final keypadTop = math.min(band.bottom + base.gap, height);
    final split = _splitBandOverWideKeypad(
      band,
      block,
      numbersOnLeft: numbersOnLeft,
    );
    return CalcLandscapeLayout._(
      lcd: split.lcd,
      history: split.history,
      band: band,
      keypad: Rect.fromLTRB(0, keypadTop, width, height),
      numbersOnLeft: numbersOnLeft,
    );
  }

  @override
  String toString() =>
      'CalcLandscapeLayout(band: $band, lcd: $lcd, history: $history, '
      'keypad: $keypad, numbersOnLeft: $numbersOnLeft)';
}

/// 넓은 배열 키패드 위의 띠 [band](본체 좌표)를 키패드 블록(폭 [block])에 맞춰 활성 LCD와 계산 기록 영역으로 나눈다 —
/// 가로형([CalcLandscapeLayout], #142)과 가로 접힘선 기준 배치의 넓은 배열([CalcTabletopLayout], #143)이 같이 쓴다.
/// 키패드는 띠와 같은 폭이고 바로 아래(가로형) 또는 접힘선 건너(접힘선 기준 배치)에 있다고 본다.
/// - 기록 영역이 있을 때: 기록 영역은 띠 높이 전체(함수부 블록 위)이고, 활성 LCD는 숫자부 블록 위에서 블록 폭의 최대 높이
///   ([_lcdMaxHeightOf] — 실물 비율 #142 R2, 줄 글자 상한 #189, 하한 [CalcTheme.screenLcdMinHeight])까지만 띠 아래쪽(키패드
///   쪽)에 붙인다. 그보다 높이면 글자는 커지지 않고 식과 답만 세로로 멀어진다.
/// - 기록 영역을 두지 않는 조건([CalcLandscapeLayout] 문서): 띠가 [CalcTheme.screenLandscapeHistoryMinHeight]보다 낮거나,
///   블록이 [CalcTheme.screenLandscapeHistoryMinLcdWidth]보다 좁거나, 블록 폭 활성 LCD의 줄 글자가 띠 폭 전체 LCD의
///   [CalcTheme.screenLandscapeHistoryMinLcdFontRatio]배보다 작다. 그때 활성 LCD는 띠 폭 전체이고 높이는 같은 최대 높이까지
///   띠 아래쪽에 붙는다.
/// [numbersOnLeft]면 숫자부(와 활성 LCD)가 왼쪽 블록이다.
({Rect lcd, Rect? history}) _splitBandOverWideKeypad(
  Rect band,
  double block, {
  required bool numbersOnLeft,
}) {
  final width = band.width;
  final bandHeight = band.height;
  double activeLcdHeightOf(double lcdWidth) => math.min(
    bandHeight,
    math.max(CalcTheme.screenLcdMinHeight, _lcdMaxHeightOf(lcdWidth)),
  );
  final blockLcdHeight = activeLcdHeightOf(block);
  final fullLcdHeight = activeLcdHeightOf(width);
  // 기록 영역을 두면 활성 LCD 줄 글자가 띠 폭 전체일 때보다 많이 작아지지 않아야 한다 — 폭 방향 경계에서 글자가 절반으로
  // 튀지 않게 한다(#142 R2: 본체 폭 626 → 626.5에서 49.5 → 23.6dp). 글자 크기는 배율 반영 전 기준으로 잰다. 비교 대상은
  // 기록 영역이 없을 때 그릴 띠 폭 전체 LCD다 — `forSize`가 줄 글자 상한(#189)을 반영하므로 큰 창은 그 글자가 상한에 묶인다.
  double lineFontOf(Size lcd) =>
      LcdFontSizes.forSize(lcd, TextScaler.noScaling).input;
  final withHistory =
      bandHeight >= CalcTheme.screenLandscapeHistoryMinHeight &&
      block >= CalcTheme.screenLandscapeHistoryMinLcdWidth &&
      lineFontOf(Size(block, blockLcdHeight)) >=
          lineFontOf(Size(width, fullLcdHeight)) *
              CalcTheme.screenLandscapeHistoryMinLcdFontRatio;
  if (!withHistory) {
    // 활성 LCD는 띠 아래(키패드 쪽)에 붙는다.
    return (
      lcd: Rect.fromLTWH(
        band.left,
        band.bottom - fullLcdHeight,
        width,
        fullLcdHeight,
      ),
      history: null,
    );
  }
  // 활성 LCD는 띠 아래(키패드 쪽)에 붙이고, 기록 영역은 띠 높이 전체를 쓴다.
  final lcdTop = band.bottom - blockLcdHeight;
  final lcdLeft = numbersOnLeft ? band.left : band.right - block;
  final historyLeft = numbersOnLeft ? band.right - block : band.left;
  return (
    lcd: Rect.fromLTWH(lcdLeft, lcdTop, block, blockLcdHeight),
    history: Rect.fromLTWH(historyLeft, band.top, block, bandHeight),
  );
}

/// 패널 [panel](본체 좌표) 맨 위에 패널 폭 전체 활성 LCD를 두고 그 아래에 계산 기록 영역을 둔다 (#143) — 가로 접힘선 실물
/// 배열의 위 패널(Flip 내부)과, 손 쪽 패널이 짧은 책 자세의 반대쪽 패널이 같이 쓴다.
/// - 활성 LCD 높이는 패널 폭의 최대 높이([_lcdMaxHeightOf], 하한 [CalcTheme.screenLcdMinHeight])까지다.
/// - 그 아래 [CalcTheme.screenLcdHistoryGap]을 두고 패널 끝까지 기록 영역이다. 기록이
///   [CalcTheme.screenHistoryBelowLcdMinHeight]보다 낮아지면 두지 않고, 활성 LCD가 패널을 줄 글자 상한 높이
///   ([_lcdAbsorbMaxHeight])까지 쓴다(세로형처럼).
({Rect lcd, Rect? history}) _lcdOverHistory(Rect panel) {
  final lcdHeight = math.min(
    panel.height,
    math.max(CalcTheme.screenLcdMinHeight, _lcdMaxHeightOf(panel.width)),
  );
  final historyTop = panel.top + lcdHeight + CalcTheme.screenLcdHistoryGap;
  final withHistory =
      panel.bottom - historyTop >= CalcTheme.screenHistoryBelowLcdMinHeight;
  return (
    lcd: Rect.fromLTWH(
      panel.left,
      panel.top,
      panel.width,
      withHistory ? lcdHeight : math.min(panel.height, _lcdAbsorbMaxHeight),
    ),
    history: withHistory
        ? Rect.fromLTRB(panel.left, historyTop, panel.right, panel.bottom)
        : null,
  );
}

/// 접힘선 기준 배치 후보 하나 ([CalcHingeSplitLayout]·[CalcTabletopLayout]을 화면이 같은 모양으로 다룬다)
typedef _HingeRegions = ({
  Rect lcd,
  Rect? history,
  Rect keypad,
  KeypadArrangement keypadArrangement,
  bool numbersOnLeft,
});

/// 세로 접힘선 기준 좌우 배치 (#25, #143, [ScreenArrangement.hingeSplit] — 폴더블 책 자세). 기준은 [CalcTheme]의 "접힘선
/// 기준 배치" 절을 따른다.
///
/// 오른손잡이([Handedness.right]) 기준 (왼손잡이는 좌우 대칭 — 손 쪽 패널이 왼쪽):
/// ```
///  ┌────────────────────┆──────────────────────┐ ← 본체 위
///  │                    ┆│      활성 LCD       ││
///  │      계산 기록      ┆├─────────────────────┤│
///  │    [history] —     ┆│                     ││
///  │    패널 전체        ┆│   50키 키패드        ││
///  │                    ┆│   (실물 배열)        ││
///  └────────────────────┆┴─────────────────────┘┘ ← 본체 아래
///  └── 반대쪽 패널 ─────┘ 접힘선 └─ 손 쪽 패널 ──┘
/// ```
/// 손 쪽 패널이 짧은 창 (분할 화면 등 — [shortHandPanel]):
/// ```
///  ┌────────────────────┆──────────────────────┐
///  │      활성 LCD       ┆│ (키가 일반 하한에 닿으면 빈 곳) ││
///  ├────────────────────┆│   50키 키패드        ││
///  │  계산 기록 (있으면)  ┆│   (본체 아래에 붙음)  ││
///  └────────────────────┆┴─────────────────────┘┘
/// ```
/// - 접힘선([hinge], 본체 좌표) 양쪽에 [CalcTheme.screenHingeMargin]씩 비운다. 주로 쓰는 손 쪽 패널이 손 쪽 패널, 다른
///   쪽이 반대쪽 패널이다.
/// - 보통은 손 쪽 패널에 세로형([CalcScreenLayout], #141)을 그 패널 크기로 그대로 쓴다 — 위에 활성 LCD, 아래에 실물 배열
///   키패드, 둘 다 패널 폭 전체. 그래서 폰(커버 화면)과 키 위치가 같다. 설정 키(ON)도 키패드 안에 있다(#190). 세로형처럼
///   키패드가 세로 한계에 닿아 남는 높이는 LCD가 줄 글자 상한 높이까지 받고, 그래도 남으면 LCD 위가 빈다. 반대쪽 패널은 높이
///   전체가 계산 기록 영역이다(`HistoryPanel`, 내용은 #145).
/// - 손 쪽 패널이 짧은 창([shortHandPanel], #143 R1·R2, 2026-11-27 사용자 결정): 세로형의 가장 낮은 키가 일반 하한
///   ([CalcTheme.keyTouchHeightFloor])보다 낮고, 키패드가 패널 높이를 다 쓰면 키가 더 커지는 창은 활성 LCD를 반대쪽 패널
///   맨 위로 옮긴다([_lcdOverHistory] — 그 아래 기록, 기록이 최소 높이에 못 미치면 없음). 키패드는 손 쪽 패널 높이(위
///   시스템 제스처 영역 아래 — 아래 항목)까지 쓰되 키가 일반 하한을 넘지 않는 높이로 줄여 본체 아래에 붙인다 — 그래서 창 높이가 늘어 세로형의 키가 일반 하한에 닿는
///   순간 키 크기가 그대로(28dp) 이어지며 LCD가 손 쪽 패널로 돌아온다(R2: 줄이지 않으면 841×508 → 510에서 39.8 → 28.1dp로
///   줄었다). 그 사이 키패드 위가 빈다. 세로형 그대로면 LCD 최소 높이(112dp)가 짧은 패널 높이를 먼저 가져가 키가 위아래
///   배치와 같아지고(841×355: 16.2dp), 쓸 수 있는 크기 경계에서 접힘선을 가로지르는 가로형(31.6dp)과 키가 2배로 튀었다.
///   패널 폭에 묶여 키가 커지지 않는 창(접힘선이 치우쳐 손 쪽 패널이 좁은 창)과, 반대쪽 패널이 활성 LCD 최소 폭
///   ([CalcTheme.screenShortBookLcdMinWidth] 200dp)보다 좁은 창은 세로형 그대로다. 기록 패널의 최소 폭은 두지 않는다 —
///   좁은 기록을 어떻게 보일지는 #145에서 정한다.
/// - 위 시스템 제스처 영역(#172): 영역이 본체 윗변 아래로 들어오는 기기(`topGestureDepth` > 0)는 짧은 손 쪽 패널의 키패드가
///   그 아래부터만 쓴다 — 첫 행이 영역에 들면 그 행만 손을 뗄 때 입력된다(#50). 그만큼 비우면 키가 쓸 수 있는 크기보다 작아지는
///   창은 그 크기를 지키는 만큼만 비운다([_keypadRoomBelowTopGesture]). 보통 책 자세는 키패드 위에 활성 LCD가 있어 해당하지
///   않는다(깊이가 활성 LCD 최소 높이 + 간격 120dp 이상인 기기는 없다고 본다 — 실측 최대 깊이 4.2dp(위 제스처 − 인셋 12.2dp). 그런 기기는 키패드가
///   패널 높이를 다 써도 키가 커지지 않아 세로형으로 돌아가고, 그 첫 행은 영역에 든다 — screen_layout_test가 이 동작을 고정한다).
/// - LCD·기록·키패드 어느 것도 접힘선 위에 놓이지 않는다. 모든 영역은 본체 안에 있다(음수·비유한 크기는 0으로 본다).
@immutable
class CalcHingeSplitLayout {
  /// 활성 LCD 영역 (본체 좌표, dp) — 손 쪽 패널 위 (손 쪽 패널이 짧으면 반대쪽 패널 맨 위, [shortHandPanel])
  final Rect lcd;

  /// 계산 기록 영역 (본체 좌표, dp) — 반대쪽 패널 전체. 손 쪽 패널이 짧으면([shortHandPanel]) 반대쪽 패널의 활성 LCD
  /// 아래이고, 그 높이가 [CalcTheme.screenHistoryBelowLcdMinHeight]에 못 미치면 `null`이다.
  final Rect? history;

  /// 키패드 영역 (본체 좌표, dp) — 손 쪽 패널 아래(본체 아래에 붙음), 실물 배열
  final Rect keypad;

  /// 손 쪽 패널이 짧아 활성 LCD를 반대쪽 패널로 옮겼는지 (#143 R1)
  final bool shortHandPanel;

  const CalcHingeSplitLayout._({
    required this.lcd,
    required this.history,
    required this.keypad,
    required this.shortHandPanel,
  });

  /// [body] (시스템 인셋·화면 여백을 뺀 본체 영역)를 세로 접힘선 [hinge](본체 좌표)로 나눠 [handedness] 쪽 패널에 세로형을
  /// 둔다. [topGestureDepth]는 위 시스템 제스처 영역이 본체 윗변 아래로 들어오는 깊이다([CalcTheme.screenTopGestureDepth],
  /// #172) — 손 쪽 패널이 짧아 키패드가 패널 높이를 쓸 때 키패드 윗변을 그 아래에 둔다.
  factory CalcHingeSplitLayout.of(
    Size body,
    Rect hinge,
    Handedness handedness, {
    double topGestureDepth = 0,
  }) {
    double finite(double v) => v.isFinite ? math.max(0.0, v) : 0.0;
    final width = finite(body.width);
    final height = finite(body.height);
    final onRight = handedness.keypadOnRight;

    // 접힘선 왼쪽 끝·오른쪽 시작 (본체 밖이면 본체 가장자리로 자른다)
    final leftEnd = (finite(hinge.left) - CalcTheme.screenHingeMargin).clamp(
      0.0,
      width,
    );
    final rightStart = (finite(hinge.right) + CalcTheme.screenHingeMargin)
        .clamp(leftEnd, width);
    final handLeft = onRight ? rightStart : 0.0;
    final handRight = onRight ? width : leftEnd;
    final handSize = Size(handRight - handLeft, height);
    final other = onRight
        ? Rect.fromLTRB(0, 0, leftEnd, height)
        : Rect.fromLTRB(rightStart, 0, width, height);
    final hand = _stackedRectsOf(handSize);
    final portraitTouch = KeypadMetrics.minKeyTouchHeightOf(
      hand.keypad.size,
      KeypadArrangement.standard,
    );
    // 손 쪽 패널이 짧은 창 (#143 R1): 키패드가 패널 높이를 다 쓰면 키가 커질 때만 LCD를 반대쪽 패널로 옮긴다.
    // 반대쪽 패널이 활성 LCD 최소 폭보다 좁으면(접힘선이 치우친 창) 옮기지 않는다 — 줄 글자가 LCD 최소 높이 글자보다 작아진다.
    // "패널 높이"는 위 시스템 제스처 영역 아래부터다(#172) — 첫 행이 알림창 끌어내리기 영역에 들지 않게 한다.
    final fullKeypad = KeypadMetrics.fitSize(
      Size(
        handSize.width,
        _keypadRoomBelowTopGesture(handSize, topGestureDepth),
      ),
    );
    final fullTouch = KeypadMetrics.minKeyTouchHeightOf(
      fullKeypad,
      KeypadArrangement.standard,
    );
    if (portraitTouch < CalcTheme.keyTouchHeightFloor &&
        other.width >= CalcTheme.screenShortBookLcdMinWidth &&
        fullTouch > portraitTouch) {
      final split = _lcdOverHistory(other);
      // 키가 일반 하한을 넘지 않는 높이까지만 쓴다(#143 R2 — 세로형으로 돌아오는 경계에서 키가 줄지 않게). 키캡이 48dp보다
      // 작은 동안 가장 낮은 키의 터치 높이는 키패드 높이에 비례하므로 비율로 줄인다.
      final keypadHeight = fullTouch > CalcTheme.keyTouchHeightFloor
          ? fullKeypad.height * CalcTheme.keyTouchHeightFloor / fullTouch
          : fullKeypad.height;
      return CalcHingeSplitLayout._(
        lcd: split.lcd,
        history: split.history,
        keypad: Rect.fromLTWH(
          handLeft,
          height - keypadHeight,
          fullKeypad.width,
          keypadHeight,
        ),
        shortHandPanel: true,
      );
    }
    return CalcHingeSplitLayout._(
      lcd: hand.lcd.shift(Offset(handLeft, 0)),
      history: other,
      keypad: hand.keypad.shift(Offset(handLeft, 0)),
      shortHandPanel: false,
    );
  }

  /// 손 쪽 패널 [panel]에서 키패드가 쓸 높이 — 위 시스템 제스처 영역 깊이 [topGestureDepth]([CalcTheme.screenTopGestureDepth],
  /// 비유한·음수는 0) 아래 높이다(#172). 단, 그만큼 비우면 키가 쓸 수 있는 크기([CalcTheme.keyTouchHeightUsableMin])보다 작아지는
  /// 창은 그 크기를 지키는 높이까지만 비운다(#172 R1) — 첫 행이 영역에 들어 손을 뗄 때 입력되더라도(#50) 계산기를 쓸 수 있는
  /// 쪽이 "창이 너무 작다" 안내보다 낫다. 그래서 쓸 수 있는 크기 경계가 깊이와 무관하고, 높이를 키우면 키패드 윗변이 영역 안에서
  /// 영역 아랫변까지 이어서 내려온다(키는 줄지 않는다). 패널 높이 전체로도 쓸 수 없는 창은 깊이만큼 비운다(어차피 접힘선 기준 배치를
  /// 쓰지 않는다 — `_Body`가 위아래 배치·가로형으로 대체하거나 안내를 띄운다).
  static double _keypadRoomBelowTopGesture(Size panel, double topGestureDepth) {
    final height = panel.height;
    final depth = topGestureDepth.isFinite
        ? math.max(0.0, topGestureDepth)
        : 0.0;
    final room = math.max(0.0, height - depth);
    if (depth == 0) return room;
    final whole = KeypadMetrics.fitSize(panel);
    final wholeTouch = KeypadMetrics.minKeyTouchHeightOf(
      whole,
      KeypadArrangement.standard,
    );
    if (wholeTouch < CalcTheme.keyTouchHeightUsableMin) return room;
    // 키캡이 48dp보다 작은 동안(쓸 수 있는 크기 근처) 가장 낮은 키의 터치 높이는 키패드 높이에 비례한다(실물 배열의 가장 낮은
    // 키 = 키패드 높이의 약 0.085배). 키캡이 48dp 이상인 큰 패널(높이 약 560dp 이상)에서는 이 비례가 틀리지만, 그 결과는
    // 깊이가 패널 높이에서 약 190dp를 뺀 값보다 깊을 때만 쓰인다 — 깊이는 120dp 미만으로 본다(위 클래스 문서). 반올림 오차로 경계
    // 아래로 떨어지지 않게 조금(0.01dp) 더 둔다.
    final usableHeight =
        whole.height * CalcTheme.keyTouchHeightUsableMin / wholeTouch + 0.01;
    return math.max(room, math.min(height, usableHeight));
  }

  /// 화면이 다루는 모양 ([_Body])
  _HingeRegions get _regions => (
    lcd: lcd,
    history: history,
    keypad: keypad,
    keypadArrangement: KeypadArrangement.standard,
    numbersOnLeft: false,
  );

  @override
  String toString() =>
      'CalcHingeSplitLayout(lcd: $lcd, history: $history, keypad: $keypad, '
      'shortHandPanel: $shortHandPanel)';
}

/// 가로 접힘선 기준 위아래 배치 (#25, #143, [ScreenArrangement.hingeStacked]) — 접힘선이 가로인 폴더블 내부 화면(Fold를
/// 가로로 돌림, Pixel Fold를 세로로 돌림, Flip 내부). 펼침·살짝 꺾음·반 접음(테이블톱 자세, Flip의 Flex 모드)에서 같다.
/// 기준은 [CalcTheme]의 "접힘선 기준 배치" 절을 따른다.
///
/// 아래 패널이 넓어 넓은 배열의 키가 더 큰 경우 (Fold 가로·Pixel Fold 세로) — 가로형([CalcLandscapeLayout])과 같은 구성이고
/// 위 띠와 키패드의 경계가 접힘선이다. 오른손잡이 기준(왼손잡이는 좌우 대칭 — 숫자부와 활성 LCD가 왼쪽):
/// ```
///  ┌────────────────────┐  ┌──────────────────────┐ ← 본체 위
///  │ 계산 기록 [history] │  │    활성 LCD [lcd]     │ ← 위 패널
///  ├ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ 접힘선 ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤
///  │ 상단 조작부 + 함수부 │  │       숫자부          │ ← 아래 패널: 넓은 배열 키패드
///  └────────────────────┴──┴──────────────────────┘ ← 본체 아래
/// ```
/// 아래 패널이 좁아 실물 배열의 키가 더 큰 경우 (Flip 내부):
/// ```
///  ┌──────────────────────────┐ ← 본체 위
///  │       활성 LCD [lcd]      │ ← 위 패널 맨 위
///  │  계산 기록 [history] ↓    │   그 아래로 기록(최근 것부터)
///  ├ ─ ─ ─ ─ 접힘선 ─ ─ ─ ─ ─ ┤
///  │   50키 키패드 (실물 배열)  │ ← 아래 패널 폭 전체
///  └──────────────────────────┘ ← 본체 아래
/// ```
/// - 접힘선([hinge], 본체 좌표) 위아래로 [CalcTheme.screenHingeMargin]씩 비운다.
/// - 키패드: 아래 패널 폭 전체를 쓰고(#141의 폭 상한 없음 — #143까지 남겼던 테이블톱 폭 상한을 없앴다) 본체 아래에 붙인다.
///   높이는 배열의 세로 한계([KeypadMetrics.fitSize])까지다. 배열은 아래 패널에서 키가 큰 쪽이다
///   ([KeypadMetrics.preferredArrangementFor] — 가장 낮은 키 셀 높이, 같으면 실물 배열).
/// - 넓은 배열: 위 패널 전체를 가로형의 위 띠처럼 블록에 맞춰 나눈다([_splitBandOverWideKeypad]) — 숫자부 위가 활성 LCD
///   (접힘선 쪽에 붙음), 함수부 위가 기록 영역(위 패널 높이 전체). 숫자부와 활성 LCD는 주로 쓰는 손 쪽이다([numbersOnLeft]).
///   위 패널이 낮거나 블록이 좁으면 가로형과 같이 기록 영역을 두지 않고 활성 LCD가 패널 폭 전체를 쓴다.
/// - 실물 배열: 활성 LCD는 위 패널 맨 위에서 패널 폭 전체, 높이는 그 폭의 최대 높이([_lcdMaxHeightOf], 하한
///   [CalcTheme.screenLcdMinHeight])까지다. 그 아래 [CalcTheme.screenLcdHistoryGap]을 두고 위 패널 끝(접힘선 위 간격)까지
///   기록 영역이다. 기록 영역이 [CalcTheme.screenHistoryBelowLcdMinHeight]보다 낮아지면 두지 않고, 활성 LCD가 위 패널을 줄 글자
///   상한 높이([_lcdAbsorbMaxHeight])까지 쓴다(세로형처럼). 손잡이와 무관하다(키패드가 폭 전체다).
/// - 모든 영역은 본체 안에 있고 접힘선 위에 놓이지 않는다 (음수·비유한 크기는 0으로 본다).
@immutable
class CalcTabletopLayout {
  /// 활성 LCD 영역 (본체 좌표, dp)
  final Rect lcd;

  /// 계산 기록 영역 (본체 좌표, dp). 위 패널이 낮거나 좁아 두지 않으면 `null`.
  final Rect? history;

  /// 키패드 영역 (본체 좌표, dp) — [keypadArrangement] 배열의 [KeypadMetrics.fitSize] 결과 크기, 아래 패널 폭 전체
  final Rect keypad;

  /// 키패드 구역 배열 — 아래 패널에서 키가 더 큰 쪽 ([KeypadMetrics.preferredArrangementFor], #80)
  final KeypadArrangement keypadArrangement;

  /// 넓은 배열에서 숫자부(와 활성 LCD)를 왼쪽에 두는지 — 왼손잡이. 실물 배열이면 언제나 `false`다.
  final bool numbersOnLeft;

  const CalcTabletopLayout._({
    required this.lcd,
    required this.history,
    required this.keypad,
    required this.keypadArrangement,
    required this.numbersOnLeft,
  });

  /// [body] (시스템 인셋·화면 여백을 뺀 본체 영역)를 가로 접힘선 [hinge](본체 좌표)로 위아래로 나눈다. [handedness]가
  /// 넓은 배열의 숫자부·활성 LCD 쪽을 정한다.
  factory CalcTabletopLayout.of(Size body, Rect hinge, Handedness handedness) {
    double finite(double v) => v.isFinite ? math.max(0.0, v) : 0.0;
    final width = finite(body.width);
    final height = finite(body.height);
    final topEnd = (finite(hinge.top) - CalcTheme.screenHingeMargin).clamp(
      0.0,
      height,
    );
    final bottomStart = (finite(hinge.bottom) + CalcTheme.screenHingeMargin)
        .clamp(topEnd, height);

    final arrangement = KeypadMetrics.preferredArrangementFor(
      Size(width, height - bottomStart),
    );
    final keypadSize = KeypadMetrics.fitSize(
      Size(width, height - bottomStart),
      arrangement,
    );
    final keypad = Rect.fromLTWH(
      0,
      height - keypadSize.height,
      width,
      keypadSize.height,
    );
    final upper = Rect.fromLTWH(0, 0, width, topEnd);

    if (arrangement == KeypadArrangement.wide) {
      final numbersOnLeft = !handedness.keypadOnRight;
      final split = _splitBandOverWideKeypad(
        upper,
        KeypadMetrics.wideBlockWidthOf(width),
        numbersOnLeft: numbersOnLeft,
      );
      return CalcTabletopLayout._(
        lcd: split.lcd,
        history: split.history,
        keypad: keypad,
        keypadArrangement: arrangement,
        numbersOnLeft: numbersOnLeft,
      );
    }

    // 실물 배열: 위 패널 맨 위가 활성 LCD, 그 아래가 기록 영역이다.
    final split = _lcdOverHistory(upper);
    return CalcTabletopLayout._(
      lcd: split.lcd,
      history: split.history,
      keypad: keypad,
      keypadArrangement: arrangement,
      numbersOnLeft: false,
    );
  }

  /// 화면이 다루는 모양 ([_Body])
  _HingeRegions get _regions => (
    lcd: lcd,
    history: history,
    keypad: keypad,
    keypadArrangement: keypadArrangement,
    numbersOnLeft: numbersOnLeft,
  );

  @override
  String toString() =>
      'CalcTabletopLayout(lcd: $lcd, history: $history, '
      'keypad: $keypad ($keypadArrangement, numbersOnLeft: $numbersOnLeft))';
}

/// 세로형([CalcScreenLayout])의 LCD·키패드 영역 ([body] 좌표) — 위아래 배치와 책 자세의 손 쪽 패널이 쓴다.
({Rect lcd, Rect keypad}) _stackedRectsOf(Size body) {
  final layout = CalcScreenLayout.of(body);
  final width = body.width.isFinite ? math.max(0.0, body.width) : 0.0;
  final height = body.height.isFinite ? math.max(0.0, body.height) : 0.0;
  // LCD와 키패드 모두 본체 폭 전체다 (#141).
  final lcd = Rect.fromLTWH(0, layout.top, width, layout.lcdHeight);
  // 남는 높이(반올림 오차 등)는 키패드가 받는다.
  final keypad = Rect.fromLTRB(
    0,
    math.min(lcd.bottom + layout.gap, height),
    width,
    height,
  );
  return (lcd: lcd, keypad: keypad);
}

/// 계산기 메인 화면: LCD + 50키 키패드. 광고 없는 배치(과금 사용자 기준)이고, 화면을 다 채운다 (#141).
///
/// 창 크기와 접힘선에 따라 배치를 고른다 ([FormFactor.arrangementOf]).
/// - **위아래 배치("세로형")** (폰 세로 화면, 태블릿 세로·좁은 창, 폴더블 커버 화면): 아래 그림, [CalcScreenLayout].
///   LCD와 키패드가 본체 폭 전체를 쓴다(#141).
/// - **가로형 배치** (태블릿 가로, 가로로 돌린 폰, 분할 화면·데스크톱의 가로 창, #142): 아래에 넓은 키패드 배열, 위 띠에
///   활성 LCD(숫자부 위)와 계산 기록(함수부 위). 숫자부와 활성 LCD는 주로 쓰는 손([handednessProvider]) 쪽이다.
///   [CalcLandscapeLayout].
/// - **접힘선 없는 창은 세로형과 가로형 중 키가 큰 쪽**으로 그린다(#142, [FormFactor.picksFormByKeySize]) — 키 크기는 가장
///   낮은 키의 셀 높이([KeypadMetrics.minKeyCellHeightOf])로 비교하고, 같으면 세로형이다. 두 키 크기가 창 크기에 따라
///   연속으로 변하므로 바뀌는 경계에서 키가 튀지 않는다([CalcTheme] "가로형 배치" 절).
/// - **접힘선 기준 배치** (폴더블 내부 화면, #25, #143 — 펼침·반 접힘 모두): 세로 접힘선이면 책 자세(손 쪽 패널에 세로형,
///   반대쪽 패널에 계산 기록, 손 쪽 패널이 짧으면 활성 LCD도 반대쪽 패널 — [CalcHingeSplitLayout]), 가로 접힘선이면 위 패널에 활성 LCD·기록, 아래 패널에 키패드
///   ([CalcTabletopLayout]). 키가 쓸 수 있는 크기([CalcTheme.keyTouchHeightUsableMin])면 접힘선을 가로지르는 배치의 키가
///   더 커도 쓴다([CalcTheme] "접힘선 기준 배치" 절). 접힘선이 둘 이상 창을 가로지르면(펼친
///   트라이폴드, #144) 접힘선을 무시하고 접힘선 없는 창과 같게 그린다([FormFactor.crossesMultipleHinges]).
/// - **설정**: 키패드의 ON 키가 설정 키다(#190, [settingsKey]) — 누르면 설정이 열린다([SettingsLauncher]). LCD 위 상단
///   띠(장식·설정 버튼, #41)는 없다. 모든 배치에서 본체 윗변부터 LCD(가로형은 위 띠)다.
/// - **짧은 창** (#38): 폴더블 기기·접힘 정보가 있어 위아래 배치로 그리는 창도 짧은 변 600dp 미만이면 위아래 배치와 가로형
///   중 키가 큰 쪽으로 그린다. 어느 배치든 그린 키가 [CalcTheme.keyTouchHeightUsableMin]보다 낮으면 계산기 대신 창을
///   키워 달라는 안내를 띄운다([CalcTheme] "짧은 창" 절).
/// - 스크린리더 읽기 순서: 활성 LCD → 계산 기록 → 키패드 (#142). 설정 키는 키패드 안이다(#190). 화면 위치와 무관하게
///   모든 배치에서 같다
///   (가로형은 기록이 활성 LCD 왼쪽에 있어도 LCD를 먼저 읽는다). 키패드 안은 함수부 다음 숫자부다(`CalcKeypad`).
/// - 맨 아래 광고 슬롯은 없다 (#141, 사용자 결정 — 광고 없는 배치가 기준). 본체는 아래 시스템 인셋 위 아래
///   여백([CalcTheme.screenBottomMargin] — 보통 화면 여백, 아래 제스처 영역이 인셋보다 화면 여백 넘게 깊으면 그 초과분만큼,
///   #63)까지 쓴다.
///   그래서 맨 아래 키 행은 홈 제스처 영역 밖에 있어 누르는 순간 입력된다(양 끝 키 중 좌우 뒤로가기 영역에 든
///   부분은 다음의 좌우 여백 항목대로 손을 뗄 때 입력된다). 무과금 사용자의 광고는 이 배치에서
///   LCD 쪽 한 영역을 줄여 넣는다(화면 맨 위·기록 영역, #18).
///
/// 위아래 배치 구성 (위 → 아래):
/// ```
///  ┌──────────────────────────┐  ← 상단 시스템 인셋 (SafeArea)
///  │       (화면 여백)        │
///  │          LCD             │  ← [CalcScreenLayout.lcdHeight] — 키패드가 쓰지 못하는 높이도 받는다 (#190)
///  │        (간격)            │
///  │     50키 키패드          │  ← [CalcScreenLayout.keypadHeight]
///  │       (아래 여백)        │  ← [CalcTheme.screenBottomMargin] (#63)
///  └──────────────────────────┘  ← 하단 시스템 인셋 (SafeArea)
/// ```
///
/// - 키패드는 스크롤 영역 밖에 고정 배치한다(`CalcKeyButton`은 누르는 순간 입력한다).
/// - LCD만 상태를 구독하고 키패드는 notifier만 읽으므로, 키 입력으로 키패드 50개가 다시 그려지지 않는다.
/// - LCD 글자 크기는 LCD가 자기 크기에서 [LcdFontSizes.forSize]로 산출한다 (`fitFontsToSize`).
/// - 좌우 여백은 [CalcTheme.screenPadding]만 둔다. 가장자리 열의 바깥쪽 일부가 Android 제스처
///   내비게이션 영역에 걸릴 수 있지만, `CalcKeyButton`이 그 영역에서 시작한 터치를 손을 뗄 때
///   확정하므로 뒤로가기 제스처와 충돌하지 않는다. 제스처 폭만큼 여백을 두면 모든 폰에서 키패드가 좁아진다.
///   아래 제스처 영역은 반대로 여백으로 피한다(위 광고 슬롯 항목) — 깊이 차이가 작아 대부분 기기에서 비용이 없다.
/// - 위 제스처 영역(알림창 끌어내리기)은 본체 위 여백으로 피하지 않는다 — 거의 모든 배치에서 본체 윗변에는 키가 아니라
///   활성 LCD나 계산 기록 영역이 온다(기록을 누르거나 스크롤하게 되면 그 위쪽이 영역에 들 수 있다 — #145에서 정한다). 키패드가 본체 윗변 가까이 오는 배치(손 쪽 패널이 짧은 책 자세)만 키패드를 영역 아래에 둔다
///   ([CalcTheme.screenTopGestureDepth], #172).
/// - 배치는 기기 종류가 아니라 창 크기로 고른다 — 방향 고정이 무시되는 경우가 있다(`FormFactor` 참조).
///   폴더블 기기([foldableDeviceProvider])는 접힘 정보가 오기 전까지 위아래 배치다(짧은 변 600dp 미만 창은 짧은 창
///   규칙으로 가로형일 수 있다, #38). 앱 시작 때는
///   Android가 창 배치 첫 값에 접힘선이 있다고 알리면 `main()`이 그 정보가 올 때까지(최대 300ms) 첫 화면을 미룬다(#158) —
///   제때 오면 첫 프레임부터 접힘선 기준 배치다.
/// - 접기·펼치기·회전으로 배치가 바뀌어도 상태는 [calcProvider]에 있고 LCD·키패드 element도 유지된다(`_Body`).
class CalculatorScreen extends ConsumerWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 폴더블 여부는 화면 정보 변화를 받은 그 프레임에 바뀔 수 있다 (#70, [foldableDeviceProvider])
    return ValueListenableBuilder<bool>(
      valueListenable: ref.watch(foldableDeviceProvider),
      builder: (context, foldableDevice, _) =>
          _buildScreen(context, foldableDevice: foldableDevice),
    );
  }

  Widget _buildScreen(BuildContext context, {required bool foldableDevice}) {
    final window = MediaQuery.sizeOf(context);
    final features = MediaQuery.displayFeaturesOf(context);
    final arrangement = FormFactor.arrangementOf(
      window,
      features,
      foldableDevice: foldableDevice,
    );
    // 접힘선(화면 좌표)을 본체 좌표로 옮긴다. 이 화면은 화면 전체를 채우므로(앱 바 없음) 본체 원점은
    // 시스템 인셋(SafeArea) + 화면 여백 만큼 떨어져 있다. 미리보기처럼 화면을 흉내 내는 곳도
    // `ScreenCoordinateRoot`가 화면 크기 그대로 이 화면을 채우므로 같다. 이 가정이 깨지면
    // 디버그 모드에서 [_BodyOriginCheck]가 오류로 알린다.
    final padding = MediaQuery.paddingOf(context);
    final bodyOrigin = Offset(
      padding.left + CalcTheme.screenPadding,
      padding.top + CalcTheme.screenPadding,
    );
    final hinge = FormFactor.hingeOf(
      window,
      features,
    )?.bounds.shift(-bodyOrigin);
    // 아래 여백: 보통 화면 여백이고, 아래 시스템 제스처 영역이 본체 아래를 가리는 것(시스템 인셋·키보드)보다 화면 여백
    // 넘게 깊으면 그 초과분만큼 넓혀 본체가 영역에 닿지 않게 한다 (#63).
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final gestureInsets = MediaQuery.systemGestureInsetsOf(context);
    final bottomMargin = CalcTheme.screenBottomMargin(
      bottomInset: math.max(
        viewPadding.bottom,
        MediaQuery.viewInsetsOf(context).bottom,
      ),
      bottomGestureInset: gestureInsets.bottom,
    );
    // 위 제스처 영역이 본체 윗변 아래로 들어오는 깊이 (#172) — 키패드가 본체 윗변 가까이 오는 배치가 키패드를 그 아래에 둔다.
    // 본체 위 여백은 넓히지 않는다(본체 원점·접힘선 좌표가 그대로다, [CalcTheme.screenTopGestureDepth]).
    final topGestureDepth = CalcTheme.screenTopGestureDepth(
      topInset: padding.top,
      topGestureInset: gestureInsets.top,
    );
    // 진단 로그 (#118) — 기기별 시스템 인셋·제스처 영역을 실기기 logcat으로 잰다(진단 빌드에서만)
    if (LayoutLog.enabled) {
      LayoutLog.systemInsets(
        window: window,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        padding: padding,
        viewPadding: viewPadding,
        gestures: gestureInsets,
      );
    }
    return Scaffold(
      backgroundColor: CalcTheme.bodyBackground,
      // 맨 아래 광고 슬롯 없이 본체가 아래 시스템 인셋 위 아래 여백까지 쓴다 (#141, #63).
      // 본체 바탕(그라데이션·잔무늬·가장자리 선, #156)은 화면 전체에 깐다.
      body: CalcBodyBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: CalcTheme.screenPadding,
              top: CalcTheme.screenPadding,
              right: CalcTheme.screenPadding,
              bottom: bottomMargin,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => _BodyOriginCheck(
                expected: bodyOrigin,
                enabled: hinge != null,
                child: _Body(
                  body: Size(constraints.maxWidth, constraints.maxHeight),
                  arrangement: arrangement,
                  picksFormByKeySize: FormFactor.picksFormByKeySize(
                    window,
                    features,
                    foldableDevice: foldableDevice,
                  ),
                  smallWindow:
                      window.shortestSide <
                      FormFactor.largeScreenMinShortestSide,
                  hinge: hinge,
                  topGestureDepth: topGestureDepth,
                  // 진단 로그용 (#158) — 켜져 있을 때만 넘긴다
                  diagnostics: LayoutLog.enabled
                      ? (
                          window: window,
                          features: features,
                          foldableDevice: foldableDevice,
                          bodyOrigin: bodyOrigin,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 본체 원점을 시스템 인셋 + 화면 여백으로 추정한 값([expected], 화면 좌표)이 실제 위치와 같은지 디버그
/// 모드에서 확인한다 (#25 R1). 접힘선을 본체 좌표로 옮길 때만([enabled]) 확인하며, 다르면 접힘선 기준
/// 배치가 접힘선에서 어긋나므로 [FlutterError.reportError]로 알린다(그리기는 계속한다). 릴리스에서는 아무것도 하지 않는다.
class _BodyOriginCheck extends StatelessWidget {
  final Offset expected;
  final bool enabled;
  final Widget child;

  const _BodyOriginCheck({
    required this.expected,
    required this.enabled,
    required this.child,
  });

  /// 위치 비교 허용 오차 (dp)
  static const double _tolerance = 0.5;

  @override
  Widget build(BuildContext context) {
    assert(() {
      if (!enabled) return true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final box = context.findRenderObject();
        if (box is! RenderBox || !box.attached || !box.hasSize) return;
        final actual = ScreenCoordinateRoot.globalToScreen(
          context,
          box.localToGlobal(Offset.zero),
        );
        if ((actual - expected).distance > _tolerance) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: FlutterError(
                '계산기 본체 원점($actual)이 추정값($expected)과 다르다.\n'
                '접힘선을 본체 좌표로 옮길 때 CalculatorScreen이 화면 원점에서 화면 전체를 채운다고 가정한다. '
                '화면을 다른 위젯 안에 넣거나 앱 바를 더하면 접힘선 기준 배치가 접힘선에서 어긋난다.',
              ),
              library: 'altcalc layout',
              context: ErrorDescription('접힘선 기준 배치 확인 중'),
            ),
          );
        }
      });
      return true;
    }());
    return child;
  }
}

/// 상태를 구독해 LCD를 그린다. M1에서는 마지막 입력 기능의 각인을 입력 줄에 보여준다.
/// TODO(M2): 수식 AST(`MathNodeWidget`)와 결과 표시로 대체한다.
class _LcdPanel extends ConsumerWidget {
  const _LcdPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(lcdStatusProvider);
    final lastInput = ref.watch(calcProvider.select((s) => s.lastInput));
    final strings = CalcSemanticStrings.of(context);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        LcdDisplay(
          status: status,
          fitFontsToSize: true,
          input: Text(
            lastInput?.label ?? '',
            key: const ValueKey('lcd-input-text'),
            // 각인 기호 대신 기능 이름을 읽는다 (#20)
            semanticsLabel: lastInput == null
                ? null
                : strings.keyFunction(lastInput.id, lastInput.layer),
          ),
        ),
        // 스크린리더 알림 전용 노드 (LCD 왼쪽 위 1dp — 화면에 보이지 않고 터치를 가로채지 않는다)
        const Positioned(
          left: 0,
          top: 0,
          width: 1,
          height: 1,
          child: IgnorePointer(child: ScreenReaderAnnouncer()),
        ),
      ],
    );
  }
}

/// 계산기 상태 변화를 스크린리더로 알린다 (#20). 무엇을 알릴지는 [announcementFor]가 정한다.
///
/// 플랫폼마다 알리는 방법이 다르다 — Flutter 자체 위젯(InputDecorator)과 같은 기준
/// (`MediaQuery.supportsAnnounceOf`)으로 나눈다.
/// - **알림 지원(iOS 등)**: `SemanticsService.sendAnnouncement`. 스크린리더가 꺼져 있으면 보내지 않는다.
/// - **알림 미지원(Android)**: 이 위젯의 liveRegion 노드 라벨을 바꾼다. Android 엔진은 알림을 지원하지 않고
///   (Android 16부터 API 폐기 예정), liveRegion 노드는 **라벨이 바뀔 때만** 읽힌다. 같은 말이 이어져도
///   ("7" → "7") 읽히도록 매번 보이지 않는 문자(U+200B)를 붙였다 뗐다 해 라벨을 바꾼다.
///
/// 상태 표시줄·입력 줄을 liveRegion으로 두지 않는 이유: 상태 표시줄 전체가 매번 다시 읽히고, 켜짐/꺼짐
/// 의미가 전달되지 않으며, 같은 입력이 이어지면 입력 줄 라벨이 그대로라 읽히지 않는다(리뷰 R2).
@visibleForTesting
class ScreenReaderAnnouncer extends ConsumerStatefulWidget {
  const ScreenReaderAnnouncer({super.key});

  /// 연속된 같은 말을 구분하려고 번갈아 붙이는 글자 (스크린리더는 읽지 않는다)
  static const String repeatMarker = '\u200B';

  @override
  ConsumerState<ScreenReaderAnnouncer> createState() =>
      _ScreenReaderAnnouncerState();
}

class _ScreenReaderAnnouncerState extends ConsumerState<ScreenReaderAnnouncer> {
  String _message = '';
  bool _marked = false;

  @override
  Widget build(BuildContext context) {
    final strings = CalcSemanticStrings.of(context);
    final supportsAnnounce = MediaQuery.supportsAnnounceOf(context);
    final view = View.of(context);
    final direction = Directionality.of(context);
    ref.listen(
      calcProvider.select((s) => (s.modifier, s.inputCount, s.lastInput)),
      (previous, next) {
        // 직전 선택 값이 없으면(오류 등) 비교할 수 없으므로 알리지 않는다.
        if (previous == null) return;
        final message = announcementFor(strings, previous, next);
        if (message == null) return;
        if (supportsAnnounce) {
          if (!SemanticsBinding.instance.semanticsEnabled) return;
          unawaited(
            SemanticsService.sendAnnouncement(view, message, direction),
          );
        } else {
          setState(() {
            _marked = !_marked;
            _message = _marked
                ? message
                : '$message${ScreenReaderAnnouncer.repeatMarker}';
          });
        }
      },
    );
    if (supportsAnnounce) return const SizedBox.shrink();
    return Semantics(
      key: const ValueKey('screen-reader-announcer'),
      container: true,
      liveRegion: true,
      label: _message,
      child: const SizedBox.expand(),
    );
  }
}

/// 상태 변화([previous] → [next])에 대해 스크린리더로 알릴 말. 알릴 것이 없으면 `null`. (#20)
///
/// 상태는 `(모디파이어 대기, 입력 수, 마지막 입력)`이다.
/// - 기능이 입력되면(입력 수 증가) 그 기능 이름을 알린다. 시프트·알파 대기가 그 입력으로 풀렸다는 것도
///   이것으로 전달된다(예: 시프트 → sin → "아크사인"). 길게 눌러 반복되는 입력은 알리지 않는다.
/// - 입력 없이 대기만 바뀌면: 켜짐("시프트 켜짐"), 또는 꺼짐(같은 키를 다시 누름, 기능 없는 층의 키).
@visibleForTesting
String? announcementFor(
  CalcSemanticStrings strings,
  (KeyModifier, int, KeyInput?) previous,
  (KeyModifier, int, KeyInput?) next,
) {
  final (before, countBefore, _) = previous;
  final (after, countAfter, input) = next;
  if (countAfter != countBefore) {
    if (input == null || input.isRepeat) return null;
    return strings.keyFunction(input.id, input.layer);
  }
  if (before == after) return null;
  if (after != KeyModifier.none) {
    return strings.modifierChanged(after, on: true);
  }
  return strings.modifierChanged(before, on: false);
}

/// 키 입력을 notifier로 전달하는 키패드. 상태를 구독하지 않는다.
class _KeypadPanel extends ConsumerWidget {
  /// 키패드 구역 배열 (#80)
  final KeypadArrangement arrangement;

  /// 넓은 배열에서 숫자부를 왼쪽에 둘지 (#142)
  final bool numbersOnLeft;

  const _KeypadPanel({required this.arrangement, this.numbersOnLeft = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CalcKeypad(
      arrangement: arrangement,
      numbersOnLeft: numbersOnLeft,
      onKeyPressed: (id) => ref.read(calcProvider.notifier).pressKey(id),
      onKeyRepeat: (id) => ref.read(calcProvider.notifier).repeatKey(id),
      // 설정 키(ON)는 계산기 입력 대신 설정을 연다 (#190). 상태 머신에도 알려 모디파이어 대기를 푼다 — 다른 키를 누른
      // 것으로 본다([CalcState.pressKey], 앱 규칙). SHIFT·ALPHA 대기 중이었으면 스크린리더가 "꺼짐"을 알린 뒤 대화상자로
      // 포커스가 옮겨 간다 — 대기가 풀렸다는 것도 사용자가 알아야 하는 상태 변화라 그대로 둔다.
      onSettingsPressed: (keyContext) {
        ref.read(calcProvider.notifier).pressKey(settingsKey);
        SettingsLauncher.openFrom(keyContext);
      },
    );
  }
}

/// 본체: LCD·기록 영역·키패드를 [arrangement]에 맞는 영역에 놓고, 설정 키(ON)가 열 설정([SettingsLauncher])에 지금
/// 배치를 알린다.
///
/// 모든 배치를 **같은 위젯 트리**(`Stack` + `Positioned.fromRect`, 자식 수·순서 고정)로 그린다. 그래서 회전·창
/// 크기 변경으로 배치가 바뀌어도 LCD·키패드 element가 유지되어 키 눌림 상태와 스크린리더 포커스가 사라지지 않는다
/// (#24 R2 — Android 16 태블릿·iPad는 방향 고정이 무시되어 회전이 잦다). 손잡이 설정이 바뀌어도
/// 영역 위치만 옮기고, LCD·키패드 위젯은 같은 인스턴스라 다시 빌드되지 않는다(가로형의 숫자부 좌우 대칭은 키패드 안 블록
/// 순서만 바꾼다 — 키 element는 그대로다, #142).
/// 폴더블을 접고 펴거나(#25) 내부 화면을 돌려 접힘선 방향이 바뀔 때도 마찬가지다. 기록 영역(#142)이 없는 배치에서도
/// 기록 영역 자식은 보이지 않게 남는다.
///
/// 스크린리더 읽기 순서는 영역마다 붙인 순서 키([OrdinalSortKey])로 정한다: 활성 LCD → 기록 → 키패드 (#142).
/// 이 위젯의 좌표가 배치 클래스들의 본체 좌표다.
class _Body extends ConsumerWidget {
  /// 본체 크기 (시스템 인셋·화면 여백 제외)
  final Size body;

  /// 배치 종류 ([FormFactor.arrangementOf] — 창 크기·접힘선으로 정한 배치)
  final ScreenArrangement arrangement;

  /// 창을 가로지르는 접힘선 (본체 좌표, 없으면 `null`) — 접힘선 기준 배치에서 쓴다.
  final Rect? hinge;

  /// 세로형과 가로형 중 키가 큰 쪽을 늘 고르는 창인지 ([FormFactor.picksFormByKeySize], #142)
  final bool picksFormByKeySize;

  /// 창의 짧은 변이 [FormFactor.largeScreenMinShortestSide] 미만인지 — 짧은 창 판정 (#38 R1)
  final bool smallWindow;

  /// 위 시스템 제스처 영역이 본체 윗변 아래로 들어오는 깊이 (dp, [CalcTheme.screenTopGestureDepth], #172) — 손 쪽 패널이
  /// 짧은 책 자세([CalcHingeSplitLayout])의 키패드 윗변 하한
  final double topGestureDepth;

  /// 진단 로그([LayoutLog], #158)에 적을 창 크기·화면 특징·폴더블 여부와 본체 원점(화면 좌표 — 키패드 위치를 화면 좌표로
  /// 적는다, #172). 로그가 꺼져 있으면 `null`이다 — 부모가 이미 읽은 값을 받으므로 이 위젯은 로그 때문에 따로 의존을 걸지
  /// 않는다.
  final ({
    Size window,
    List<DisplayFeature> features,
    bool foldableDevice,
    Offset bodyOrigin,
  })?
  diagnostics;

  const _Body({
    required this.body,
    required this.arrangement,
    required this.picksFormByKeySize,
    required this.smallWindow,
    this.hinge,
    required this.topGestureDepth,
    this.diagnostics,
  });

  /// 영역별 스크린리더 읽기 순서 (#142)
  static const double _lcdOrder = 0;
  static const double _historyOrder = 1;
  static const double _keypadOrder = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Rect lcd;
    final Rect keypad;
    // 키패드 구역 배열 — 가로형·가로 접힘선 배치는 넓은 배열을 쓸 수 있다 (#80, #142)
    var keypadArrangement = KeypadArrangement.standard;
    // 넓은 배열에서 숫자부를 왼쪽에 둘지 — 가로형·가로 접힘선 배치의 왼손잡이 (#142, #143)
    var numbersOnLeft = false;
    // 계산 기록 영역 — 가로형에서 위 띠가 충분히 클 때, 접힘선 기준 배치 (#142, #143)
    Rect? history;
    // 실제로 그린 배치 — 접힘선 기준 배치를 쓸 수 없어 위아래 배치로 그리면 [ScreenArrangement.stacked]다.
    // 설정 대화상자가 접힘선으로 나뉠지·손잡이 설정이 이 배치에 적용되는지 고를 때 쓴다 (#41 R1).
    final ScreenArrangement drawn;
    final hinge = this.hinge;
    final handedness = ref.watch(handednessProvider);
    // 위아래 배치 — 접힘선 기준 배치를 쓸 수 없을 때와 가로형과의 비교가 이 배치를 본다.
    final stacked = _stackedRectsOf(body);
    final stackedTouch = KeypadMetrics.minKeyTouchHeightOf(
      stacked.keypad.size,
      KeypadArrangement.standard,
    );

    // 접힘선 기준 배치 후보. 쓸 수 없으면 `null`이다 — 키가 쓸 수 있는 크기([CalcTheme.keyTouchHeightUsableMin])보다
    // 낮거나 활성 LCD가 최소 높이([CalcTheme.screenLcdMinHeight])보다 낮을 때다. 본체 좌표로 판정해야 인셋·화면 여백·
    // 접힘선 간격이 빠진 실제 크기를 본다(#25 R2). 키가 쓸 수 있는 크기면 접힘선을 가로지르는 배치의 키가 더 커도 이것을
    // 쓴다(#143 — 접힘선은 각도와 무관하게 언제나 경계다, [CalcTheme] "접힘선 기준 배치" 절).
    _HingeRegions? hingeLayoutFor(Handedness h) {
      if (hinge == null) return null;
      final regions = switch (arrangement) {
        ScreenArrangement.hingeSplit => CalcHingeSplitLayout.of(
          body,
          hinge,
          h,
          topGestureDepth: topGestureDepth,
        )._regions,
        ScreenArrangement.hingeStacked => CalcTabletopLayout.of(
          body,
          hinge,
          h,
        )._regions,
        ScreenArrangement.stacked || ScreenArrangement.landscape => null,
      };
      if (regions == null) return null;
      final usable =
          KeypadMetrics.minKeyTouchHeightOf(
                regions.keypad.size,
                regions.keypadArrangement,
              ) >=
              CalcTheme.keyTouchHeightUsableMin &&
          regions.lcd.height >= CalcTheme.screenLcdMinHeight - _epsilon;
      return usable ? regions : null;
    }

    // 손잡이별 후보는 한 번만 계산해 그린 배치·손잡이 판정이 함께 쓴다.
    final hingeLayouts = {
      for (final h in Handedness.values) h: hingeLayoutFor(h),
    };
    final hingeLayout = hingeLayouts[handedness];
    switch (arrangement) {
      case ScreenArrangement.hingeSplit || ScreenArrangement.hingeStacked
          when hingeLayout != null:
        lcd = hingeLayout.lcd;
        history = hingeLayout.history;
        keypad = hingeLayout.keypad;
        keypadArrangement = hingeLayout.keypadArrangement;
        numbersOnLeft = hingeLayout.numbersOnLeft;
        drawn = arrangement;
      // 접힘선 없는 창(#142)과, 접힘선 기준 배치를 쓸 수 없어(키가 너무 작음, 호출 측 불일치) 위아래 배치로 대체하는
      // 창: 가로형의 키가 더 크면 가로형으로 그린다.
      case ScreenArrangement.stacked ||
          ScreenArrangement.landscape ||
          ScreenArrangement.hingeSplit ||
          ScreenArrangement.hingeStacked:
        final landscape = _landscapeAlternative(
          body,
          handedness,
          stacked.keypad.size,
          compare:
              picksFormByKeySize ||
              smallWindow ||
              stackedTouch < CalcTheme.keyTouchHeightFloor,
        );
        if (landscape != null) {
          lcd = landscape.lcd;
          history = landscape.history;
          keypad = landscape.keypad;
          keypadArrangement = KeypadArrangement.wide;
          numbersOnLeft = landscape.numbersOnLeft;
          drawn = ScreenArrangement.landscape;
        } else {
          lcd = stacked.lcd;
          keypad = stacked.keypad;
          drawn = ScreenArrangement.stacked;
        }
    }
    // 그린 배치의 키도 쓸 수 없을 만큼 작으면(#38) 계산기 대신 안내를 띄운다. LCD·기록·키패드는
    // 트리에 남겨(보이지 않게) 창을 다시 키우면 상태 그대로 돌아온다. 숨긴 동안은 터치·키보드 포커스·의미
    // 트리에서 빠진다(`Visibility`). 키를 누른 채 창이 줄면 그 키의 자동 반복은 손을 뗄 때까지 이어진다 —
    // 드문 경우라 따로 멈추지 않는다.
    // TODO(#18): 무과금 광고를 넣을 때 안내 화면에서는 광고를 싣지 않게 하고(내용 없는 화면의 광고), 광고 높이가
    // 본체 높이·안내 기준을 바꾸는 것도 함께 확인한다.
    final tooSmall =
        KeypadMetrics.minKeyTouchHeightOf(keypad.size, keypadArrangement) <
        CalcTheme.keyTouchHeightUsableMin;
    // 진단 로그 (#158, 진단 빌드에서만 켜진다): 배치가 바뀐 프레임마다 한 줄 — 첫 프레임 깜빡임을 logcat으로 본다.
    final diagnostics = this.diagnostics;
    if (diagnostics != null) {
      LayoutLog.layout(
        chosen: arrangement,
        drawn: drawn,
        // 손 쪽 패널이 짧은 책 자세(#143 R1)는 활성 LCD가 키패드 옆 패널에 있다 — 키패드와 가로로 겹치지 않는다.
        lcdBesideKeypad:
            drawn == ScreenArrangement.hingeSplit &&
            (lcd.right <= keypad.left + _epsilon ||
                lcd.left >= keypad.right - _epsilon),
        tooSmall: tooSmall,
        // 안내 중에는 키패드가 숨어 있으므로 위치를 적지 않는다 (#172 R1)
        keypad: tooSmall ? null : keypad.shift(diagnostics.bodyOrigin),
        window: diagnostics.window,
        features: diagnostics.features,
        foldableDevice: diagnostics.foldableDevice,
      );
    }
    // 손잡이를 바꾸면 배치가 달라지는지 (#41 R2): 위아래 배치로 그렸어도, 반대 손잡이로는 접힘선 기준 배치가
    // 될 수 있다(세로 접힘선 양쪽 폭이 다르면 키패드가 들어갈 패널이 손잡이마다 다르다).
    // 접힘선 기준 배치는 반대 손잡이로도 같은 배치이고 키패드 자리·숫자부 쪽이 같으면 키가 옮겨 가지 않는다 — 실물 배열
    // 키패드가 아래 패널 폭 전체를 쓰는 가로 접힘선(Flip 내부)이 그렇다. 책 자세는 키패드가 반대쪽 패널로, 가로 접힘선의
    // 넓은 배열은 숫자부와 활성 LCD가 손 쪽으로 옮겨 간다(#143). 가로형도 숫자부와 활성 LCD가 옮겨 간다(#142).
    final otherLayout =
        hingeLayouts[handedness == Handedness.right
            ? Handedness.left
            : Handedness.right];
    final keypadMoves = switch (drawn) {
      ScreenArrangement.landscape => true,
      ScreenArrangement.hingeSplit || ScreenArrangement.hingeStacked =>
        otherLayout == null ||
            otherLayout.numbersOnLeft != numbersOnLeft ||
            !_sameRect(otherLayout.keypad, keypad),
      ScreenArrangement.stacked => false,
    };
    final handednessApplies =
        keypadMoves ||
        (drawn == ScreenArrangement.stacked &&
            hingeLayouts.entries.any(
              (e) => e.key != handedness && e.value != null,
            ));
    // 손잡이를 바꿔도 그린 배치가 같은지 (#129): 접힘선 기준 배치는 두 손잡이 모두 그 배치를 쓸 수 있을 때다.
    // 가로형·위아래 배치는 손잡이와 무관하다(위아래 배치로 대체한 화면은 위 판정처럼 반대 손잡이로 달라질 수 있다).
    final handednessKeepsArrangement = hingeLayouts.values.every(
      (l) => (l == null) == (hingeLayout == null),
    );
    // 안내 중에는 보이지 않게 하되 element·상태는 유지한다 (`maintainState` — 트리 모양이 바뀌지 않는다).
    Widget shown(Widget child, {bool visible = true}) => Visibility(
      visible: visible && !tooSmall,
      maintainState: true,
      child: child,
    );
    // 스크린리더 읽기 순서를 정하는 영역 노드 (#142)
    Widget ordered(double order, Widget child) => Semantics(
      container: true,
      explicitChildNodes: true,
      sortKey: OrdinalSortKey(order),
      child: child,
    );
    // 설정 키(ON, #190)가 여는 대화상자가 지금 배치를 따르도록 본체 전체를 감싼다.
    return SettingsLauncher(
      arrangement: drawn,
      handednessApplies: handednessApplies,
      handednessKeepsArrangement: handednessKeepsArrangement,
      // 손잡이와 무관한 값만 — 바뀌면 열린 대화상자가 지금 설정 키 쪽으로 옮겨 간다(#218)
      geometry: (body: body, hinge: hinge, chosen: arrangement),
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: lcd,
            child: shown(ordered(_lcdOrder, const _LcdPanel())),
          ),
          // 기록 영역이 없는 배치에서도 자식 자리를 지켜 트리 모양을 고정한다.
          Positioned.fromRect(
            rect: history ?? Rect.zero,
            child: shown(
              ordered(_historyOrder, const HistoryPanel()),
              visible: history != null,
            ),
          ),
          Positioned.fromRect(
            rect: keypad,
            // 배열마다 const 인스턴스라, 손잡이만 바뀌고 키패드 크기·배열이 같으면 키패드 50개를 다시 빌드하지 않는다
            // (크기가 바뀌면 `CalcKeypad`가 새 치수로 다시 빌드한다). 가로형의 손잡이 변경은 숫자부 쪽이 바뀌어 다시 빌드한다.
            child: shown(
              ordered(_keypadOrder, switch ((
                keypadArrangement,
                numbersOnLeft,
              )) {
                (KeypadArrangement.standard, _) => const _KeypadPanel(
                  arrangement: KeypadArrangement.standard,
                ),
                (KeypadArrangement.wide, false) => const _KeypadPanel(
                  arrangement: KeypadArrangement.wide,
                ),
                (KeypadArrangement.wide, true) => const _KeypadPanel(
                  arrangement: KeypadArrangement.wide,
                  numbersOnLeft: true,
                ),
              }),
            ),
          ),
          // 마지막 자식이라 있다가 없어져도 앞 자식들의 element는 그대로다.
          if (tooSmall) const Positioned.fill(child: WindowTooSmallNotice()),
        ],
      ),
    );
  }

  /// 크기·위치 비교 허용 오차 (dp) — 부동소수점 오차
  static const double _epsilon = 0.01;

  /// 손잡이를 바꿔도 키패드가 [a] → [b]로 같은 자리인지 (부동소수점 오차 [_epsilon] 안). #143 전에는 테이블톱 키패드
  /// 블록 폭 상한 때문에 몇 dp만 옮겨 가는 창이 있어 16dp까지 같은 자리로 봤다(#80 R2) — 이제 접힘선 기준 배치의
  /// 키패드는 패널 폭 전체라, 손잡이로 옮겨 가면 반대쪽 패널로 간다.
  static bool _sameRect(Rect a, Rect b) =>
      (a.left - b.left).abs() < _epsilon &&
      (a.top - b.top).abs() < _epsilon &&
      (a.right - b.right).abs() < _epsilon &&
      (a.bottom - b.bottom).abs() < _epsilon;

  /// 위아래 배치 대신 쓸 가로형 배치 (#142, 짧은 창 #38). 위아래 배치 키패드([stackedKeypad])보다 가로형의 가장 낮은 키
  /// 셀이 높지 않으면 `null`(위아래 배치 그대로 — 같으면 키가 더 넓은 위아래 배치). [compare]가 거짓이면 비교하지 않는다.
  ///
  /// 키 크기는 [KeypadMetrics.minKeyCellHeightOf]로 비교한다 — 터치 높이([KeypadMetrics.minKeyTouchHeightOf])는 큰 키에서
  /// 각인 띠를 터치 영역에서 빼며 한 번 줄어 큰 화면의 비교가 뒤집힌다. 두 셀 높이는 창 크기에 따라 연속으로 변하므로
  /// 큰 쪽을 고르면 배치가 바뀌는 경계에서 키가 튀지 않는다([CalcTheme] "가로형 배치" 절).
  /// 비교하는 창([CalculatorScreen]이 정한다):
  /// - 접힘선 없는 창([FormFactor.picksFormByKeySize]): 늘 비교한다.
  /// - 폴더블 기기·접힘 정보가 있어 위아래 배치로 그리는 창: 짧은 변 600dp 미만이거나(#38 R1) 위아래 배치의 키가
  ///   [CalcTheme.keyTouchHeightFloor]보다 낮을 때만 비교한다 — 접힘 정보가 늦게 오는 폴더블 내부 화면을 가로형으로
  ///   그렸다가 바꾸는 깜빡임을 막는다(#25). 접힘선 기준 배치를 쓸 수 없어 물러선 창(#143)도 이 규칙이다 — 접힘 정보가 온
  ///   뒤라 깜빡임은 없지만, 접힘 정보가 오기 전(위아래 배치)과 같은 배치로 남아 접힘 정보가 와도 배치가 바뀌지 않는다.
  ///   접힘선이 둘 이상 가로지르는 창(펼친 트라이폴드)은 앞의 접힘선 없는 창과 같다(#144).
  /// 가로형 키패드 크기는 손잡이와 무관하다.
  static CalcLandscapeLayout? _landscapeAlternative(
    Size body,
    Handedness handedness,
    Size stackedKeypad, {
    required bool compare,
  }) {
    if (!compare) return null;
    final landscape = CalcLandscapeLayout.of(body, handedness);
    return KeypadMetrics.minKeyCellHeightOf(
              landscape.keypad.size,
              KeypadArrangement.wide,
            ) >
            KeypadMetrics.minKeyCellHeightOf(
              stackedKeypad,
              KeypadArrangement.standard,
            )
        ? landscape
        : null;
  }
}

/// 창이 너무 작아 키패드를 쓸 수 없다는 안내 (#38) — 본체 전체를 덮는다.
///
/// 그린 배치의 키가 [CalcTheme.keyTouchHeightUsableMin]보다 낮을 때 [CalculatorScreen]이 계산기 대신 띄운다.
/// 아이콘과 문구는 본체 폭에서 줄을 바꾸고 본체 가운데에 둔다. 높이가 모자라면 줄이지 않고 스크롤한다 — 줄이면
/// 큰 글자 배율을 쓰는 사용자의 글자가 되돌려진다(#38 R1).
/// 나타날 때 스크린리더가 읽도록 liveRegion으로 둔다. 터치·입력은 받지 않는다.
@visibleForTesting
class WindowTooSmallNotice extends StatelessWidget {
  const WindowTooSmallNotice({super.key});

  /// 안내 영역 키 (테스트용)
  static const Key noticeKey = ValueKey('window-too-small-notice');

  @override
  Widget build(BuildContext context) {
    final strings = SettingsStrings.of(context);
    final color = CalcPalette.of(context).noticeForeground;
    return Semantics(
      key: noticeKey,
      container: true,
      liveRegion: true,
      // liveRegion 노드 자신이 문구를 라벨로 가져야 나타날 때 읽힌다 — Android는 liveRegion 노드의 라벨이 바뀔 때만
      // 알린다(`ScreenReaderAnnouncer` 참조). 아래 Text는 같은 말을 두 번 읽지 않도록 의미 트리에서 뺀다.
      label: strings.windowTooSmall,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const padding = CalcTheme.windowTooSmallPadding;
          final minHeight = constraints.maxHeight.isFinite
              ? math.max(0.0, constraints.maxHeight - 2 * padding)
              : 0.0;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(padding),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.open_in_full,
                      size: CalcTheme.windowTooSmallIconSize,
                      color: color,
                    ),
                    const SizedBox(height: CalcTheme.windowTooSmallPadding),
                    ExcludeSemantics(
                      child: Text(
                        strings.windowTooSmall,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: color,
                          fontSize: CalcTheme.windowTooSmallFontSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
