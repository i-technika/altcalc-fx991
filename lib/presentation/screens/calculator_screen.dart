import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show DisplayFeature;

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

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
import '../widgets/calc_keypad.dart';
import '../widgets/history_panel.dart';
import '../widgets/lcd_display.dart';
import '../widgets/screen_coordinate_root.dart';
import '../widgets/settings_button.dart';
import '../widgets/top_strip.dart';

/// 본체 영역의 세로 배치 (위 → 아래: 상단 띠 · LCD · 간격 · 키패드) — 접힘선 없는 세로로 긴 창의 "세로형" 배치 (#141).
///
/// 기준은 [CalcTheme]의 "화면 배치" 절을 따른다 (#23, #141).
/// - 폭: LCD와 키패드 모두 본체 폭 전체를 쓴다 (#141 — 폭 상한 없음, 태블릿 세로에서도 양옆이 비지 않는다).
/// - 상단 띠 최소 높이: [CalcTheme.screenTopStripMinHeight]를 먼저 떼어 둔다 (#41 — 설정 아이콘 줄).
///   아래 LCD·키패드 규칙의 "본체 높이"는 이것을 뺀 높이다.
/// - 큰 세로 창의 띠 (#141 R1·R2): 위 규칙으로 정한 키패드가 [CalcTheme.screenTopStripFullRowKeypadMinHeight](실물 크기
///   키패드 높이)보다 높으면, 그 높이 아래로 내려가지 않는 만큼 키패드에서 떼어 띠를 내용 줄 전체 높이(화면 여백 포함
///   [CalcTheme.topStripRowMaxHeight])까지 늘린다(LCD는 그대로). 태블릿 세로에서 설정 아이콘·태양전지가 다 들어가고 터치 영역이 LCD에 겹치지 않는다. 폰은 키패드가 그
///   높이에 닿지 않아 그대로이고, 창이 커지면 띠가 늘어나는 동안 키패드는 그 높이에 머물러 키가 줄지 않는다.
/// - LCD 높이: [CalcTheme.screenLcdHeightRatio] 목표, [CalcTheme.screenLcdMinHeight] ~ 최대 높이 범위. 최대 높이는
///   (본체 폭 / [CalcTheme.screenLcdMinAspectRatio])와 줄 글자 상한 높이([LcdFontSizes.heightAtMaxLineFont], #189) 중 낮은 쪽
///   ([_lcdMaxHeightOf]) — 태블릿 세로는 상한 높이에서 멈추고 남는 높이를 키패드가 받는다.
/// - 키패드: 나머지 높이 중 가로/세로 비 하한([CalcTheme.keypadMinAspectRatio] — 키가 세로로 길어지지 않게)이
///   허용하는 만큼. 키패드가 쓰지 못하는 높이는 LCD 최대 높이까지 LCD에 주고, 그래도 남으면 [top]에 더한다
///   (그래서 남는 높이가 최소 띠 이상인 화면의 배치는 최소 띠가 없을 때와 같다).
/// - 본체가 아주 낮으면 키패드 높이가 0이 될 때까지만 LCD를 최소 높이로 지킨다.
///   짧은 창에서도 상단 띠 최소 높이를 먼저 떼므로 우선순위는 띠 > LCD 최소 높이 > 키패드다 (#38에서 유지하기로 정함).
///   키가 작아지는 짧은 창은 이 배치 안에서 높이를 나누는 대신 화면이 가로형([CalcLandscapeLayout])으로 바꾸거나 안내를
///   띄운다([CalculatorScreen], [CalcTheme] "짧은 창" 절).
///   본체가 최소 띠 + 간격보다 낮으면 띠, 간격 순으로 본체 높이까지만 받아, 어떤 경우에도 합계가 본체 높이를
///   넘지 않는다.
@immutable
class CalcScreenLayout {
  /// LCD 위 상단 띠 높이 (dp) — 본체 안쪽만 센 값이다(본체 위 화면 여백 제외).
  /// 본체가 그보다 낮지 않으면 [CalcTheme.screenTopStripMinHeight] 이상이다. 띠에 두는 것은 [CalcTopStripLayout].
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
    final bodyHeight = finite(body.height);
    final divided = _divideBodyHeight(
      bodyHeight,
      lcdMaxHeight: _lcdMaxHeightOf(width),
      keypadMaxHeight: KeypadMetrics.fitSize(Size(width, double.infinity))
          .height,
    );
    final base = CalcScreenLayout._(
      top: divided.top,
      lcdHeight: divided.lcd,
      gap: divided.gap,
      keypadHeight: divided.keypad,
    );
    // 큰 세로 창은 키패드를 실물 크기 아래로 줄이지 않는 만큼 띠를 내용 줄 전체 높이까지 늘린다 (#141 R1).
    // 늘린 몫은 키패드에서만 뺀다 — LCD까지 다시 나누면 키패드가 폭에 묶인 창(폭 약 480~570dp)에서 폭이 늘 때
    // LCD가 한 번에 13dp 줄어드는 불연속이 생긴다(#141 R2). 이 식은 창 폭·높이에 대해 연속이다.
    const fullRow = CalcTheme.topStripRowMaxHeight - CalcTheme.screenPadding;
    final grow =
        (base.keypadHeight - CalcTheme.screenTopStripFullRowKeypadMinHeight)
            .clamp(0.0, math.max(0.0, fullRow - base.top));
    if (grow <= 0) return base;
    return CalcScreenLayout._(
      top: base.top + grow,
      lcdHeight: base.lcdHeight,
      gap: base.gap,
      keypadHeight: base.keypadHeight - grow,
    );
  }

  @override
  String toString() =>
      'CalcScreenLayout(top: $top, lcd: $lcdHeight, gap: $gap, '
      'keypad: $keypadHeight)';
}

/// 본체 높이 [bodyHeight](유한한 0 이상 값)를 위 → 아래 (상단 띠 · LCD · 간격 · 키패드)로 나눈다 — 세로형([CalcScreenLayout])과
/// 가로형([CalcLandscapeLayout])이 같이 쓰는 규칙이다 (#23, #41, #142).
/// - 상단 띠 최소 높이([CalcTheme.screenTopStripMinHeight])를 먼저 떼고, 나머지를 LCD·간격·키패드가 나눈다.
/// - LCD: 목표 높이 [lcdTarget](= 나머지 × [CalcTheme.screenLcdHeightRatio])를 [CalcTheme.screenLcdMinHeight] ~
///   [lcdMaxHeight] 범위로 제한한다(최대 높이가 최소 높이보다 낮으면 최소 높이). 키패드가 세로 한계([keypadMaxHeight])에 닿아
///   쓰지 못하는 높이는 LCD 최대 높이까지 LCD가 받는다. 최대 높이는 세로형이 [_lcdMaxHeightOf](줄 글자 상한 #189 포함),
///   가로형의 위 띠가 본체 폭 / [CalcTheme.screenLcdMinAspectRatio]다.
/// - 키패드: 나머지 높이, [keypadMaxHeight]까지. 그래도 남는 높이는 띠에 더한다.
/// - 본체가 아주 낮으면 키패드 높이가 0이 될 때까지만 LCD를 최소 높이로 지킨다. 띠, 간격 순으로 본체 높이까지만 받아 합계가
///   본체 높이를 넘지 않는다.
({double top, double lcd, double gap, double keypad, double lcdTarget})
_divideBodyHeight(
  double bodyHeight, {
  required double lcdMaxHeight,
  required double keypadMaxHeight,
}) {
  final strip = math.min(CalcTheme.screenTopStripMinHeight, bodyHeight);
  final height = bodyHeight - strip;
  final gap = math.min(CalcTheme.screenLcdKeypadGap, height);
  final available = height - gap;
  final lcdMax = math.max(CalcTheme.screenLcdMinHeight, lcdMaxHeight);
  final lcdTarget = height * CalcTheme.screenLcdHeightRatio;
  final lcd = math.min(
    math
        .max(lcdTarget, available - keypadMaxHeight)
        .clamp(CalcTheme.screenLcdMinHeight, lcdMax),
    available,
  );
  final keypad = math.min(available - lcd, keypadMaxHeight);
  return (
    // 남는 높이를 먼저 구한 뒤 띠에 더한다 — `strip + available - lcd - keypad` 순서로 계산하면 남는 높이가
    // 0이어도 부동소수점 오차로 띠가 최소 높이보다 작아진다(본체 376×718 등, #41 R1).
    top: strip + ((available - lcd) - keypad),
    lcd: lcd,
    gap: gap,
    keypad: keypad,
    lcdTarget: lcdTarget,
  );
}

