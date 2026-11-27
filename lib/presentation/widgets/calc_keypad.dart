import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/key_definitions.dart';
import '../../core/theme/calc_theme.dart';
import '../l10n/calc_semantic_strings.dart';
import 'calc_key_button.dart';
import 'key_legend_view.dart';
import 'text_fit.dart';

/// 키패드 구역 배열 (#80).
///
/// 두 배열 모두 구역 안의 키 배열·행 수는 실물 그대로이고, 구역(상단 조작부+함수부 / 숫자부)을 놓는 방향만 다르다.
/// ```
///  standard (실물)           wide (낮고 넓은 영역)
///  ┌───────────────┐         ┌───────────────┐   ┌────────────┐
///  │ 상단 조작부 2행 │         │ 상단 조작부 2행 │   │            │
///  │ 함수부 3행      │         │ 함수부 3행      │   │ 숫자부 4행  │
///  ├───────────────┤         └───────────────┘   └────────────┘
///  │ 숫자부 4행      │          └─── 블록 ───┘ 간격 └── 블록 ──┘
///  └───────────────┘
/// ```
enum KeypadArrangement {
  /// 실물 배열 — 숫자부가 함수부 아래에 있다.
  standard,

  /// 숫자부를 함수부 옆에 나란히 둔다. 가로형 배치(`CalcLandscapeLayout`, #142)와 반 접은 테이블톱 자세의 아래
  /// 절반처럼 낮고 넓은 영역에서 [standard]보다 키가 클 때 쓴다. 높이가 [standard]의 약 절반이라
  /// 같은 높이에서 키가 약 2배가 된다(Fold 가로 반 접힘 19.9 → 39.9dp).
  /// 숫자부는 기본으로 오른쪽이고(블록 순서는 실물의 "함수부 다음 숫자부"를 읽는 순서로 옮긴 것), `CalcKeypad.numbersOnLeft`로
  /// 좌우를 맞바꿀 수 있다 — 가로형 배치는 손잡이에 따라 숫자부를 주로 쓰는 손 쪽에 둔다(#142, 사용자 결정).
  /// 테이블톱 배치는 #143까지 손잡이와 무관하게 숫자부가 오른쪽이고, 블록 폭 상한
  /// (`CalcTheme.screenTabletopKeypadMaxBlockWidth`)에 걸리는 넓은 창(아래 절반 폭 약 990dp 초과)에서는 키패드가 손 쪽
  /// 가장자리로 가서 왼손잡이면 숫자부가 화면 가운데 쪽에 온다.
  wide,
}

/// 키패드 크기에서 산출한 배치·글자 치수. 화면 크기와 시스템 글자 배율, 라벨 글자 폭, 구역 배열로 정해진다.
///
/// 세로 배치 (행 높이 단위, 숫자부 행은 [CalcTheme.keypadNumberRowHeightRatio]배 — [KeypadArrangement.standard]):
/// ```
///  상단 조작부  2행 (좌 2×2 · 커서 패드 · 우 2×2, 각 2열 폭 = 함수부 6열과 같은 열 폭)
///  함수부       3행 × 6열
///  (구역 간격)
///  숫자부       4행 × 5열
/// ```
/// [KeypadArrangement.wide]는 위 두 구역을 같은 폭의 블록([blockWidth])으로 좌우에 놓는다. 숫자부 4행이 함수부 5행과
/// 같은 높이를 나누므로 숫자부 행은 함수부 행의 1.25배다(실물 비 1.2에 가깝다). 키 사이 간격과 블록의 가로/세로 비
/// 범위는 같은 함수부 행 높이의 [KeypadArrangement.standard] 키패드와 같게 맞춰, 배열만 다르고 키 하나의 모양은
/// 같은 범위다.
@immutable
class KeypadMetrics {
  /// 구역 배열
  final KeypadArrangement arrangement;

  /// 실제 키패드 크기 (가로/세로 비 제한 반영, 주어진 영역 이하)
  final Size size;

  /// 구역 블록 폭 (dp) — [KeypadArrangement.standard]는 키패드 폭, [KeypadArrangement.wide]는 좌우 블록 하나의 폭
  final double blockWidth;

  /// 키 사이 가로 간격 (dp)
  final double horizontalGap;

  /// 키 사이 세로 간격 (dp)
  final double verticalGap;

  /// 함수부와 숫자부 사이 간격 (dp) — [KeypadArrangement.standard]는 세로, [KeypadArrangement.wide]는 가로 간격
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
    required this.arrangement,
    required this.size,
    required this.blockWidth,
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

  /// [KeypadArrangement.standard] 키패드 높이(구역 간격 제외)를 함수부 행 높이 단위로 센 값 (9.8)
  static double get _standardRowUnits =>
      functionRowCount +
      numberRows.length * CalcTheme.keypadNumberRowHeightRatio;

  /// [KeypadArrangement.wide] 키패드 높이에 곱하면 함수부 행 높이가 같은 [KeypadArrangement.standard] 키패드 높이가
  /// 되는 배수 (2.0). 키 사이 세로 간격과 블록의 가로/세로 비 범위를 그 "같은 행 높이의 표준 키패드"에 맞춘다.
  static double get wideHeightFactor =>
      _standardRowUnits /
      (1 - CalcTheme.keypadSectionGapRatio) /
      functionRowCount;

  /// [KeypadArrangement.wide] 키패드 폭을 블록 폭 단위로 센 값 (블록 2개 + 블록 사이 간격)
  static const double _wideWidthUnits = 2 + CalcTheme.keypadWideSectionGapRatio;

  /// [KeypadArrangement.wide] 키패드 폭 [width]에서 블록 하나의 폭 (dp) — 가로형 배치가 위 띠를 블록에 맞춰 나눌 때
  /// 쓴다(#142). 블록 사이 간격은 `width - 2 × 블록 폭`이다.
  static double wideBlockWidthOf(double width) =>
      math.max(0.0, width) / _wideWidthUnits;

  /// 상단 조작부·함수부 키의 셀 너비 (간격 제외, dp)
  double get functionKeyWidth =>
      math.max(0.0, blockWidth / functionColumns - horizontalGap);

  /// 숫자부 키의 셀 너비 (간격 제외, dp)
  double get numberKeyWidth =>
      math.max(0.0, blockWidth / numberColumns - horizontalGap);

  /// 상단 조작부·함수부 키의 셀 높이 (간격 제외, dp)
  double get functionKeyHeight =>
      math.max(0.0, functionRowHeight - verticalGap);

  /// 숫자부 키의 셀 높이 (간격 제외, dp)
  double get numberKeyHeight => math.max(0.0, numberRowHeight - verticalGap);

