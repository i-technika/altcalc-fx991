import 'dart:math' as math;
import 'dart:ui' show DisplayFeature;

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/key_definitions.dart';
import '../../core/layout/form_factor.dart';
import '../../core/layout/layout_log.dart';
import '../../core/theme/calc_theme.dart';
import '../../domain/models/handedness.dart';
import '../l10n/calc_semantic_strings.dart';
import '../l10n/settings_strings.dart';
import '../providers/calc_provider.dart';
import '../providers/device_provider.dart';
import '../providers/release_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/calc_body_background.dart';
import '../widgets/calc_keypad.dart';
import '../widgets/lcd_display.dart';
import '../widgets/screen_coordinate_root.dart';
import '../widgets/settings_launcher.dart';

/// 본체 영역의 세로 배치 (위 → 아래: LCD · 간격 · 키패드) — 접힘선 없는 세로로 긴 창의 "세로형" 배치 (#141).
///
/// 기준은 [CalcTheme]의 "화면 배치" 절을 따른다 (#23, #141, #190, #232).
/// - 폭: LCD와 키패드 모두 본체 폭 전체를 쓴다 (#141 — 폭 상한 없음, 태블릿 세로에서도 양옆이 비지 않는다).
/// - LCD 높이: [CalcTheme.screenLcdHeightRatio] 목표, [CalcTheme.screenLcdMinHeight] ~ 최대 높이 범위. 최대 높이는
///   (본체 폭 / [CalcTheme.screenLcdMinAspectRatio])와 줄 글자 상한 높이([LcdFontSizes.heightAtMaxLineFont], #189) 중 낮은 쪽
///   ([_lcdMaxHeightOf]) — 태블릿 세로는 상한 높이에서 멈추고 남는 높이를 키패드가 받는다.
/// - 키패드: 나머지 높이 중 가로/세로 비 하한([CalcTheme.keypadMinAspectRatio] — 키가 세로로 길어지지 않게)이
///   허용하는 만큼.
/// - 키패드가 쓰지 못하는 높이(#190, #232): LCD가 상한 없이 모두 받는다 — 위 최대 높이를 넘을 수 있다(줄 글자는 커지지 않고
///   입력·결과 줄만 높아진다, [CalcTheme] "화면 배치" 절). LCD는 본체 윗변부터 키패드 바로 위까지다 — LCD 위에 빈 곳이 없다.
///   (#232 전에는 LCD가 줄 글자 상한 높이까지만 받고 그 위가 빈 곳으로 남았다 — 412×915에서 약 17.5dp. #190 전에는 LCD 위
///   상단 띠(장식·설정 버튼, #41)가 최소 12dp와 남는 높이를 받았다.)
/// - 본체가 아주 낮으면 키패드 높이가 0이 될 때까지만 LCD를 최소 높이로 지킨다. 우선순위는 LCD 최소 높이 > 키패드다
///   (#38에서 유지하기로 정함). 키가 작아지는 짧은 창은 이 배치 안에서 높이를 나누는 대신 화면이 가로형
///   ([CalcLandscapeLayout])으로 바꾸거나 안내를 띄운다([CalculatorScreen], [CalcTheme] "짧은 창" 절).
///   본체가 간격보다 낮으면 간격은 본체 높이까지만 받아, 어떤 경우에도 합계가 본체 높이를 넘지 않는다.
@immutable
class CalcScreenLayout {
  /// LCD 높이 (dp) — LCD 폭은 본체 폭이고(#141), LCD 윗변은 본체 윗변이다(#232)
  final double lcdHeight;

  /// LCD와 키패드 사이 간격 (dp) — [CalcTheme.screenLcdKeypadGap], 본체가 그보다 낮으면 본체 높이
  final double gap;

  /// 키패드 영역 높이 (dp) — 키패드 폭은 본체 폭이다 (#141)
  final double keypadHeight;

  const CalcScreenLayout._({
    required this.lcdHeight,
    required this.gap,
    required this.keypadHeight,
  });

  /// [body] (시스템 인셋·화면 여백을 뺀 본체 영역)의 세로 배치.
  /// `lcdHeight + gap + keypadHeight`는 본체 높이와 같다 (음수·비유한 크기는 0으로 본다).
  factory CalcScreenLayout.of(Size body) {
    double finite(double v) => v.isFinite ? math.max(0.0, v) : 0.0;
    final width = finite(body.width);
    final divided = _divideBodyHeight(
      finite(body.height),
      lcdMaxHeight: _lcdMaxHeightOf(width),
      keypadMaxHeight: KeypadMetrics.fitSize(Size(width, double.infinity))
          .height,
    );
    return CalcScreenLayout._(
      lcdHeight: divided.lcd,
      gap: divided.gap,
      keypadHeight: divided.keypad,
    );
  }

  @override
  String toString() =>
      'CalcScreenLayout(lcd: $lcdHeight, gap: $gap, keypad: $keypadHeight)';
}