/// 폭 [lcdWidth] LCD의 최대 높이 (dp) — 폭 기준 최대 높이(폭 / [CalcTheme.screenLcdMinAspectRatio])와 줄 글자 상한
/// 높이([LcdFontSizes.heightAtMaxLineFont], #189) 중 낮은 쪽. 어느 쪽이든 그보다 높이면 줄 글자는 커지지 않고 입력·결과
/// 줄 사이만 벌어진다. 최소 높이([CalcTheme.screenLcdMinHeight])는 호출하는 배치가 따로 지킨다.
double _lcdMaxHeightOf(double lcdWidth) => math.min(
  lcdWidth / CalcTheme.screenLcdMinAspectRatio,
  LcdFontSizes.heightAtMaxLineFont,
);

/// 접힘선 없는 가로로 넓은 창의 "가로형" 배치 (#142, [ScreenArrangement.landscape]). 기준은 [CalcTheme]의 "가로형 배치"
/// 절을 따른다.
///
/// 오른손잡이([Handedness.right]) 기준 (왼손잡이는 좌우 대칭 — 숫자부와 활성 LCD가 왼쪽):
/// ```
///  ┌──────────────────────────────────────────────┐
///  │ AltCalc                          ▮▮▮▮     ⚙ │ ← 상단 띠 (위 띠 폭 전체, [top])
///  ├────────────────────┐  ┌──────────────────────┤
///  │ 계산 기록 [history] │  │    활성 LCD [lcd]     │ ← 위 띠 ([band])
///  ├────────────────────┘  └──────────────────────┤
///  │ 상단 조작부 + 함수부 │  │       숫자부          │ ← 넓은 배열 키패드 [keypad]
///  │      5행 × 6열      │  │      4행 × 5열        │
///  └────────────────────┴──┴──────────────────────┘ ← 본체 아래
///   └──── 블록 ────────┘ 간격 └──── 블록 ─────────┘
/// ```
/// - 키패드: 넓은 배열([KeypadArrangement.wide])로 본체 폭 전체를 쓰고 본체 아래에 붙인다. 높이는 넓은 배열의 세로 한계
///   ([KeypadMetrics.fitSize])까지다. 숫자부는 주로 쓰는 손 쪽 블록이다([numbersOnLeft]).
/// - 높이 나누기: 세로형([CalcScreenLayout])과 같은 규칙을 위 띠 폭 전체(본체 폭)로 쓴다 — 상단 띠 최소 높이를 먼저 떼고,
///   LCD 목표 비율([CalcTheme.screenLcdHeightRatio]) · 최소 높이 · 최대 높이(본체 폭 / [CalcTheme.screenLcdMinAspectRatio] — 세로형과
///   달리 줄 글자 상한 높이로 줄이지 않는다, #189) 안에서 위 띠([band]), 나머지는 키패드가 세로 한계까지 받는다. 위 띠의 높이는 기록 영역 유무와 무관하다 — 그래서 기록 영역이 생기고
///   없어지는 경계(창 높이·폭 어느 쪽으로 넘어도)에서 키·위 띠 높이가 튀지 않는다(#142 R1: 블록 폭으로 위 띠 최대 높이를
///   정하면 본체 폭 461 → 461.5에서 LCD가 228.8 → 128dp로 줄고 빈 띠가 생겼다).
/// - 활성 LCD: 위 띠 아래쪽(키패드 바로 위)에 두고, 높이는 그 폭의 최대 높이([_lcdMaxHeightOf] — 폭 /
///   [CalcTheme.screenLcdMinAspectRatio](#142 R2)와 줄 글자 상한 높이(#189) 중 낮은 쪽, 하한 [CalcTheme.screenLcdMinHeight])까지만이다.
///   그보다 높이면 글자는 커지지 않고 식과 답만 세로로 멀어진다. 위 띠가 그보다 높으면 활성 LCD 위가 빈다(12.9인치 iPad 가로:
///   위 띠 479.1, 활성 LCD 655×273.5). 기록 영역이 있으면 기록 영역은 위 띠 전체를 쓴다.
/// - 띠를 내용 줄 전체 높이까지 늘리기: LCD가 목표 높이(와 최소 높이)보다 높아진 몫(키패드가 세로 한계에 닿아 남는 높이)
///   에서 띠를 [CalcTheme.topStripRowMaxHeight](화면 여백 포함)까지 늘린다. 키패드에서는 떼지 않는다 — 태블릿 가로는 키패드가
///   세로 한계에 닿고 LCD가 남는 높이를 받아, 띠가 최소 높이(줄 20dp)로 남으면 설정 아이콘이 줄고 태양전지가 숨는다
///   (세로형 큰 창의 띠 #141 R1과 같은 이유).
/// - 위 띠: 키패드 블록에 맞춰 둘로 나눈다. 숫자부 위가 활성 LCD, 함수부 위가 계산 기록 영역(`HistoryPanel`, 내용은 #145)이고
///   둘 사이는 키패드의 블록 사이 간격과 같다. LCD 하나를 전체 폭으로 늘이면 식은 왼쪽 끝, 답은 오른쪽 끝으로 멀어진다
///   (사용자 결정). 다음 중 하나면 기록 영역을 두지 않고([history]가 `null`) 활성 LCD가 띠 폭 전체를 쓴다.
///   - 위 띠가 [CalcTheme.screenLandscapeHistoryMinHeight]보다 낮다 (가로 폰 등 — 띠가 LCD 최소 높이에 묶인 창)
///   - 블록이 [CalcTheme.screenLandscapeHistoryMinLcdWidth]보다 좁다 (좁은 창)
///   - 블록 폭 활성 LCD의 줄 글자가 띠 폭 전체 LCD의 [CalcTheme.screenLandscapeHistoryMinLcdFontRatio]배보다 작다 (#142 R2 —
///     위 띠가 높은데 블록이 좁은 창. 경계에서 줄 글자가 30%보다 많이 줄지 않게 한다)
///   기록 영역이 없는 가로형의 무과금 광고 자리는 #18에서 정한다(기록 영역을 줄여 넣을 곳이 없다).
/// - 설정 버튼·장식: 상단 띠의 내용 줄([CalcTopStripLayout])이 위 띠([band]) 바로 위에서 위 띠 폭 전체를 쓴다 — 세로형과 같이 워드마크는 왼쪽 끝,
///   설정 버튼은 오른쪽 끝, 태양전지는 그 왼쪽이다. 손잡이와 무관하다.
/// - 모든 영역은 본체 안에 있다 (음수·비유한 크기는 0으로 본다).
@immutable
class CalcLandscapeLayout {
  /// LCD 위 상단 띠 높이 (dp) — 본체 안쪽만 센 값이다(본체 위 화면 여백 제외). [CalcScreenLayout.top]과 같은 뜻이다.
  final double top;

  /// 활성 LCD 영역 (본체 좌표, dp)
  final Rect lcd;

  /// 계산 기록 영역 (본체 좌표, dp). 위 띠가 낮거나 좁아 두지 않으면 `null`.
  final Rect? history;

  /// 키패드 영역 (본체 좌표, dp) — [KeypadArrangement.wide] 배열
  final Rect keypad;

