import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';
import '../../domain/models/lcd_status.dart';
import '../l10n/calc_semantic_strings.dart';
import 'text_fit.dart';

/// 입력·결과 줄이 LCD 폭을 넘을 때의 좌/우 스크롤 표시(◄/►) 여부.
@immutable
class LcdLineOverflow {
  /// 왼쪽에 가려진 내용이 있음 (◄)
  final bool left;

  /// 오른쪽에 가려진 내용이 있음 (►)
  final bool right;

  const LcdLineOverflow({this.left = false, this.right = false});

  /// 넘침 없음
  static const LcdLineOverflow none = LcdLineOverflow();

  @override
  bool operator ==(Object other) =>
      other is LcdLineOverflow && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);

  @override
  String toString() => 'LcdLineOverflow(left: $left, right: $right)';
}

/// LCD 크기에서 산출한 상태 표시·입력 줄·결과 줄 글자 크기 (#23). 모두 배율 반영 **전** 크기다.
///
/// [LcdDisplay]는 상태 표시줄을 뺀 높이를 입력 줄 [CalcTheme.lcdInputLineFlex]행 : 결과 줄
/// [CalcTheme.lcdResultLineFlex]행으로 나눈다. 줄 글자 크기는 [LcdDisplay]가 실제로 그리는 방식
/// (배율 반영·정수 올림)으로 계산해 다음 둘을 모두 만족하는 가장 큰 값이다.
/// - **높이 기준**: 상태 표시줄 + 전체 행 + 2행 줄마다 분수 막대·여백([CalcTheme.lcdFractionBarRatio])이
///   LCD 안쪽 높이에 들어간다. 그래서 입력·결과 줄이 각각 분수(분자·막대·분모)를 잘림 없이 담는다.
/// - **폭 기준**: 결과 줄에 [CalcTheme.lcdLineColumns]칸과 양쪽 ◄/► 자리가 들어간다.
///
/// 실물 Natural 표시처럼 입력·결과 줄은 같은 크기다.
///
/// ## 시스템 글자 배율
/// - **줄 글자**는 이미 LCD를 채우는 크기라 배율로 더 키울 공간이 없다. 그래서 배율 반영 후 크기가
///   LCD 크기로 정해진다(배율과 무관하게 같은 크기로 보인다).
/// - **상태 표시**는 배율 반영 후 줄 글자 × [CalcTheme.lcdStatusFontRatio]에 다시 배율을 반영한다.
///   큰 글자를 쓰는 사용자에게 작은 상태 표시가 커지고, 그만큼 줄 글자가 줄어든다.
/// - 조건을 만족하는 크기가 없을 만큼 LCD가 작으면 하한([minFittedFontSize])을 돌려준다(이때는 넘쳐 잘린다).
///
/// 분수 1단(분자·막대·분모)까지만 보장한다. 정적분·시그마·√ 안 분수처럼 그보다 높은 템플릿의
/// 축소·세로 처리는 #36(M2)에서 정한다.
@immutable
class LcdFontSizes {
  /// 상태 표시 글자 크기 (dp)
  final double status;

  /// 입력 줄 글자 크기 (dp)
  final double input;

  /// 결과 줄 글자 크기 (dp)
  final double result;

  const LcdFontSizes({
    required this.status,
    required this.input,
    required this.result,
  });

