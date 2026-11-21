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
  /// 가로/세로 비를 지키는 가장 큰 키패드 크기.
  static Size fitSize(Size available) {
    final availableWidth = math.max(0.0, available.width);
    final availableHeight = math.max(0.0, available.height);
    final width = math.min(
      availableWidth,
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
  /// 커서 패드 키(화살표 한 글자)는 부채꼴 키캡이 함수부 키캡보다 크므로 폭 계산에서 뺀다.
  factory KeypadMetrics.compute(Size available, TextScaler textScaler) {
    final size = fitSize(available);
    final horizontalGap = size.width * CalcTheme.keyHorizontalGapRatio;
    final verticalGap = size.height * CalcTheme.keyVerticalGapRatio;
    final sectionGap = size.height * CalcTheme.keypadSectionGapRatio;

    final rowUnits =
        functionRowCount +
        numberRows.length * CalcTheme.keypadNumberRowHeightRatio;
    final rowUnit = math.max(0.0, size.height - sectionGap) / rowUnits;
    final functionRowHeight = rowUnit;
    final numberRowHeight = rowUnit * CalcTheme.keypadNumberRowHeightRatio;

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

/// 실물 리플레이 패드처럼 타원을 대각선으로 4등분한 부채꼴 방향 키 묶음 (각인 띠 없음).
///
/// ```
///   ┌───────────┐
///   │ ╲   ▲   ╱ │   각 방향 키는 자기 부채꼴 전체가 터치 영역이다
///   │ ◄  ╲ ╱  ► │   (가운데·대각선 근처까지 데드존 없음, 타원 밖은 무시).
///   │    ╱ ╲    │   키캡은 [sectorBox] 상자에 그리고, [CalcKeyButton.shape]로 부채꼴 경로를
///   │ ╱   ▼   ╲ │   넘겨 그림·누름·이동 이탈(반복 중단) 판정을 모두 부채꼴로 제한한다.
///   └───────────┘
/// ```
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

  /// [sector] 부채꼴 경로 생성기 (정적 함수라 매 빌드 같은 인스턴스 — 불필요한 재클립 방지)
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

  /// [size] 패드 안에서 [sector]의 시맨틱 영역 — 3×3 격자의 가장자리 가운데 칸 (서로 겹치지 않는다)
  static Rect semanticRect(CursorPadSector sector, Size size) {
    final w = size.width / 3;
    final h = size.height / 3;
    return switch (sector) {
      CursorPadSector.up => Rect.fromLTWH(w, 0, w, h),
      CursorPadSector.down => Rect.fromLTWH(w, 2 * h, w, h),
      CursorPadSector.left => Rect.fromLTWH(0, h, w, h),
      CursorPadSector.right => Rect.fromLTWH(2 * w, h, w, h),
    };
  }

  /// 방향별 키 명세
  static CalcKeyDef defOf(CursorPadSector sector) => switch (sector) {
    CursorPadSector.up => cursorPad.up,
    CursorPadSector.down => cursorPad.down,
    CursorPadSector.left => cursorPad.left,
    CursorPadSector.right => cursorPad.right,
  };

  /// [size] 패드 안에서 [sector] 키캡을 그리는 상자 (부채꼴을 감싸는 반쪽 사각형)
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

  /// [sectorBox] 로컬 좌표의 부채꼴(삼각형) 경로 — 패드 중심과 두 모서리를 잇는다.
  static Path sectorPath(CursorPadSector sector, Size boxSize) {
    final w = boxSize.width;
    final h = boxSize.height;
    final points = switch (sector) {
      CursorPadSector.up => [Offset.zero, Offset(w, 0), Offset(w / 2, h)],
      CursorPadSector.down => [Offset(0, h), Offset(w, h), Offset(w / 2, 0)],
      CursorPadSector.left => [Offset.zero, Offset(w, h / 2), Offset(0, h)],
      CursorPadSector.right => [Offset(w, 0), Offset(0, h / 2), Offset(w, h)],
    };
    return Path()..addPolygon(points, true);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
        final press = onKeyPressed;
        final strings = CalcSemanticStrings.of(context);
        return ClipOval(
          key: const ValueKey('cursor-pad'),
          child: Stack(
            children: [
              for (final sector in CursorPadSector.values)
                Positioned.fromRect(
                  rect: sectorBox(sector, size),
                  child: ExcludeSemantics(
                    child: buttonBuilder(defOf(sector), shapeOf(sector)),
                  ),
                ),
              // 부채꼴 경계선과 테두리 (터치는 통과시킨다)
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _CursorPadDividerPainter()),
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
        );
      },
    );
  }
}

/// 커서 패드 대각선 경계와 타원 테두리
class _CursorPadDividerPainter extends CustomPainter {
  const _CursorPadDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CalcTheme.keyBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = CalcTheme.cursorPadDividerWidth;
    canvas
      ..drawLine(Offset.zero, Offset(size.width, size.height), paint)
      ..drawLine(Offset(size.width, 0), Offset(0, size.height), paint)
      ..drawOval(
        (Offset.zero & size).deflate(CalcTheme.cursorPadDividerWidth / 2),
        paint,
      );
  }

  @override
  bool shouldRepaint(_CursorPadDividerPainter oldDelegate) => false;
}