  /// 숫자부(와 활성 LCD)를 왼쪽에 두는지 — 왼손잡이
  final bool numbersOnLeft;

  const CalcLandscapeLayout._({
    required this.top,
    required this.lcd,
    required this.history,
    required this.band,
    required this.keypad,
    required this.numbersOnLeft,
  });

  /// 위 띠 전체 (상단 띠 아래 ~ 키패드 위 간격, 본체 폭 전체, 본체 좌표) — 활성 LCD와 기록 영역이 이 안에 있고, 상단 띠의
  /// 내용 줄이 이 위에 이 폭으로 놓인다. 높이는 기록 영역 유무와 무관하다. 활성 LCD가 이보다 낮으면(블록 폭 실물 비율 #142 R2,
  /// 줄 글자 상한 #189) 활성 LCD 위가 빈다.
  final Rect band;

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
    // 위 띠의 높이는 띠 폭 전체로 정한다 — 기록 영역 유무와 무관하다. 줄 글자 상한 높이(#189)로는 줄이지 않는다 — 위 띠가
    // 그보다 높으면 기록 영역이 위 띠 전체를 쓰고, 활성 LCD는 아래(키패드 바로 위)에 그 높이까지만 놓인다.
    final base = _divideBodyHeight(
      height,
      lcdMaxHeight: width / CalcTheme.screenLcdMinAspectRatio,
      keypadMaxHeight: keypadMaxHeight,
    );
    // LCD가 목표 높이(와 최소 높이)보다 높아진 몫에서만 띠를 줄 전체 높이까지 늘린다 — 키는 그대로다.
    // 늘린 뒤 LCD = max(하한, LCD − 늘릴 수 있는 최대)라 창 크기에 대해 연속이고, 창이 높아질 때 줄지 않는다.
    const fullRow = CalcTheme.topStripRowMaxHeight - CalcTheme.screenPadding;
    final lcdFloor = math.max(
      base.lcdTarget,
      math.min(CalcTheme.screenLcdMinHeight, base.lcd),
    );
    final grow = (base.lcd - lcdFloor).clamp(
      0.0,
      math.max(0.0, fullRow - base.top),
    );
    final top = base.top + grow;
    final lcdHeight = base.lcd - grow;
    // 활성 LCD 높이 — LCD 폭의 최대 높이([_lcdMaxHeightOf])까지만이다. 기록 영역이 있으면 블록 폭의 실물 비율 높이(#142 R2),
    // 없으면 띠 폭 전체의 줄 글자 상한 높이(#189)에 걸린다. 그보다 높이면 글자는 커지지 않고 식과 답만 세로로 멀어진다.
    // 남는 높이는 기록 영역이 쓰거나(위 띠 전체) 활성 LCD 위의 빈 곳이 된다.
    double activeLcdHeightOf(double lcdWidth) => math.min(
      lcdHeight,
      math.max(CalcTheme.screenLcdMinHeight, _lcdMaxHeightOf(lcdWidth)),
    );
    final blockLcdHeight = activeLcdHeightOf(block);
    final fullLcdHeight = activeLcdHeightOf(width);
    // 기록 영역을 두면 활성 LCD 줄 글자가 띠 폭 전체일 때보다 많이 작아지지 않아야 한다 — 폭 방향 경계에서 글자가 절반으로
    // 튀지 않게 한다(#142 R2: 본체 폭 626 → 626.5에서 49.5 → 23.6dp). 글자 크기는 배율 반영 전 기준으로 잰다. 띠 폭 전체 LCD도
    // 실제로 그릴 높이(줄 글자 상한 높이까지, #189)로 잰다 — 상한에 묶인 글자와 비교한다.
    double lineFontOf(Size lcd) =>
        LcdFontSizes.forSize(lcd, TextScaler.noScaling).input;
    final withHistory =
        lcdHeight >= CalcTheme.screenLandscapeHistoryMinHeight &&
        block >= CalcTheme.screenLandscapeHistoryMinLcdWidth &&
        lineFontOf(Size(block, blockLcdHeight)) >=
            lineFontOf(Size(width, fullLcdHeight)) *
                CalcTheme.screenLandscapeHistoryMinLcdFontRatio;
    // 남는 높이(반올림 오차 등)는 키패드가 받는다 (세로형 `_Body._stackedRects`와 같다).
    final keypadTop = math.min(top + lcdHeight + base.gap, height);
    final keypad = Rect.fromLTRB(0, keypadTop, width, height);

    final Rect lcd;
    Rect? history;
    // 활성 LCD는 위 띠 아래(키패드 바로 위)에 붙인다.
    final bandBottom = top + lcdHeight;
    if (withHistory) {
      // 기록 영역은 위 띠 높이 전체를 쓴다.
      final lcdTop = bandBottom - blockLcdHeight;
      final left = Rect.fromLTWH(0, lcdTop, block, blockLcdHeight);
      final right = Rect.fromLTWH(width - block, lcdTop, block, blockLcdHeight);
      final leftBand = Rect.fromLTWH(0, top, block, lcdHeight);
      final rightBand = Rect.fromLTWH(width - block, top, block, lcdHeight);
      lcd = numbersOnLeft ? left : right;
      history = numbersOnLeft ? rightBand : leftBand;
    } else {
      lcd = Rect.fromLTWH(0, bandBottom - fullLcdHeight, width, fullLcdHeight);
    }
    return CalcLandscapeLayout._(
      top: top,
      lcd: lcd,
      history: history,
      band: Rect.fromLTWH(0, top, width, lcdHeight),
      keypad: keypad,
      numbersOnLeft: numbersOnLeft,
    );
  }

  @override
  String toString() =>
      'CalcLandscapeLayout(top: $top, band: $band, lcd: $lcd, history: $history, '
      'keypad: $keypad, numbersOnLeft: $numbersOnLeft)';
}

/// 세로 접힘선 기준 좌우 배치 (#25, [ScreenArrangement.hingeSplit] — 폴더블 책 자세). 기준은 [CalcTheme]의 "접힘선 기준
/// 배치" 절을 따른다. 손 쪽 패널을 세로형으로, 반대쪽 패널을 기록으로 다시 정하는 것은 #143이다 — 그때까지 예전 좌우 분할
/// 배치(#24)의 접힘선 규칙을 그대로 쓴다(접힘선 없는 좌우 분할은 가로형 #142가 대체했다).
///
/// 오른손잡이([Handedness.right]) 기준 (왼손잡이는 좌우 대칭):
/// ```
///  ┌────────────────────┆──────────────────────┐
///  │  (띠 — 장식 줄)    ┆                      │
///  ├────────────────────┆──────────────────────┤ ← 키패드 윗변 = LCD 윗변
///  │        LCD         ┆                      │
///  ├────────────────────┆    50키 키패드        │
///  │ [설정]             ┆                      │
///  └────────────────────┆──────────────────────┘ ← 본체 아래
///  └── LCD 쪽 절반 ─────┘ 접힘선
/// ```
/// - 접힘선([hinge], 본체 좌표) 양쪽에 [CalcTheme.screenHingeMargin]씩 비우고, 주로 쓰는 손 쪽 절반 전체가 키패드 자리,
///   다른 절반 전체가 LCD 쪽 패널이다.
/// - 키패드: 손 쪽 절반에 [KeypadMetrics.fitSize](실물 배열)로 맞춰 손 쪽 가장자리·본체 아래에 붙인다.
/// - LCD: 폭은 패널 폭과 키패드 폭 × [CalcTheme.screenLcdMaxWidthRatio] 중 작은 쪽이고 (#71), 상한에 걸리면(LCD 쪽 절반이
///   키패드 쪽보다 넓을 때) 접힘선 쪽에 붙어 눈 이동을 줄인다. 높이는 그 폭의 최대 높이([_lcdMaxHeightOf] — 폭 /
///   [CalcTheme.screenLcdMinAspectRatio]와 줄 글자 상한 높이 #189 중 낮은 쪽, 하한 [CalcTheme.screenLcdMinHeight])이되, 아래에 설정 버튼 자리를 남기도록 키패드
///   높이에서 버튼 자리를 뺀 높이를 넘지 않는다. 윗변은 키패드 윗변에 맞춘다.
/// - 설정 버튼: LCD 바로 아래, LCD의 키패드에서 먼 쪽 끝.
/// - 본체가 키패드 최대 높이보다 높으면 위쪽 남는 높이는 LCD 위 띠다. 띠가 충분히 높으면 LCD 바로 위에 장식 줄을 둔다
///   ([CalcTopStripLayout], #41).
/// - 키패드는 손 쪽 절반 폭을 다 쓰므로(#141) LCD와 키패드 사이는 접힘선 + 양쪽 간격이다(두 화면 기기 1114×720: 50dp).
///   그래서 LCD·키패드·설정 버튼 어느 것도 접힘선 위에 놓이지 않는다.
/// - 모든 영역은 본체 안에 있다 (음수·비유한 크기는 0으로 본다).
@immutable
class CalcHingeSplitLayout {
  /// LCD 영역 (본체 좌표, dp)
  final Rect lcd;