/// 본체 높이 [bodyHeight](유한한 0 이상 값)를 위 → 아래 (LCD · 간격 · 키패드)로 나눈다 — 세로형([CalcScreenLayout])과
/// 가로형([CalcLandscapeLayout])이 같이 쓰는 규칙이다 (#23, #142, #190).
/// - LCD: 목표 높이(= 본체 높이 × [CalcTheme.screenLcdHeightRatio])를 [CalcTheme.screenLcdMinHeight] ~
///   [lcdMaxHeight] 범위로 제한한다(최대 높이가 최소 높이보다 낮으면 최소 높이). 최대 높이는 세로형이 [_lcdMaxHeightOf]
///   (줄 글자 상한 #189 포함), 가로형의 위 띠가 본체 폭 / [CalcTheme.screenLcdMinAspectRatio]다.
/// - 키패드: 나머지 높이, [keypadMaxHeight]까지. 키패드가 세로 한계에 닿아 쓰지 못하는 높이는 모두 LCD 쪽([lcd] —
///   세로형은 LCD, 가로형은 위 띠)이 받는다(#190 전에는 최대 높이를 넘는 몫이 LCD 위 상단 띠였다. #232 전에는 세로형 LCD가
///   줄 글자 상한 높이까지만 받고 그 위가 비었다).
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
///
/// 이 높이는 LCD가 **목표로 가져가는** 높이의 상한이다 — 그보다 남는 높이를 키패드가 쓸 수 있으면 키패드가 받는다(태블릿
/// 세로). 키패드도 쓰지 못해 남는 높이는 LCD가 이 상한을 넘어 받는다(#232 — LCD 위나 아래에 본체만 보이는 빈 곳을 두지
/// 않는다, [CalcTheme] "화면 배치" 절).
double _lcdMaxHeightOf(double lcdWidth) => math.min(
  lcdWidth / CalcTheme.screenLcdMinAspectRatio,
  LcdFontSizes.heightAtMaxLineFont,
);

/// 접힘선 없는 가로로 넓은 창의 "가로형" 배치 (#142, [ScreenArrangement.landscape]). 기준은 [CalcTheme]의 "가로형 배치"
/// 절을 따른다.
///
/// 오른손잡이([Handedness.right]) 기준 (왼손잡이는 좌우 대칭 — 숫자부가 왼쪽):
/// ```
///  ┌──────────────────────────────────────────────┐ ← 본체 위
///  │            LCD [lcd] — 넓은 계산 영역           │ ← 위 띠 (본체 폭 전체)
///  ├────────────────────┬──┬──────────────────────┤
///  │ 상단 조작부 + 함수부 │  │       숫자부          │ ← 넓은 배열 키패드 [keypad]
///  │      5행 × 6열      │  │      4행 × 5열        │
///  └────────────────────┴──┴──────────────────────┘ ← 본체 아래
///   └──── 블록 ────────┘ 간격 └──── 블록 ─────────┘
/// ```
/// - 키패드: 넓은 배열([KeypadArrangement.wide])로 본체 폭 전체를 쓰고 본체 아래에 붙인다. 높이는 넓은 배열의 세로 한계
///   ([KeypadMetrics.fitSize])까지다. 숫자부는 주로 쓰는 손 쪽 블록이다([numbersOnLeft]).
/// - 높이 나누기: 세로형([CalcScreenLayout])과 같은 규칙을 본체 폭으로 쓴다 — LCD 목표 비율
///   ([CalcTheme.screenLcdHeightRatio]) · 최소 높이 · 최대 높이(본체 폭 / [CalcTheme.screenLcdMinAspectRatio] — 세로형과 달리
///   줄 글자 상한 높이로 줄이지 않는다, #189) 안에서 LCD,
///   나머지는 키패드가 세로 한계까지 받고, 키패드가 쓰지 못하는 높이는 모두 LCD가 받는다(#190 — 상단 띠가 없다).
/// - LCD: 본체 윗변부터 키패드 위 간격까지, 본체 폭 전체다 — 넓은 계산 영역(#284, 2026-11-28 사용자 결정). LCD가 그 폭의
///   최대 높이([_lcdMaxHeightOf] — 폭 / [CalcTheme.screenLcdMinAspectRatio]와 줄 글자 상한 높이(#189) 중 낮은 쪽)보다 높으면
///   글자는 커지지 않고 입력·결과 줄만 높아진다(#232).
///   #284 전에는 위 띠를 키패드 블록에 맞춰 둘로 나눠 숫자부 위를 활성 LCD, 함수부 위를 계산 기록 영역(#142·#145)으로 썼다.
///   기록 목록(#145)을 하지 않기로 하면서 기록 영역 자리를 LCD에 붙였다.
/// - 모든 영역은 본체 안에 있다 (음수·비유한 크기는 0으로 본다).
@immutable
class CalcLandscapeLayout {
  /// LCD 영역 (본체 좌표, dp) — 본체 윗변 ~ 키패드 위 간격, 본체 폭 전체
  final Rect lcd;

  /// 키패드 영역 (본체 좌표, dp) — [KeypadArrangement.wide] 배열
  final Rect keypad;

  /// 숫자부를 왼쪽에 두는지 — 왼손잡이
  final bool numbersOnLeft;

