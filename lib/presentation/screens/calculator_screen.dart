import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/layout/form_factor.dart';
import '../../core/theme/calc_theme.dart';
import '../../domain/models/calc_state.dart';
import '../../domain/models/handedness.dart';
import '../l10n/calc_semantic_strings.dart';
import '../providers/calc_provider.dart';
import '../providers/device_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/banner_ad_slot.dart';
import '../widgets/calc_keypad.dart';
import '../widgets/lcd_display.dart';
import '../widgets/screen_coordinate_root.dart';
import '../widgets/settings_button.dart';

/// 광고 슬롯을 뺀 본체 영역의 세로 배치 (위 → 아래: 상단 띠 · LCD · 간격 · 키패드).
///
/// 기준은 [CalcTheme]의 "화면 배치" 절을 따른다 (#23).
/// - LCD: [CalcTheme.screenLcdHeightRatio] 목표, [CalcTheme.screenLcdMinHeight] ~
///   (폭 / [CalcTheme.screenLcdMinAspectRatio]) 범위.
/// - 키패드: 나머지 높이 중 가로/세로 비 하한([CalcTheme.keypadMinAspectRatio])과 최대 폭
///   ([CalcTheme.keypadMaxWidth])이 허용하는 만큼.
///   키패드가 쓰지 못하는 높이는 LCD 최대 높이까지 LCD에 주고, 그래도 남으면 [top]으로 둔다.
/// - 본체가 아주 낮으면 키패드 높이가 0이 될 때까지만 LCD를 최소 높이로 지킨다 (TODO(#38)).
///   본체가 간격보다 낮으면 간격도 본체 높이로 줄어, 어떤 경우에도 합계가 본체 높이를 넘지 않는다.
@immutable
class CalcScreenLayout {
  /// LCD 위 상단 띠 높이 (dp)
  final double top;

  /// LCD 높이 (dp)
  final double lcdHeight;

  /// LCD와 키패드 사이 간격 (dp) — [CalcTheme.screenLcdKeypadGap], 본체가 그보다 낮으면 본체 높이
  final double gap;

  /// 키패드 영역 높이 (dp)
  final double keypadHeight;

  const CalcScreenLayout._({
    required this.top,
    required this.lcdHeight,
    required this.gap,
    required this.keypadHeight,
  });

  /// [body] (광고 슬롯·화면 여백을 뺀 본체 영역)의 세로 배치.
  /// `top + lcdHeight + gap + keypadHeight`는 본체 높이와 같다 (음수·비유한 크기는 0으로 본다).
  factory CalcScreenLayout.of(Size body) {
    double finite(double v) => v.isFinite ? math.max(0.0, v) : 0.0;
    final width = finite(body.width);
    final height = finite(body.height);
    final gap = math.min(CalcTheme.screenLcdKeypadGap, height);
    final available = height - gap;
    final keypadMax =
        math.min(width, CalcTheme.keypadMaxWidth) /
        CalcTheme.keypadMinAspectRatio;
    final lcdMax = math.max(
      CalcTheme.screenLcdMinHeight,
      width / CalcTheme.screenLcdMinAspectRatio,
    );
    final lcd = math.min(
      math
          .max(height * CalcTheme.screenLcdHeightRatio, available - keypadMax)
          .clamp(CalcTheme.screenLcdMinHeight, lcdMax),
      available,
    );
    final keypad = math.min(available - lcd, keypadMax);
    return CalcScreenLayout._(
      top: available - lcd - keypad,
      lcdHeight: lcd,
      gap: gap,
      keypadHeight: keypad,
    );
  }

  @override
  String toString() =>
      'CalcScreenLayout(top: $top, lcd: $lcdHeight, gap: $gap, '
      'keypad: $keypadHeight)';
}