  /// [size] 크기의 LCD(베젤 포함)에 [textScaler]로 그릴 때의 글자 크기.
  ///
  /// [textScaler]는 [LcdDisplay]가 실제로 쓰는 배율([CalcTheme.lcdMaxTextScaleFactor]로 제한한 값)이다.
  /// 크기가 무한·NaN인 축은 [LcdDisplay.fallbackSize]의 값을 쓴다.
  factory LcdFontSizes.forSize(Size size, TextScaler textScaler) {
    double finite(double v, double fallback) =>
        v.isFinite ? math.max(0.0, v) : fallback;
    const chrome = 2 * (CalcTheme.lcdFrameWidth + CalcTheme.lcdInnerPadding);
    final innerWidth = math.max(
      0.0,
      finite(size.width, LcdDisplay.fallbackSize.width) - chrome,
    );
    final innerHeight = math.max(
      0.0,
      finite(size.height, LcdDisplay.fallbackSize.height) - chrome,
    );

    const rowCount = CalcTheme.lcdInputLineFlex + CalcTheme.lcdResultLineFlex;
    // LcdDisplay는 줄 높이를 flex 비율로 나누므로, 줄마다 분수 막대 몫을 정확히 받으려면 두 줄의
    // 행 수가 같아야 한다 (calc_theme_test 불변식).
    const fractionLines = 2;
    const columns = CalcTheme.lcdLineColumns;

    // 상태 표시 글자 크기 (배율 반영 전) — 배율 반영 줄 글자 × 비율 (위 "시스템 글자 배율" 참고)
    double statusOf(double line) => math.max(
      minFittedFontSize,
      textScaler.scale(line) * CalcTheme.lcdStatusFontRatio,
    );

    // [line]: 배율 반영 전 줄 글자 크기
    bool fits(double line) {
      final scaledLine = textScaler.scale(line);
      final scaledStatus = textScaler.scale(statusOf(line));
      // 높이: 상태 표시줄은 LcdDisplay와 같은 식이다. 분수의 분자·분모 Text는 각각 높이가 정수로
      // 올림되므로 행마다 1dp를 더한다.
      final height =
          scaledStatus * CalcTheme.lcdStatusBarHeightRatio +
          rowCount * (scaledLine * _lineHeightFactor + 1) +
          fractionLines * scaledLine * CalcTheme.lcdFractionBarRatio;
      // 폭: ◄/► 자리는 _ScrollArrow와 같은 식(줄 글자 × 비율을 배율 반영). 자간은 배율과 무관하다.
      final arrow =
          textScaler.scale(line * CalcTheme.lcdScrollArrowFontRatio) *
          CalcTheme.lcdScrollArrowWidthRatio;
      final width =
          columns *
              (scaledLine * CalcTheme.lcdLineCharWidthRatio +
                  _maxLetterSpacing) +
          2 * arrow;
      return height <= innerHeight && width <= innerWidth;
    }

    // 탐색 상한은 폭 기준만으로 정한 값(자간·◄/► 무시)이다. 배율이 1보다 작으면 배율 반영 전 크기로
    // 되돌려 키운다. 높이와 무관하게 두어, 폭 기준에 걸리는 LCD는 높이가 달라도 같은 탐색 경로로
    // 정확히 같은 값을 얻는다 (배율이 단조라는 전제).
    final widthBound = math.max(
      minFittedFontSize,
      innerWidth / (columns * CalcTheme.lcdLineCharWidthRatio),
    );
    final scaleAtBound = textScaler.scale(widthBound) / widthBound;
    final line = fitFontSize(
      scaleAtBound < 1 && scaleAtBound > 0
          ? widthBound / scaleAtBound
          : widthBound,
      textScaler: TextScaler.noScaling,
      fits: fits,
    );
    return LcdFontSizes(status: statusOf(line), input: line, result: line);
  }

  /// 입력·결과 줄 스타일 중 큰 줄 높이 배수 (행 높이 = 글자 크기 × 이 값)
  static double get _lineHeightFactor => math.max(
    CalcTheme.lcdInputStyle.height ?? 1.0,
    CalcTheme.lcdResultStyle.height ?? 1.0,
  );

  /// 입력·결과 줄 스타일 중 큰 자간 (dp)
  static double get _maxLetterSpacing => math.max(
    CalcTheme.lcdInputStyle.letterSpacing ?? 0.0,
    CalcTheme.lcdResultStyle.letterSpacing ?? 0.0,
  );

  @override
  bool operator ==(Object other) =>
      other is LcdFontSizes &&
      other.status == status &&
      other.input == input &&
      other.result == result;

  @override
  int get hashCode => Object.hash(status, input, result);

  @override
  String toString() =>
      'LcdFontSizes(status: $status, input: $input, result: $result)';
}