  const CalcLandscapeLayout._({
    required this.lcd,
    required this.keypad,
    required this.numbersOnLeft,
  });

  /// [body] (시스템 인셋·화면 여백을 뺀 본체 영역)의 가로형 배치. [handedness]가 숫자부 쪽을 정한다.
  factory CalcLandscapeLayout.of(Size body, Handedness handedness) {
    double finite(double v) => v.isFinite ? math.max(0.0, v) : 0.0;
    final width = finite(body.width);
    final height = finite(body.height);
    final keypadMaxHeight = KeypadMetrics.fitSize(
      Size(width, double.infinity),
      KeypadArrangement.wide,
    ).height;
    // LCD는 본체 윗변부터다(#190).
    final base = _divideBodyHeight(
      height,
      lcdMaxHeight: width / CalcTheme.screenLcdMinAspectRatio,
      keypadMaxHeight: keypadMaxHeight,
    );
    final lcd = Rect.fromLTWH(0, 0, width, base.lcd);
    // 남는 높이(반올림 오차 등)는 키패드가 받는다 (세로형 [_stackedRectsOf]와 같다).
    final keypadTop = math.min(lcd.bottom + base.gap, height);
    return CalcLandscapeLayout._(
      lcd: lcd,
      keypad: Rect.fromLTRB(0, keypadTop, width, height),
      numbersOnLeft: !handedness.keypadOnRight,
    );
  }

  @override
  String toString() =>
      'CalcLandscapeLayout(lcd: $lcd, keypad: $keypad, '
      'numbersOnLeft: $numbersOnLeft)';
}

/// 접힘선 기준 배치 후보 하나 ([CalcHingeSplitLayout]·[CalcTabletopLayout]을 화면이 같은 모양으로 다룬다).
/// [minSectionGap]은 넓은 배열의 블록 사이 최소 간격이다(책 자세의 접힘선, #285 — 가로 접힘선은 0).
typedef _HingeRegions = ({
  Rect lcd,
  Rect keypad,
  KeypadArrangement keypadArrangement,
  bool numbersOnLeft,
  double minSectionGap,
});

/// 세로 접힘선 기준 배치 (#25, #143, #285, [ScreenArrangement.hingeSplit] — 폴더블 책 자세). 태블릿 가로형
/// ([CalcLandscapeLayout])과 같은 구성이고, 넓은 배열 키패드의 두 블록 사이에 접힘선이 온다(2026-11-28 사용자 결정, #285).
/// 기준은 [CalcTheme]의 "접힘선 기준 배치" 절을 따른다.
///
/// 오른손잡이([Handedness.right]) 기준 (왼손잡이는 좌우 대칭 — 숫자부가 왼쪽 패널):
/// ```
///  ┌────────────────────┆──────────────────────┐ ← 본체 위
///  │        LCD [lcd] — 넓은 계산 영역 (접힘선에 걸침)     │
///  ├────────────────────┆──────────────────────┤
///  │ 상단 조작부 + 함수부 ┆       숫자부          │ ← 넓은 배열 키패드 [keypad]
///  │      5행 × 6열      ┆      4행 × 5열        │   블록 사이 간격에 접힘선
///  └────────────────────┆──────────────────────┘ ← 본체 아래
///  └── 왼쪽 패널 ───────┘ 접힘선 └─ 오른쪽 패널 ─┘
/// ```
/// - 키패드: 넓은 배열([KeypadArrangement.wide])을 접힘선 가운데를 기준으로 좌우 대칭으로 두고 본체 아래에 붙인다. 블록
///   폭은 두 패널(접힘선 양쪽 [CalcTheme.screenHingeMargin]을 뺀 쪽) 중 좁은 쪽 폭이고, 블록 사이 간격은 접힘선 폭 + 양쪽
///   여백([minSectionGap]) 이상이다 — 보통 간격(블록 폭의 [CalcTheme.keypadWideSectionGapRatio]배)이 더 넓으면 그만큼 블록이
///   줄어든다. 그래서 어느 키도 접힘선 위에 놓이지 않는다. 접힘선이 창 가운데가 아니면 넓은 패널의 바깥쪽이 빈다.
///   숫자부는 주로 쓰는 손 쪽 패널이다([numbersOnLeft], 2026-11-28 사용자 결정 — 손잡이 설정을 따른다).
/// - LCD: 본체 윗변부터 키패드 위 간격까지, 본체 폭 전체다 — 넓은 계산 영역이고 폭 0 접힘선(Galaxy Z Fold·Pixel Fold)에
///   그대로 걸친다. 폭이 있는 물리 힌지(두 화면 기기 — 그 자리에 화면이 없다, [occludingHingeWidth] 초과)에서는 숫자부 쪽
///   패널에만 둔다([lcdOnNumberPanel], 사용자 결정 — 글자가 힌지에 가리지 않게). 함수부 쪽 패널의 같은 높이는 빈 본체다.
/// - 높이 나누기: 가로형과 같은 규칙이다([_divideBodyHeight] — LCD 목표 비율·최소 높이·최대 높이(LCD 폭 /
///   [CalcTheme.screenLcdMinAspectRatio]) 안에서 LCD, 나머지는 키패드가 세로 한계까지 받고 키패드가 쓰지 못하는 높이는 LCD가
///   받는다).
/// - #285 전에는 손 쪽 패널에 세로형(위 활성 LCD, 아래 실물 배열 키패드)을 그 패널 크기로 두고 반대쪽 패널 전체를 계산 기록
///   영역으로 썼다(#143). 손 쪽 패널이 짧은 창은 활성 LCD를 반대쪽 패널로 옮기고 키패드가 위 시스템 제스처 영역 아래까지
///   올라갔다(#143 R1, #172). 기록 목록(#145)을 하지 않기로 하면서 태블릿 가로형처럼 바꿨다.
/// - 모든 영역은 본체 안에 있다 (음수·비유한 크기는 0으로 본다).
@immutable
class CalcHingeSplitLayout {
  /// LCD 영역 (본체 좌표, dp) — 본체 폭 전체, 물리 힌지면 숫자부 쪽 패널([lcdOnNumberPanel])
  final Rect lcd;