  /// [available] 영역 안에서 [arrangement] 배열이 세로로 길어지지 않는 가장 큰 키패드 크기.
  ///
  /// 폭은 언제나 영역 폭 전체다 — 가로 쪽 상한은 없다(#141, 사용자 결정 "가로로는 구역을 끝까지 채운다").
  /// 높이만 영역 높이와 다음 상한 중 작은 쪽으로 줄인다. 그래서 키는 가로로 넓어질 수는 있어도 세로로 길어지지 않는다.
  /// - [KeypadArrangement.standard]: 키패드 폭 / [CalcTheme.keypadMinAspectRatio].
  /// - [KeypadArrangement.wide]: 블록 폭 / ([CalcTheme.keypadMinAspectRatio] × [wideHeightFactor]) — 같은 행 높이의
  ///   표준 키패드와 키 모양의 세로 한계가 같다. 블록 폭은 영역 폭에서 블록 사이 간격
  ///   (블록 폭 × [CalcTheme.keypadWideSectionGapRatio])을 뺀 절반이다.
  static Size fitSize(
    Size available, [
    KeypadArrangement arrangement = KeypadArrangement.standard,
  ]) {
    final width = available.width.isFinite
        ? math.max(0.0, available.width)
        : 0.0;
    final availableHeight = math.max(0.0, available.height);
    final maxHeight = switch (arrangement) {
      KeypadArrangement.standard => width / CalcTheme.keypadMinAspectRatio,
      KeypadArrangement.wide =>
        width /
            _wideWidthUnits /
            (CalcTheme.keypadMinAspectRatio * wideHeightFactor),
    };
    return Size(width, math.min(availableHeight, maxHeight));
  }

  /// [available] 영역에서 키가 더 큰 배열 — [KeypadArrangement.wide]의 가장 낮은 키가 [KeypadArrangement.standard]보다
  /// **클 때만** wide다(같으면 실물 배열). 낮고 넓은 영역(반 접은 테이블톱 자세의 아래 절반)에서 쓴다 (#80).
  static KeypadArrangement preferredArrangementFor(Size available) =>
      minKeyTouchHeightOf(available, KeypadArrangement.wide) >
          minKeyTouchHeightOf(available, KeypadArrangement.standard)
      ? KeypadArrangement.wide
      : KeypadArrangement.standard;

  /// 키패드 크기 [size]의 치수:
  /// (블록 폭, 키 사이 가로 간격, 키 사이 세로 간격, 구역 간격, 함수부 행 높이, 숫자부 행 높이)
  static (double, double, double, double, double, double) _geometryOf(
    Size size,
    KeypadArrangement arrangement,
  ) {
    switch (arrangement) {
      case KeypadArrangement.standard:
        final sectionGap = size.height * CalcTheme.keypadSectionGapRatio;
        final rowUnit =
            math.max(0.0, size.height - sectionGap) / _standardRowUnits;
        return (
          size.width,
          size.width * CalcTheme.keyHorizontalGapRatio,
          size.height * CalcTheme.keyVerticalGapRatio,
          sectionGap,
          rowUnit,
          rowUnit * CalcTheme.keypadNumberRowHeightRatio,
        );
      case KeypadArrangement.wide:
        final block = size.width / _wideWidthUnits;
        return (
          block,
          block * CalcTheme.keyHorizontalGapRatio,
          // 함수부 행 높이가 같은 표준 키패드와 같은 세로 간격
          size.height * wideHeightFactor * CalcTheme.keyVerticalGapRatio,
          math.max(0.0, size.width - 2 * block),
          size.height / functionRowCount,
          size.height / numberRows.length,
        );
    }
  }

  /// [available] 영역에 [arrangement] 배열 키패드를 놓았을 때 가장 낮은 키의 셀 높이 (dp, 키 사이 간격 제외 — 각인 띠와
  /// 키캡을 합친 높이, 커서 패드 제외). 두 배열 모두 함수부 행이 가장 낮다.
  ///
  /// 키패드 크기에 대해 단조 증가한다 — 세로형과 가로형 중 키가 큰 쪽을 고를 때 쓴다(#142). [minKeyTouchHeightOf]는
  /// 키캡이 [CalcTheme.keyMinTouchTargetHeight]를 넘는 순간 각인 띠를 터치 영역에서 빼므로 키가 커질 때 한 번 줄어든다
  /// (셀 66.7dp에서 66.7 → 48dp). 그 값으로 비교하면 키가 큰 배치를 버리게 된다 — 12.9인치 iPad 세로 1024×1366은
  /// 세로형(셀 76.1dp, 터치 54.8dp)이 가로형(셀·터치 55.4dp)보다 키가 큰데 터치 높이로는 가로형이 이긴다.
  static double minKeyCellHeightOf(
    Size available,
    KeypadArrangement arrangement,
  ) {
    final (_, _, verticalGap, _, functionRowHeight, numberRowHeight) =
        _geometryOf(fitSize(available, arrangement), arrangement);
    return math.max(
      0.0,
      math.min(functionRowHeight, numberRowHeight) - verticalGap,
    );
  }

  /// [available] 영역에 [arrangement] 배열 키패드를 놓았을 때 가장 낮은 키의 터치 높이 (dp, 커서 패드 제외).
  ///
  /// [CalcKeyButton]과 같은 규칙으로 구한다: 키캡이 [CalcTheme.keyMinTouchTargetHeight]보다 낮으면 각인 띠까지
  /// 넓힌 셀 높이, 아니면 키캡 높이. 글자 크기를 재지 않으므로 [compute]보다 가볍다 — 배치를 고를 때 쓴다 (#25).
  ///
  /// [arrangement]는 기본값 없이 받는다 — 빠뜨리면 넓은 배열 키패드를 실물 배열로 재어 배치 판정이 조용히 틀린다(#80 R1).
  static double minKeyTouchHeightOf(
    Size available,
    KeypadArrangement arrangement,
  ) {
    final (_, _, verticalGap, _, functionRowHeight, numberRowHeight) =
        _geometryOf(fitSize(available, arrangement), arrangement);
    double touchOf(double rowHeight) {
      final cell = math.max(0.0, rowHeight - verticalGap);
      final cap = cell * (1 - CalcTheme.keyLegendHeightRatio);
      return cap < CalcTheme.keyMinTouchTargetHeight ? cell : cap;
    }

    return math.min(touchOf(functionRowHeight), touchOf(numberRowHeight));
  }

  /// 높이 기준 글자 크기: 배율을 반영한 한 줄 높이(정수 올림, [fitFontSizeToHeight])와 [tallLegends]
  /// (한 줄보다 높을 수 있는 2차원 각인, #155)의 실제 높이([KeyLegendView.tallestAt])가 모두 [maxHeight] 이하인
  /// 가장 큰 글자 크기 (배율 반영 전).
  ///
  /// 2차원 각인의 높이는 잉크(비례)와 한 줄 상자(작은 글자에서 반올림)를 합친 값이다. 비례 높이로만 판정하면
  /// 작은 글자에서 넘치고(#155 R2), 전체를 정수로 올리면 실제로는 들어가는데도 줄어든다(#155 R1). 그래서 실제
  /// 높이로 판정한다. 테스트가 같은 판정을 쓰도록 공개한다.
  @visibleForTesting
  static double fitToHeight(
    double fontSize, {
    required double maxHeight,
    required TextScaler textScaler,
    required TextStyle style,
    required List<KeyLegendEmMetrics> tallLegends,
  }) => _fitToHeight(
    fontSize,
    maxHeight: maxHeight,
    textScaler: textScaler,
    style: style,
    tallLegends: tallLegends,
  );

  static double _fitToHeight(
    double fontSize, {
    required double maxHeight,
    required TextScaler textScaler,
    required TextStyle style,
    required List<KeyLegendEmMetrics> tallLegends,
  }) => fitFontSize(
    fontSize,
    textScaler: textScaler,
    fits: (scaled) =>
        (scaled * (style.height ?? 1.0)).ceilToDouble() <= maxHeight &&
        (tallLegends.isEmpty ||
            KeyLegendView.tallestAt(tallLegends, style, scaled) <= maxHeight),
  );