  /// 키패드 영역 (본체 좌표, dp) — [KeypadMetrics.fitSize] 결과 크기
  final Rect keypad;

  /// 설정 버튼 영역 (본체 좌표, dp)
  final Rect settingsButton;

  const CalcHingeSplitLayout._({
    required this.lcd,
    required this.keypad,
    required this.settingsButton,
  });

  /// [body] (시스템 인셋·화면 여백을 뺀 본체 영역)를 세로 접힘선 [hinge](본체 좌표)로 나눠 [handedness] 쪽 절반에 키패드를
  /// 둔다.
  factory CalcHingeSplitLayout.of(
    Size body,
    Rect hinge,
    Handedness handedness,
  ) {
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
    final keypadRegion = onRight ? width - rightStart : leftEnd;
    final keypadSize = KeypadMetrics.fitSize(Size(keypadRegion, height));
    final panelLeft = onRight ? 0.0 : rightStart;
    final panelWidth = onRight ? leftEnd : width - rightStart;
    final keypadLeft = onRight ? width - keypadSize.width : 0.0;
    final keypadTop = height - keypadSize.height;

    // LCD 폭 상한 (#71) — 상한에 걸리면 패널 안에서 키패드 쪽(접힘선 쪽)에 붙인다.
    final lcdWidth = math.min(
      panelWidth,
      keypadSize.width * CalcTheme.screenLcdMaxWidthRatio,
    );
    final lcdLeft = onRight ? panelLeft + panelWidth - lcdWidth : panelLeft;

    // LCD 아래에 설정 버튼 자리(간격 + 버튼)를 남긴다.
    const buttonBlock =
        CalcTheme.screenSettingsGap + CalcTheme.settingsButtonSize;
    final lcdMax = math.max(0.0, keypadSize.height - buttonBlock);
    final lcdHeight = math.min(
      math.max(_lcdMaxHeightOf(lcdWidth), CalcTheme.screenLcdMinHeight),
      lcdMax,
    );
    final lcd = Rect.fromLTWH(lcdLeft, keypadTop, lcdWidth, lcdHeight);
    // 버튼은 항상 LCD 아래에 둔다. 본체가 버튼 자리보다 낮은 비정상 크기에서만 버튼이 줄어든다
    // (그 전에 키가 [CalcTheme.keyTouchHeightUsableMin] 미만이 되어 화면이 이 배치를 쓰지 않는다).
    final buttonTop = math.min(
      lcd.bottom + CalcTheme.screenSettingsGap,
      height,
    );
    final button = math.min(CalcTheme.settingsButtonSize, height - buttonTop);
    // LCD의 키패드에서 먼 쪽 끝. LCD가 버튼보다 좁은 비정상 크기에서도 패널 밖(키패드 쪽)으로 나가지 않는다.
    final buttonWidth = math.min(CalcTheme.settingsButtonSize, panelWidth);
    final buttonLeft = onRight
        ? math.min(lcd.left, panelLeft + panelWidth - buttonWidth)
        : math.max(lcd.right - buttonWidth, panelLeft);
    return CalcHingeSplitLayout._(
      lcd: lcd,
      keypad: Rect.fromLTWH(
        keypadLeft,
        keypadTop,
        keypadSize.width,
        keypadSize.height,
      ),
      settingsButton: Rect.fromLTWH(buttonLeft, buttonTop, buttonWidth, button),
    );
  }

  @override
  String toString() =>
      'CalcHingeSplitLayout(lcd: $lcd, keypad: $keypad, '
      'settings: $settingsButton)';
}

/// 가로 접힘선 기준 위아래 배치 (#25, [ScreenArrangement.hingeStacked]) — 반 접어 세워 둔 테이블톱 자세(Flip의
/// Flex 모드 포함)나 물리 힌지. 기준은 [CalcTheme]의 "접힘선 기준 배치" 절을 따른다.
///
/// 오른손잡이([Handedness.right]) 기준 (왼손잡이는 좌우 대칭). 실물 배열 키패드 옆에 버튼 자리가 남는 경우:
/// ```
///  ┌─────────────────────────────────────────────┐
///  │               (띠 — 장식 줄)                 │
///  │  (여백)   ┌──────────────────────────────────┤
///  │           │               LCD                │  ← 위 절반 (아래쪽 = 접힘선 쪽에 붙인다)
///  ├ ─ ─ ─ ─ ─ ┴ ─ ─ ─ 접힘선 ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤
///  │ [설정]                 ┌──────────────────┐  │
///  │                        │   50키 키패드     │  │  ← 아래 절반
///  └────────────────────────┴──────────────────┘──┘ ← 본체 아래
/// ```
/// 넓은 배열이 아래 절반 폭을 다 쓰는 경우 (Fold 가로·Pixel Fold 세로 반 접힘, #80):
/// ```
///  ┌─────────────────────────────────────────────┐
///  │ [설정]               (띠 — 장식 줄)          │  ← 버튼은 위 절반 위 모서리
///  │  (여백)          ┌───────────────────────────┤
///  │                  │            LCD            │
///  ├ ─ ─ ─ ─ ─ ─ ─ ─ ─┴─ ─ 접힘선 ─ ─ ─ ─ ─ ─ ─ ─ ┤
///  │┌ 상단 조작부+함수부 ┐  ┌───── 숫자부 ───────┐ │
///  ││   5행 × 6열        │  │    4행 × 5열       │ │  ← 아래 절반
///  └┴────────────────────┴──┴────────────────────┴─┘
/// ```
/// - 접힘선([hinge], 본체 좌표) 위아래로 [CalcTheme.screenHingeMargin]씩 비운다.
/// - 키패드: 아래 절반에 [KeypadMetrics.fitSize]로 맞춰, 주로 쓰는 손 쪽 가장자리·본체 아래에 붙인다.
///   #143까지는 #141 전의 키패드 폭 상한(블록 480dp·가로/세로 비 1.25)을 그대로 쓴다([_interimKeypadRegion]).
///   아래 절반은 낮고 넓어, 넓은 배열([KeypadArrangement.wide] — 숫자부를 함수부 오른쪽에 둔다)의 키가 실물 배열보다
///   크면 그 배열을 쓴다(#80, 사용자 결정 — Fold 가로 반 접힘 19.9 → 39.9dp, Pixel Fold 세로 27.1 → 37.7dp).
///   넓은 배열은 대개 아래 절반 폭을 다 써서, 설정 버튼은 위 절반 모서리로 간다(아래).
///   폭이 좁은 화면(Flip 내부)은 실물 배열의 키가 더 커 그대로다.
/// - LCD: 폭은 위 절반 폭과 [CalcTheme.screenTabletopLcdMaxWidth] 중 작은 쪽이고 (#92), 키패드와 같은 쪽(주로 쓰는
///   손 쪽) 가장자리에 붙인다 — 상한에 걸리면 LCD의 손 쪽 끝이 키패드의 바깥 끝과 맞고, 반대쪽은 빈 여백이 된다.
///   상한은 실제 키패드 폭이 아니라 키패드 최대 폭 기준이다. 실물 배열의 키패드가 아래 절반 높이에 묶여 좁아질 때
///   보는 쪽인 위 절반의 LCD까지 그 폭으로 줄이면 글자만 작아지므로 LCD가 키패드보다 넓을 수 있고,
///   반대로 넓은 배열의 키패드(Fold 가로 반 접힘 825dp)보다는 좁다 — 근거는 [CalcTheme.screenTabletopLcdMaxWidth].
///   높이는 폭의 최대 높이(폭 / [CalcTheme.screenLcdMinAspectRatio])와 위 절반 높이 중
///   작은 쪽이고, 접힘선 쪽(아래)에 붙인다 — 남는 높이는 LCD 위 띠가 된다(위아래 배치와 같은 방식,
///   장식은 [CalcTopStripLayout]).
/// - 설정 버튼: 아래 절반에서 키패드 반대쪽 끝, 키패드 윗변 높이. 그 자리가 없으면(키패드가 아래 절반 폭을
///   거의 다 쓰면) 위 절반의 키패드 반대쪽 위 모서리에 둔다. LCD가 그 버튼과 가로로 겹치면 LCD를 버튼 아래로
///   줄이고, 폭 상한 덕에 버튼 옆(간격 [CalcTheme.screenSettingsGap] 이상)으로 비켜 있으면 줄이지 않는다.
/// - 모든 영역은 본체 안에 있고 접힘선 위에 놓이지 않는다 (음수·비유한 크기는 0으로 본다).
@immutable
class CalcTabletopLayout {
  /// LCD 영역 (본체 좌표, dp)
  final Rect lcd;

