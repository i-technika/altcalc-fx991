import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/constants/key_definitions.dart';
import '../../core/theme/calc_theme.dart';
import 'calc_key_button.dart';
import 'text_fit.dart';

/// 키패드 크기에서 산출한 배치·글자 치수. 화면 크기와 시스템 글자 배율만으로 정해지는 순수 계산이다.
///
/// 세로 배치 (행 높이 단위, 숫자부 행은 [CalcTheme.keypadNumberRowHeightRatio]배):
/// ```
///  상단 조작부  2행 (좌 2×2 · 커서 패드 · 우 2×2, 각 2열 폭)
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

  /// 상단 조작부·함수부 공통 열 수 (상단 조작부는 2열 블록 3개)
  static const int columnCount = functionColumns;

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
  /// 글자 크기는 가장 작은 키 셀(함수부 행)을 기준으로 [CalcKeyButton]과 같은 비율로 한 번만 계산해
  /// 모든 키에 주입한다. 배율은 [CalcKeyButton]과 같이 [CalcTheme.keyMaxTextScaleFactor]까지
  /// 반영하며, 배율을 반영한 글자가 각인 띠·키캡 높이를 넘지 않도록 미리 줄여 둔다.
  /// 그래서 큰 글자 설정에서도 키마다 크기가 들쭉날쭉하지 않고 함께 커진다.
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
    double capHeightOf(double rowHeight) {
      final cell = math.max(0.0, rowHeight - verticalGap);
      return cell * (1 - CalcTheme.keyLegendHeightRatio);
    }

    final cellHeight = math.max(0.0, functionRowHeight - verticalGap);
    final legendHeight = cellHeight * CalcTheme.keyLegendHeightRatio;
    final capHeight = capHeightOf(functionRowHeight);
    final scaler = textScaler.clamp(
      maxScaleFactor: CalcTheme.keyMaxTextScaleFactor,
    );

    final legendFontSize = fitFontSizeToHeight(
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
    final mainLabelFontSize = fitFontSizeToHeight(
      math.max(minFittedFontSize, capHeight * CalcTheme.keyMainLabelFontRatio),
      maxHeight: capInnerHeight,
      textScaler: scaler,
      heightFactor: CalcTheme.keyMainLabelStyle.height ?? 1.0,
    );

    return KeypadMetrics._(
      size: size,
      horizontalGap: horizontalGap,
      verticalGap: verticalGap,
      sectionGap: sectionGap,
      functionRowHeight: functionRowHeight,
      numberRowHeight: numberRowHeight,
      legendFontSize: legendFontSize,
      mainLabelFontSize: mainLabelFontSize,
      extendFunctionHitArea: capHeight < CalcTheme.keyMinTouchTargetHeight,
      extendNumberHitArea:
          capHeightOf(numberRowHeight) < CalcTheme.keyMinTouchTargetHeight,
    );
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
///   세로·가로가 모두 유한해야 한다(제약이 무한한 축은 [fallbackSize]의 값을 쓴다).
/// - [CalcKeyButton]은 누르는 순간 입력하므로 **스크롤 영역 안에 두지 않는다**.
///
/// ## 입력 계약
/// - 키를 누르면 [onKeyPressed], [autoRepeatKeys]를 길게 누르면 [onKeyRepeat]을 호출한다.
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
  }) {
    return CalcKeyButton(
      keyDef: def,
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
                  child: _CursorPad(button: _button),
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

/// 원형 받침 위에 4방향 키를 십자로 놓은 커서 패드 (각인 띠 없음).
class _CursorPad extends StatelessWidget {
  final Widget Function(CalcKeyDef def, {bool showLegendBand}) button;

  const _CursorPad({required this.button});

  @override
  Widget build(BuildContext context) {
    Widget key(CalcKeyDef def, double widthFactor) => FractionallySizedBox(
      widthFactor: widthFactor,
      child: Padding(
        padding: const EdgeInsets.all(CalcTheme.keyBorderWidth),
        child: button(def, showLegendBand: false),
      ),
    );
    const vertical = CalcTheme.cursorPadVerticalKeyWidthRatio;
    const horizontal = CalcTheme.cursorPadHorizontalKeyWidthRatio;

    return DecoratedBox(
      key: const ValueKey('cursor-pad-base'),
      decoration: const ShapeDecoration(
        color: CalcTheme.cursorPadBase,
        shape: OvalBorder(),
      ),
      child: Column(
        children: [
          Expanded(child: Center(child: key(cursorPad.up, vertical))),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: key(cursorPad.left, horizontal * 2),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: key(cursorPad.right, horizontal * 2),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: Center(child: key(cursorPad.down, vertical))),
        ],
      ),
    );
  }
}