/// 대화면 가로 창의 좌우 분할 배치 (#24). 기준은 [CalcTheme]의 "좌우 분할 배치" 절을 따른다.
///
/// 오른손잡이([Handedness.right]) 기준 (왼손잡이는 좌우 대칭):
/// ```
///  ┌──────────┬────────────────────┬──┬─────────────┐
///  │          │  (빈 띠 — #41)     │  │             │
///  │          ├────────────────────┤  ├─────────────┤ ← 키패드 윗변 = LCD 윗변
///  │  (여백)  │        LCD         │간│             │
///  │          ├────────────────────┤격│  50키 키패드 │
///  │          │ [설정]             │  │             │
///  └──────────┴────────────────────┴──┴─────────────┘ ← 본체 아래 (광고 슬롯은 그 아래 전체 폭)
///  └──────── LCD 쪽 패널 ─────────┘
/// ```
/// - 키패드: 주로 쓰는 손 쪽 가장자리·본체 아래에 붙인다. 크기는 [KeypadMetrics.fitSize]
///   (폭 ≤ (본체 폭 − 간격) × [CalcTheme.screenSplitKeypadMaxWidthRatio], 높이 ≤ 본체 높이).
/// - LCD 쪽 패널: 나머지 폭 전체.
/// - LCD: 폭은 패널 폭과 키패드 폭 × [CalcTheme.screenSplitLcdMaxWidthRatio] 중 작은 쪽이고 (#71),
///   패널 안에서 키패드 쪽에 붙인다 — 그래서 LCD와 키패드 사이는 간격만큼이고, 남는 폭은 패널 바깥쪽 여백이다.
///   (접힘선이 없으면 패널이 항상 키패드 이상이라 LCD 폭 = 키패드 폭 × 비율이다.)
///   높이는 그 폭의 최대 높이(폭 / [CalcTheme.screenLcdMinAspectRatio], 하한 [CalcTheme.screenLcdMinHeight])이되,
///   아래에 설정 버튼 자리를 남기도록 키패드 높이에서 버튼 자리를 뺀 높이를 넘지 않는다.
/// - 설정 버튼: LCD 바로 아래, LCD의 키패드에서 먼 쪽 끝.
/// - 본체가 키패드 최대 높이보다 높으면 위쪽 남는 높이는 빈 띠다 — 위아래 배치의 상단 띠처럼 키패드를 광고 슬롯
///   바로 위에 붙인 채로 둔다. 위쪽 띠·패널 바깥쪽 여백의 활용은 TODO(#41).
/// - 모든 영역은 본체 안에 있다 (음수·비유한 크기는 0으로 본다).
///
/// ## 세로 접힘선 기준 (#25, [ScreenArrangement.hingeSplit])
/// 접힘선([hinge], 본체 좌표)을 주면 키패드 쪽과 LCD 쪽의 경계를 접힘선으로 고정한다. 접힘선 양쪽에
/// [CalcTheme.screenHingeMargin]씩 비우고, 주로 쓰는 손 쪽 절반 전체가 키패드 자리(폭 비율 상한 없음,
/// [CalcTheme.keypadMaxWidth]는 적용), 다른 절반 전체가 LCD 쪽 패널이다. 나머지 규칙은 같다 — LCD 폭 상한에
/// 걸리면 LCD는 접힘선 쪽에 붙는다. 키패드는 그대로 바깥(손 쪽) 가장자리에 붙으므로, 키패드가 자기 절반보다
/// 좁으면 LCD와 키패드 사이는 접힘선 + 양쪽 간격보다 넓어진다(두 화면 기기 1114×720: 94dp). 그래도 LCD를
/// 바깥 가장자리에 붙이는 것(138dp)보다 가까워 눈 이동이 짧다 — 접힘선 쪽을 고른 이유다.
/// 그래서 LCD·키패드·설정 버튼 어느 것도 접힘선 위에 놓이지 않는다.
@immutable
class CalcSplitLayout {
  /// LCD 영역 (본체 좌표, dp)
  final Rect lcd;

  /// 키패드 영역 (본체 좌표, dp) — [KeypadMetrics.fitSize] 결과 크기
  final Rect keypad;

  /// 설정 버튼 영역 (본체 좌표, dp)
  final Rect settingsButton;

  const CalcSplitLayout._({
    required this.lcd,
    required this.keypad,
    required this.settingsButton,
  });