/// fx-991EX ClassWiz 스타일의 도트 매트릭스 LCD.
///
/// 구성 (위 → 아래):
/// ```
///  ╔══════════════════════════════════╗  ← 은색 베젤 (CalcTheme.lcdFrame)
///  ║ S  A  M  STO  D  FIX  E  Math ... ║  ← 상태 표시줄 (고정 슬롯을 폭 전체에 분포)
///  ║◄ 2+3×                           ►║  ← 입력 줄 (왼쪽 정렬)
///  ║                                5 ║  ← 결과 줄 (오른쪽 정렬)
///  ╚══════════════════════════════════╝
/// ```
///
/// ## 크기 계약
/// - 크기는 부모가 정한다. 제약이 무한한 축에만 [fallbackSize]의 해당 축 값을 쓴다.
///   LCD : 키패드 비율은 `CalculatorScreen`이 정한다.
/// - 글자 크기: [fitFontsToSize]가 `true`면 실제 LCD 크기·배율로 [LcdFontSizes.forSize]를 산출해 쓴다
///   (계산기 화면). 아니면 [statusFontSize]·[inputFontSize]·[resultFontSize]를 쓰고, 주입하지 않으면
///   테마 기본 크기다.
/// - 상태 표시줄 높이는 상태 글자 크기 × [CalcTheme.lcdStatusBarHeightRatio]이고,
///   남은 높이를 입력 줄과 결과 줄이 [CalcTheme.lcdInputLineFlex] : [CalcTheme.lcdResultLineFlex]행으로 나눈다.
/// - 상태 표시줄은 폭이 남으면 슬롯을 고르게 펼치고, 모자라면 통째로 축소한다.
///   슬롯 위치는 표시 상태와 무관하게 LCD 크기로만 정해진다.
/// - 시스템 글자 배율은 LCD 전체에 [CalcTheme.lcdMaxTextScaleFactor]까지만 반영한다.
///   줄 글자([DefaultTextStyle])는 배율을 반영한 높이가 줄 높이를 넘지 않도록 줄어든다.
///   [fitFontsToSize]이면 줄 글자는 LCD를 채우는 크기라 배율로 커지지 않고 상태 표시만 커진다
///   ([LcdFontSizes] 참고).
/// - LCD는 실물처럼 항상 왼쪽 → 오른쪽(LTR)으로 배치한다.
///
/// ## 줄 내용 계약 (M2 `MathNodeWidget` 연동)
/// - [input]/[result]는 **제약 없이**(가로·세로 무한) 자기 크기대로 그려진다. 그 뒤 줄 영역에 맞춰
///   실물처럼 입력은 왼쪽 위, 결과는 오른쪽 아래로 정렬하고, 줄 밖으로 나간 부분은 잘라낸다(축소하지 않음).
///   (2행 줄에서 한 행짜리 입력은 입력 줄 위쪽, 결과는 결과 줄 아래쪽에 붙는다.)
///   그래서 `Row`/`Column` 재귀 트리(2D 수식)가 줄보다 커도 넘침 오류 없이 실물 LCD처럼 잘려 보인다.
/// - 줄 크기는 [LcdLineScope.maybeOf]로 알 수 있다. 커서 따라가기 같은 가로 스크롤은 내용 위젯이
///   이 크기를 기준으로 스스로 처리한다. 스크롤 뷰를 쓰려면 이 크기의 `SizedBox`로 감싼다.
///   [fitFontsToSize]이면 입력·결과 줄은 각각 분수 1단(분자·막대·분모)을 잘림 없이 담는다.
///   그보다 세로로 큰 수식(정적분·시그마·겹분수 등)을 축소할지, 세로 스크롤할지는 #36(M2)에서 정한다.
/// - 가려진 쪽이 있으면 호출자가 [inputOverflow]/[resultOverflow]로 ◄/►를 켠다.
///   ◄/► 자리는 항상 비워 두므로 켜고 꺼도 줄 폭이 같다. 자동 판정은 M2 스크롤 구현과 함께 정한다.
/// - 일반 [Text]를 넘기면 입력 줄은 [CalcTheme.lcdInputStyle], 결과 줄은 [CalcTheme.lcdResultStyle]
///   (글자 크기는 위 규칙으로 조정)이 적용된다.
class LcdDisplay extends StatelessWidget {
  /// 상태 표시줄 상태
  final LcdStatus status;

  /// 입력 줄 내용 (`null`이면 빈 줄)
  final Widget? input;

