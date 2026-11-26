import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';
import '../../domain/models/lcd_status.dart';
import '../l10n/calc_semantic_strings.dart';
import 'lcd_status_icon.dart';
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
///  ║ S A M →x √▭✎ D R G FIX SCI E i ∠ ▼▲ ‖ ║  ← 상태 표시줄 (실물 세그먼트 위치의 고정 슬롯)
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
/// - 상태 표시줄은 슬롯 가운데를 실물 세그먼트의 비율 위치에 두고, 겹치는 슬롯은 민다. 밀어도 들어가지
///   않으면 슬롯을 붙여 통째로 축소한다([LcdStatusBar]). 슬롯 위치는 표시 상태와 무관하게 LCD 크기로만 정해진다.
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

  /// 꺼진 상태 표시기를 흐리게 보여줄지 여부 (실물 LCD의 꺼진 세그먼트 비침 효과).
  /// 기본값 `true` — 색은 [CalcTheme.lcdStatusInactive](활성 색의 약 4%, 사용자 결정)라
  /// 정면에서는 거의 보이지 않는다(#44, 실물 확인). 기기의 고대비 설정이 켜지면
  /// [CalcTheme.lcdStatusInactiveHighContrast](약 15%)로 올린다(#54, [CalcPalette]).
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
/// [LcdIndicatorSlot] 순서대로 고정 너비 슬롯을 놓는다. 각 슬롯의 가운데는 실물 세그먼트의 위치
/// ([LcdIndicatorSlot.centerFraction] — 표시줄 폭 대비 비율)에 둔다(#58). 표시기가 꺼져도 슬롯은 남으므로
/// 다른 표시기의 위치가 바뀌지 않는다.
///
/// 앱의 글자는 실물 세그먼트보다 넓을 수 있다. 그래서 이웃과 겹치거나 표시줄 밖으로 나가는 슬롯은
/// 실물 위치에서 벗어나는 양(제곱합)이 가장 작도록 함께 민다([lcdStatusSlotLefts]). 밀어도 들어가지 않을
/// 만큼 좁으면, 슬롯을 최소 간격으로 붙인 줄 전체를 축소한다.
///
/// 스크린리더에는 켜진 표시기의 의미만 화면 순서대로 읽힌다
/// (예: "시프트, 메모리, 수학 입출력, 각도 단위 도" — [CalcSemanticStrings.statusBar]).
///
/// 왼쪽 → 오른쪽 배치를 전제한다. [LcdDisplay]는 주변이 RTL이어도 LTR로 고정하므로, 단독으로 쓸 때도
/// `Directionality(textDirection: TextDirection.ltr)` 아래에 둔다.
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
    final sized = style.fontSize != null
        ? style
        : style.copyWith(fontSize: CalcTheme.lcdStatusStyle.fontSize);
    // 슬롯 글자(Text)와 같은 규칙으로 주변 기본 글자 스타일을 합친다 — 자간·줄 높이가 상속될 수 있고,
    // 슬롯 폭과 아이콘 치수가 실제 글자와 같은 값을 써야 한다(#57 리뷰 R2).
    final resolvedStyle = DefaultTextStyle.of(context).style.merge(sized);
    final fontSize = textScaler.scale(resolvedStyle.fontSize!);
    final slotHeight = fontSize * CalcTheme.lcdStatusBarHeightRatio;
    // 직접 그리는 아이콘(#57)의 치수 — 세 아이콘이 같은 값을 쓰므로 한 번만 계산한다.
    final iconMetrics = LcdStatusIconMetrics.of(
      resolvedStyle,
      textScaler,
      slotHeight,
    );
    final slots = LcdIndicatorSlot.values;
    // 꺼진 표시기 색은 기기의 고대비 설정을 따른다 (#54).
    final inactiveColor = CalcPalette.of(context).lcdStatusInactive;
    // 글자마다 글리프 폭 + 자간 (자간은 글자 배율과 무관한 dp). 음수 자간이 글리프 폭보다 크면 0으로 둔다 —
    // 슬롯 폭이 음수가 되면 레이아웃 예외가 난다(#44 리뷰 R2). 칸 수는 슬롯이 정한다(#57).
    final charWidth = math.max(
      0.0,
      fontSize * CalcTheme.lcdStatusCharWidthRatio +
          (resolvedStyle.letterSpacing ?? 0),
    );
    final widths = [for (final s in slots) charWidth * s.columns];
    final centers = [for (final s in slots) s.centerFraction];
    final minGap = fontSize * CalcTheme.lcdStatusSlotGapRatio;

    Widget bar(double width, List<double> lefts) => SizedBox(
      width: width,
      height: slotHeight,
      child: Stack(
        children: [
          for (final (i, slot) in slots.indexed)
            Positioned(
              left: lefts[i],
              top: 0,
              width: widths[i],
              height: slotHeight,
              child: _IndicatorSlot(
                key: ValueKey(slot),
                slot: slot,
                label: status.indicatorFor(slot),
                width: widths[i],
                height: slotHeight,
                iconMetrics: iconMetrics,
                style: resolvedStyle,
                textScaler: textScaler,
                showInactive: showInactive,
                inactiveColor: inactiveColor,
              ),
            ),
        ],
      ),
    );

    return Semantics(
      label: CalcSemanticStrings.of(context).statusBar(status),
      // 상태 변화 알림은 화면(CalculatorScreen)의 알림 전용 노드가 맡는다. 여기를 liveRegion으로 두면
      // Android에서 상태 표시줄 전체를 매번 다시 읽고 켜짐/꺼짐 의미도 전달되지 않는다(#20 리뷰 R2).
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.hasBoundedWidth) {
            final lefts = lcdStatusSlotLefts(
              centers: centers,
              widths: widths,
              barWidth: constraints.maxWidth,
              minGap: minGap,
            );
            if (lefts != null) {
              // 실물 세그먼트 위치에 놓는다(겹치는 슬롯만 가까운 자리로 민다).
              return Align(
                alignment: Alignment.centerLeft,
                child: bar(constraints.maxWidth, lefts),
              );
            }
          }
          // 좁은 화면이나 큰 글자 배율에서는 최소 간격으로 붙인 줄 전체를 축소해 넘치지 않게 한다.
          final packed =
              widths.fold(0.0, (a, b) => a + b) + minGap * (slots.length - 1);
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            // 붙인 폭에서 가능한 배치는 왼쪽부터 꽉 붙이는 것 하나뿐이다.
            child: bar(packed, _packedLefts(widths, minGap)),
          );
        },
      ),
    );
  }

  /// 슬롯을 왼쪽부터 [minGap] 간격으로 붙인 왼쪽 위치
  static List<double> _packedLefts(List<double> widths, double minGap) {
    final lefts = <double>[];
    var x = 0.0;
    for (final w in widths) {
      lefts.add(x);
      x += w + minGap;
    }
    return lefts;
  }
}