  /// [body] (광고 슬롯·화면 여백을 뺀 본체 영역)를 [handedness]에 따라 좌우로 나눈다.
  /// [hinge]를 주면(본체 좌표의 세로 접힘선) 그 접힘선을 경계로 나눈다.
  factory CalcSplitLayout.of(Size body, Handedness handedness, {Rect? hinge}) {
    double finite(double v) => v.isFinite ? math.max(0.0, v) : 0.0;
    final width = finite(body.width);
    final height = finite(body.height);
    final onRight = handedness.keypadOnRight;

    final Size keypadSize;
    final double panelLeft;
    final double panelWidth;
    if (hinge == null) {
      final gap = math.min(CalcTheme.screenSplitGap, width);
      keypadSize = KeypadMetrics.fitSize(
        Size((width - gap) * CalcTheme.screenSplitKeypadMaxWidthRatio, height),
      );
      panelWidth = math.max(0.0, width - gap - keypadSize.width);
      panelLeft = onRight ? 0.0 : keypadSize.width + gap;
    } else {
      // 접힘선 왼쪽 끝·오른쪽 시작 (본체 밖이면 본체 가장자리로 자른다)
      final leftEnd = (finite(hinge.left) - CalcTheme.screenHingeMargin).clamp(
        0.0,
        width,
      );
      final rightStart = (finite(hinge.right) + CalcTheme.screenHingeMargin)
          .clamp(leftEnd, width);
      final keypadRegion = onRight ? width - rightStart : leftEnd;
      keypadSize = KeypadMetrics.fitSize(Size(keypadRegion, height));
      panelLeft = onRight ? 0.0 : rightStart;
      panelWidth = onRight ? leftEnd : width - rightStart;
    }
    final keypadLeft = onRight ? width - keypadSize.width : 0.0;
    final keypadTop = height - keypadSize.height;

    // LCD 폭 상한 (#71) — 상한에 걸리면 패널 안에서 키패드 쪽에 붙인다.
    final lcdWidth = math.min(
      panelWidth,
      keypadSize.width * CalcTheme.screenSplitLcdMaxWidthRatio,
    );
    final lcdLeft = onRight ? panelLeft + panelWidth - lcdWidth : panelLeft;

    // LCD 아래에 설정 버튼 자리(간격 + 버튼)를 남긴다.
    const buttonBlock =
        CalcTheme.screenSplitSettingsGap + CalcTheme.settingsButtonSize;
    final lcdMax = math.max(0.0, keypadSize.height - buttonBlock);
    final lcdHeight = math.min(
      math.max(
        lcdWidth / CalcTheme.screenLcdMinAspectRatio,
        CalcTheme.screenLcdMinHeight,
      ),
      lcdMax,
    );
    final lcd = Rect.fromLTWH(lcdLeft, keypadTop, lcdWidth, lcdHeight);
    // 버튼은 항상 LCD 아래에 둔다. 본체가 버튼 자리보다 낮은 비정상 크기에서만 버튼이 줄어든다
    // (좌우 분할은 짧은 변 600dp 이상 창에서만 쓰므로 실제로는 생기지 않는다).
    final buttonTop = math.min(
      lcd.bottom + CalcTheme.screenSplitSettingsGap,
      height,
    );
    final button = math.min(CalcTheme.settingsButtonSize, height - buttonTop);
    // LCD의 키패드에서 먼 쪽 끝. LCD가 버튼보다 좁은 비정상 크기에서도 패널 밖(키패드 쪽)으로 나가지 않는다.
    final buttonWidth = math.min(CalcTheme.settingsButtonSize, panelWidth);
    final buttonLeft = onRight
        ? math.min(lcd.left, panelLeft + panelWidth - buttonWidth)
        : math.max(lcd.right - buttonWidth, panelLeft);
    return CalcSplitLayout._(
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
      'CalcSplitLayout(lcd: $lcd, keypad: $keypad, '
      'settings: $settingsButton)';
}

/// 가로 접힘선 기준 위아래 배치 (#25, [ScreenArrangement.hingeStacked]) — 반 접어 세워 둔 테이블톱 자세(Flip의
/// Flex 모드 포함)나 물리 힌지. 기준은 [CalcTheme]의 "접힘선 기준 배치" 절을 따른다.
///
/// 오른손잡이([Handedness.right]) 기준 (왼손잡이는 좌우 대칭):
/// ```
///  ┌─────────────────────────────────────────────┐
///  │                 (빈 띠)                      │
///  │                  LCD                         │  ← 위 절반 (아래쪽 = 접힘선 쪽에 붙인다)
///  ├ ─ ─ ─ ─ ─ ─ ─ ─ 접힘선 ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤
///  │ [설정]                 ┌──────────────────┐  │
///  │                        │   50키 키패드     │  │  ← 아래 절반
///  └────────────────────────┴──────────────────┘──┘ ← 본체 아래 (광고 슬롯은 그 아래 전체 폭)
/// ```
/// - 접힘선([hinge], 본체 좌표) 위아래로 [CalcTheme.screenHingeMargin]씩 비운다.
/// - 키패드: 아래 절반에 [KeypadMetrics.fitSize]로 맞춰, 주로 쓰는 손 쪽 가장자리·본체 아래에 붙인다.
/// - LCD: 위 절반 폭 전체. 높이는 폭의 최대 높이(폭 / [CalcTheme.screenLcdMinAspectRatio])와 위 절반 높이 중
///   작은 쪽이고, 접힘선 쪽(아래)에 붙인다 — 남는 높이는 LCD 위 빈 띠가 된다(위아래 배치와 같은 방식).
/// - 설정 버튼: 아래 절반에서 키패드 반대쪽 끝, 키패드 윗변 높이. 그 자리가 없으면(키패드가 아래 절반 폭을
///   거의 다 쓰면) 위 절반의 키패드 반대쪽 위 모서리에 두고, LCD는 버튼 아래로 줄인다.
/// - 모든 영역은 본체 안에 있고 접힘선 위에 놓이지 않는다 (음수·비유한 크기는 0으로 본다).
@immutable
class CalcTabletopLayout {
  /// LCD 영역 (본체 좌표, dp)
  final Rect lcd;

  /// 키패드 영역 (본체 좌표, dp) — [KeypadMetrics.fitSize] 결과 크기
  final Rect keypad;

  /// 설정 버튼 영역 (본체 좌표, dp)
  final Rect settingsButton;

  const CalcTabletopLayout._({
    required this.lcd,
    required this.keypad,
    required this.settingsButton,
  });

  /// [body] (광고 슬롯·화면 여백을 뺀 본체 영역)를 가로 접힘선 [hinge](본체 좌표)로 위아래로 나눈다.
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

    final keypadSize = KeypadMetrics.fitSize(Size(width, height - bottomStart));
    final keypad = Rect.fromLTWH(
      onRight ? width - keypadSize.width : 0.0,
      height - keypadSize.height,
      keypadSize.width,
      keypadSize.height,
    );

    const button = CalcTheme.settingsButtonSize;
    final buttonWidth = math.min(button, width);
    final besideKeypad =
        width - keypadSize.width >= CalcTheme.screenSplitGap + button &&
        keypadSize.height >= button;
    final buttonLeft = onRight ? 0.0 : width - buttonWidth;
    final Rect settings;
    var lcdRegionTop = 0.0;
    if (besideKeypad) {
      settings = Rect.fromLTWH(buttonLeft, keypad.top, buttonWidth, button);
    } else {
      // 위 절반 위 모서리 — LCD는 그 아래로 줄인다.
      final buttonHeight = math.min(button, topEnd);
      settings = Rect.fromLTWH(buttonLeft, 0, buttonWidth, buttonHeight);
      lcdRegionTop = math.min(
        buttonHeight + CalcTheme.screenSplitSettingsGap,
        topEnd,
      );
    }

    final lcdHeight = math.min(
      width / CalcTheme.screenLcdMinAspectRatio,
      topEnd - lcdRegionTop,
    );
    final lcd = Rect.fromLTWH(0, topEnd - lcdHeight, width, lcdHeight);
    return CalcTabletopLayout._(
      lcd: lcd,
      keypad: keypad,
      settingsButton: settings,
    );
  }

  @override
  String toString() =>
      'CalcTabletopLayout(lcd: $lcd, keypad: $keypad, '
      'settings: $settingsButton)';
}

/// 계산기 메인 화면: LCD + 50키 키패드 + 최하단 광고 슬롯.
///
/// 창 크기와 접힘선에 따라 배치를 고른다 ([FormFactor.arrangementOf]).
/// - **위아래 배치** (폰 세로 화면, 태블릿 세로·좁은 창, 폴더블 커버 화면): 아래 그림, [CalcScreenLayout].
/// - **좌우 분할 배치** (대화면 가로 창): LCD와 키패드를 좌우로 나누고, 주로 쓰는 손([handednessProvider])
///   쪽에 키패드를 둔다. [CalcSplitLayout].
/// - **접힘선 기준 배치** (폴더블 내부 화면, #25): 세로 접힘선이면 접힘선을 경계로 좌우 분할
///   ([CalcSplitLayout]의 `hinge`), 가로 접힘선이면 위 절반 LCD·아래 절반 키패드([CalcTabletopLayout]).
/// - 광고 슬롯은 모든 배치에서 본체 아래 전체 폭이다.
///
/// 위아래 배치 구성 (위 → 아래):
/// ```
///  ┌──────────────────────────┐  ← 상단 시스템 인셋 (SafeArea)
///  │       (상단 띠)          │  ← [CalcScreenLayout.top] — 세로로 긴 화면에서만 생긴다
///  │          LCD             │  ← [CalcScreenLayout.lcdHeight]
///  │        (간격)            │
///  │     50키 키패드          │  ← [CalcScreenLayout.keypadHeight]
///  ├──────────────────────────┤
///  │ 안전 여백 + 광고 슬롯    │  ← [BannerAdSlot] (하단·좌우 시스템 인셋은 슬롯이 처리)
///  └──────────────────────────┘
/// ```
///
/// - 키패드는 스크롤 영역 밖에 고정 배치한다(`CalcKeyButton`은 누르는 순간 입력한다).
/// - LCD만 상태를 구독하고 키패드는 notifier만 읽으므로, 키 입력으로 키패드 50개가 다시 그려지지 않는다.
/// - LCD 글자 크기는 LCD가 자기 크기에서 [LcdFontSizes.forSize]로 산출한다 (`fitFontsToSize`).
/// - 좌우 여백은 [CalcTheme.screenPadding]만 둔다. 가장자리 열의 바깥쪽 일부가 Android 제스처
///   내비게이션 영역에 걸릴 수 있지만, `CalcKeyButton`이 그 영역에서 시작한 터치를 손을 뗄 때
///   확정하므로 뒤로가기 제스처와 충돌하지 않는다. 제스처 폭만큼 여백을 두면 모든 폰에서 키패드가 좁아진다.
/// - 배치는 기기 종류가 아니라 창 크기로 고른다 — 방향 고정이 무시되는 경우가 있다(`FormFactor` 참조).
///   폴더블 기기([foldableDeviceProvider])는 접힘 정보가 오기 전까지 위아래 배치다.
/// - 접기·펼치기·회전으로 배치가 바뀌어도 상태는 [calcProvider]에 있고 LCD·키패드 element도 유지된다(`_Body`).
class CalculatorScreen extends ConsumerWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = MediaQuery.sizeOf(context);
    final features = MediaQuery.displayFeaturesOf(context);
    final arrangement = FormFactor.arrangementOf(
      window,
      features,
      foldableDevice: ref.watch(foldableDeviceProvider),
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
    return Scaffold(
      backgroundColor: CalcTheme.bodyBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CalcTheme.screenPadding,
                  CalcTheme.screenPadding,
                  CalcTheme.screenPadding,
                  0,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => _BodyOriginCheck(
                    expected: bodyOrigin,
                    enabled: hinge != null,
                    child: _Body(
                      body: constraints.biggest,
                      arrangement: arrangement,
                      hinge: hinge,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // TODO(#18): M6에서 적응형 배너 광고를 child로 연결한다.
          const BannerAdSlot(),
        ],
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
  const _KeypadPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CalcKeypad(
      onKeyPressed: (id) => ref.read(calcProvider.notifier).pressKey(id),
      onKeyRepeat: (id) => ref.read(calcProvider.notifier).repeatKey(id),
    );
  }
}

/// 본체: LCD·키패드(·설정 버튼)를 [arrangement]에 맞는 영역에 놓는다.
///
/// 두 배치를 **같은 위젯 트리**(`Stack` + `Positioned.fromRect`)로 그린다. 그래서 회전·창 크기 변경으로
/// 배치가 바뀌어도 LCD·키패드 element가 유지되어 키 눌림 상태와 스크린리더 포커스가 사라지지 않는다
/// (#24 R2 — Android 16 태블릿·iPad는 방향 고정이 무시되어 회전이 잦다). 손잡이 설정이 바뀌어도
/// 영역 위치만 옮기고, LCD·키패드 위젯은 같은 인스턴스라 다시 빌드되지 않는다.
/// 폴더블을 접고 펴거나(#25) 내부 화면을 돌려 접힘선 방향이 바뀔 때도 마찬가지다.
class _Body extends ConsumerWidget {
  /// 본체 크기 (광고 슬롯·화면 여백 제외)
  final Size body;

  /// 배치 종류
  final ScreenArrangement arrangement;

  /// 창을 가로지르는 접힘선 (본체 좌표, 없으면 `null`) — 접힘선 기준 배치에서 쓴다.
  final Rect? hinge;

  const _Body({required this.body, required this.arrangement, this.hinge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Rect lcd;
    final Rect keypad;
    Rect? settings;
    final hinge = this.hinge;
    final handedness = ref.watch(handednessProvider);
    // 접힘선 기준 배치 후보. 키가 터치 하한보다 낮아지면 쓰지 않는다 (#25 R2 — 본체 좌표로 판정해야
    // 인셋·광고 슬롯·접힘선 간격이 빠진 실제 키패드 크기를 본다).
    ({Rect lcd, Rect keypad, Rect settings})? hingeLayout;
    if (hinge != null) {
      switch (arrangement) {
        case ScreenArrangement.hingeSplit:
          final l = CalcSplitLayout.of(body, handedness, hinge: hinge);
          if (KeypadMetrics.minKeyTouchHeightOf(l.keypad.size) >=
              CalcTheme.keyTouchHeightFloor) {
            hingeLayout = (
              lcd: l.lcd,
              keypad: l.keypad,
              settings: l.settingsButton,
            );
          }
        case ScreenArrangement.hingeStacked:
          final l = CalcTabletopLayout.of(body, hinge, handedness);
          if (KeypadMetrics.minKeyTouchHeightOf(l.keypad.size) >=
              CalcTheme.tabletopKeyTouchHeightFloor) {
            hingeLayout = (
              lcd: l.lcd,
              keypad: l.keypad,
              settings: l.settingsButton,
            );
          }
        case ScreenArrangement.stacked || ScreenArrangement.split:
          break;
      }
    }
    switch (arrangement) {
      case ScreenArrangement.split:
        final layout = CalcSplitLayout.of(body, handedness);
        lcd = layout.lcd;
        keypad = layout.keypad;
        settings = layout.settingsButton;
      case ScreenArrangement.hingeSplit || ScreenArrangement.hingeStacked
          when hingeLayout != null:
        lcd = hingeLayout.lcd;
        keypad = hingeLayout.keypad;
        settings = hingeLayout.settings;
      // 접힘선 기준 배치를 쓸 수 없으면(키가 터치 하한보다 낮음, 호출 측 불일치) 위아래 배치로 그린다.
      case ScreenArrangement.stacked ||
          ScreenArrangement.hingeSplit ||
          ScreenArrangement.hingeStacked:
        // TODO(#41): 상단 띠([CalcScreenLayout.top]) 활용 (장식·설정 진입 등)
        final layout = CalcScreenLayout.of(body);
        final width = body.width.isFinite ? math.max(0.0, body.width) : 0.0;
        final height = body.height.isFinite ? math.max(0.0, body.height) : 0.0;
        lcd = Rect.fromLTWH(0, layout.top, width, layout.lcdHeight);
        // 남는 높이(반올림 오차 등)는 키패드가 받는다.
        keypad = Rect.fromLTRB(
          0,
          math.min(lcd.bottom + layout.gap, height),
          width,
          height,
        );
    }
    return Stack(
      children: [
        Positioned.fromRect(rect: lcd, child: const _LcdPanel()),
        Positioned.fromRect(rect: keypad, child: const _KeypadPanel()),
        if (settings != null)
          Positioned.fromRect(rect: settings, child: const SettingsButton()),
      ],
    );
  }
}