  /// 키패드 영역 (본체 좌표, dp) — [KeypadArrangement.wide] 배열, 접힘선 가운데 기준 좌우 대칭, 본체 아래에 붙음
  final Rect keypad;

  /// 숫자부를 왼쪽 패널에 두는지 — 왼손잡이
  final bool numbersOnLeft;

  /// 넓은 배열 블록 사이 최소 간격 (dp) — 접힘선 폭 + 양쪽 [CalcTheme.screenHingeMargin] (`CalcKeypad.minSectionGap`)
  final double minSectionGap;

  /// 물리 힌지라 LCD를 숫자부 쪽 패널에만 두었는지
  final bool lcdOnNumberPanel;

  const CalcHingeSplitLayout._({
    required this.lcd,
    required this.keypad,
    required this.numbersOnLeft,
    required this.minSectionGap,
    required this.lcdOnNumberPanel,
  });

  /// LCD가 걸쳐도 되는 접힘선 폭의 상한 (dp) — 이보다 넓은 접힘선(물리 힌지)에서는 LCD를 숫자부 쪽 패널에만 둔다.
  /// 폭 0 접힘선의 보고 오차(에뮬레이터 `7.6in Foldable`의 1px `hinge` = 0.38dp)를 걸러 낸다.
  static const double occludingHingeWidth = 1.0;

  /// [body] (시스템 인셋·화면 여백을 뺀 본체 영역)를 세로 접힘선 [hinge](본체 좌표)로 나눈 책 자세. [handedness]가 숫자부
  /// 쪽 패널을 정한다.
  factory CalcHingeSplitLayout.of(
    Size body,
    Rect hinge,
    Handedness handedness,
  ) {
    double finite(double v) => v.isFinite ? math.max(0.0, v) : 0.0;
    final width = finite(body.width);
    final height = finite(body.height);
    final numbersOnLeft = !handedness.keypadOnRight;

    // 접힘선 왼쪽 패널 끝·오른쪽 패널 시작 (본체 밖이면 본체 가장자리로 자른다)
    final leftEnd = (finite(hinge.left) - CalcTheme.screenHingeMargin).clamp(
      0.0,
      width,
    );
    final rightStart = (finite(hinge.right) + CalcTheme.screenHingeMargin)
        .clamp(leftEnd, width);
    final gap = rightStart - leftEnd;
    // 키패드: 접힘선 가운데 기준 좌우 대칭 — 블록 폭은 좁은 쪽 패널 폭이다.
    final block = math.min(leftEnd, width - rightStart);
    final keypadLeft = leftEnd - block;
    final keypadWidth = 2 * block + gap;
    final keypadMaxHeight = KeypadMetrics.fitSize(
      Size(keypadWidth, double.infinity),
      KeypadArrangement.wide,
      gap,
    ).height;

    // LCD: 폭 0 접힘선은 본체 폭 전체, 물리 힌지는 숫자부 쪽 패널
    final hingeWidth = finite(hinge.right) - finite(hinge.left);
    final lcdOnNumberPanel = hingeWidth > occludingHingeWidth;
    final (lcdLeft, lcdRight) = !lcdOnNumberPanel
        ? (0.0, width)
        : numbersOnLeft
        ? (0.0, leftEnd)
        : (rightStart, width);
    final base = _divideBodyHeight(
      height,
      lcdMaxHeight: (lcdRight - lcdLeft) / CalcTheme.screenLcdMinAspectRatio,
      keypadMaxHeight: keypadMaxHeight,
    );
    final lcd = Rect.fromLTRB(lcdLeft, 0, lcdRight, base.lcd);
    // 남는 높이(반올림 오차 등)는 키패드가 받는다 (세로형 [_stackedRectsOf]와 같다).
    final keypadTop = math.min(lcd.bottom + base.gap, height);
    return CalcHingeSplitLayout._(
      lcd: lcd,
      keypad: Rect.fromLTRB(
        keypadLeft,
        keypadTop,
        keypadLeft + keypadWidth,
        height,
      ),
      numbersOnLeft: numbersOnLeft,
      minSectionGap: gap,
      lcdOnNumberPanel: lcdOnNumberPanel,
    );
  }

