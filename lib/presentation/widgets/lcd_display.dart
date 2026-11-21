import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';
import '../../domain/models/lcd_status.dart';

/// 입력·결과 줄이 LCD 폭을 넘을 때의 좌/우 스크롤 표시(◀/▶) 여부.
@immutable
class LcdLineOverflow {
  /// 왼쪽에 가려진 내용이 있음 (◀)
  final bool left;

  /// 오른쪽에 가려진 내용이 있음 (▶)
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

/// fx-991EX ClassWiz 스타일의 도트 매트릭스 LCD.
///
/// 구성 (위 → 아래):
/// ```
///  ╔══════════════════════════════════╗  ← 은색 베젤 (CalcTheme.lcdFrame)
///  ║ S  A  M  STO  D  FIX  E  Math ... ║  ← 상태 표시줄 (고정 슬롯을 폭 전체에 분포)
///  ║◀ 2+3×                           ▶║  ← 입력 줄 (왼쪽 정렬)
///  ║                                5 ║  ← 결과 줄 (오른쪽 정렬)
///  ╚══════════════════════════════════╝
/// ```
///
/// ## 크기 계약
/// - 크기는 부모가 정한다. 제약이 무한한 축에만 [fallbackSize]의 해당 축 값을 쓴다.
///   LCD : 키패드 비율과 글자 크기 산정 기준은 #23에서 정의하며, 부모가 [statusFontSize]·
///   [inputFontSize]·[resultFontSize]를 주입한다.
/// - 상태 표시줄 높이는 상태 글자 크기 × [CalcTheme.lcdStatusBarHeightRatio]이고,
///   남은 높이를 입력 줄과 결과 줄이 [CalcTheme.lcdInputLineFlex] : [CalcTheme.lcdResultLineFlex]로 나눈다.
/// - 상태 표시줄은 폭이 남으면 슬롯을 고르게 펼치고, 모자라면 통째로 축소한다.
///   슬롯 위치는 표시 상태와 무관하게 LCD 크기로만 정해진다.
/// - 시스템 글자 배율은 LCD 전체에 [CalcTheme.lcdMaxTextScaleFactor]까지만 반영한다.
///   줄 글자([DefaultTextStyle])는 배율을 반영한 높이가 줄 높이를 넘지 않도록 줄어든다.
/// - LCD는 실물처럼 항상 왼쪽 → 오른쪽(LTR)으로 배치한다.
///
/// ## 줄 내용 계약 (M2 `MathNodeWidget` 연동)
/// - [input]/[result]는 **제약 없이**(가로·세로 무한) 자기 크기대로 그려진다. 그 뒤 줄 영역에 맞춰
///   입력은 왼쪽, 결과는 오른쪽, 세로는 가운데로 정렬하고, 줄 밖으로 나간 부분은 잘라낸다(축소하지 않음).
///   그래서 `Row`/`Column` 재귀 트리(2D 수식)가 줄보다 커도 넘침 오류 없이 실물 LCD처럼 잘려 보인다.
/// - 줄 크기는 [LcdLineScope.maybeOf]로 알 수 있다. 커서 따라가기 같은 가로 스크롤은 내용 위젯이
///   이 크기를 기준으로 스스로 처리한다. 스크롤 뷰를 쓰려면 이 크기의 `SizedBox`로 감싼다.
///   줄보다 세로로 큰 수식(분수·적분 등)을 축소할지, 줄 높이를 늘릴지는 M2에서 정한다.
/// - 가려진 쪽이 있으면 호출자가 [inputOverflow]/[resultOverflow]로 ◀/▶를 켠다.
///   ◀/▶ 자리는 항상 비워 두므로 켜고 꺼도 줄 폭이 같다. 자동 판정은 M2 스크롤 구현과 함께 정한다.
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
  }) : assert(
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
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : fallbackSize.width;
    final height = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : fallbackSize.height;

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
                          alignment: Alignment.centerLeft,
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
                          alignment: Alignment.centerRight,
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
    final requested = fontSize ?? base.fontSize!;
    final heightFactor = base.height ?? 1.0;
    // TextPainter는 문단 높이를 정수로 올림하므로 올림한 높이로 판정한다.
    bool fits(double size) =>
        (textScaler.scale(size) * heightFactor).ceilToDouble() <= lineHeight;
    if (fits(requested)) return base.copyWith(fontSize: requested);
    if (!fits(_minLineFontSize)) {
      return base.copyWith(fontSize: _minLineFontSize);
    }
    // 시스템 글자 배율이 비선형(안드로이드 14 이상)일 수 있으므로 비례 계산 대신 이분 탐색으로
    // 줄 높이에 들어가는 가장 큰 글자 크기를 찾는다. lo는 항상 줄 높이에 들어간다.
    var lo = _minLineFontSize;
    var hi = requested;
    for (var i = 0; i < 24; i++) {
      final mid = (lo + hi) / 2;
      if (fits(mid)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return base.copyWith(fontSize: lo);
  }

  /// 줄 글자 크기 하한 (dp) — 0 크기 글꼴을 피하기 위한 값. 이보다 낮은 줄은 잘린다.
  static const double _minLineFontSize = 1.0;
}

/// LCD 상단 상태 표시줄.
///
/// [LcdIndicatorSlot] 순서대로 고정 너비 슬롯을 배치한다. 폭이 남으면 슬롯 사이를 고르게 벌려
/// LCD 폭 전체에 분포시키고, 모자라면 줄 전체를 축소한다. 표시기가 꺼져도 슬롯은 남으므로
/// 다른 표시기의 위치가 바뀌지 않는다. 스크린리더에는 켜진 표시기만 읽힌다
/// (표시기별 의미 라벨은 TODO(#20)).
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
      label: status.activeIndicators.join(' '),
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

/// 입력 줄 또는 결과 줄 한 줄: `[◀] 내용 [▶]`.
class _LcdLine extends StatelessWidget {
  final Alignment alignment;
  final TextStyle style;
  final LcdLineOverflow overflow;
  final TextScaler textScaler;
  final Widget? child;

  const _LcdLine({
    super.key,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScrollArrow(
          symbol: '◀',
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
          symbol: '▶',
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
  /// 줄 내용 영역 크기 (◀/▶ 자리 제외)
  final Size size;

  const LcdLineScope({super.key, required this.size, required super.child});

  /// 가장 가까운 LCD 줄의 크기. LCD 줄 밖이면 `null`.
  static Size? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LcdLineScope>()?.size;

  @override
  bool updateShouldNotify(LcdLineScope oldWidget) => oldWidget.size != size;
}

/// 줄 양끝의 스크롤 표시(◀/▶). 꺼져도 자리를 유지해 내용 위치가 흔들리지 않는다.
class _ScrollArrow extends StatelessWidget {
  final String symbol;
  final bool visible;
  final TextStyle style;
  final TextScaler textScaler;

  const _ScrollArrow({
    required this.symbol,
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
                  symbol,
                  style: style.copyWith(color: CalcTheme.lcdText),
                  textScaler: textScaler,
                  maxLines: 1,
                  softWrap: false,
                  // TODO(#20): 스크린리더 라벨 다국어 처리
                  semanticsLabel: symbol == '◀'
                      ? '왼쪽에 내용 더 있음'
                      : '오른쪽에 내용 더 있음',
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
