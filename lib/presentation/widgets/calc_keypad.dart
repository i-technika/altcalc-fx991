import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/key_definitions.dart';
import '../../core/theme/calc_theme.dart';
import '../l10n/calc_semantic_strings.dart';
import 'calc_key_button.dart';
import 'text_fit.dart';

/// 키패드 크기에서 산출한 배치·글자 치수. 화면 크기와 시스템 글자 배율, 라벨 글자 폭으로 정해진다.
///
/// 세로 배치 (행 높이 단위, 숫자부 행은 [CalcTheme.keypadNumberRowHeightRatio]배):
/// ```
///  상단 조작부  2행 (좌 2×2 · 커서 패드 · 우 2×2, 각 2열 폭 = 함수부 6열과 같은 열 폭)
///  함수부       3행 × 6열
///  (구역 간격)
///  숫자부       4행 × 5열
/// ```
@immutable
class KeypadMetrics {
  /// 실제 키패드 크기 (가로/세로 비 제한 반영, 주어진 영역 이하)
  final Size size;

  /// 키 사이 가로 간격 (dp)
  final double horizontalGap;

  /// 키 사이 세로 간격 (dp)
  final double verticalGap;

  /// 함수부와 숫자부 사이 간격 (dp)
  final double sectionGap;

  /// 상단 조작부·함수부 행 높이 (간격 포함, dp)
  final double functionRowHeight;

  /// 숫자부 행 높이 (간격 포함, dp)
  final double numberRowHeight;

  /// 키패드 전체에 통일해 주입하는 각인 글자 크기 (배율 반영 전, dp)
  final double legendFontSize;

  /// 키패드 전체에 통일해 주입하는 메인 라벨 글자 크기 (배율 반영 전, dp)
  final double mainLabelFontSize;

  /// 함수부·상단 조작부 키의 터치 영역을 각인 띠까지 넓힐지 여부
  final bool extendFunctionHitArea;

  /// 숫자부 키의 터치 영역을 각인 띠까지 넓힐지 여부
  final bool extendNumberHitArea;

  const KeypadMetrics._({
    required this.size,
    required this.horizontalGap,
    required this.verticalGap,
    required this.sectionGap,
    required this.functionRowHeight,
    required this.numberRowHeight,
    required this.legendFontSize,
    required this.mainLabelFontSize,
    required this.extendFunctionHitArea,
    required this.extendNumberHitArea,
  });

  /// 상단 조작부 행 수
  static const int controlRowCount = 2;

  /// 상단 조작부 + 함수부 행 수 (같은 행 높이를 쓴다)
  static int get functionRowCount => controlRowCount + functionRows.length;

  /// 상단 조작부·함수부 키의 셀 너비 (간격 제외, dp)
  double get functionKeyWidth =>
      math.max(0.0, size.width / functionColumns - horizontalGap);

  /// 숫자부 키의 셀 너비 (간격 제외, dp)
  double get numberKeyWidth =>
      math.max(0.0, size.width / numberColumns - horizontalGap);

  /// 상단 조작부·함수부 키의 셀 높이 (간격 제외, dp)
  double get functionKeyHeight =>
      math.max(0.0, functionRowHeight - verticalGap);

  /// 숫자부 키의 셀 높이 (간격 제외, dp)
  double get numberKeyHeight => math.max(0.0, numberRowHeight - verticalGap);

  /// [available] 영역 안에서 [CalcTheme.keypadMinAspectRatio]~[CalcTheme.keypadMaxAspectRatio]
  /// 가로/세로 비를 지키는 가장 큰 키패드 크기. 폭은 [CalcTheme.keypadMaxWidth]를 넘지 않는다.
  static Size fitSize(Size available) {
    final availableWidth = math.max(0.0, available.width);
    final availableHeight = math.max(0.0, available.height);
    final width = math.min(
      math.min(availableWidth, CalcTheme.keypadMaxWidth),
      availableHeight * CalcTheme.keypadMaxAspectRatio,
    );
    final height = math.min(
      availableHeight,
      width / CalcTheme.keypadMinAspectRatio,
    );
    return Size(width, height);
  }