  /// 결과 줄 내용 (`null`이면 빈 줄)
  final Widget? result;

  /// 입력 줄 좌/우 스크롤 표시
  final LcdLineOverflow inputOverflow;

  /// 결과 줄 좌/우 스크롤 표시
  final LcdLineOverflow resultOverflow;

  /// 상태 표시 글자 크기 (dp). `null`이면 [CalcTheme.lcdStatusStyle]의 크기.
  final double? statusFontSize;

  /// 입력 줄 글자 크기 (dp). `null`이면 [CalcTheme.lcdInputStyle]의 크기. 줄 높이를 넘으면 줄어든다.
  final double? inputFontSize;

  /// 결과 줄 글자 크기 (dp). `null`이면 [CalcTheme.lcdResultStyle]의 크기. 줄 높이를 넘으면 줄어든다.
  final double? resultFontSize;

  /// 꺼진 상태 표시기를 흐리게 보여줄지 여부 (실물 LCD의 꺼진 세그먼트 비침 효과)
  final bool showInactiveIndicators;

  /// 도트 매트릭스 격자 표시 여부
  final bool showDotMatrix;

  /// `true`면 글자 크기를 LCD 크기에서 [LcdFontSizes.forSize]로 산출한다.
  /// 이때 [statusFontSize]·[inputFontSize]·[resultFontSize]는 주입할 수 없다.
  final bool fitFontsToSize;

  /// 제약이 무한한 축에 쓰는 기본 크기
  static const Size fallbackSize = Size(360, 160);

  const LcdDisplay({
    super.key,
    this.status = LcdStatus.initial,
    this.input,
    this.result,
    this.inputOverflow = LcdLineOverflow.none,
    this.resultOverflow = LcdLineOverflow.none,
    this.statusFontSize,
    this.inputFontSize,
    this.resultFontSize,
    this.showInactiveIndicators = true,
    this.showDotMatrix = true,
    this.fitFontsToSize = false,
  }) : assert(
         !fitFontsToSize ||
             (statusFontSize == null &&
                 inputFontSize == null &&
                 resultFontSize == null),
         'fitFontsToSize와 글자 크기 주입은 함께 쓸 수 없다',
       ),
       assert(
         statusFontSize == null ||
             (statusFontSize > 0 && statusFontSize < double.infinity),
         'statusFontSize는 유한한 양수여야 한다',
       ),
       assert(
         inputFontSize == null ||
             (inputFontSize > 0 && inputFontSize < double.infinity),
         'inputFontSize는 유한한 양수여야 한다',
       ),
       assert(
         resultFontSize == null ||
             (resultFontSize > 0 && resultFontSize < double.infinity),
         'resultFontSize는 유한한 양수여야 한다',
       );

  @override
  Widget build(BuildContext context) {
    // LCD 안의 모든 글자(줄 내용 포함)에 같은 배율 상한을 적용한다.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: CalcTheme.lcdMaxTextScaleFactor,
      child: Directionality(
        textDirection: TextDirection.ltr,
        // 커서 깜빡임 등 LCD 안의 다시 그리기가 키패드로 번지지 않게 한다.
        child: RepaintBoundary(child: LayoutBuilder(builder: _buildLayout)),
      ),
    );
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final textScaler = MediaQuery.textScalerOf(context);
    final strings = CalcSemanticStrings.of(context);
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : fallbackSize.width;
    final height = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : fallbackSize.height;

    final fitted = fitFontsToSize
        ? LcdFontSizes.forSize(Size(width, height), textScaler)
        : null;
    final statusFontSize = fitted?.status ?? this.statusFontSize;
    final inputFontSize = fitted?.input ?? this.inputFontSize;
    final resultFontSize = fitted?.result ?? this.resultFontSize;