  /// [available] 영역과 시스템 글자 배율([textScaler], `MediaQuery` 값 그대로)로 치수를 계산한다.
  ///
  /// ## 글자 크기 통일
  /// 각인·메인 라벨 글자 크기를 각각 하나로 정해 모든 키에 주입한다. 배율은 [CalcKeyButton]과 같이
  /// [CalcTheme.keyMaxTextScaleFactor]까지 반영하며, 다음 순서로 정한다.
  /// 1. **높이 기준**: 함수부 셀 높이에서 [CalcKeyButton]과 같은 비율로 구한 크기를, 배율을 반영해도
  ///    각인 띠·키캡 안쪽 높이를 넘지 않도록 줄인다. 큰 키(태블릿)에서는 [CalcTheme.keyMainLabelMaxFontSize]·
  ///    [CalcTheme.keyLegendMaxFontSize]에서 멈춘다(#141). 폭 기준은 줄이기만 하므로 키가 가로로 넓어져도 글자는
  ///    이 높이 기준보다 커지지 않는다.
  /// 2. **폭 기준**: 실제 글꼴로 모든 라벨의 폭을 재어, 배율을 반영해도 모든 라벨이 자기 셀 폭에
  ///    들어가는 크기까지 줄인다. 그래서 대부분의 키는 `FittedBox`가 따로 줄이지 않고 같은 크기로 그려진다.
  /// 3. **하한**: 긴 라벨 몇 개 때문에 전체가 지나치게 작아지지 않도록, 높이 기준의
  ///    [CalcTheme.keypadUniformFontMinRatio]배 아래로는 내리지 않는다. 이보다 긴 라벨만
  ///    `FittedBox`가 개별로 줄인다.
  ///
  /// 커서 패드 키(화살표 한 글자)는 키캡 상자(패드 반쪽)가 함수부 키캡보다 크므로 폭 계산에서 뺀다.
  factory KeypadMetrics.compute(
    Size available,
    TextScaler textScaler, {
    KeypadArrangement arrangement = KeypadArrangement.standard,
  }) {
    final size = fitSize(available, arrangement);
    final (
      blockWidth,
      horizontalGap,
      verticalGap,
      sectionGap,
      functionRowHeight,
      numberRowHeight,
    ) = _geometryOf(
      size,
      arrangement,
    );

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
    final limits = _LabelLimits.measure(
      functionKeyWidth: math.max(
        0.0,
        blockWidth / functionColumns - horizontalGap,
      ),
      numberKeyWidth: math.max(0.0, blockWidth / numberColumns - horizontalGap),
    );

    // 1. 높이 기준 — 큰 키에서도 상한에서 멈춘다 (#141). 가장 높은 각인(분수 등 2차원 각인, #155)까지
    //    띠·키캡 안에 들어가게 한다.
    final legendByHeight = _fitToHeight(
      math.max(
        minFittedFontSize,
        math.min(
          legendHeight * CalcTheme.keyLegendFontRatio,
          CalcTheme.keyLegendMaxFontSize,
        ),
      ),
      maxHeight: legendHeight,
      textScaler: scaler,
      style: CalcTheme.keyShiftLabelStyle,
      tallLegends: limits.tallLegends,
    );
    // 키캡 안쪽 높이: 눌림 이동 여유와 테두리를 뺀다.
    final capInnerHeight =
        capHeight -
        math.min(CalcTheme.keyPressedOffset, capHeight) -
        2 * CalcTheme.keyBorderWidth;
    final mainByHeight = _fitToHeight(
      math.max(
        minFittedFontSize,
        math.min(
          capHeight * CalcTheme.keyMainLabelFontRatio,
          CalcTheme.keyMainLabelMaxFontSize,
        ),
      ),
      maxHeight: capInnerHeight,
      textScaler: scaler,
      style: CalcTheme.keyMainLabelStyle,
      tallLegends: limits.tallMains,
    );

    // 2·3. 폭 기준 + 하한
    final widths = limits;
    double unify(double byHeight, double maxScaledByWidth) => math.max(
      fitFontSize(
        byHeight,
        textScaler: scaler,
        fits: (scaled) => scaled <= maxScaledByWidth,
      ),
      byHeight * CalcTheme.keypadUniformFontMinRatio,
    );

    return KeypadMetrics._(
      arrangement: arrangement,
      size: size,
      blockWidth: blockWidth,
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

/// 모든 라벨이 자기 셀 폭에 들어가는 (배율 반영) 최대 글자 크기와, 가장 높은 라벨의 높이.
///
/// 크기는 실제 글꼴로 그린 각인 크기([KeyLegendView.emSize] — 2차원 각인 포함, 글자 크기 1dp당 값)로 잰다.
/// (키 라벨 스타일은 `letterSpacing: 0`을 명시하므로 자간 때문에 폭이 글자 크기에 비례하지 않는 일은 없다.)
class _LabelLimits {
  /// 메인 라벨 최대 글자 크기 (배율 반영 후, dp)
  final double main;

  /// 각인 최대 글자 크기 (배율 반영 후, dp)
  final double legend;

  /// 2차원 메인 각인의 em 치수 (한 줄보다 높을 수 있어 높이 기준이 함께 잰다, #155)
  final List<KeyLegendEmMetrics> tallMains;

  /// 2차원 SHIFT·ALPHA 각인의 em 치수
  final List<KeyLegendEmMetrics> tallLegends;

  const _LabelLimits(this.main, this.legend, this.tallMains, this.tallLegends);

  static double _emWidth(KeyLegend legend, TextStyle style) =>
      KeyLegendView.emSize(legend, style).width;

  static _LabelLimits measure({
    required double functionKeyWidth,
    required double numberKeyWidth,
  }) {
    var main = double.infinity;
    var legend = double.infinity;
    final tallMains = <KeyLegendEmMetrics>[];
    final tallLegends = <KeyLegendEmMetrics>[];
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
            _emWidth(def.mainLegend, CalcTheme.keyMainLabelStyle),
      );
      if (!def.mainLegend.isPlain) {
        tallMains.add(
          KeyLegendView.emMetrics(def.mainLegend, CalcTheme.keyMainLabelStyle),
        );
      }
      for (final (l, style) in [
        (def.shiftLegend, CalcTheme.keyShiftLabelStyle),
        (def.alphaLegend, CalcTheme.keyAlphaLabelStyle),
      ]) {
        if (l != null && !l.isPlain) {
          tallLegends.add(KeyLegendView.emMetrics(l, style));
        }
      }

      // 각인: CalcKeyButton의 각인 띠와 같은 규칙. 두 각인이 함께 들어가려면 (어느 배분이든)
      // 두 폭의 합이 띠 폭 이하여야 하고, 짧은 쪽이 우선 배분을 받으면 절반 이하여야 한다.
      // 글자 수 비례 배분은 고정폭 글꼴에서 합 조건과 같다. 사이 간격은 상한으로 잡는다.
      // (두 칸 폭 `⇔`이 든 `a b/c⇔d/c`는 한 글자 `y`와 짝이라 우선 배분을 받으므로 비례 배분을 쓰지 않는다.)
      final shift = def.shiftLegend;
      final alpha = def.alphaLegend;
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
      final shiftRunes = shift.plainText.runes.length;
      final alphaRunes = alpha.plainText.runes.length;
      if (math.min(shiftRunes, alphaRunes) <=
          CalcTheme.keyLegendPriorityMaxRunes) {
        final shortEm = shiftRunes <= alphaRunes ? shiftEm : alphaEm;
        legend = math.min(legend, usable / 2 / shortEm);
      }
    }
    return _LabelLimits(main, legend, tallMains, tallLegends);
  }
}

/// fx-991EX 50키 키패드.
///
/// 키 명세([controlLeftRows]·[cursorPad]·[controlRightRows]·[functionRows]·[numberRows])를
/// 실물 배열로 배치하고, 모든 키에 같은 글자 크기([KeypadMetrics])를 주입한다.
/// 상태 관리에 의존하지 않으며 입력은 콜백으로만 내보낸다.
///
/// ## 배치 계약
/// - 주어진 영역 안에서 [arrangement] 배열의 가로/세로 비를 제한한 크기([KeypadMetrics.fitSize])로 가운데 정렬한다.
///   제약이 무한한 축은 [fallbackSize]의 값을 쓴다. 배열은 호출자가 정한다 — 영역에서 키가 더 큰 배열은
///   [KeypadMetrics.preferredArrangementFor]로 고른다.
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

