import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';
import '../../domain/models/lcd_status.dart';

/// fx-991EX ClassWiz 스타일의 도트 매트릭스 LCD.
///
/// 구성 (위 → 아래):
/// ```
///  ╔══════════════════════════════╗  ← 은색 베젤 (CalcTheme.lcdFrame)
///  ║ S A M STO D FIX E Math ∠ Disp║  ← 상태 표시줄 (고정 슬롯, 꺼진 표시기는 흐리게)
///  ║◀ 2+3×                       ▶║  ← 입력 줄 (왼쪽 정렬, 넘치면 잘림 + ◀/▶)
///  ║                            5 ║  ← 결과 줄 (오른쪽 정렬)
///  ╚══════════════════════════════╝
/// ```
///
/// ## 크기 계약
/// - 크기는 부모가 정한다. 제약이 무한한 축에만 [fallbackSize]의 해당 축 값을 쓴다.
///   LCD : 키패드 비율과 LCD 글자 크기 산정은 #23에서 정의하며, 부모가 [statusFontSize]를 주입한다.
/// - 상태 표시줄 높이는 상태 글자 크기 × [CalcTheme.lcdStatusBarHeightRatio]이고,
///   남은 높이를 입력 줄과 결과 줄이 [CalcTheme.lcdInputLineFlex] : [CalcTheme.lcdResultLineFlex]로 나눈다.
/// - 상태 표시줄은 폭이 모자라면 통째로 축소되어 넘치지 않는다.
/// - 입력·결과 줄의 내용([input]/[result])은 **축소하지 않고 잘라낸다** (실물처럼 스크롤로 보여주는 방식).
///   가려진 쪽이 있으면 호출자가 [inputOverflow]/[resultOverflow]로 ◀/▶를 켠다.
///   줄 높이보다 큰 내용도 잘리므로, 2D 수식의 글자 크기는 렌더러(M2 `MathNodeWidget`)가 줄 높이에 맞춘다.
/// - 일반 [Text]를 넘기면 입력 줄은 [CalcTheme.lcdInputStyle], 결과 줄은 [CalcTheme.lcdResultStyle]이 적용된다.
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
    this.showInactiveIndicators = true,
    this.showDotMatrix = true,
  }) : assert(
         statusFontSize == null || statusFontSize > 0,
         'statusFontSize는 양수여야 한다',
       );

  @override
  Widget build(BuildContext context) {
    final fontSize = statusFontSize ?? CalcTheme.lcdStatusStyle.fontSize!;
    final textScaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: CalcTheme.lcdMaxTextScaleFactor);
    final statusStyle = CalcTheme.lcdStatusStyle.copyWith(fontSize: fontSize);
    // 상태 표시줄 높이는 배율을 반영한 글자 크기를 기준으로 한다.
    final preferredStatusBarHeight =
        textScaler.scale(fontSize) * CalcTheme.lcdStatusBarHeightRatio;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : fallbackSize.width;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : fallbackSize.height;
        // LCD가 아주 낮아도 Column이 넘치지 않도록 상태 표시줄을 안쪽 높이 이내로 제한한다.
        const chrome =
            2 * (CalcTheme.lcdFrameWidth + CalcTheme.lcdInnerPadding);
        final innerHeight = (height - chrome).clamp(0.0, double.infinity);
        final statusBarHeight = preferredStatusBarHeight.clamp(
          0.0,
          innerHeight,
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
                              style: statusStyle,
                              textScaler: textScaler,
                              showInactive: showInactiveIndicators,
                            ),
                          ),
                          Expanded(
                            flex: CalcTheme.lcdInputLineFlex,
                            child: _LcdLine(
                              key: const ValueKey('lcd-input-line'),
                              alignment: Alignment.centerLeft,
                              style: CalcTheme.lcdInputStyle,
                              overflow: inputOverflow,
                              indicatorStyle: statusStyle,
                              textScaler: textScaler,
                              child: input,
                            ),
                          ),
                          Expanded(
                            flex: CalcTheme.lcdResultLineFlex,
                            child: _LcdLine(
                              key: const ValueKey('lcd-result-line'),
                              alignment: Alignment.centerRight,
                              style: CalcTheme.lcdResultStyle,
                              overflow: resultOverflow,
                              indicatorStyle: statusStyle,
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
      },
    );
  }
}