    // LCD가 아주 낮아도 Column이 넘치지 않도록 상태 표시줄을 안쪽 높이 이내로 제한한다.
    const chrome = 2 * (CalcTheme.lcdFrameWidth + CalcTheme.lcdInnerPadding);
    final innerHeight = math.max(0.0, height - chrome);
    final statusFont = statusFontSize ?? CalcTheme.lcdStatusStyle.fontSize!;
    final statusBarHeight = math.min(
      textScaler.scale(statusFont) * CalcTheme.lcdStatusBarHeightRatio,
      innerHeight,
    );
    final linesHeight = innerHeight - statusBarHeight;
    const flexSum = CalcTheme.lcdInputLineFlex + CalcTheme.lcdResultLineFlex;
    final inputStyle = fitLineStyle(
      CalcTheme.lcdInputStyle,
      fontSize: inputFontSize,
      lineHeight: linesHeight * CalcTheme.lcdInputLineFlex / flexSum,
      textScaler: textScaler,
    );
    final resultStyle = fitLineStyle(
      CalcTheme.lcdResultStyle,
      fontSize: resultFontSize,
      lineHeight: linesHeight * CalcTheme.lcdResultLineFlex / flexSum,
      textScaler: textScaler,
    );

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CalcTheme.lcdBackground,
          border: Border.all(
            color: CalcTheme.lcdFrame,
            width: CalcTheme.lcdFrameWidth,
          ),
          borderRadius: BorderRadius.circular(CalcTheme.lcdBorderRadius),
        ),
        // DecoratedBox는 테두리만큼 자식을 밀어주지 않으므로 베젤 두께를 직접 비운다.
        child: Padding(
          padding: const EdgeInsets.all(CalcTheme.lcdFrameWidth),
          child: ClipRRect(
            // 베젤 안쪽 모서리에 맞춰 격자·내용을 자른다.
            borderRadius: BorderRadius.circular(
              CalcTheme.lcdBorderRadius - CalcTheme.lcdFrameWidth,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (showDotMatrix)
                  const RepaintBoundary(
                    child: CustomPaint(painter: _DotMatrixPainter()),
                  ),
                Padding(
                  padding: const EdgeInsets.all(CalcTheme.lcdInnerPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: statusBarHeight,
                        child: LcdStatusBar(
                          status: status,
                          style: CalcTheme.lcdStatusStyle.copyWith(
                            fontSize: statusFont,
                          ),
                          textScaler: textScaler,
                          showInactive: showInactiveIndicators,
                        ),
                      ),
                      Expanded(
                        flex: CalcTheme.lcdInputLineFlex,
                        child: _LcdLine(
                          key: const ValueKey('lcd-input-line'),
                          semanticLabel: strings.inputLine,
                          alignment: Alignment.topLeft,
                          style: inputStyle,
                          overflow: inputOverflow,
                          textScaler: textScaler,
                          child: input,
                        ),
                      ),
                      Expanded(
                        flex: CalcTheme.lcdResultLineFlex,
                        child: _LcdLine(
                          key: const ValueKey('lcd-result-line'),
                          semanticLabel: strings.resultLine,
                          alignment: Alignment.bottomRight,
                          style: resultStyle,
                          overflow: resultOverflow,
                          textScaler: textScaler,
                          child: result,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// [base] 스타일에 요청 글자 크기([fontSize], 없으면 [base]의 크기)를 적용하되,
  /// 배율을 반영한 한 줄 높이(렌더링 시 정수로 올림)가 [lineHeight]를 넘으면 그 안에 들어오도록 줄인다.
  @visibleForTesting
  static TextStyle fitLineStyle(
    TextStyle base, {
    double? fontSize,
    required double lineHeight,
    required TextScaler textScaler,
  }) {
    // 하한은 [minFittedFontSize]이며, 그보다 낮은 줄은 잘린다.
    return base.copyWith(
      fontSize: fitFontSizeToHeight(
        fontSize ?? base.fontSize!,
        maxHeight: lineHeight,
        textScaler: textScaler,
        heightFactor: base.height ?? 1.0,
      ),
    );
  }
}

/// LCD 상단 상태 표시줄.
///
/// [LcdIndicatorSlot] 순서대로 고정 너비 슬롯을 배치한다. 폭이 남으면 슬롯 사이를 고르게 벌려
/// LCD 폭 전체에 분포시키고, 모자라면 줄 전체를 축소한다. 표시기가 꺼져도 슬롯은 남으므로
/// 다른 표시기의 위치가 바뀌지 않는다. 스크린리더에는 켜진 표시기의 의미만 읽힌다
/// (예: "알파, 메모리, 각도 도, 수학 입출력" — [CalcSemanticStrings.statusBar]).
class LcdStatusBar extends StatelessWidget {
  /// 표시할 상태
  final LcdStatus status;

  /// 표시 글자 스타일 (색은 켜짐/꺼짐에 따라 덮어쓴다). 글자 크기가 없으면 [CalcTheme.lcdStatusStyle]의 크기.
  final TextStyle style;

  /// 시스템 글자 배율
  final TextScaler textScaler;

  /// 꺼진 표시기를 흐리게 보여줄지 여부
  final bool showInactive;

  const LcdStatusBar({
    super.key,
    required this.status,
    this.style = CalcTheme.lcdStatusStyle,
    this.textScaler = TextScaler.noScaling,
    this.showInactive = true,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = style.fontSize != null
        ? style
        : style.copyWith(fontSize: CalcTheme.lcdStatusStyle.fontSize);
    final fontSize = textScaler.scale(resolvedStyle.fontSize!);
    final slots = LcdIndicatorSlot.values;
    double slotWidth(LcdIndicatorSlot s) =>
        fontSize * CalcTheme.lcdStatusCharWidthRatio * s.template.length;
    final slotsWidth = slots.map(slotWidth).fold(0.0, (a, b) => a + b);
    final minGap = fontSize * CalcTheme.lcdStatusSlotGapRatio;

    Widget row(double gap) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, slot) in slots.indexed) ...[
          if (i > 0) SizedBox(width: gap),
          _IndicatorSlot(
            key: ValueKey(slot),
            slot: slot,
            label: status.indicatorFor(slot),
            width: slotWidth(slot),
            height: fontSize * CalcTheme.lcdStatusBarHeightRatio,
            style: resolvedStyle,
            textScaler: textScaler,
            showInactive: showInactive,
          ),
        ],
      ],
    );

    return Semantics(
      label: CalcSemanticStrings.of(context).statusBar(status),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final natural = slotsWidth + minGap * (slots.length - 1);
          if (constraints.hasBoundedWidth && natural <= constraints.maxWidth) {
            // 폭이 남으면 실물처럼 LCD 폭 전체에 고르게 펼친다.
            final gap =
                (constraints.maxWidth - slotsWidth) / (slots.length - 1);
            return Align(alignment: Alignment.centerLeft, child: row(gap));
          }
          // 좁은 화면이나 큰 글자 배율에서는 줄 전체를 축소해 넘치지 않게 한다.
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: row(minGap),
          );
        },
      ),
    );
  }
}