  /// 구역 배열 (#80)
  final KeypadArrangement arrangement;

  /// [KeypadArrangement.wide]에서 숫자부를 함수부 왼쪽에 둘지 (#142 — 가로형 배치의 왼손잡이). 구역 안의 키 배열과
  /// 스크린리더 읽기 순서(함수부 다음 숫자부)는 그대로이고 블록의 좌우만 바뀐다. [KeypadArrangement.standard]에서는 쓰지 않는다.
  final bool numbersOnLeft;

  /// 제약이 무한한 축에 쓰는 기본 크기
  static const Size fallbackSize = Size(360, 420);

  const CalcKeypad({
    super.key,
    this.onKeyPressed,
    this.onKeyRepeat,
    this.enableHaptics = true,
    this.arrangement = KeypadArrangement.standard,
    this.numbersOnLeft = false,
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
        final metrics = KeypadMetrics.compute(
          available,
          textScaler,
          arrangement: arrangement,
        );
        return Center(
          child: SizedBox.fromSize(
            key: const ValueKey('calc-keypad'),
            size: metrics.size,
            child: _KeypadBody(
              metrics: metrics,
              numbersOnLeft: numbersOnLeft,
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
  final bool numbersOnLeft;
  final ValueChanged<CalcKeyId>? onKeyPressed;
  final ValueChanged<CalcKeyId>? onKeyRepeat;
  final bool enableHaptics;

  const _KeypadBody({
    required this.metrics,
    required this.numbersOnLeft,
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
    Path Function(Size size)? hitShape,
    EdgeInsets hitOutset = EdgeInsets.zero,
    EdgeInsets labelInsets = EdgeInsets.zero,
  }) {
    return CalcKeyButton(
      keyDef: def,
      shape: shape,
      hitShape: hitShape,
      hitOutset: hitOutset,
      labelInsets: labelInsets,
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

  /// 구역 하나를 스크린리더 탐색 단위로 묶는다 — 넓은 배열에서 두 구역의 행 높이가 달라, 묶지 않으면 화면 위치순
  /// 정렬이 함수부와 숫자부 키를 섞어 읽는다. 키는 각자 노드로 남는다(`explicitChildNodes`).
  /// 구역 순서는 [order]로 정한다 — 숫자부를 왼쪽에 둔 넓은 배열(#142)도 화면 위치와 무관하게 함수부를 먼저 읽는다.
  static Widget _section(Widget child, double order) => Semantics(
    container: true,
    explicitChildNodes: true,
    sortKey: OrdinalSortKey(order),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final controlHeight =
        metrics.functionRowHeight * KeypadMetrics.controlRowCount;
    final extendFunction = metrics.extendFunctionHitArea;
    final wide = metrics.arrangement == KeypadArrangement.wide;
    // 두 배열을 같은 위젯 트리(`Flex` + 같은 자식 종류·순서)로 그린다 — 테이블톱 자세로 접고 펼 때 배열이 바뀌어도
    // 키 element가 유지되어 키 눌림 상태와 스크린리더 포커스가 사라지지 않는다 (#80, `_Body`의 배치 전환과 같은 이유).
    return Flex(
      direction: wide ? Axis.horizontal : Axis.vertical,
      // 넓은 배열의 좌우 대칭(#142)은 블록 순서만 거꾸로 놓는다 — 자식 순서·종류가 그대로라 손잡이를 바꿔도 키
      // element가 유지된다. 구역 안의 키 줄(`Row`)은 이 값을 물려받지 않아 키 배열은 실물 그대로다.
      textDirection: wide && numbersOnLeft
          ? TextDirection.rtl
          : TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 상단 조작부 + 함수부 — 표준 배열은 위, 넓은 배열은 왼쪽 블록
        SizedBox(
          width: wide ? metrics.blockWidth : null,
          height: wide
              ? null
              : metrics.functionRowHeight * KeypadMetrics.functionRowCount,
          child: _section(
            Column(
              children: [
                _controlSection(controlHeight, extendFunction),
                // 함수부는 블록의 남은 높이를 모두 쓴다 (부동소수 오차로 넘치지 않게).
                Expanded(
                  child: _grid(functionRows, extendHitArea: extendFunction),
                ),
              ],
            ),
            0,
          ),
        ),
        SizedBox(
          width: wide ? metrics.sectionGap : null,
          height: wide ? null : metrics.sectionGap,
        ),
        // 숫자부는 남은 높이(넓은 배열은 남은 폭)를 모두 쓴다 (부동소수 오차로 넘치지 않게).
        Expanded(
          child: _section(
            _grid(numberRows, extendHitArea: metrics.extendNumberHitArea),
            1,
          ),
        ),
      ],
    );
  }

  /// 상단 조작부: 좌 2×2 / 커서 패드 / 우 2×2 (각 2열 폭)
  Widget _controlSection(double controlHeight, bool extendFunction) {
    return SizedBox(
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
                buttonBuilder: (def, keyShape) => _button(
                  def,
                  showLegendBand: false,
                  shape: keyShape.shape,
                  hitShape: keyShape.hitShape,
                  hitOutset: keyShape.hitOutset,
                  labelInsets: keyShape.labelInsets,
                ),
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
    );
  }
}

/// 커서 패드 방향
enum CursorPadSector { up, down, left, right }

/// 커서 패드 방향 키 하나의 그림 모양·터치 모양·터치 여백·라벨 여백 (`CalcKeyButton`의 같은 이름 인자로 넘긴다)
typedef CursorPadKeyShape = ({
  Path Function(Size size) shape,
  Path Function(Size size) hitShape,
  EdgeInsets hitOutset,
  EdgeInsets labelInsets,
});

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
/// - **터치 영역** (#64): 외곽 안은 그림과 같이 X자 홈으로, 외곽 밖과 셀 여백은 **홈이 외곽과 만나는 점에서
///   셀 모서리로 이은 선**으로 나눈다. 그래서 셀의 네 변은 각각 그 쪽 방향 하나의 것이다(왼쪽 변 전체가 ◀).
///   셀([hitSectorAt]의 `bounds`) 안에서 데드존만 빼면 모든 점이 어느 한 방향에 속한다.
///
/// [sectorAt]·[hitSectorAt]은 위 정의를 그대로 옮긴 명세(참값) 판정이다. 실제 그림은 [sectorPath],
/// 누름·이동 이탈 판정은 [hitPath]가 다각형으로 근사해 맡는다(곡선 구간은 [_arcSegments]개 선분,
/// 경계에서 0.3dp 미만 차이). 테스트는 명세 판정과 경로가 일치하는지로 경로를 검증한다.
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

  /// 정규화 좌표에서 홈이 가로축과 이루는 각 (k < 1이면 45°보다 크다 — 실측 k ≈ 0.9, #65)
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
    return [
      for (var i = 0; i <= _arcSegments; i++)
        _outlinePoint(from + (to - from) * i / _arcSegments),
      ..._deadZoneArc(from, to),
    ];
  }

  /// 정규화 각도 [from]~[to] 구역의 데드존 호 — [to] 쪽 홈에서 [from] 쪽 홈으로 반시계 방향.
  List<Offset> _deadZoneArc(double from, double to) {
    // 화면 각도로 고르게 나눈다 (끝 각도는 시작보다 작아지게 2π 단위로 맞춘다).
    final a0 = (_circlePoint(to, 1) - center).direction;
    var a1 = (_circlePoint(from, 1) - center).direction;
    while (a1 > a0) {
      a1 -= 2 * math.pi;
    }
    return [
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

  /// [sector]의 시맨틱(스크린리더 터치 탐색) 영역 (패드 로컬 좌표).
  ///
  /// 네 영역은 서로 겹치지 않는다. 각 영역은 자기 방향이 입력되는 곳에만 걸친다. 외곽 안에서는 자기 구역이고,
  /// 그려진 허브의 고리(데드존 밖) 가운데 가운데 사각형(|dx| < X이고 |dy| < Y, 아래) 밖 부분도 포함한다.
  /// 외곽 밖에서는 자기 방향의 터치 영역이다. 데드존은 덮지 않는다(#166).
  /// 누르면 입력되는 곳과 스크린리더가 읽는 곳을 맞추기 위해서다. #43에서는 그려진 허브 전체를 피했다.
  /// 그런데 허브를 실측대로 키운 뒤(#65) 320×568·상태바 20dp의 ▲·▼ 영역 높이가 17.4dp로 낮아졌다.
  ///
  /// 화면 좌표에서 홈은 |dx| = m·|dy| (m = k·[radiusX]/[radiusY])이다. ◀·▶ 영역을 |dx| ≥ X, |dy| ≤ Y,
  /// ▲·▼ 영역을 |dx| ≤ X, |dy| ≥ Y로 두고 X = m·Y로 맞추면 각 영역이 홈을 넘지 않는다.
  /// - Y는 중심에서 위쪽 변까지 거리 H의 1/3이다. 위쪽 변은 셀([bounds])의 위 변이고, 없으면 패드 상자의 위 변이다.
  ///   [bounds]가 위아래로 대칭이면 ▲·▼ 영역 높이(H − Y)와 ◀·▶ 영역 높이(2Y)가 같다.
  ///   [bounds]를 생략하면 ▲·▼ 영역의 위 변은 외곽 위 끝이라서 ▲·▼가 선 두께만큼 낮다.
  /// - 셀이 패드보다 크게 높으면 H/3이 홈 끝(홈이 외곽과 만나는 점)보다 높아질 수 있다. 그러면 X = m·Y가 홈 끝을
  ///   넘어 ▲·▼ 영역이 외곽 밖 ◀·▶ 터치 영역을 덮고, 더 높으면 ◀·▶ 사각형이 뒤집힌다(리뷰 R1).
  ///   그래서 Y의 상한을 홈 끝 높이의 98%로 둔다. 셀까지 넓힌 영역이 자기 방향 터치 영역 안에 머무는 조건은
  ///   Y ≤ 홈 끝 높이 하나다. 지금 k에서 홈 끝 높이는 외곽 반높이의 약 0.66이다. 지금 배치의 셀은 패드 높이의
  ///   1.08배 이하라서 상한이 걸리지 않는다. Y가 셀 높이를 따르므로 셀 여백은 ▲·▼와 ◀·▶가 고르게 나눠 갖는다.
  ///   R1에서 Y를 패드에만 묶었더니 390×844 등 흔한 세로 폰에서 ◀·▶ 짧은 변이 2dp쯤 줄었다(리뷰 R2).
  /// - 데드존을 피하도록 Y와 X는 데드존 반지름 이상으로 둔다. 지금 상수(데드존 0.1)에서는 H/3이 항상 더
  ///   커서 걸리지 않는 안전장치다.
  /// - 측정(320×568·상태바 20dp, 패드 97.7×67.8dp): ▲·▼ 43.1×17.4 → 29.6×22.6dp, ◀·▶ 27.3×32.9 → 34.1×22.6dp.
  ///   짧은 변이 17.4dp에서 22.6dp가 된다.
  /// - 대가: 고리를 덮으려고 X·Y를 줄이면 홈 옆 대각선 빈 곳(|dx| > X이고 |dy| > Y)이 커진다. 그래서 누르면
  ///   입력되는 곳 가운데 터치 탐색으로 읽히는 넓이는 오히려 준다(리뷰 R2 측정, 셀 기준).
  ///   320×568·상태바 20dp에서 50.1% → 43.7%, 412×915에서 49.7% → 42.7%다.
  ///   사각형 네 개로 덮는 넓이는 Y가 허브 반지름쯤일 때 가장 크다. 따라서 짧은 변을 키우는 대신 치르는 값이다.
  ///   가운데 사각형(|dx| < X이고 |dy| < Y)도 빈 곳이다. 허브 반지름보다 X·Y가 조금 작을 뿐이라 고리 대부분이
  ///   여기에 든다(#173 확인 전에는 문서에 없었다 — 아래).
  /// - m < 1이면(지금 k와 패드 비율 1.4 이상에서는 m ≥ 1.26) ▲·▼ 폭 2·m·Y가 가장 짧은 변이 될 수 있다.
  /// - TalkBack 에뮬레이터 확인(#173, Android 16 Google Play 이미지, 411×914dp·상태바와 제스처 막대 각 24dp).
  ///   확인된 동작:
  ///   - 터치 탐색이 초점을 둔 노드가 이 영역과 12px(4.6dp) 격자 690점 모두 일치했다.
  ///     영역 경계 0.5px 안의 점은 어긋날 수 있다(고리 위 48점 중 ▼ 경계 2점).
  ///   - 쓸어 넘기기 순서는 ◀ ▲ ▼ ▶이다(정렬 키 없이 위치로 정해진다).
  ///   - 두 번 탭하면 초점 방향이 입력된다.
  ///
  ///   빈 곳 두 가지(홈 옆 대각선·가운데 사각형)가 그대로 나타났다. 1px 계산으로는 누르면 입력되는 곳 가운데
  ///   읽히는 곳이 약 44%, 허브 고리 가운데는 약 19%다. 위 R2 측정(412×915 42.7%)은 인셋 없는 화면이다.
  ///   ◀·▶는 고리 바깥 가장자리 약 1.6dp 띠에서만 읽힌다. 빈 곳을 짚으면 초점이 앞 방향에 남는다.
  ///   그 상태에서 두 번 탭하면 손가락 아래 방향이 아니라 앞 방향이 입력된다. 대응은 #203에서 정한다.
  ///   짧은 변 실측(uiautomator)은 Android 320×568(상태바·제스처 막대 각 24dp)에서 21.3dp, 411×914 화면의
  ///   반 분할 창(411×452dp)에서 17.1dp였다.
  ///
  /// [bounds](셀)를 주면 바깥쪽 변을 셀 변까지 넓힌다 — 터치 영역(#64)과 같게, 셀 여백을 손가락으로
  /// 훑어도 그쪽 방향이 읽힌다. 넓힌 부분도 그 방향의 터치 영역([hitSectorAt]) 안이다.
  Rect semanticRect(CursorPadSector sector, [Rect? bounds]) {
    if (_isEmpty) return Rect.zero;
    final m = _k * radiusX / radiusY;
    final top = bounds?.top ?? 0;
    final grooveHeight =
        center.dy - _grooveEnd(CursorPadSector.up, CursorPadSector.left).dy;
    final y = math.max(
      math.min((center.dy - top) / 3, grooveHeight * 0.98),
      math.max(deadZoneRadius, deadZoneRadius / m),
    );
    final x = m * y;
    final c = center;
    return switch (sector) {
      CursorPadSector.up => Rect.fromLTRB(
        c.dx - x,
        bounds?.top ?? c.dy - radiusY,
        c.dx + x,
        c.dy - y,
      ),
      CursorPadSector.down => Rect.fromLTRB(
        c.dx - x,
        c.dy + y,
        c.dx + x,
        bounds?.bottom ?? c.dy + radiusY,
      ),
      CursorPadSector.left => Rect.fromLTRB(
        bounds?.left ?? c.dx - radiusX,
        c.dy - y,
        c.dx - x,
        c.dy + y,
      ),
      CursorPadSector.right => Rect.fromLTRB(
        c.dx + x,
        c.dy - y,
        bounds?.right ?? c.dx + radiusX,
        c.dy + y,
      ),
    };
  }

  /// [sector] 구역 넓이 (dp², [sectorPath] 다각형의 신발끈 공식)
  double sectorArea(CursorPadSector sector) =>
      _isEmpty ? 0 : polygonArea(sectorPolygon(sector));

  /// 닫힌 다각형 [points]의 넓이 (dp², 신발끈 공식)
  static double polygonArea(List<Offset> points) {
    var twice = 0.0;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final q = points[(i + 1) % points.length];
      twice += p.dx * q.dy - q.dx * p.dy;
    }
    return twice.abs() / 2;
  }

  /// [localPosition](패드 로컬 좌표)을 누르면 입력될 방향 (#64). 셀 [bounds](패드 로컬 좌표, 패드 상자를 품는다)
  /// 안에서 데드존만 뺀다. 외곽 안은 [sectorAt]과 같고(X자 홈), 외곽 밖은 그 사분면의 홈 끝(홈이 외곽과
  /// 만나는 점)과 셀 모서리를 이은 선의 어느 쪽인지로 정한다. 셀 밖·데드존·유한하지 않은 좌표면 `null`이다.
  CursorPadSector? hitSectorAt(Offset localPosition, Rect bounds) {
    if (_isEmpty || bounds.isEmpty || !localPosition.isFinite) return null;
    assert(_debugBoundsContainPad(bounds));
    if (!_closedContains(bounds, localPosition)) return null;
    final d = localPosition - center;
    if (d.distance <= deadZoneRadius) return null;
    final u = d.dx / radiusX;
    final v = d.dy / radiusY;
    final horizontal = u < 0 ? CursorPadSector.left : CursorPadSector.right;
    final vertical = v < 0 ? CursorPadSector.up : CursorPadSector.down;
    if (math.pow((u + v).abs(), _p) + math.pow((u - v).abs(), _p) <= 2) {
      return u.abs() <= _k * v.abs() ? vertical : horizontal;
    }
    // 외곽 밖: 홈 끝 → 셀 모서리 선을 기준으로, 셀 위·아래 변 쪽이면 ▲·▼, 옆 변 쪽이면 ◀·▶
    final end = _grooveEnd(vertical, horizontal);
    final corner = _cornerOf(vertical, horizontal, bounds);
    final reference = Offset(
      end.dx,
      corner.dy,
    ); // 홈 끝 바로 위(아래)의 셀 변 위 점 — ▲·▼ 쪽
    return _sameSide(end, corner, localPosition, reference)
        ? vertical
        : horizontal;
  }

  /// 셀 [bounds]가 패드 상자를 품는지 (터치 영역 계산의 전제, 부동소수 오차 허용) — 디버그 assert용
  bool _debugBoundsContainPad(Rect bounds) {
    assert(
      bounds.left <= 1e-6 &&
          bounds.top <= 1e-6 &&
          bounds.right >= size.width - 1e-6 &&
          bounds.bottom >= size.height - 1e-6,
      '셀 $bounds가 패드 상자 $size를 품지 않는다',
    );
    return true;
  }

  /// 경계 포함 사각형 판정 ([Rect.contains]는 오른쪽·아래 변을 뺀다)
  static bool _closedContains(Rect r, Offset p) =>
      p.dx >= r.left && p.dx <= r.right && p.dy >= r.top && p.dy <= r.bottom;

  /// [vertical]·[horizontal] 사분면의 홈이 외곽과 만나는 점
  Offset _grooveEnd(CursorPadSector vertical, CursorPadSector horizontal) {
    final t = _grooveAngle;
    final phi = switch ((vertical, horizontal)) {
      (CursorPadSector.down, CursorPadSector.right) => t,
      (CursorPadSector.down, _) => math.pi - t,
      (CursorPadSector.up, CursorPadSector.left) => math.pi + t,
      _ => -t,
    };
    return _outlinePoint(phi);
  }

  /// [vertical]·[horizontal] 사분면의 셀 모서리
  static Offset _cornerOf(
    CursorPadSector vertical,
    CursorPadSector horizontal,
    Rect bounds,
  ) => Offset(
    horizontal == CursorPadSector.left ? bounds.left : bounds.right,
    vertical == CursorPadSector.up ? bounds.top : bounds.bottom,
  );

  /// [p]와 [q]가 [a]–[b] 직선의 같은 쪽(또는 선 위)인지
  static bool _sameSide(Offset a, Offset b, Offset p, Offset q) {
    final ab = b - a;
    double cross(Offset x) => ab.dx * (x.dy - a.dy) - ab.dy * (x.dx - a.dx);
    return cross(p) * cross(q) >= 0;
  }

  /// [sector]의 터치 영역 다각형 (패드 로컬 좌표): 한쪽 홈 끝 → 셀 모서리 둘 → 다른 홈 끝 → 데드존 호.
  /// 외곽 안 부분은 [sectorPolygon]과 같고(외곽 호가 안쪽 선이 될 뿐), 셀의 그쪽 변 전체를 가진다.
  /// 패드나 셀이 비어 있으면 빈 목록. [bounds](셀)는 패드 상자를 품어야 한다.
  List<Offset> hitPolygon(CursorPadSector sector, Rect bounds) {
    if (_isEmpty || bounds.isEmpty) return const [];
    assert(_debugBoundsContainPad(bounds));
    final (from, to) = _angles(sector);
    final corners = switch (sector) {
      CursorPadSector.right => [bounds.topRight, bounds.bottomRight],
      CursorPadSector.down => [bounds.bottomRight, bounds.bottomLeft],
      CursorPadSector.left => [bounds.bottomLeft, bounds.topLeft],
      CursorPadSector.up => [bounds.topLeft, bounds.topRight],
    };
    return [
      _outlinePoint(from),
      ...corners,
      _outlinePoint(to),
      ..._deadZoneArc(from, to),
    ];
  }

  /// [sector] 터치 영역 경로 (패드 로컬 좌표, [hitPolygon])
  Path hitPath(CursorPadSector sector, Rect bounds) {
    final points = hitPolygon(sector, bounds);
    if (points.isEmpty) return Path();
    return Path()..addPolygon(points, true);
  }

  /// [sector] 터치 영역 넓이 (dp², [hitPolygon])
  double hitArea(CursorPadSector sector, Rect bounds) =>
      polygonArea(hitPolygon(sector, bounds));
}

/// 실물 fx-991EX 리플레이 패드처럼 가로로 긴 둥근 마름모를 X자 홈으로 4분할한 방향 키 묶음
/// (각인 띠 없음, 모양은 [CursorPadGeometry], 치수는 실측 — [CalcTheme.cursorPadGrooveSlope] 등, #65).
///
/// ```
///      ╲    ▲    ╱       ▲·▼: 위·아래 호를 따라 휜 띠
///   ◀    ╲  ●  ╱    ▶    ◀·▶: 옆으로 뭉툭한 넓은 구역
///        ╱     ╲         ●: 검은 허브 (지름 = 패드 높이의 약 1/2, 한가운데 작은 원만 데드존)
///      ╱    ▼    ╲
/// ```
/// 외곽은 가로로 긴 둥근 마름모이고, 외곽 밖도 가까운 방향의 터치 영역이다.
/// 각 방향 키캡은 [sectorBox](패드를 반으로 나눈 사각형)에 그리고 [CalcKeyButton.shape]로 구역 경로를
/// 넘겨 그림을 구역 안으로 제한한다.
///
/// ## 터치 영역은 셀 전체로 넓힌다 (#64)
/// 패드 상자의 약 30%는 외곽 밖이다. #64 당시 모양(홈 기울기 실측 #65 전)에서는 ◀·▶ 구역이 좁았다
/// (세로 폰에서 함수 키 셀의 약 0.55배).
/// 그래서 그림은 그대로 두고, 버튼 상자를 셀의 반쪽([sectorBox]에 셀 크기를 넣은 것)으로 넓혀
/// [CalcKeyButton.hitShape]·[CalcKeyButton.hitOutset]으로 터치 영역을 [CursorPadGeometry.hitPolygon]으로 준다.
/// - 외곽 안은 그림과 같이 X자 홈으로 나눈다(그린 구역 = 누르는 구역).
/// - 외곽 밖·셀 여백은 **홈이 외곽과 만나는 점에서 셀 모서리로 이은 선**으로 나눈다. 셀의 네 변이 각각
///   그쪽 방향 하나의 것이 되어, 이웃 키(ALPHA·MENU)와 맞닿은 옆 변은 전부 ◀·▶이고 위·아래 변은 ▲·▼다.
///   - 홈을 그대로 연장하는 방식은 (#64 당시 모양에서) 되찾은 넓이의 약 80%를 이미 넓던 ▲·▼에 주고,
///     옆 변의 위·아래 끝까지 ▲·▼로 만들었다(왼쪽 가장자리를 눌렀는데 ▲ — 리뷰 R1).
///   - 홈 기울기 실측(#65) 뒤 터치 넓이는 함수 키 셀 대비 ◀·▶ 약 1.14~1.20배, ▲·▼ 약 1.05~1.11배다.
///     셀이 패드 비율 상한보다 넓은 키패드(#159)에서는 ▲·▼가 약 0.54~0.66배까지 낮아진다.
///   - 방향 키에 들어가는 가장 큰 원(내접원)은 셀이 패드와 비슷하면 셀까지 넓혀도 조금만 는다(▲·▼ 약 +1~4dp).
///     홈 사이 쐐기와 셀 변이 정하기 때문이며, 쐐기는 실물 모양이라 바꾸지 않는다. 지금은 실물처럼 ▲·▼ 쪽이
///     좁다(세로 폰 ▲·▼ 약 30~46dp, ◀·▶ 약 36~52dp). 셀이 패드보다 가로로 긴 배치(분할 화면 등)에서는
///     옆 여백을 받는 ◀·▶ 내접원이 약 +12dp 커진다.
///   - 경계는 외곽에서 꺾이지만 끊기지 않고, 누른 채 이동할 때의 이탈 판정도 같은 경로를 쓴다.
/// - 셀 밖(셀 여백 `_cellPadding`)은 넓히지 않는다 — 이웃 키와의 간격은 다른 키 사이와 같다.
/// - 한가운데 데드존은 그대로 누를 수 없고, 누른 채 데드존이나 다른 방향·셀 밖으로 나가면 반복이 멈춘다.
/// - 스크린리더 시맨틱 영역도 바깥쪽 변을 셀 변까지 넓힌다([CursorPadGeometry.semanticRect]의 `bounds`).
/// - 패드 상자는 셀 **가운데**에 있다고 가정한다([hitPath]가 상자 크기만으로 셀·패드를 되돌린다).
///
/// ## 허브 한가운데만 데드존이다 (#43)
/// 가운데는 네 방향이 만나 손가락이 어느 쪽을 노렸는지 가장 모호한 곳이다. 가까운 방향으로 보내면
/// 의도와 다른 방향으로 커서가 움직이는 오입력이 생기고(되돌리기 어렵다), 무시하면 다시 누르기만 하면 된다.
/// 그래서 한가운데([CursorPadGeometry.deadZoneRadius])는 누를 수 없게 두고, 누른 채 그리로 미끄러지면
/// 반복 입력도 멈춘다. 다만 그려진 허브 전체를 데드존으로 두면 작은 폰에서 ▲·▼ 터치 깊이가 28dp 아래로
/// 줄어들어, 허브 바깥 고리는 홈으로 나뉜 방향 키에 준다(실물보다 누를 수 있는 곳이 넓다 — 실측 허브는
/// 지름이 패드 높이의 약 1/2이라 고리가 넓다, #65).
///
/// 패드 상자는 셀 가운데에 [fitSize]로 가로/세로 비를 제한해 놓는다(셀의 남는 부분도 위 규칙의 터치 영역).
///
/// 버튼의 시맨틱 영역은 반쪽 사각형이라 서로 겹치므로(터치 탐색으로 ▲·▼에 닿을 수 없음),
/// 버튼 시맨틱은 빼고 방향별로 겹치지 않는 [semanticRect] 영역에 시맨틱 노드를 따로 둔다.
class CursorPad extends StatelessWidget {
  /// 방향 키 위젯 생성기. [CursorPadKeyShape]의 네 값을 `CalcKeyButton`의 `shape`·`hitShape`·`hitOutset`·`labelInsets`에
  /// 넘겨야 한다(보통 `showLegendBand: false`인 [CalcKeyButton]).
  final Widget Function(CalcKeyDef def, CursorPadKeyShape shape) buttonBuilder;

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

  /// [sector] 터치 경로 생성기 (`CalcKeyButton.hitShape`용, 정적 함수라 매 빌드 같은 인스턴스)
  static Path Function(Size size) hitShapeOf(CursorPadSector sector) =>
      switch (sector) {
        CursorPadSector.up => _upHitPath,
        CursorPadSector.down => _downHitPath,
        CursorPadSector.left => _leftHitPath,
        CursorPadSector.right => _rightHitPath,
      };

  static Path _upHitPath(Size s) => hitPath(CursorPadSector.up, s);
  static Path _downHitPath(Size s) => hitPath(CursorPadSector.down, s);
  static Path _leftHitPath(Size s) => hitPath(CursorPadSector.left, s);
  static Path _rightHitPath(Size s) => hitPath(CursorPadSector.right, s);

  /// 셀([cell]) 안에서 패드 상자가 놓이는 사각형 (셀 로컬 좌표, 가운데 정렬)
  static Rect padRectIn(Size cell) {
    final pad = fitSize(cell);
    return Offset(
          (cell.width - pad.width) / 2,
          (cell.height - pad.height) / 2,
        ) &
        pad;
  }

  /// [sector] 버튼 상자(셀의 반쪽)에서 그림 상자(패드의 반쪽)까지의 여백 (`CalcKeyButton.hitOutset`)
  static EdgeInsets hitOutsetOf(CursorPadSector sector, Size cell) {
    final outer = sectorBox(sector, cell);
    final pad = padRectIn(cell);
    final inner = sectorBox(sector, pad.size).shift(pad.topLeft);
    // 패드 중심 = 셀 중심이라 가운데 쪽 변은 0이어야 하지만 부동소수 오차로 음수가 될 수 있어 자른다.
    // (오차보다 큰 음수면 패드가 셀 가운데에 있다는 가정이 깨진 것이다 — [hitPath]가 어긋난다.)
    double side(double v) {
      assert(v > -1e-6, '패드 상자가 셀 반쪽 밖으로 나갔다 ($v)');
      return math.max(0.0, v);
    }

    return EdgeInsets.fromLTRB(
      side(inner.left - outer.left),
      side(inner.top - outer.top),
      side(outer.right - inner.right),
      side(outer.bottom - inner.bottom),
    );
  }

  /// [sector] 키캡(패드의 반쪽, 패드 크기 [size])에서 라벨 자리를 뺄 여백 (`CalcKeyButton.labelInsets`, #65).
  ///
  /// - 가운데 쪽 변: 허브 반지름 + 둘레선 반 두께를 뺀다.
  /// - 바깥쪽 변: 외곽선 두께를 뺀다. 반쪽 상자 변에서 외곽선 안쪽 가장자리까지의 거리다.
  ///
  /// 그러면 라벨이 허브 둘레선과 외곽선 사이 가운데쯤에 놓인다. 키캡 아래 눌림 여유 1dp 때문에 ±1dp
  /// 어긋나고, ▲는 눌리면 1dp 허브 쪽으로 내려간다. 눌린 상태에서도 허브에 닿지 않는지는 키패드 테스트가 확인한다.
  /// 그 사이가 라벨보다 좁으면 라벨을 줄여 그린다. 예: 가로로 긴 800×300 키패드, 글자 배율 1.3의 ▲·▼.
  /// 실측 허브는 지름이 패드 높이의 약 1/2이다. 반쪽 상자 가운데(허브 가장자리)에 두면 라벨 절반이 허브에 덮인다.
  static EdgeInsets labelInsetsOf(CursorPadSector sector, Size size) {
    final inner =
        CursorPadGeometry(size).hubRadius + CalcTheme.cursorPadDividerWidth / 2;
    const outer = CalcTheme.cursorPadDividerWidth;
    return switch (sector) {
      CursorPadSector.up => EdgeInsets.only(top: outer, bottom: inner),
      CursorPadSector.down => EdgeInsets.only(top: inner, bottom: outer),
      CursorPadSector.left => EdgeInsets.only(left: outer, right: inner),
      CursorPadSector.right => EdgeInsets.only(left: inner, right: outer),
    };
  }

  /// [sector] 버튼 상자(셀의 반쪽, 크기 [boxSize]) 로컬 좌표의 터치 경로 — 상자 크기만으로 셀·패드 크기를
  /// 되돌려 계산한다([CursorPadGeometry.hitPolygon]).
  static Path hitPath(CursorPadSector sector, Size boxSize) {
    final cell = padSizeOf(sector, boxSize);
    final pad = padRectIn(cell);
    final box = sectorBox(sector, cell);
    final bounds = (Offset.zero & cell).shift(-pad.topLeft); // 패드 로컬 좌표의 셀
    return CursorPadGeometry(pad.size)
        .hitPath(sector, bounds)
        .shift(pad.topLeft - box.topLeft);
  }

  /// [size] 패드 안에서 [sector]의 시맨틱 영역 ([CursorPadGeometry.semanticRect], [bounds]는 패드 로컬 좌표의 셀)
  static Rect semanticRect(CursorPadSector sector, Size size, [Rect? bounds]) =>
      CursorPadGeometry(size).semanticRect(sector, bounds);

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
        final padRect = padRectIn(cell);
        final size = padRect.size;
        final bounds = (Offset.zero & cell).shift(
          -padRect.topLeft,
        ); // 패드 로컬 좌표의 셀
        final press = onKeyPressed;
        final strings = CalcSemanticStrings.of(context);
        return SizedBox.fromSize(
          size: cell,
          child: Stack(
            children: [
              // 방향 키: 버튼 상자는 셀의 반쪽(터치 영역), 그림은 그 안의 패드 반쪽 (#64)
              for (final sector in CursorPadSector.values)
                Positioned.fromRect(
                  rect: sectorBox(sector, cell),
                  child: ExcludeSemantics(
                    child: buttonBuilder(defOf(sector), (
                      shape: shapeOf(sector),
                      hitShape: hitShapeOf(sector),
                      hitOutset: hitOutsetOf(sector, cell),
                      labelInsets: labelInsetsOf(sector, size),
                    )),
                  ),
                ),
              Positioned.fromRect(
                rect: padRect,
                child: Stack(
                  key: const ValueKey('cursor-pad'),
                  children: [
                    // X자 홈·외곽선·허브 (터치는 통과시켜 아래 방향 키가 받는다 — 한가운데는 키 경로 밖이라 데드존)
                    // 키를 누를 때마다 장식(128각형 외곽 등)을 다시 그리지 않도록 레이어를 분리한다.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _CursorPadDecorationPainter(
                              CalcPalette.of(context).keyBorder,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 겹치지 않는 시맨틱 영역 — 바깥쪽 변은 셀 변까지 (자식이 없어 터치는 받지 않는다)
              for (final sector in CursorPadSector.values)
                Positioned.fromRect(
                  rect: semanticRect(
                    sector,
                    size,
                    bounds,
                  ).shift(padRect.topLeft),
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
        );
      },
    );
  }
}

/// 커서 패드 X자 홈·외곽선과 가운데 허브
class _CursorPadDecorationPainter extends CustomPainter {
  /// 홈·외곽선·허브 둘레 색 (키캡 테두리와 같다 — 고대비 모드에서 바뀐다, #54)
  final Color lineColor;

  const _CursorPadDecorationPainter(this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = CursorPadGeometry(size);
    final line = Paint()
      ..color = lineColor
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
  bool shouldRepaint(_CursorPadDecorationPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}