  /// [available] 영역과 시스템 글자 배율([textScaler], `MediaQuery` 값 그대로)로 치수를 계산한다.
  ///
  /// ## 글자 크기 통일
  /// 각인·메인 라벨 글자 크기를 각각 하나로 정해 모든 키에 주입한다. 배율은 [CalcKeyButton]과 같이
  /// [CalcTheme.keyMaxTextScaleFactor]까지 반영하며, 다음 순서로 정한다.
  /// 1. **높이 기준**: 함수부 셀 높이에서 [CalcKeyButton]과 같은 비율로 구한 크기를, 배율을 반영해도
  ///    각인 띠·키캡 안쪽 높이를 넘지 않도록 줄인다.
  /// 2. **폭 기준**: 실제 글꼴로 모든 라벨의 폭을 재어, 배율을 반영해도 모든 라벨이 자기 셀 폭에
  ///    들어가는 크기까지 줄인다. 그래서 대부분의 키는 `FittedBox`가 따로 줄이지 않고 같은 크기로 그려진다.
  /// 3. **하한**: 긴 라벨 몇 개 때문에 전체가 지나치게 작아지지 않도록, 높이 기준의
  ///    [CalcTheme.keypadUniformFontMinRatio]배 아래로는 내리지 않는다. 이보다 긴 라벨만
  ///    `FittedBox`가 개별로 줄인다.
  ///
  /// 커서 패드 키(화살표 한 글자)는 키캡 상자(패드 반쪽)가 함수부 키캡보다 크므로 폭 계산에서 뺀다.
  /// 키패드 크기 [size]의 세로 치수: (키 사이 세로 간격, 구역 간격, 함수부 행 높이, 숫자부 행 높이)
  static (double, double, double, double) _rowsOf(Size size) {
    final verticalGap = size.height * CalcTheme.keyVerticalGapRatio;
    final sectionGap = size.height * CalcTheme.keypadSectionGapRatio;
    final rowUnits =
        functionRowCount +
        numberRows.length * CalcTheme.keypadNumberRowHeightRatio;
    final rowUnit = math.max(0.0, size.height - sectionGap) / rowUnits;
    return (
      verticalGap,
      sectionGap,
      rowUnit,
      rowUnit * CalcTheme.keypadNumberRowHeightRatio,
    );
  }

  /// [available] 영역에 키패드를 놓았을 때 가장 낮은 키의 터치 높이 (dp, 커서 패드 제외).
  ///
  /// [CalcKeyButton]과 같은 규칙으로 구한다: 키캡이 [CalcTheme.keyMinTouchTargetHeight]보다 낮으면 각인 띠까지
  /// 넓힌 셀 높이, 아니면 키캡 높이. 글자 크기를 재지 않으므로 [compute]보다 가볍다 — 배치를 고를 때 쓴다 (#25).
  static double minKeyTouchHeightOf(Size available) {
    final (verticalGap, _, functionRowHeight, numberRowHeight) = _rowsOf(
      fitSize(available),
    );
    double touchOf(double rowHeight) {
      final cell = math.max(0.0, rowHeight - verticalGap);
      final cap = cell * (1 - CalcTheme.keyLegendHeightRatio);
      return cap < CalcTheme.keyMinTouchTargetHeight ? cell : cap;
    }

    return math.min(touchOf(functionRowHeight), touchOf(numberRowHeight));
  }

  factory KeypadMetrics.compute(Size available, TextScaler textScaler) {
    final size = fitSize(available);
    final horizontalGap = size.width * CalcTheme.keyHorizontalGapRatio;
    final (verticalGap, sectionGap, functionRowHeight, numberRowHeight) =
        _rowsOf(size);

    // CalcKeyButton 내부 치수와 같은 방식으로 각인 띠·키캡 높이를 구한다.
    double capHeightOf(double rowHeight) =>
        math.max(0.0, rowHeight - verticalGap) *
        (1 - CalcTheme.keyLegendHeightRatio);

    final cellHeight = math.max(0.0, functionRowHeight - verticalGap);
    final legendHeight = cellHeight * CalcTheme.keyLegendHeightRatio;
    final capHeight = capHeightOf(functionRowHeight);
    final scaler = textScaler.clamp(
      maxScaleFactor: CalcTheme.keyMaxTextScaleFactor,
    );

    // 1. 높이 기준
    final legendByHeight = fitFontSizeToHeight(
      math.max(minFittedFontSize, legendHeight * CalcTheme.keyLegendFontRatio),
      maxHeight: legendHeight,
      textScaler: scaler,
      heightFactor: CalcTheme.keyShiftLabelStyle.height ?? 1.0,
    );
    // 키캡 안쪽 높이: 눌림 이동 여유와 테두리를 뺀다.
    final capInnerHeight =
        capHeight -
        math.min(CalcTheme.keyPressedOffset, capHeight) -
        2 * CalcTheme.keyBorderWidth;
    final mainByHeight = fitFontSizeToHeight(
      math.max(minFittedFontSize, capHeight * CalcTheme.keyMainLabelFontRatio),
      maxHeight: capInnerHeight,
      textScaler: scaler,
      heightFactor: CalcTheme.keyMainLabelStyle.height ?? 1.0,
    );

    // 2·3. 폭 기준 + 하한
    final widths = _LabelWidthLimits.measure(
      functionKeyWidth: math.max(
        0.0,
        size.width / functionColumns - horizontalGap,
      ),
      numberKeyWidth: math.max(0.0, size.width / numberColumns - horizontalGap),
    );
    double unify(double byHeight, double maxScaledByWidth) => math.max(
      fitFontSize(
        byHeight,
        textScaler: scaler,
        fits: (scaled) => scaled <= maxScaledByWidth,
      ),
      byHeight * CalcTheme.keypadUniformFontMinRatio,
    );

    return KeypadMetrics._(
      size: size,
      horizontalGap: horizontalGap,
      verticalGap: verticalGap,
      sectionGap: sectionGap,
      functionRowHeight: functionRowHeight,
      numberRowHeight: numberRowHeight,
      legendFontSize: unify(legendByHeight, widths.legend),
      mainLabelFontSize: unify(mainByHeight, widths.main),
      extendFunctionHitArea: capHeight < CalcTheme.keyMinTouchTargetHeight,
      extendNumberHitArea:
          capHeightOf(numberRowHeight) < CalcTheme.keyMinTouchTargetHeight,
    );
  }
}