  /// 화면이 다루는 모양 ([_Body])
  _HingeRegions get _regions => (
    lcd: lcd,
    keypad: keypad,
    keypadArrangement: KeypadArrangement.wide,
    numbersOnLeft: numbersOnLeft,
    minSectionGap: minSectionGap,
  );

  @override
  String toString() =>
      'CalcHingeSplitLayout(lcd: $lcd, keypad: $keypad, '
      'numbersOnLeft: $numbersOnLeft, minSectionGap: $minSectionGap, '
      'lcdOnNumberPanel: $lcdOnNumberPanel)';
}

/// 가로 접힘선 기준 위아래 배치 (#25, #143, [ScreenArrangement.hingeStacked]) — 접힘선이 가로인 폴더블 내부 화면(Fold를
/// 가로로 돌림, Pixel Fold를 세로로 돌림, Flip 내부). 펼침·살짝 꺾음·반 접음(테이블톱 자세, Flip의 Flex 모드)에서 같다.
/// 기준은 [CalcTheme]의 "접힘선 기준 배치" 절을 따른다.
///
/// 위 패널 전체가 LCD(넓은 계산 영역, #284)이고 아래 패널이 키패드다. 아래 패널이 넓어 넓은 배열의 키가 더 큰 경우
/// (Fold 가로·Pixel Fold 세로)는 가로형([CalcLandscapeLayout])과 같은 구성이고 LCD와 키패드의 경계가 접힘선이다.
/// 오른손잡이 기준(왼손잡이는 좌우 대칭 — 숫자부가 왼쪽):
/// ```
///  ┌──────────────────────────────────────────────┐ ← 본체 위
///  │            LCD [lcd] — 넓은 계산 영역           │ ← 위 패널 전체
///  ├ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ 접힘선 ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤
///  │ 상단 조작부 + 함수부 │  │       숫자부          │ ← 아래 패널: 넓은 배열 키패드
///  └────────────────────┴──┴──────────────────────┘ ← 본체 아래
/// ```
/// 아래 패널이 좁아 실물 배열의 키가 더 큰 경우 (Flip 내부):
/// ```
///  ┌──────────────────────────┐ ← 본체 위
///  │         LCD [lcd]         │ ← 위 패널 전체
///  ├ ─ ─ ─ ─ 접힘선 ─ ─ ─ ─ ─ ┤
///  │   50키 키패드 (실물 배열)  │ ← 아래 패널 폭 전체
///  └──────────────────────────┘ ← 본체 아래
/// ```
/// - 접힘선([hinge], 본체 좌표) 위아래로 [CalcTheme.screenHingeMargin]씩 비운다.
/// - 키패드: 아래 패널 폭 전체를 쓰고(#141의 폭 상한 없음 — #143까지 남겼던 테이블톱 폭 상한을 없앴다) 본체 아래에 붙인다.
///   높이는 배열의 세로 한계([KeypadMetrics.fitSize])까지다. 배열은 아래 패널에서 키가 큰 쪽이다
///   ([KeypadMetrics.preferredArrangementFor] — 가장 낮은 키 셀 높이, 같으면 실물 배열).
/// - LCD: 위 패널 전체(본체 윗변 ~ 접힘선 위 여백, 본체 폭 전체)다 — 넓은 계산 영역(#284, 2026-11-28 사용자 결정). 그 폭의
///   최대 높이([_lcdMaxHeightOf])보다 높으면 글자는 커지지 않고 입력·결과 줄만 높아진다(#232).
///   #284 전에는 넓은 배열에서 위 패널을 블록에 맞춰 활성 LCD(숫자부 위)와 기록 영역(함수부 위)으로 나눴고, 실물 배열(Flip
///   내부)에서는 위 패널 맨 위의 활성 LCD 아래에 기록 영역을 뒀다.
/// - 넓은 배열의 숫자부는 주로 쓰는 손 쪽이다([numbersOnLeft]). 실물 배열은 손잡이와 무관하다(키패드가 폭 전체다).
/// - 모든 영역은 본체 안에 있고 접힘선 위에 놓이지 않는다 (음수·비유한 크기는 0으로 본다).
@immutable
class CalcTabletopLayout {
  /// LCD 영역 (본체 좌표, dp) — 위 패널 전체
  final Rect lcd;

  /// 키패드 영역 (본체 좌표, dp) — [keypadArrangement] 배열의 [KeypadMetrics.fitSize] 결과 크기, 아래 패널 폭 전체
  final Rect keypad;

  /// 키패드 구역 배열 — 아래 패널에서 키가 더 큰 쪽 ([KeypadMetrics.preferredArrangementFor], #80)
  final KeypadArrangement keypadArrangement;

  /// 넓은 배열에서 숫자부를 왼쪽에 두는지 — 왼손잡이. 실물 배열이면 언제나 `false`다.
  final bool numbersOnLeft;

  const CalcTabletopLayout._({
    required this.lcd,
    required this.keypad,
    required this.keypadArrangement,
    required this.numbersOnLeft,
  });