  /// 키패드 영역 (본체 좌표, dp) — [keypadArrangement] 배열의 [KeypadMetrics.fitSize] 결과 크기
  final Rect keypad;

  /// 키패드 구역 배열 — 아래 절반에서 키가 더 큰 쪽 ([KeypadMetrics.preferredArrangementFor], #80)
  final KeypadArrangement keypadArrangement;

  /// 설정 버튼 영역 (본체 좌표, dp)
  final Rect settingsButton;

  const CalcTabletopLayout._({
    required this.lcd,
    required this.keypad,
    required this.keypadArrangement,
    required this.settingsButton,
  });

  /// [body] (시스템 인셋·화면 여백을 뺀 본체 영역)를 가로 접힘선 [hinge](본체 좌표)로 위아래로 나눈다.
  factory CalcTabletopLayout.of(Size body, Rect hinge, Handedness handedness) {
    double finite(double v) => v.isFinite ? math.max(0.0, v) : 0.0;
    final width = finite(body.width);
    final height = finite(body.height);
    final onRight = handedness.keypadOnRight;
    final topEnd = (finite(hinge.top) - CalcTheme.screenHingeMargin).clamp(
      0.0,
      height,
    );
    final bottomStart = (finite(hinge.bottom) + CalcTheme.screenHingeMargin)
        .clamp(topEnd, height);

    // 아래 절반은 낮고 넓어, 넓은 배열의 키가 더 크면 그 배열로 놓는다 (#80). 두 배열 모두 #141 전의 폭 상한을
    // 그대로 적용한 영역에서 잰다(#143까지 — [_interimKeypadRegion]).
    final keypadRegion = Size(width, height - bottomStart);
    final standardRegion = _interimKeypadRegion(
      keypadRegion,
      KeypadArrangement.standard,
    );
    final wideRegion = _interimKeypadRegion(
      keypadRegion,
      KeypadArrangement.wide,
    );
    final arrangement =
        KeypadMetrics.minKeyTouchHeightOf(wideRegion, KeypadArrangement.wide) >
            KeypadMetrics.minKeyTouchHeightOf(
              standardRegion,
              KeypadArrangement.standard,
            )
        ? KeypadArrangement.wide
        : KeypadArrangement.standard;
    final keypadSize = KeypadMetrics.fitSize(
      arrangement == KeypadArrangement.wide ? wideRegion : standardRegion,
      arrangement,
    );
    final keypad = Rect.fromLTWH(
      onRight ? width - keypadSize.width : 0.0,
      height - keypadSize.height,
      keypadSize.width,
      keypadSize.height,
    );

    // LCD 폭 상한 (#92, #143에서 위 패널을 기록·활성 LCD로 나눌 때까지) — 키패드와 같은 쪽 가장자리에 붙인다.
    final lcdWidth = math.min(width, CalcTheme.screenTabletopLcdMaxWidth);
    final lcdLeft = onRight ? width - lcdWidth : 0.0;

    const button = CalcTheme.settingsButtonSize;
    final buttonWidth = math.min(button, width);
    final besideKeypad =
        width - keypadSize.width >= CalcTheme.screenPanelGap + button &&
        keypadSize.height >= button;
    final buttonLeft = onRight ? 0.0 : width - buttonWidth;
    final Rect settings;
    var lcdRegionTop = 0.0;
    if (besideKeypad) {
      settings = Rect.fromLTWH(buttonLeft, keypad.top, buttonWidth, button);
    } else {
      // 위 절반 위 모서리 — LCD가 버튼과 가로로 겹치면 LCD를 그 아래로 줄인다.
      final buttonHeight = math.min(button, topEnd);
      settings = Rect.fromLTWH(buttonLeft, 0, buttonWidth, buttonHeight);
      final clearOfButton = onRight
          ? lcdLeft >= settings.right + CalcTheme.screenSettingsGap
          : lcdLeft + lcdWidth <= settings.left - CalcTheme.screenSettingsGap;
      if (!clearOfButton) {
        lcdRegionTop = math.min(
          buttonHeight + CalcTheme.screenSettingsGap,
          topEnd,
        );
      }
    }

    // 줄 글자 상한 높이(#189)는 적용하지 않는다 — LCD 폭 상한(480dp)에서 줄 글자가 폭에 묶여(39.1dp) 상한에 닿지 않는다.
    final lcdHeight = math.min(
      lcdWidth / CalcTheme.screenLcdMinAspectRatio,
      topEnd - lcdRegionTop,
    );
    final lcd = Rect.fromLTWH(lcdLeft, topEnd - lcdHeight, lcdWidth, lcdHeight);
    return CalcTabletopLayout._(
      lcd: lcd,
      keypad: keypad,
      keypadArrangement: arrangement,
      settingsButton: settings,
    );
  }

  /// [region](아래 절반)을 #141 전 키패드 폭 상한으로 줄인 영역 — #143에서 접힘선 배치를 다시 정할 때까지 테이블톱만
  /// 예전 배치를 유지한다. `KeypadMetrics.fitSize`는 #141부터 받은 폭을 다 쓰므로(가로 상한 없음), 여기서 영역 폭을
  /// 블록 폭 [CalcTheme.screenTabletopKeypadMaxBlockWidth]·블록 가로/세로 비 [CalcTheme.screenTabletopKeypadMaxAspectRatio]
  /// (넓은 배열은 × `KeypadMetrics.wideHeightFactor`) 이하로 먼저 줄인다. 그러면 크기가 #141 전 `fitSize`와 같다.
  /// 키패드가 아래 절반 폭을 다 쓰지 않는 창(세로로 긴 대화면 716×1200 등)은 그 옆에 설정 버튼을 두는 배치(#80)도
  /// 그대로다.
  static Size _interimKeypadRegion(Size region, KeypadArrangement arrangement) {
    final wide = arrangement == KeypadArrangement.wide;
    final block = math.min(
      CalcTheme.screenTabletopKeypadMaxBlockWidth,
      region.height *
          CalcTheme.screenTabletopKeypadMaxAspectRatio *
          (wide ? KeypadMetrics.wideHeightFactor : 1),
    );
    final units = wide ? 2 + CalcTheme.keypadWideSectionGapRatio : 1.0;
    return Size(math.min(region.width, block * units), region.height);
  }