/// 모든 라벨이 자기 셀 폭에 들어가는 (배율 반영) 최대 글자 크기.
class _LabelWidthLimits {
  /// 메인 라벨 최대 글자 크기 (배율 반영 후, dp)
  final double main;

  /// 각인 최대 글자 크기 (배율 반영 후, dp)
  final double legend;

  const _LabelWidthLimits(this.main, this.legend);

  /// 폭 측정 기준 글자 크기 — 폭은 글자 크기에 비례한다고 보고 1dp당 폭(em 폭)을 구한다.
  /// (키 라벨 스타일은 `letterSpacing: 0`을 명시하므로 자간 때문에 비례가 깨지지 않는다.)
  static const double _probeFontSize = 100;

  /// em 폭 캐시. 화면 크기와 무관하므로 라벨·스타일별로 한 번만 잰다.
  /// 시스템 글꼴이 바뀌면(글꼴 지연 로드 등) 비운다.
  static final Map<(String, TextStyle), double> _emWidthCache = {};
  static bool _listeningSystemFonts = false;

  static double _emWidth(String text, TextStyle style) {
    if (!_listeningSystemFonts) {
      _listeningSystemFonts = true;
      PaintingBinding.instance.systemFonts.addListener(_emWidthCache.clear);
    }
    return _emWidthCache.putIfAbsent((text, style), () {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(fontSize: _probeFontSize),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final width = painter.width / _probeFontSize;
      painter.dispose();
      return width;
    });
  }

  static _LabelWidthLimits measure({
    required double functionKeyWidth,
    required double numberKeyWidth,
  }) {
    var main = double.infinity;
    var legend = double.infinity;
    final numberIds = {
      for (final row in numberRows)
        for (final def in row) def.id,
    };
    final cursorIds = {for (final def in cursorPad.all) def.id};

    for (final def in allKeys) {
      if (cursorIds.contains(def.id)) continue;
      final width = numberIds.contains(def.id)
          ? numberKeyWidth
          : functionKeyWidth;

      // 메인 라벨: 키캡 좌우 여백과 테두리를 뺀 폭 (CalcKeyButton의 키캡 배치와 같다)
      final capInner =
          width * (1 - 2 * CalcTheme.keyCapHorizontalPaddingRatio) -
          2 * CalcTheme.keyBorderWidth;
      main = math.min(
        main,
        math.max(0.0, capInner) /
            _emWidth(def.mainLabel, CalcTheme.keyMainLabelStyle),
      );

      // 각인: CalcKeyButton의 각인 띠와 같은 규칙. 두 각인이 함께 들어가려면 (어느 배분이든)
      // 두 폭의 합이 띠 폭 이하여야 하고, 짧은 쪽이 우선 배분을 받으면 절반 이하여야 한다.
      // 글자 수 비례 배분은 고정폭 글꼴에서 합 조건과 같다. 사이 간격은 상한으로 잡는다.
      // (두 칸 폭 `⇔`이 든 `a b/c⇔d/c`는 한 글자 `y`와 짝이라 우선 배분을 받으므로 비례 배분을 쓰지 않는다.)
      final shift = def.shiftLabel;
      final alpha = def.alphaLabel;
      if (shift == null && alpha == null) continue;
      if (shift == null || alpha == null) {
        final (text, style) = shift != null
            ? (shift, CalcTheme.keyShiftLabelStyle)
            : (alpha!, CalcTheme.keyAlphaLabelStyle);
        legend = math.min(legend, width / _emWidth(text, style));
        continue;
      }
      final usable = math.max(
        0.0,
        width - width * CalcTheme.keyLegendGapMaxWidthRatio,
      );
      final shiftEm = _emWidth(shift, CalcTheme.keyShiftLabelStyle);
      final alphaEm = _emWidth(alpha, CalcTheme.keyAlphaLabelStyle);
      legend = math.min(legend, usable / (shiftEm + alphaEm));
      final shortRunes = math.min(shift.runes.length, alpha.runes.length);
      if (shortRunes <= CalcTheme.keyLegendPriorityMaxRunes) {
        final shortEm = shift.runes.length <= alpha.runes.length
            ? shiftEm
            : alphaEm;
        legend = math.min(legend, usable / 2 / shortEm);
      }
    }
    return _LabelWidthLimits(main, legend);
  }
}