/// 상태 표시줄의 고정 너비 슬롯 하나.
class _IndicatorSlot extends StatelessWidget {
  final LcdIndicatorSlot slot;

  /// 켜진 표시 문자 (`null`이면 꺼짐)
  final String? label;
  final double width;
  final double height;
  final TextStyle style;
  final TextScaler textScaler;
  final bool showInactive;

  const _IndicatorSlot({
    super.key,
    required this.slot,
    required this.label,
    required this.width,
    required this.height,
    required this.style,
    required this.textScaler,
    required this.showInactive,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = label != null;
    final text = label ?? (showInactive ? slot.template : null);

    return SizedBox(
      width: width,
      height: height,
      child: text == null
          ? null
          : FittedBox(
              // 대체 폰트 폭이 예상과 달라도 슬롯 너비 안에 맞춘다.
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                style: style.copyWith(
                  color: isOn
                      ? CalcTheme.lcdStatusActive
                      : CalcTheme.lcdStatusInactive,
                ),
                textScaler: textScaler,
                maxLines: 1,
                softWrap: false,
              ),
            ),
    );
  }
}

/// 입력 줄 또는 결과 줄 한 줄: `[◄] 내용 [►]`.
class _LcdLine extends StatelessWidget {
  /// 스크린리더가 줄 내용 앞에 읽는 줄 이름 ("입력"/"결과")
  final String semanticLabel;
  final Alignment alignment;
  final TextStyle style;
  final LcdLineOverflow overflow;
  final TextScaler textScaler;
  final Widget? child;