  @override
  String toString() =>
      'CalcTabletopLayout(lcd: $lcd, keypad: $keypad ($keypadArrangement), '
      'settings: $settingsButton)';
}

/// LCD 위 상단 띠의 내용 배치 (#41). 기준은 [CalcTheme]의 "상단 띠" 절을 따른다.
///
/// 좌표는 다른 배치 클래스와 같은 본체 좌표다. 띠는 본체 위 화면 여백([CalcTheme.screenPadding])까지 쓰므로
/// 띠 윗변은 `y = −screenPadding`이고, 그래서 영역의 `top`이 음수일 수 있다.
/// ```
///   y = −screenPadding ┌──────────────────────────────┐ ← 띠 윗변 (상단 시스템 인셋 바로 아래)
///                      │        (높은 띠의 빈 곳)      │
///                      │ AltCalc          ▮▮▮▮     ⚙  │ ← 내용 줄 [row] (LCD 바로 위, LCD와 같은 폭)
///   y = lcd.top        ├──────────── LCD ─────────────┤
/// ```
/// - 내용 줄: 높이는 띠 높이와 [CalcTheme.topStripRowMaxHeight] 중 작은 쪽.
/// - 설정 버튼([settingsButton]): 줄 오른쪽 끝의 [CalcTheme.settingsButtonSize] 정사각형 터치 영역.
///   줄이 그보다 낮으면 줄 윗변에서 아래로 LCD 위에 겹치고, 아이콘은 위쪽 [settingsVisualHeight](= 줄 높이)
///   구간 가운데에 그린다. 위아래 배치·가로형은 띠에 둔다 — 버튼이 다른 곳에 있는 배치는 그 영역을
///   `settingsButton` 인자로 넘기고, 이때 [settingsButton]은 `null`이다.
/// - 워드마크([wordmark])·태양전지 장식([solarPanel]): 줄 높이·폭이 모자라면 `null`(그리지 않음).
///   다른 곳의 설정 버튼과 겹치면 둘 다 `null`이다.
@immutable
class CalcTopStripLayout {
  /// 내용 줄 영역 (본체 좌표, dp)
  final Rect row;

  /// 띠에 둔 설정 버튼의 터치 영역 (본체 좌표, dp). 버튼이 다른 곳에 있는 배치는 `null`.
  final Rect? settingsButton;

  /// 설정 버튼 터치 영역 위쪽에서 아이콘·눌림 표시를 그리는 구간 높이 (dp) — 줄 높이
  final double settingsVisualHeight;

  /// 설정 아이콘 크기 (dp)
  final double settingsIconSize;

  /// 워드마크 자리 (본체 좌표, dp). 그리지 않으면 `null`.
  final Rect? wordmark;

  /// 워드마크 글자 크기 (dp, 배율 반영 전)
  final double wordmarkFontSize;

  /// 태양전지 장식 영역 (본체 좌표, dp). 그리지 않으면 `null`.
  final Rect? solarPanel;

  const CalcTopStripLayout._({
    required this.row,
    required this.settingsButton,
    required this.settingsVisualHeight,
    required this.settingsIconSize,
    required this.wordmark,
    required this.wordmarkFontSize,
    required this.solarPanel,
  });

  /// 높이 문턱 비교의 허용 오차 (dp) — 최소 띠의 줄 높이가 워드마크 문턱과 같으므로, 부동소수점 오차로
  /// 문턱 바로 아래가 되어도 숨기지 않는다.
  static const double _epsilon = 1e-6;

  /// [body](본체 크기) 안의 [lcd](본체 좌표) 위 띠 배치.
  /// [settingsButton]은 띠 밖 다른 곳에 놓인 설정 버튼 영역이다 — `null`이면 띠 안(줄 오른쪽 끝)에 둔다.
  factory CalcTopStripLayout.of(Size body, Rect lcd, {Rect? settingsButton}) {
    double finite(double v) => v.isFinite ? math.max(0.0, v) : 0.0;
    final bodyHeight = finite(body.height);
    const bandTop = -CalcTheme.screenPadding;
    final lcdTop = finite(lcd.top);
    final lcdLeft = finite(lcd.left);
    final width = finite(lcd.width);
    final rowHeight = math.min(
      lcdTop - bandTop,
      CalcTheme.topStripRowMaxHeight,
    );
    final row = Rect.fromLTWH(lcdLeft, lcdTop - rowHeight, width, rowHeight);

    // 설정 버튼: 줄 오른쪽 끝. 터치 영역은 줄 윗변에서 아래로 버튼 크기만큼(본체 아래로는 나가지 않는다).
    Rect? button;
    if (settingsButton == null) {
      final size = math.min(CalcTheme.settingsButtonSize, width);
      button = Rect.fromLTRB(
        row.right - size,
        row.top,
        row.right,
        math.max(
          row.bottom,
          math.min(row.top + CalcTheme.settingsButtonSize, bodyHeight),
        ),
      );
    }
    final iconSize = (rowHeight - 2 * CalcTheme.topStripIconMargin).clamp(
      CalcTheme.settingsIconMinSize,
      CalcTheme.settingsIconSize,
    );

    // 장식이 쓸 수 있는 오른쪽 끝 — 띠 안의 설정 버튼 왼쪽, 버튼이 없으면 줄 안쪽 여백
    final contentLeft = row.left + CalcTheme.topStripInset;
    final contentRight = button != null
        ? button.left - CalcTheme.topStripGap
        : row.right - CalcTheme.topStripInset;

    Rect? wordmark;
    final wordmarkWidth = math.min(
      width * CalcTheme.topStripWordmarkMaxWidthRatio,
      contentRight - contentLeft,
    );
    if (rowHeight >= CalcTheme.topStripWordmarkMinHeight - _epsilon &&
        wordmarkWidth >= CalcTheme.topStripWordmarkMinWidth) {
      wordmark = Rect.fromLTWH(contentLeft, row.top, wordmarkWidth, rowHeight);
    }

    Rect? solar;
    if (wordmark != null &&
        rowHeight >= CalcTheme.topStripSolarMinHeight - _epsilon) {
      final solarHeight = rowHeight * CalcTheme.topStripSolarHeightRatio;
      final solarWidth = solarHeight * CalcTheme.topStripSolarAspectRatio;
      final solarLeft = contentRight - solarWidth;
      if (solarLeft >= wordmark.right + CalcTheme.topStripGap) {
        solar = Rect.fromLTWH(
          solarLeft,
          row.top + (rowHeight - solarHeight) / 2,
          solarWidth,
          solarHeight,
        );
      }
    }

    // 다른 곳에 놓인 설정 버튼(테이블톱 위 절반 모서리)과 겹치는 장식 줄에는 아무것도 그리지 않는다.
    if (settingsButton != null &&
        row.overlaps(settingsButton.inflate(CalcTheme.topStripGap))) {
      wordmark = null;
      solar = null;
    }

    return CalcTopStripLayout._(
      row: row,
      settingsButton: button,
      settingsVisualHeight: rowHeight,
      settingsIconSize: iconSize,
      wordmark: wordmark,
      wordmarkFontSize: math.min(
        rowHeight * CalcTheme.topStripWordmarkFontRatio,
        CalcTheme.topStripWordmarkMaxFontSize,
      ),
      solarPanel: solar,
    );
  }