/// fx-991EX 50키 키패드.
///
/// 키 명세([controlLeftRows]·[cursorPad]·[controlRightRows]·[functionRows]·[numberRows])를
/// 실물 배열로 배치하고, 모든 키에 같은 글자 크기([KeypadMetrics])를 주입한다.
/// 상태 관리에 의존하지 않으며 입력은 콜백으로만 내보낸다.
///
/// ## 배치 계약
/// - 주어진 영역 안에서 가로/세로 비를 제한한 크기([KeypadMetrics.fitSize])로 가운데 정렬한다.
///   제약이 무한한 축은 [fallbackSize]의 값을 쓴다.
/// - [CalcKeyButton]은 누르는 순간 입력하므로 **스크롤 영역 안에 두지 않는다**.
/// - 키 사이 간격은 터치 영역에 넣지 않는다(실물처럼 인접 키 오입력을 막는 중립 영역).
///
/// ## 입력 계약
/// - 키를 누르면 [onKeyPressed], [autoRepeatKeys]를 누르고 있는 동안 [onKeyRepeat]을 호출한다.
///   모디파이어 해석(1회성 SHIFT/ALPHA)은 호출자(상태 머신)가 맡는다.
/// - [onKeyPressed]가 `null`이면 모든 키가 비활성이다.
class CalcKeypad extends StatelessWidget {
  /// 키 입력 콜백
  final ValueChanged<CalcKeyId>? onKeyPressed;

  /// 반복 입력 콜백 ([autoRepeatKeys]에만 연결)
  final ValueChanged<CalcKeyId>? onKeyRepeat;

  /// 햅틱 피드백 사용 여부
  final bool enableHaptics;

  /// 제약이 무한한 축에 쓰는 기본 크기
  static const Size fallbackSize = Size(360, 420);

  const CalcKeypad({
    super.key,
    this.onKeyPressed,
    this.onKeyRepeat,
    this.enableHaptics = true,
  });

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    // 글꼴이 나중에 로드되면(웹 지연 로드, FontLoader 등) 라벨 폭 캐시가 비워진다. LayoutBuilder는
    // 제약이 바뀌지 않으면 다시 빌드하지 않으므로, 글꼴 변경 알림에 맞춰 다시 빌드해 글자 크기를
    // 새 글꼴로 다시 계산한다. 글꼴 변경은 드물어 평소 키 입력 리빌드에는 영향이 없다.
    return ListenableBuilder(
      listenable: PaintingBinding.instance.systemFonts,
      builder: (context, _) => _buildForFonts(textScaler),
    );
  }

  Widget _buildForFonts(TextScaler textScaler) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = Size(
          constraints.hasBoundedWidth
              ? constraints.maxWidth
              : fallbackSize.width,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : fallbackSize.height,
        );
        final metrics = KeypadMetrics.compute(available, textScaler);
        return Center(
          child: SizedBox.fromSize(
            key: const ValueKey('calc-keypad'),
            size: metrics.size,
            child: _KeypadBody(
              metrics: metrics,
              onKeyPressed: onKeyPressed,
              onKeyRepeat: onKeyRepeat,
              enableHaptics: enableHaptics,
            ),
          ),
        );
      },
    );
  }
}

class _KeypadBody extends StatelessWidget {
  final KeypadMetrics metrics;
  final ValueChanged<CalcKeyId>? onKeyPressed;
  final ValueChanged<CalcKeyId>? onKeyRepeat;
  final bool enableHaptics;

  const _KeypadBody({
    required this.metrics,
    required this.onKeyPressed,
    required this.onKeyRepeat,
    required this.enableHaptics,
  });

  EdgeInsets get _cellPadding => EdgeInsets.symmetric(
    horizontal: metrics.horizontalGap / 2,
    vertical: metrics.verticalGap / 2,
  );

  Widget _button(
    CalcKeyDef def, {
    bool showLegendBand = true,
    bool extendHitArea = false,
    Path Function(Size size)? shape,
  }) {
    return CalcKeyButton(
      keyDef: def,
      shape: shape,
      onPressed: onKeyPressed,
      onRepeat: autoRepeatKeys.contains(def.id) ? onKeyRepeat : null,
      enableHaptics: enableHaptics,
      showLegendBand: showLegendBand,
      extendHitAreaToLegend: showLegendBand && extendHitArea,
      legendFontSize: metrics.legendFontSize,
      mainLabelFontSize: metrics.mainLabelFontSize,
    );
  }