  const _LcdLine({
    super.key,
    required this.semanticLabel,
    required this.alignment,
    required this.style,
    required this.overflow,
    required this.textScaler,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final arrowStyle = style.copyWith(
      fontSize: style.fontSize! * CalcTheme.lcdScrollArrowFontRatio,
      fontWeight: FontWeight.normal,
      letterSpacing: 0,
      height: 1.0,
    );
    // 스크린리더: 줄 이름("입력"/"결과")과 ◄/► 표시·줄 내용을 한 덩어리로 읽는다.
    return MergeSemantics(
      child: Semantics(label: semanticLabel, child: _buildRow(arrowStyle)),
    );
  }

  Widget _buildRow(TextStyle arrowStyle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScrollArrow(
          isLeft: true,
          visible: overflow.left,
          style: arrowStyle,
          textScaler: textScaler,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => LcdLineScope(
              size: constraints.biggest,
              child: ClipRect(
                key: const ValueKey('lcd-line-content'),
                child: DefaultTextStyle(
                  style: style,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  // 내용은 제약 없이 자기 크기로 그리고, 줄 영역에 정렬한 뒤 넘친 부분만 자른다.
                  child: OverflowBox(
                    alignment: alignment,
                    minWidth: 0,
                    maxWidth: double.infinity,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
        _ScrollArrow(
          isLeft: false,
          visible: overflow.right,
          style: arrowStyle,
          textScaler: textScaler,
        ),
      ],
    );
  }
}

/// LCD 입력·결과 줄의 크기를 줄 내용 위젯에 알려 준다.
///
/// 줄 내용은 제약 없이 그려지므로 `LayoutBuilder`로는 줄 크기를 알 수 없다.
/// 가로 스크롤이나 넘침 판정이 필요한 내용 위젯(M2 `MathNodeWidget`)은 이 값을 기준으로 삼는다.
class LcdLineScope extends InheritedWidget {
  /// 줄 내용 영역 크기 (◄/► 자리 제외)
  final Size size;

  const LcdLineScope({super.key, required this.size, required super.child});

  /// 가장 가까운 LCD 줄의 크기. LCD 줄 밖이면 `null`.
  static Size? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LcdLineScope>()?.size;

  @override
  bool updateShouldNotify(LcdLineScope oldWidget) => oldWidget.size != size;
}

/// 줄 양끝의 스크롤 표시(◄/►). 꺼져도 자리를 유지해 내용 위치가 흔들리지 않는다.
class _ScrollArrow extends StatelessWidget {
  /// 왼쪽(◄) 표시인지. 글자 대신 방향으로 구분해, 글리프를 바꿔도 음성 라벨이 뒤바뀌지 않는다.
  final bool isLeft;
  final bool visible;
  final TextStyle style;
  final TextScaler textScaler;

  /// 화살표 글자. 한 칸 폭인 `◄`·`►`를 쓴다 (`◀`·`▶`는 두 칸 폭 — [CalcTheme.lcdScrollArrowWidthRatio]).
  static const String leftSymbol = '◄';
  static const String rightSymbol = '►';

  const _ScrollArrow({
    required this.isLeft,
    required this.visible,
    required this.style,
    required this.textScaler,
  });

  @override
  Widget build(BuildContext context) {
    final width =
        textScaler.scale(style.fontSize!) * CalcTheme.lcdScrollArrowWidthRatio;
    return SizedBox(
      width: width,
      child: visible
          ? Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  isLeft ? leftSymbol : rightSymbol,
                  style: style.copyWith(color: CalcTheme.lcdText),
                  textScaler: textScaler,
                  maxLines: 1,
                  softWrap: false,
                  semanticsLabel: CalcSemanticStrings.of(context)
                      .scrollMore(left: isLeft),
                ),
              ),
            )
          : null,
    );
  }
}

/// 도트 매트릭스 픽셀 사이의 틈을 아주 옅은 격자선으로 그린다.
class _DotMatrixPainter extends CustomPainter {
  const _DotMatrixPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CalcTheme.lcdDotGrid
      ..strokeWidth = CalcTheme.lcdDotGridStrokeWidth;
    const pitch = CalcTheme.lcdDotPitch;
    for (var x = pitch; x < size.width; x += pitch) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = pitch; y < size.height; y += pitch) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DotMatrixPainter oldDelegate) => false;
}