/// 상태 표시줄 슬롯의 왼쪽 위치를 정한다 (#58). 들어가지 않으면 `null`.
///
/// 목표는 각 슬롯의 가운데를 실물 위치([centers] — 0~1 비율 × [barWidth])에 두는 것이다. 제약은 셋이다.
/// - 이웃 슬롯 사이는 [minGap] 이상 띄운다(순서 유지).
/// - 첫 슬롯은 왼쪽 경계, 마지막 슬롯은 오른쪽 경계 안에 둔다.
/// - 이 제약 안에서 목표 위치와의 차이 제곱합이 가장 작은 배치를 고른다.
///   겹치는 무리는 한쪽만 밀리지 않고 양쪽으로 고르게 벌어진다.
///
/// 풀이: 슬롯 i의 왼쪽에서 앞 슬롯들의 폭·간격 합 o_i를 빼면(y_i = x_i − o_i) 간격 제약이 y의 단조 증가로 바뀐다.
/// 그래서 y의 목표값에 단조 회귀(PAVA — 거꾸로 된 이웃 무리를 평균으로 합친다)를 하고, 경계 [0, U]로
/// 자른다(U = [barWidth] − 마지막 슬롯 폭 − o_마지막). 단조 회귀를 상수 구간으로 자른 값이 구간 제약이 있는
/// 단조 회귀의 해다. U < 0이면 폭 합과 최소 간격 합이 [barWidth]보다 커서 들어가지 않는다. 다만 부동소수
/// 오차를 위해 U가 −[barWidth]×1e-6 이상이면 꽉 붙인 배치를 돌려준다(오른쪽 끝이 그만큼 넘을 수 있다).
///
/// [centers]는 정렬되지 않아도 되지만 유한해야 하고, [widths]·[minGap]은 0 이상의 유한값이어야 한다.
/// NaN이 섞이면 평균 비교가 거짓이 되어 순서가 뒤집힌 배치가 나오므로 assert로 막는다.
@visibleForTesting
List<double>? lcdStatusSlotLefts({
  required List<double> centers,
  required List<double> widths,
  required double barWidth,
  required double minGap,
}) {
  assert(centers.length == widths.length);
  assert(centers.every((c) => c.isFinite), 'centers는 유한해야 한다');
  assert(widths.every((w) => w.isFinite && w >= 0), 'widths는 0 이상의 유한값이어야 한다');
  assert(minGap.isFinite && minGap >= 0, 'minGap은 0 이상의 유한값이어야 한다');
  assert(barWidth.isFinite, 'barWidth는 유한해야 한다');
  final n = widths.length;
  if (n == 0) return const [];
  // o_i: 앞 슬롯들의 폭 + 최소 간격 합
  final offsets = List<double>.filled(n, 0);
  for (var i = 1; i < n; i++) {
    offsets[i] = offsets[i - 1] + widths[i - 1] + minGap;
  }
  final upper = barWidth - widths[n - 1] - offsets[n - 1];
  // 부동소수 오차만큼은 허용한다(꽉 차게 붙인 경우).
  if (upper < -1e-6 * math.max(1, barWidth)) return null;
  // PAVA: 무리마다 (합, 개수)를 쌓고, 앞 무리 평균이 더 크면 합친다.
  final sums = <double>[];
  final counts = <int>[];
  for (var i = 0; i < n; i++) {
    var sum = centers[i] * barWidth - widths[i] / 2 - offsets[i];
    var count = 1;
    while (sums.isNotEmpty && sums.last / counts.last > sum / count) {
      sum += sums.removeLast();
      count += counts.removeLast();
    }
    sums.add(sum);
    counts.add(count);
  }
  final lefts = <double>[];
  for (final (b, sum) in sums.indexed) {
    final y = (sum / counts[b]).clamp(0.0, math.max(0.0, upper));
    for (var k = 0; k < counts[b]; k++) {
      lefts.add(y + offsets[lefts.length]);
    }
  }
  return lefts;
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

  /// 꺼진 표시기 색 ([CalcPalette.lcdStatusInactive])
  final Color inactiveColor;

  /// 아이콘 슬롯의 치수 (상태 표시줄이 한 번 계산해 넘긴다)
  final LcdStatusIconMetrics iconMetrics;

  const _IndicatorSlot({
    super.key,
    required this.slot,
    required this.label,
    required this.width,
    required this.height,
    required this.style,
    required this.textScaler,
    required this.showInactive,
    required this.inactiveColor,
    required this.iconMetrics,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = label != null;
    final color = isOn ? CalcTheme.lcdStatusActive : inactiveColor;
    final icon = slot.icon;
    if (icon != null) {
      // 글꼴 글자로는 모양이 맞지 않는 표시기는 직접 그린다 (#57).
      return SizedBox(
        width: width,
        height: height,
        child: isOn || showInactive
            ? LcdStatusIcon(
                key: ValueKey(icon),
                icon: icon,
                color: color,
                metrics: iconMetrics,
              )
            : null,
      );
    }
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
                style: style.copyWith(color: color),
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
    // M2에서 줄 내용(MathNodeWidget)이 커서 위치·동작 같은 자체 시맨틱을 가지면, MergeSemantics가
    // 그것까지 흡수하므로 이 병합 방식을 다시 정한다.
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