  /// [body] (시스템 인셋·화면 여백을 뺀 본체 영역)를 가로 접힘선 [hinge](본체 좌표)로 위아래로 나눈다. [handedness]가
  /// 넓은 배열의 숫자부 쪽을 정한다.
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
    return CalcTabletopLayout._(
      // 위 패널 전체가 LCD다(#284).
      lcd: Rect.fromLTWH(0, 0, width, topEnd),
      keypad: keypad,
      keypadArrangement: arrangement,
      numbersOnLeft:
          arrangement == KeypadArrangement.wide && !handedness.keypadOnRight,
    );
  }

  /// 화면이 다루는 모양 ([_Body])
  _HingeRegions get _regions => (
    lcd: lcd,
    keypad: keypad,
    keypadArrangement: keypadArrangement,
    numbersOnLeft: numbersOnLeft,
    minSectionGap: 0,
  );

  @override
  String toString() =>
      'CalcTabletopLayout(lcd: $lcd, '
      'keypad: $keypad ($keypadArrangement, numbersOnLeft: $numbersOnLeft))';
}

/// 세로형([CalcScreenLayout])의 LCD·키패드 영역 ([body] 좌표) — 위아래 배치가 쓴다.
({Rect lcd, Rect keypad}) _stackedRectsOf(Size body) {
  final layout = CalcScreenLayout.of(body);
  final width = body.width.isFinite ? math.max(0.0, body.width) : 0.0;
  final height = body.height.isFinite ? math.max(0.0, body.height) : 0.0;
  // LCD와 키패드 모두 본체 폭 전체다 (#141).
  final lcd = Rect.fromLTWH(0, 0, width, layout.lcdHeight);
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
/// - **가로형 배치** (태블릿 가로, 가로로 돌린 폰, 분할 화면·데스크톱의 가로 창, #142): 아래에 넓은 키패드 배열, 위 띠
///   전체에 LCD(넓은 계산 영역, #284). 숫자부는 주로 쓰는 손([handednessProvider]) 쪽이다. [CalcLandscapeLayout].
/// - **접힘선 없는 창은 세로형과 가로형 중 키가 큰 쪽**으로 그린다(#142, [FormFactor.picksFormByKeySize]) — 키 크기는 가장
///   낮은 키의 셀 높이([KeypadMetrics.minKeyCellHeightOf])로 비교하고, 같으면 세로형이다. 두 키 크기가 창 크기에 따라
///   연속으로 변하므로 바뀌는 경계에서 키가 튀지 않는다([CalcTheme] "가로형 배치" 절).
/// - **접힘선 기준 배치** (폴더블 내부 화면, #25, #143 — 펼침·반 접힘 모두): 세로 접힘선이면 책 자세(태블릿 가로형처럼 접힘선
///   양쪽에 함수부·숫자부, 위에 LCD — [CalcHingeSplitLayout], #285), 가로 접힘선이면 위 패널 전체에 LCD(#284), 아래 패널에
///   키패드([CalcTabletopLayout]). 키가 쓸 수 있는 크기([CalcTheme.keyTouchHeightUsableMin])면 접힘선을 가로지르는 배치의 키가
///   더 커도 쓴다([CalcTheme] "접힘선 기준 배치" 절). 접힘선이 둘 이상 창을 가로지르면(펼친
///   트라이폴드, #144) 접힘선을 무시하고 접힘선 없는 창과 같게 그린다([FormFactor.crossesMultipleHinges]).
/// - **설정**: 키패드의 ON 키가 설정 키다(#190, [settingsKey]) — 누르면 설정이 열린다([SettingsLauncher]). LCD 위 상단
///   띠(장식·설정 버튼, #41)는 없다. 모든 배치에서 본체 윗변부터 LCD(가로형은 위 띠)다.
/// - **짧은 창** (#38): 폴더블 기기·접힘 정보가 있어 위아래 배치로 그리는 창도 짧은 변 600dp 미만이면 위아래 배치와 가로형
///   중 키가 큰 쪽으로 그린다. 어느 배치든 그린 키가 [CalcTheme.keyTouchHeightUsableMin]보다 낮으면 계산기 대신 창을
///   키워 달라는 안내를 띄운다([CalcTheme] "짧은 창" 절).
/// - 스크린리더 읽기 순서: LCD → 키패드 (#142). 설정 키는 키패드 안이다(#190).
///   화면 위치와 무관하게 모든 배치에서 같다. 키패드 안은 함수부 다음 숫자부다(`CalcKeypad`).
/// - 맨 아래 광고 슬롯은 없다 (#141, 사용자 결정 — 광고 없는 배치가 기준). 본체는 아래 시스템 인셋 위 아래
///   여백([CalcTheme.screenBottomMargin] — 보통 화면 여백, 아래 제스처 영역이 인셋보다 화면 여백 넘게 깊으면 그 초과분만큼,
///   #63)까지 쓴다.
///   그래서 맨 아래 키 행은 홈 제스처 영역 밖에 있어 누르는 순간 입력된다(양 끝 키 중 좌우 뒤로가기 영역에 든
///   부분은 다음의 좌우 여백 항목대로 손을 뗄 때 입력된다). 무과금 사용자의 광고는 이 배치에 넣고 광고 높이만큼 LCD를
///   줄인다(폰 세로는 키패드 아래, 가로형·책 자세는 화면 아래쪽, 가로 접힘선은 위 패널 — 2026-11-28 결정, #18).
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
/// - 위 제스처 영역(알림창 끌어내리기)은 본체 위 여백으로 피하지 않는다 — 모든 배치에서 본체 윗변에는 키가 아니라 LCD(최소
///   [CalcTheme.screenLcdMinHeight])가 온다. (#285 전에는 손 쪽 패널이 짧은 책 자세의 키패드가 본체 윗변 가까이 와서 영역
///   아래에 뒀다, #172.)
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
    // 위 시스템 제스처 영역(알림창 끌어내리기)은 피하지 않는다 — 모든 배치에서 본체 윗변에는 키가 아니라 LCD가 온다(#285 —
    // 그 전에는 손 쪽 패널이 짧은 책 자세의 키패드를 영역 아래에 뒀다, #172).
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
/// TODO(M3): 수식 AST(`MathNodeWidget`)와 결과 표시로 대체한다.
class _LcdPanel extends ConsumerWidget {
  const _LcdPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(lcdStatusProvider);
    final lastInput = ref.watch(calcProvider.select((s) => s.lastInput));
    final strings = CalcSemanticStrings.of(context);
    // 상태 변화 알림 노드는 계산기 화면 바깥, 루트 Navigator의 다음 형제에 있다 — `ScreenReaderAnnouncerLayer` (#207)
    return LcdDisplay(
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
    );
  }
}