/// LCD 상단 상태 표시줄.
///
/// [LcdIndicatorSlot] 순서대로 고정 너비 슬롯을 배치한다. 표시기가 꺼져도 슬롯은 남으므로
/// 다른 표시기의 위치가 바뀌지 않는다. 스크린리더에는 켜진 표시기만 읽힌다.
class LcdStatusBar extends StatelessWidget {
  /// 표시할 상태
  final LcdStatus status;

  /// 표시 글자 스타일 (색은 켜짐/꺼짐에 따라 덮어쓴다)
  final TextStyle style;

  /// 시스템 글자 배율 (상한 적용된 값)
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
    final fontSize = textScaler.scale(style.fontSize!);
    final gap = fontSize * CalcTheme.lcdStatusSlotGapRatio;
    final active = status.activeIndicators;

    return Semantics(
      label: active.join(' '),
      excludeSemantics: true,
      child: FittedBox(
        // 좁은 화면이나 큰 글자 배율에서도 넘치지 않도록 줄 전체를 축소한다.
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, slot) in LcdIndicatorSlot.values.indexed) ...[
              if (i > 0) SizedBox(width: gap),
              _IndicatorSlot(
                key: ValueKey(slot),
                slot: slot,
                label: status.indicatorFor(slot),
                style: style,
                textScaler: textScaler,
                showInactive: showInactive,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 상태 표시줄의 고정 너비 슬롯 하나.
class _IndicatorSlot extends StatelessWidget {
  final LcdIndicatorSlot slot;

  /// 켜진 표시 문자 (`null`이면 꺼짐)
  final String? label;
  final TextStyle style;
  final TextScaler textScaler;
  final bool showInactive;

  const _IndicatorSlot({
    super.key,
    required this.slot,
    required this.label,
    required this.style,
    required this.textScaler,
    required this.showInactive,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = textScaler.scale(style.fontSize!);
    final width =
        fontSize * CalcTheme.lcdStatusCharWidthRatio * slot.template.length;
    final isOn = label != null;
    final text = label ?? (showInactive ? slot.template : null);

    return SizedBox(
      width: width,
      height: fontSize * CalcTheme.lcdStatusBarHeightRatio,
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
  final TextStyle indicatorStyle;
  final TextScaler textScaler;
  final Widget? child;

  const _LcdLine({
    super.key,
    required this.alignment,
    required this.style,
    required this.overflow,
    required this.indicatorStyle,
    required this.textScaler,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScrollArrow(
          symbol: '◀',
          visible: overflow.left,
          style: indicatorStyle,
          textScaler: textScaler,
        ),
        Expanded(
          child: DefaultTextStyle(
            style: style,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            // 내용은 축소하지 않고 줄 영역 밖을 잘라낸다 (넘침 경고 없이).
            child: UnconstrainedBox(
              alignment: alignment,
              constrainedAxis: Axis.vertical,
              clipBehavior: Clip.hardEdge,
              // 세로는 줄 높이 안에서 가운데 정렬 (내용이 줄 높이를 강제로 받지 않도록 느슨하게 푼다).
              child: Center(child: child),
            ),
          ),
        ),
        _ScrollArrow(
          symbol: '▶',
          visible: overflow.right,
          style: indicatorStyle,
          textScaler: textScaler,
        ),
      ],
    );
  }
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
        textScaler.scale(style.fontSize!) * CalcTheme.lcdStatusCharWidthRatio;
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