  @override
  String toString() =>
      'CalcTopStripLayout(row: $row, settings: $settingsButton '
      '(visual $settingsVisualHeight, icon $settingsIconSize), '
      'wordmark: $wordmark @$wordmarkFontSize, solar: $solarPanel)';
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
/// - **접힘선 기준 배치** (폴더블 내부 화면, #25): 세로 접힘선이면 접힘선을 경계로 좌우 배치([CalcHingeSplitLayout]),
///   가로 접힘선이면 위 절반 LCD·아래 절반 키패드([CalcTabletopLayout]).
/// - **짧은 창** (#38): 폴더블 기기·접힘 정보가 있어 위아래 배치로 그리는 창도 짧은 변 600dp 미만이면 위아래 배치와 가로형
///   중 키가 큰 쪽으로 그린다. 어느 배치든 그린 키가 [CalcTheme.keyTouchHeightUsableMin]보다 낮으면 계산기 대신 창을
///   키워 달라는 안내를 띄운다([CalcTheme] "짧은 창" 절).
/// - 스크린리더 읽기 순서: 활성 LCD → 계산 기록 → 키패드 → 설정 버튼 (#142). 화면 위치와 무관하게 모든 배치에서 같다
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
///  │ AltCalc      ▮▮▮▮     ⚙ │  ← 상단 띠: 화면 여백 + [CalcScreenLayout.top] — 장식·설정 버튼
///  │                          │     ([CalcTopStripLayout], #41). 낮은 폰은 아이콘 줄(20dp)만 남는다
///  │          LCD             │  ← [CalcScreenLayout.lcdHeight]
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
    final bottomMargin = CalcTheme.screenBottomMargin(
      bottomInset: math.max(
        MediaQuery.viewPaddingOf(context).bottom,
        MediaQuery.viewInsetsOf(context).bottom,
      ),
      bottomGestureInset: MediaQuery.systemGestureInsetsOf(context).bottom,
    );
    return Scaffold(
      backgroundColor: CalcTheme.bodyBackground,
      // 맨 아래 광고 슬롯 없이 본체가 아래 시스템 인셋 위 아래 여백까지 쓴다 (#141, #63).
      body: SafeArea(
        child: Padding(
          // 위쪽 화면 여백은 `_Body`가 갖는다 — 상단 띠가 그 여백까지 쓴다 (#41).
          padding: EdgeInsets.only(
            left: CalcTheme.screenPadding,
            right: CalcTheme.screenPadding,
            bottom: bottomMargin,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => _BodyOriginCheck(
              expected: bodyOrigin,
              enabled: hinge != null,
              child: _Body(
                body: Size(
                  constraints.maxWidth,
                  math.max(0.0, constraints.maxHeight - _Body.origin.dy),
                ),
                arrangement: arrangement,
                picksFormByKeySize: FormFactor.picksFormByKeySize(
                  features,
                  foldableDevice: foldableDevice,
                ),
                smallWindow:
                    window.shortestSide < FormFactor.largeScreenMinShortestSide,
                hinge: hinge,
                // 진단 로그용 (#158) — 켜져 있을 때만 넘긴다
                diagnostics: LayoutLog.enabled
                    ? (
                        window: window,
                        features: features,
                        foldableDevice: foldableDevice,
                      )
                    : null,
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
        // child(`_Body`)는 위쪽 화면 여백을 포함하므로 그 안의 본체 원점을 본다.
        final actual = ScreenCoordinateRoot.globalToScreen(
          context,
          box.localToGlobal(_Body.origin),
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
    );
  }
}

/// 본체: LCD·기록 영역·키패드·상단 띠 장식·설정 버튼을 [arrangement]에 맞는 영역에 놓는다.
///
/// 모든 배치를 **같은 위젯 트리**(`Stack` + `Positioned.fromRect`, 자식 수·순서 고정)로 그린다. 그래서 회전·창
/// 크기 변경으로 배치가 바뀌어도 LCD·키패드 element가 유지되어 키 눌림 상태와 스크린리더 포커스가 사라지지 않는다
/// (#24 R2 — Android 16 태블릿·iPad는 방향 고정이 무시되어 회전이 잦다). 손잡이 설정이 바뀌어도
/// 영역 위치만 옮기고, LCD·키패드 위젯은 같은 인스턴스라 다시 빌드되지 않는다(가로형의 숫자부 좌우 대칭은 키패드 안 블록
/// 순서만 바꾼다 — 키 element는 그대로다, #142).
/// 폴더블을 접고 펴거나(#25) 내부 화면을 돌려 접힘선 방향이 바뀔 때도 마찬가지다. 기록 영역(#142)이 없는 배치에서도
/// 기록 영역 자식은 보이지 않게 남는다.
///
/// 스크린리더 읽기 순서는 영역마다 붙인 순서 키([OrdinalSortKey])로 정한다: 활성 LCD → 기록 → 키패드 → 설정 버튼 (#142).
///
/// 이 위젯은 본체 위 화면 여백([CalcTheme.screenPadding])까지 차지한다 — 상단 띠가 그 여백을 쓴다 (#41).
/// 배치 클래스들의 본체 좌표는 이 위젯 안에서 [origin]만큼 내려간 곳이 원점이다.
class _Body extends ConsumerWidget {
  /// 이 위젯 안에서 본체 좌표 원점의 위치 (위쪽 화면 여백 아래)
  static const Offset origin = Offset(0, CalcTheme.screenPadding);

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

  /// 진단 로그([LayoutLog], #158)에 적을 창 크기·화면 특징·폴더블 여부. 로그가 꺼져 있으면 `null`이다 — 부모가 이미
  /// 읽은 값을 받으므로 이 위젯은 로그 때문에 따로 의존을 걸지 않는다.
  final ({Size window, List<DisplayFeature> features, bool foldableDevice})?
  diagnostics;

  const _Body({
    required this.body,
    required this.arrangement,
    required this.picksFormByKeySize,
    required this.smallWindow,
    this.hinge,
    this.diagnostics,
  });

  /// 영역별 스크린리더 읽기 순서 (#142)
  static const double _lcdOrder = 0;
  static const double _historyOrder = 1;
  static const double _keypadOrder = 2;
  static const double _settingsOrder = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Rect lcd;
    final Rect keypad;
    // 키패드 구역 배열 — 가로형·테이블톱 배치는 넓은 배열을 쓸 수 있다 (#80, #142)
    var keypadArrangement = KeypadArrangement.standard;
    // 넓은 배열에서 숫자부를 왼쪽에 둘지 — 가로형의 왼손잡이 (#142)
    var numbersOnLeft = false;
    // 계산 기록 영역 — 가로형에서 위 띠가 충분히 클 때만 있다 (#142)
    Rect? history;
    // 상단 띠 내용 줄의 기준 영역 — LCD, 가로형은 위 띠 전체(활성 LCD + 기록)
    Rect? stripBase;
    // 띠 밖에 놓는 설정 버튼 (접힘선 기준 배치). 위아래 배치·가로형은 상단 띠 안에 둔다.
    Rect? settings;
    // 실제로 그린 배치 — 접힘선 기준 배치를 쓸 수 없어 위아래 배치로 그리면 [ScreenArrangement.stacked]다.
    // 설정 대화상자가 접힘선으로 나뉠지·손잡이 설정이 이 배치에 적용되는지 고를 때 쓴다 (#41 R1).
    final ScreenArrangement drawn;
    final hinge = this.hinge;
    final handedness = ref.watch(handednessProvider);
    // 위아래 배치 — 접힘선 기준 배치·가로형과의 비교가 이 배치의 키 크기를 본다.
    final stacked = _stackedRects(body);
    final stackedTouch = KeypadMetrics.minKeyTouchHeightOf(
      stacked.keypad.size,
      KeypadArrangement.standard,
    );
    // 접힘선 기준 배치를 쓸지: 키가 배치별 하한([floor]) 이상이거나, 하한 미만이어도 쓸 수 있는 크기
    // ([CalcTheme.keyTouchHeightUsableMin] 이상)이고 위아래 배치보다 크면 쓴다 (#38 R1 — 위아래 배치도 접힘선을
    // 가로지르므로, 더 작은 위아래 배치나 안내로 물러설 이유가 없다).
    bool acceptsHingeKeypad(
      Rect keypad,
      KeypadArrangement keypadArrangement,
      double floor,
    ) {
      final touch = KeypadMetrics.minKeyTouchHeightOf(
        keypad.size,
        keypadArrangement,
      );
      return touch >= floor ||
          (touch >= CalcTheme.keyTouchHeightUsableMin && touch > stackedTouch);
    }

    // 접힘선 기준 배치 후보. 키가 너무 작으면 쓰지 않는다 (#25 R2 — 본체 좌표로 판정해야
    // 인셋·화면 여백·접힘선 간격이 빠진 실제 키패드 크기를 본다).
    ({
      Rect lcd,
      Rect keypad,
      KeypadArrangement keypadArrangement,
      Rect settings,
    })?
    hingeLayoutFor(Handedness h) {
      if (hinge == null) return null;
      switch (arrangement) {
        case ScreenArrangement.hingeSplit:
          final l = CalcHingeSplitLayout.of(body, hinge, h);
          if (acceptsHingeKeypad(
            l.keypad,
            KeypadArrangement.standard,
            CalcTheme.keyTouchHeightFloor,
          )) {
            return (
              lcd: l.lcd,
              keypad: l.keypad,
              keypadArrangement: KeypadArrangement.standard,
              settings: l.settingsButton,
            );
          }
        case ScreenArrangement.hingeStacked:
          final l = CalcTabletopLayout.of(body, hinge, h);
          // 반 접은 테이블톱은 완화된 하한 — 위아래 배치는 세워진 위 절반으로 키 행이 올라간다(#25, #80 R1).
          if (acceptsHingeKeypad(
            l.keypad,
            l.keypadArrangement,
            CalcTheme.tabletopKeyTouchHeightFloor,
          )) {
            return (
              lcd: l.lcd,
              keypad: l.keypad,
              keypadArrangement: l.keypadArrangement,
              settings: l.settingsButton,
            );
          }
        case ScreenArrangement.stacked || ScreenArrangement.landscape:
          break;
      }
      return null;
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
        keypad = hingeLayout.keypad;
        keypadArrangement = hingeLayout.keypadArrangement;
        settings = hingeLayout.settings;
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
          stripBase = landscape.band;
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
    // 그린 배치의 키도 쓸 수 없을 만큼 작으면(#38) 계산기 대신 안내를 띄운다. LCD·키패드·띠·설정 버튼은
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
        tooSmall: tooSmall,
        window: diagnostics.window,
        features: diagnostics.features,
        foldableDevice: diagnostics.foldableDevice,
      );
    }
    // 손잡이를 바꾸면 배치가 달라지는지 (#41 R2): 위아래 배치로 그렸어도, 반대 손잡이로는 접힘선 기준 배치가
    // 될 수 있다(세로 접힘선 양쪽 폭이 다르면 키패드가 들어갈 절반이 손잡이마다 다르다).
    // 접힘선 기준 배치는 반대 손잡이로도 같은 배치이고 키패드 자리가 같으면 키패드가 옮겨 가지 않는다 — 넓은
    // 키패드 배열(#80)이 아래 절반 폭을 다 쓰는 테이블톱(Fold 가로·Pixel Fold 세로 반 접힘)이 그렇다(#80 R1).
    // 가로형은 숫자부와 활성 LCD가 손 쪽으로 옮겨 간다(#142).
    final otherLayout =
        hingeLayouts[handedness == Handedness.right
            ? Handedness.left
            : Handedness.right];
    final keypadMoves = switch (drawn) {
      ScreenArrangement.landscape => true,
      ScreenArrangement.hingeSplit || ScreenArrangement.hingeStacked =>
        otherLayout == null || !_keypadStaysPut(otherLayout.keypad, keypad),
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
    // 상단 띠 (#41): LCD(가로형은 위 띠 전체) 위에 장식 줄을 두고, 위아래 배치·가로형은 설정 버튼도 그 줄에 둔다.
    final strip = CalcTopStripLayout.of(
      body,
      stripBase ?? lcd,
      settingsButton: settings,
    );
    final stripButton = strip.settingsButton;
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
    return Stack(
      children: [
        Positioned.fromRect(
          rect: lcd.shift(origin),
          child: shown(ordered(_lcdOrder, const _LcdPanel())),
        ),
        // 기록 영역이 없는 배치에서도 자식 자리를 지켜 트리 모양을 고정한다.
        Positioned.fromRect(
          rect: (history ?? Rect.zero).shift(origin),
          child: shown(
            ordered(_historyOrder, const HistoryPanel()),
            visible: history != null,
          ),
        ),
        Positioned.fromRect(
          rect: keypad.shift(origin),
          // 배열마다 const 인스턴스라, 손잡이만 바뀌고 키패드 크기·배열이 같으면 키패드 50개를 다시 빌드하지 않는다
          // (크기가 바뀌면 `CalcKeypad`가 새 치수로 다시 빌드한다). 가로형의 손잡이 변경은 숫자부 쪽이 바뀌어 다시 빌드한다.
          child: shown(
            ordered(_keypadOrder, switch ((keypadArrangement, numbersOnLeft)) {
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
        Positioned.fromRect(
          rect: strip.row.shift(origin),
          child: shown(
            TopStripDecoration(
              wordmark: strip.wordmark?.shift(-strip.row.topLeft),
              wordmarkFontSize: strip.wordmarkFontSize,
              solarPanel: strip.solarPanel?.shift(-strip.row.topLeft),
            ),
          ),
        ),
        // 띠 안의 버튼은 터치 영역이 LCD·기록 영역 위쪽에 겹칠 수 있어 그보다 나중에(위에) 둔다.
        Positioned.fromRect(
          rect: (settings ?? stripButton!).shift(origin),
          child: shown(
            ordered(
              _settingsOrder,
              stripButton == null
                  ? SettingsButton(
                      arrangement: drawn,
                      handednessApplies: handednessApplies,
                      handednessKeepsArrangement: handednessKeepsArrangement,
                    )
                  : SettingsButton(
                      arrangement: drawn,
                      handednessApplies: handednessApplies,
                      handednessKeepsArrangement: handednessKeepsArrangement,
                      visualHeight: strip.settingsVisualHeight,
                      iconSize: strip.settingsIconSize,
                    ),
            ),
          ),
        ),
        // 마지막 자식이라 있다가 없어져도 앞 자식들의 element는 그대로다.
        if (tooSmall) const Positioned.fill(child: WindowTooSmallNotice()),
      ],
    );
  }

  /// 손잡이를 바꿔도 키패드가 [a] → [b]로 사실상 같은 자리인지. 크기는 같고(부동소수점 오차 0.5dp 미만), 가로 이동이
  /// [CalcTheme.screenPanelGap](16dp) 미만이면 같은 자리로 본다 — 넓은 배열 블록 폭이 상한에 걸려 아래 절반 폭에서
  /// 몇 dp만 남는 창(반 접힌 폭 약 1010dp: 5.2dp 이동)은 키패드가 옮겨 갔다고 느낄 수 없다(#80 R2).
  static bool _keypadStaysPut(Rect a, Rect b) {
    const e = 0.5;
    return (a.width - b.width).abs() < e &&
        (a.top - b.top).abs() < e &&
        (a.bottom - b.bottom).abs() < e &&
        (a.left - b.left).abs() < CalcTheme.screenPanelGap;
  }

  /// 위아래 배치의 LCD·키패드 영역 (본체 좌표) — [CalcScreenLayout].
  static ({Rect lcd, Rect keypad}) _stackedRects(Size body) {
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
  ///   그렸다가 바꾸는 깜빡임을 막는다(#25). 이 창들의 배치는 #143·#144에서 다시 정한다.
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

/// 창이 너무 작아 키패드를 쓸 수 없다는 안내 (#38) — 본체(위쪽 화면 여백 포함) 전체를 덮는다.
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
    final color = CalcPalette.of(context).settingsIcon;
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