/// 키 입력을 notifier로 전달하는 키패드. 상태를 구독하지 않는다.
class _KeypadPanel extends ConsumerWidget {
  /// 키패드 구역 배열 (#80)
  final KeypadArrangement arrangement;

  /// 넓은 배열에서 숫자부를 왼쪽에 둘지 (#142)
  final bool numbersOnLeft;

  /// 넓은 배열 블록 사이 최소 간격 (책 자세의 접힘선, #285 — `CalcKeypad.minSectionGap`)
  final double minSectionGap;

  const _KeypadPanel({
    required this.arrangement,
    this.numbersOnLeft = false,
    this.minSectionGap = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CalcKeypad(
      arrangement: arrangement,
      numbersOnLeft: numbersOnLeft,
      minSectionGap: minSectionGap,
      // 배포된 기능의 각인만 인쇄한다 (#267)
      releasedFeatures: ref.watch(releasedKeyFeaturesProvider),
      onKeyPressed: (id) => ref.read(calcProvider.notifier).pressKey(id),
      onKeyRepeat: (id) => ref.read(calcProvider.notifier).repeatKey(id),
      // 설정 키(ON)는 계산기 입력 대신 설정을 연다 (#190). 상태 머신에도 알려 모디파이어 대기를 푼다 — 다른 키를 누른
      // 것으로 본다([CalcState.pressKey], 앱 규칙). SHIFT·ALPHA 대기 중이었으면 스크린리더가 "꺼짐"을 알린 뒤 대화상자로
      // 포커스가 옮겨 간다 — 대기가 풀렸다는 것도 사용자가 알아야 하는 상태 변화라 그대로 둔다. 알림 노드는 대화상자
      // 장벽에 막히지 않는 곳에 있다(`ScreenReaderAnnouncerLayer`). TalkBack은 "시프트 꺼짐" → 대화상자(창 종류·제목)
      // 순서로 서로 끊지 않고 읽는다(#207 에뮬레이터 실측).
      onSettingsPressed: (keyContext) {
        ref.read(calcProvider.notifier).pressKey(settingsKey);
        SettingsLauncher.openFrom(keyContext);
      },
    );
  }
}

/// 본체: LCD·키패드를 [arrangement]에 맞는 영역에 놓고, 설정 키(ON)가 열 설정([SettingsLauncher])에 지금
/// 배치를 알린다.
///
/// 모든 배치를 **같은 위젯 트리**(`Stack` + `Positioned.fromRect`, 자식 수·순서 고정)로 그린다. 그래서 회전·창
/// 크기 변경으로 배치가 바뀌어도 LCD·키패드 element가 유지되어 키 눌림 상태와 스크린리더 포커스가 사라지지 않는다
/// (#24 R2 — Android 16 태블릿·iPad는 방향 고정이 무시되어 회전이 잦다). 손잡이 설정이 바뀌어도
/// 영역 위치만 옮기고, LCD·키패드 위젯은 같은 인스턴스라 다시 빌드되지 않는다(가로형의 숫자부 좌우 대칭은 키패드 안 블록
/// 순서만 바꾼다 — 키 element는 그대로다, #142).
/// 폴더블을 접고 펴거나(#25) 내부 화면을 돌려 접힘선 방향이 바뀔 때도 마찬가지다. (#285 전에는 계산 기록 영역 자식도 있었다.)
///
/// 스크린리더 읽기 순서는 영역마다 붙인 순서 키([OrdinalSortKey])로 정한다: LCD → 키패드 (#142).
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
    this.diagnostics,
  });

  /// 영역별 스크린리더 읽기 순서 (#142)
  static const double _lcdOrder = 0;
  static const double _keypadOrder = 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Rect lcd;
    final Rect keypad;
    // 키패드 구역 배열 — 가로형·가로 접힘선 배치는 넓은 배열을 쓸 수 있다 (#80, #142)
    var keypadArrangement = KeypadArrangement.standard;
    // 넓은 배열에서 숫자부를 왼쪽에 둘지 — 가로형·가로 접힘선 배치의 왼손잡이 (#142, #143)
    var numbersOnLeft = false;
    // 넓은 배열 블록 사이 최소 간격 — 책 자세의 접힘선 (#285)
    var minSectionGap = 0.0;
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
                minSectionGap: regions.minSectionGap,
              ) >=
              CalcTheme.keyTouchHeightUsableMin &&
          regions.lcd.height >= CalcTheme.screenLcdMinHeight - _epsilon &&
          // LCD가 본체보다 좁은 배치(물리 힌지의 책 자세 — 숫자부 쪽 패널에만 LCD, #285)는 LCD 최소 높이의 가로/세로 비 폭
          // ([_lcdMinWidth] 196dp) 이상이어야 한다 — 그보다 좁으면 줄 글자가 LCD 최소 높이 글자보다 작다(#285 R1, 옛
          // `screenShortBookLcdMinWidth` 200dp와 같은 생각).
          regions.lcd.width >= math.min(body.width, _lcdMinWidth) - _epsilon;
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
        keypad = hingeLayout.keypad;
        keypadArrangement = hingeLayout.keypadArrangement;
        numbersOnLeft = hingeLayout.numbersOnLeft;
        minSectionGap = hingeLayout.minSectionGap;
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
    // 그린 배치의 키도 쓸 수 없을 만큼 작으면(#38) 계산기 대신 안내를 띄운다. LCD·키패드는
    // 트리에 남겨(보이지 않게) 창을 다시 키우면 상태 그대로 돌아온다. 숨긴 동안은 터치·키보드 포커스·의미
    // 트리에서 빠진다(`Visibility`). 키를 누른 채 창이 줄면 그 키의 자동 반복은 손을 뗄 때까지 이어진다 —
    // 드문 경우라 따로 멈추지 않는다.
    // TODO(#18): 무과금 광고를 넣을 때 안내 화면에서는 광고를 싣지 않게 하고(내용 없는 화면의 광고), 광고 높이가
    // 본체 높이·안내 기준을 바꾸는 것도 함께 확인한다.
    final tooSmall =
        KeypadMetrics.minKeyTouchHeightOf(
          keypad.size,
          keypadArrangement,
          minSectionGap: minSectionGap,
        ) <
        CalcTheme.keyTouchHeightUsableMin;
    // 진단 로그 (#158, 진단 빌드에서만 켜진다): 배치가 바뀐 프레임마다 한 줄 — 첫 프레임 깜빡임을 logcat으로 본다.
    final diagnostics = this.diagnostics;
    if (diagnostics != null) {
      LayoutLog.layout(
        chosen: arrangement,
        drawn: drawn,
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
    // 키패드가 아래 패널 폭 전체를 쓰는 가로 접힘선(Flip 내부)이 그렇다. 책 자세(#285)와 가로 접힘선의 넓은 배열은 숫자부가
    // 손 쪽 패널로 옮겨 간다(#143). 가로형도 숫자부가 옮겨 간다(#142). LCD는 본체 폭 전체라 옮겨 가지 않는다(#284) — 물리
    // 힌지의 책 자세만 LCD가 숫자부 쪽 패널로 옮겨 간다(#285).
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
                // 책 자세는 접힘선 폭에 따라 블록 사이 간격이 달라 const로 둘 수 없다(#285) — 배치가 바뀔 때만 다시 빌드된다.
                (KeypadArrangement.wide, _) when minSectionGap > 0 =>
                  _KeypadPanel(
                    arrangement: KeypadArrangement.wide,
                    numbersOnLeft: numbersOnLeft,
                    minSectionGap: minSectionGap,
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

  /// 접힘선 기준 배치에서 본체보다 좁은 LCD가 가져야 하는 폭 (dp, #285 R1) — LCD 최소 높이 × 최소 가로/세로 비(112 × 1.75).
  static const double _lcdMinWidth =
      CalcTheme.screenLcdMinHeight * CalcTheme.screenLcdMinAspectRatio;

  /// 손잡이를 바꿔도 키패드가 [a] → [b]로 같은 자리인지 (부동소수점 오차 [_epsilon] 안). #143 전에는 테이블톱 키패드
  /// 블록 폭 상한 때문에 몇 dp만 옮겨 가는 창이 있어 16dp까지 같은 자리로 봤다(#80 R2) — 이제 가로 접힘선의 키패드는 아래
  /// 패널 폭 전체이고, 책 자세의 키패드는 접힘선 기준 대칭이라 손잡이로 자리가 바뀌지 않는다(숫자부만 옮겨 간다, #285).
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