  /// 행 목록을 같은 높이의 행 × 같은 폭의 열로 배치한다.
  Widget _grid(List<List<CalcKeyDef>> rows, {required bool extendHitArea}) {
    return Column(
      children: [
        for (final row in rows)
          Expanded(
            child: Row(
              children: [
                for (final def in row)
                  Expanded(
                    child: Padding(
                      padding: _cellPadding,
                      child: _button(def, extendHitArea: extendHitArea),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controlHeight =
        metrics.functionRowHeight * KeypadMetrics.controlRowCount;
    final extendFunction = metrics.extendFunctionHitArea;
    return Column(
      children: [
        // 상단 조작부: 좌 2×2 / 커서 패드 / 우 2×2 (각 2열 폭)
        SizedBox(
          height: controlHeight,
          child: Row(
            children: [
              Expanded(
                child: _grid(controlLeftRows, extendHitArea: extendFunction),
              ),
              Expanded(
                child: Padding(
                  padding: _cellPadding,
                  child: CursorPad(
                    buttonBuilder: (def, shape) =>
                        _button(def, showLegendBand: false, shape: shape),
                    onKeyPressed: onKeyPressed,
                    enableHaptics: enableHaptics,
                  ),
                ),
              ),
              Expanded(
                child: _grid(controlRightRows, extendHitArea: extendFunction),
              ),
            ],
          ),
        ),
        SizedBox(
          height: metrics.functionRowHeight * functionRows.length,
          child: _grid(functionRows, extendHitArea: extendFunction),
        ),
        SizedBox(height: metrics.sectionGap),
        // 숫자부는 남은 높이를 모두 쓴다 (부동소수 오차로 넘치지 않게).
        Expanded(
          child: _grid(numberRows, extendHitArea: metrics.extendNumberHitArea),
        ),
      ],
    );
  }
}

/// 커서 패드 방향
enum CursorPadSector { up, down, left, right }

/// 커서 패드 모양 계산기 — 패드 상자([size]) 로컬 좌표의 외곽·X자 홈·허브와 방향 판정.
///
/// 패드 중심을 원점으로, 반폭 [radiusX]·반높이 [radiusY]로 정규화한 좌표 (u, v)를 쓴다.
/// - **외곽**: 45° 돌린 Lamé 곡선 |u+v|ᵖ + |u−v|ᵖ = 2 (p = [CalcTheme.cursorPadOutlineExponent]) —
///   꼭짓점이 (±1, 0)·(0, ±1)에 있고 꼭짓점 곡률이 유한한(둥근) 가로로 긴 마름모.
///   외곽선이 상자 밖으로 나가지 않도록 반지름은 선 두께 절반만큼 줄인다.
/// - **X자 홈**: |u| = k·|v| (k = [CalcTheme.cursorPadGrooveSlope]). |u| ≤ k·|v|이면 ▲·▼, 아니면 ◀·▶.
/// - **허브**: 중심에서 화면 거리 [hubRadius]인 원을 검게 그린다. 홈은 허브 가장자리에서 시작한다.
/// - **데드존**: 중심에서 [deadZoneRadius] 이내만 어느 방향에도 속하지 않는다. 허브보다 작아서,
///   허브 바깥 고리를 누르면 홈으로 나뉜 방향이 입력된다(작은 화면의 ▲·▼ 터치 깊이 확보, #43).
///
/// [sectorAt]은 위 정의를 그대로 옮긴 명세(참값) 판정이다. 실제 그림·누름·이동 이탈 판정은 이를
/// 다각형으로 근사한 [sectorPath]가 맡는다(곡선 구간은 [_arcSegments]개 선분, 경계에서 0.3dp 미만 차이).
/// 테스트는 두 판정이 일치하는지로 경로를 검증한다.
@immutable
class CursorPadGeometry {
  /// 패드 상자 크기
  final Size size;

  /// 외곽 반폭 (dp)
  final double radiusX;

  /// 외곽 반높이 (dp)
  final double radiusY;

  /// 그려지는 허브 반지름 (dp)
  final double hubRadius;

  /// 누를 수 없는 가운데 원의 반지름 (dp, [hubRadius] 이하)
  final double deadZoneRadius;

  factory CursorPadGeometry(Size size) {
    const inset = CalcTheme.cursorPadDividerWidth / 2;
    final rx = math.max(0.0, size.width / 2 - inset);
    final ry = math.max(0.0, size.height / 2 - inset);
    final short = math.min(rx, ry);
    return CursorPadGeometry._(
      size,
      rx,
      ry,
      CalcTheme.cursorPadHubRadiusRatio * short,
      CalcTheme.cursorPadDeadZoneRadiusRatio * short,
    );
  }

  const CursorPadGeometry._(
    this.size,
    this.radiusX,
    this.radiusY,
    this.hubRadius,
    this.deadZoneRadius,
  );

  static const double _p = CalcTheme.cursorPadOutlineExponent;
  static const double _k = CalcTheme.cursorPadGrooveSlope;

  /// 곡선 구간(외곽 호·데드존 호) 하나를 나누는 선분 수
  static const int _arcSegments = 32;

  /// 패드 중심
  Offset get center => size.center(Offset.zero);

  bool get _isEmpty => radiusX <= 0 || radiusY <= 0;

  /// [localPosition](패드 로컬 좌표)이 속한 방향. 데드존·외곽 밖이거나 유한하지 않은 좌표면 `null`이다.
  CursorPadSector? sectorAt(Offset localPosition) {
    if (_isEmpty || !localPosition.isFinite) return null;
    final d = localPosition - center;
    if (d.distance <= deadZoneRadius) return null;
    final u = d.dx / radiusX;
    final v = d.dy / radiusY;
    if (math.pow((u + v).abs(), _p) + math.pow((u - v).abs(), _p) > 2) {
      return null;
    }
    if (u.abs() <= _k * v.abs()) {
      return v < 0 ? CursorPadSector.up : CursorPadSector.down;
    }
    return u < 0 ? CursorPadSector.left : CursorPadSector.right;
  }

  /// 정규화 좌표에서 홈이 가로축과 이루는 각 (k > 1이면 45°보다 작다)
  static final double _grooveAngle = math.atan2(1, _k);

  /// [sector]가 차지하는 정규화 각도 범위 (y 아래 방향, 시계 방향으로 증가)
  static (double, double) _angles(CursorPadSector sector) {
    final t = _grooveAngle;
    return switch (sector) {
      CursorPadSector.right => (-t, t),
      CursorPadSector.down => (t, math.pi - t),
      CursorPadSector.left => (math.pi - t, math.pi + t),
      CursorPadSector.up => (math.pi + t, 2 * math.pi - t),
    };
  }

  /// 정규화 각도 [phi] 방향의 외곽 위 점
  Offset _outlinePoint(double phi) {
    final c = math.cos(phi);
    final s = math.sin(phi);
    final rho = math.pow(
      2 / (math.pow((c + s).abs(), _p) + math.pow((c - s).abs(), _p)),
      1 / _p,
    );
    return center + Offset(rho * c * radiusX, rho * s * radiusY);
  }

  /// 정규화 각도 [phi] 방향 직선과 중심에서 반지름 [radius]인 원의 교점
  Offset _circlePoint(double phi, double radius) {
    final psi = math.atan2(math.sin(phi) * radiusY, math.cos(phi) * radiusX);
    return center + Offset.fromDirection(psi, radius);
  }

  /// [sector] 구역 다각형 꼭짓점 (패드 로컬 좌표): 외곽 호를 시계 방향으로 따라간 뒤,
  /// 데드존 호를 반시계 방향으로 되돌아온다 (두 호를 잇는 변이 X자 홈이다). 비어 있으면 빈 목록.
  List<Offset> sectorPolygon(CursorPadSector sector) {
    if (_isEmpty) return const [];
    final (from, to) = _angles(sector);
    // 데드존 호는 화면 각도로 고르게 나눈다 (끝 각도는 시작보다 작아지게 2π 단위로 맞춘다).
    final a0 = (_circlePoint(to, 1) - center).direction;
    var a1 = (_circlePoint(from, 1) - center).direction;
    while (a1 > a0) {
      a1 -= 2 * math.pi;
    }
    return [
      for (var i = 0; i <= _arcSegments; i++)
        _outlinePoint(from + (to - from) * i / _arcSegments),
      for (var i = 0; i <= _arcSegments; i++)
        center +
            Offset.fromDirection(
              a0 + (a1 - a0) * i / _arcSegments,
              deadZoneRadius,
            ),
    ];
  }

  /// [sector] 구역 경로 (패드 로컬 좌표)
  Path sectorPath(CursorPadSector sector) {
    if (_isEmpty) return Path();
    return Path()..addPolygon(sectorPolygon(sector), true);
  }

  /// 외곽선 경로 (패드 로컬 좌표)
  Path outlinePath() {
    if (_isEmpty) return Path();
    const segments = _arcSegments * 4;
    return Path()..addPolygon([
      for (var i = 0; i < segments; i++)
        _outlinePoint(2 * math.pi * i / segments),
    ], true);
  }

  /// X자 홈 네 줄 — 각각 (허브 가장자리 끝, 외곽 위 끝)
  List<(Offset, Offset)> grooves() {
    if (_isEmpty) return const [];
    final t = _grooveAngle;
    return [
      for (final phi in [t, math.pi - t, math.pi + t, -t])
        (_circlePoint(phi, hubRadius), _outlinePoint(phi)),
    ];
  }

  /// 시맨틱 영역을 나누는 기준 — ◀·▶ 영역 반높이를 외곽 반높이의 이 비율(허브보다 작으면 허브 반지름)로 둔다.
  static const double _semanticSplitRatio = 0.3;

  /// [sector]의 시맨틱(스크린리더 터치 탐색) 영역 (패드 로컬 좌표).
  ///
  /// 네 영역은 서로 겹치지 않고, 각 영역은 자기 구역 또는 외곽 밖에만 걸친다(허브는 덮지 않는다).
  /// 화면 좌표에서 홈은 |dx| = m·|dy| (m = k·[radiusX]/[radiusY])이므로, ◀·▶ 영역을 |dx| ≥ X, |dy| ≤ Y,
  /// ▲·▼ 영역을 |dx| ≤ X, |dy| ≥ Y로 두고 X ≥ m·Y를 지키면 각 영역이 홈을 넘지 않는다.
  Rect semanticRect(CursorPadSector sector) {
    if (_isEmpty) return Rect.zero;
    final m = _k * radiusX / radiusY;
    final y0 = math.max(hubRadius, _semanticSplitRatio * radiusY);
    final x = math.max(m * y0, hubRadius);
    final y = x / m;
    final c = center;
    return switch (sector) {
      CursorPadSector.up => Rect.fromLTRB(
        c.dx - x,
        c.dy - radiusY,
        c.dx + x,
        c.dy - y,
      ),
      CursorPadSector.down => Rect.fromLTRB(
        c.dx - x,
        c.dy + y,
        c.dx + x,
        c.dy + radiusY,
      ),
      CursorPadSector.left => Rect.fromLTRB(
        c.dx - radiusX,
        c.dy - y,
        c.dx - x,
        c.dy + y,
      ),
      CursorPadSector.right => Rect.fromLTRB(
        c.dx + x,
        c.dy - y,
        c.dx + radiusX,
        c.dy + y,
      ),
    };
  }

  /// [sector] 구역 넓이 (dp², [sectorPath] 다각형의 신발끈 공식)
  double sectorArea(CursorPadSector sector) {
    if (_isEmpty) return 0;
    final points = sectorPolygon(sector);
    var twice = 0.0;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final q = points[(i + 1) % points.length];
      twice += p.dx * q.dy - q.dx * p.dy;
    }
    return twice.abs() / 2;
  }
}

/// 실물 fx-991EX 리플레이 패드처럼 가로로 긴 둥근 마름모를 X자 홈으로 4분할한 방향 키 묶음
/// (각인 띠 없음, 모양은 [CursorPadGeometry]).
///
/// ```
///   ◀  ╲    ▲    ╱  ▶     ▲·▼: 넓은 사다리꼴, ◀·▶: 좁은 삼각형에 가깝다
///         ╲ ● ╱           ●: 검은 허브 (한가운데 작은 원만 데드존)
///         ╱   ╲           외곽: 가로로 긴 둥근 마름모 (밖은 무시)
///      ╱    ▼    ╲
/// ```
/// 각 방향 키캡은 [sectorBox](패드를 반으로 나눈 사각형)에 그리고, [CalcKeyButton.shape]로 구역 경로를
/// 넘겨 그림·누름·이동 이탈(반복 중단) 판정을 모두 구역 안으로 제한한다.
///
/// ## 허브 한가운데만 데드존이다 (#43)
/// 가운데는 네 방향이 만나 손가락이 어느 쪽을 노렸는지 가장 모호한 곳이다. 가까운 방향으로 보내면
/// 의도와 다른 방향으로 커서가 움직이는 오입력이 생기고(되돌리기 어렵다), 무시하면 다시 누르기만 하면 된다.
/// 그래서 한가운데([CursorPadGeometry.deadZoneRadius])는 누를 수 없게 두고, 누른 채 그리로 미끄러지면
/// 반복 입력도 멈춘다. 다만 그려진 허브 전체를 데드존으로 두면 작은 폰에서 ▲·▼ 터치 깊이가 28dp 아래로
/// 줄어들어, 허브 바깥 고리는 홈으로 나뉜 방향 키에 준다(실물보다 누를 수 있는 곳이 조금 넓다).
///
/// 패드 상자는 셀 가운데에 [fitSize]로 가로/세로 비를 제한해 놓는다(셀의 남는 부분은 데드존).
///
/// 버튼의 시맨틱 영역은 반쪽 사각형이라 서로 겹치므로(터치 탐색으로 ▲·▼에 닿을 수 없음),
/// 버튼 시맨틱은 빼고 방향별로 겹치지 않는 [semanticRect] 영역에 시맨틱 노드를 따로 둔다.
class CursorPad extends StatelessWidget {
  /// 방향 키 위젯 생성기. [shape]를 `CalcKeyButton.shape`에 넘겨야 한다
  /// (보통 `showLegendBand: false`인 [CalcKeyButton]).
  final Widget Function(CalcKeyDef def, Path Function(Size size) shape)
  buttonBuilder;

  /// 시맨틱 탭(스크린리더) 입력 콜백. `null`이면 시맨틱 노드가 비활성이다.
  final ValueChanged<CalcKeyId>? onKeyPressed;

  /// 시맨틱 탭 햅틱 사용 여부 (버튼과 같게 맞춘다)
  final bool enableHaptics;

  const CursorPad({
    super.key,
    required this.buttonBuilder,
    this.onKeyPressed,
    this.enableHaptics = true,
  });

  /// [sector] 구역 경로 생성기 (정적 함수라 매 빌드 같은 인스턴스 — 불필요한 재클립 방지)
  static Path Function(Size size) shapeOf(CursorPadSector sector) =>
      switch (sector) {
        CursorPadSector.up => _upPath,
        CursorPadSector.down => _downPath,
        CursorPadSector.left => _leftPath,
        CursorPadSector.right => _rightPath,
      };

  static Path _upPath(Size s) => sectorPath(CursorPadSector.up, s);
  static Path _downPath(Size s) => sectorPath(CursorPadSector.down, s);
  static Path _leftPath(Size s) => sectorPath(CursorPadSector.left, s);
  static Path _rightPath(Size s) => sectorPath(CursorPadSector.right, s);

  /// [size] 패드 안에서 [sector]의 시맨틱 영역 ([CursorPadGeometry.semanticRect])
  static Rect semanticRect(CursorPadSector sector, Size size) =>
      CursorPadGeometry(size).semanticRect(sector);

  /// 패드 셀([cell]) 안에 놓을 패드 상자 크기 — 가로/세로 비를
  /// [CalcTheme.cursorPadMinAspectRatio]~[CalcTheme.cursorPadMaxAspectRatio]로 제한한 가장 큰 크기.
  static Size fitSize(Size cell) {
    final w = math.max(0.0, cell.width);
    final h = math.max(0.0, cell.height);
    if (w <= 0 || h <= 0) return Size.zero;
    final aspect = w / h;
    if (aspect > CalcTheme.cursorPadMaxAspectRatio) {
      return Size(h * CalcTheme.cursorPadMaxAspectRatio, h);
    }
    if (aspect < CalcTheme.cursorPadMinAspectRatio) {
      return Size(w, w / CalcTheme.cursorPadMinAspectRatio);
    }
    return Size(w, h);
  }

  /// 방향별 키 명세
  static CalcKeyDef defOf(CursorPadSector sector) => switch (sector) {
    CursorPadSector.up => cursorPad.up,
    CursorPadSector.down => cursorPad.down,
    CursorPadSector.left => cursorPad.left,
    CursorPadSector.right => cursorPad.right,
  };

  /// [size] 패드 안에서 [sector] 키캡을 그리는 상자 (구역을 감싸는 반쪽 사각형)
  static Rect sectorBox(CursorPadSector sector, Size size) {
    final w = size.width;
    final h = size.height;
    return switch (sector) {
      CursorPadSector.up => Rect.fromLTWH(0, 0, w, h / 2),
      CursorPadSector.down => Rect.fromLTWH(0, h / 2, w, h / 2),
      CursorPadSector.left => Rect.fromLTWH(0, 0, w / 2, h),
      CursorPadSector.right => Rect.fromLTWH(w / 2, 0, w / 2, h),
    };
  }

  /// [sectorBox] 크기([boxSize])로부터 패드 크기를 되돌린다.
  static Size padSizeOf(CursorPadSector sector, Size boxSize) =>
      switch (sector) {
        CursorPadSector.up ||
        CursorPadSector.down => Size(boxSize.width, boxSize.height * 2),
        CursorPadSector.left ||
        CursorPadSector.right => Size(boxSize.width * 2, boxSize.height),
      };

  /// [sectorBox] 로컬 좌표의 [sector] 구역 경로 — 상자 크기만으로 패드 크기를 되돌려 계산한다.
  static Path sectorPath(CursorPadSector sector, Size boxSize) {
    final padSize = padSizeOf(sector, boxSize);
    final origin = sectorBox(sector, padSize).topLeft;
    return CursorPadGeometry(padSize).sectorPath(sector).shift(-origin);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = constraints.biggest;
        if (!cell.isFinite || cell.isEmpty) return const SizedBox.shrink();
        final size = fitSize(cell);
        final press = onKeyPressed;
        final strings = CalcSemanticStrings.of(context);
        return Center(
          child: SizedBox.fromSize(
            size: size,
            child: Stack(
              key: const ValueKey('cursor-pad'),
              children: [
                for (final sector in CursorPadSector.values)
                  Positioned.fromRect(
                    rect: sectorBox(sector, size),
                    child: ExcludeSemantics(
                      child: buttonBuilder(defOf(sector), shapeOf(sector)),
                    ),
                  ),
                // X자 홈·외곽선·허브 (터치는 통과시켜 아래 방향 키가 받는다 — 한가운데는 키 경로 밖이라 데드존)
                // 키를 누를 때마다 장식(128각형 외곽 등)을 다시 그리지 않도록 레이어를 분리한다.
                const Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _CursorPadDecorationPainter(),
                      ),
                    ),
                  ),
                ),
                // 겹치지 않는 시맨틱 영역 (자식이 없어 터치는 받지 않는다)
                for (final sector in CursorPadSector.values)
                  Positioned.fromRect(
                    rect: semanticRect(sector, size),
                    child: Semantics(
                      container: true,
                      button: true,
                      enabled: press != null,
                      label: strings.keyButton(defOf(sector).id),
                      onTap: press == null
                          ? null
                          : () {
                              if (enableHaptics) HapticFeedback.lightImpact();
                              press(defOf(sector).id);
                            },
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 커서 패드 X자 홈·외곽선과 가운데 허브
class _CursorPadDecorationPainter extends CustomPainter {
  const _CursorPadDecorationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = CursorPadGeometry(size);
    final line = Paint()
      ..color = CalcTheme.keyBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = CalcTheme.cursorPadDividerWidth;
    for (final (from, to) in geometry.grooves()) {
      canvas.drawLine(from, to, line);
    }
    canvas
      ..drawPath(geometry.outlinePath(), line)
      ..drawCircle(
        geometry.center,
        geometry.hubRadius,
        Paint()..color = CalcTheme.cursorPadHub,
      )
      ..drawCircle(geometry.center, geometry.hubRadius, line);
  }

  @override
  bool shouldRepaint(_CursorPadDecorationPainter oldDelegate) => false;
}
