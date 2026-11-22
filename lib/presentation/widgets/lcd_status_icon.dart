import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';
import '../../domain/models/lcd_status.dart';

/// LCD 상태 표시줄에서 글자 대신 직접 그리는 아이콘 (#57).
///
/// 글꼴 글자로는 실물 모양·크기가 맞지 않는 표시기(`→x`, `√▭✎`, `‖`)를 그린다.
/// - 세로 기준은 옆 슬롯 글자(`LcdStatusBar`가 `FittedBox` 가운데 정렬로 그림)와 같은 방식으로 정한다:
///   주변 기본 글자 스타일을 합친 [style]의 글자를 이 상자에 맞춰 줄이고 가운데 놓았을 때의 기준선과,
///   글꼴의 대문자·x높이([CalcTheme.lcdStatusCapHeightRatio]·[CalcTheme.lcdStatusXHeightRatio] —
///   상태 표시 글꼴 Noto Sans Mono SemiBold 전용 값)로 정한다([LcdStatusIconMetrics]).
/// - 잉크는 대문자 높이 띠(대문자 윗선 ~ 기준선) 안, 슬롯 폭 안에 그린다. 좌표를 그 안에서 계산하고,
///   클립은 반올림 오차에 대한 안전장치로만 둔다.
/// - `→x`의 x는 글꼴 글자 그대로 그린다(직접 그린 대각선은 곱셈 기호 ×처럼 읽힌다).
/// - 가로는 슬롯 칸([LcdIndicatorSlot.columns])마다 글자 한 칸(글리프 폭 + 자간)을 쓴다.
class LcdStatusIcon extends StatelessWidget {
  /// 그릴 아이콘
  final LcdIndicatorIcon icon;

  /// 선·면 색 (켜짐 [CalcTheme.lcdStatusActive] / 꺼짐 [CalcTheme.lcdStatusInactive])
  final Color color;

  /// 옆 슬롯 글자와 같은 스타일. 글자 크기가 없으면 [CalcTheme.lcdStatusStyle]의 크기를 쓴다.
  final TextStyle style;

  /// 시스템 글자 배율 (옆 슬롯 글자와 같게)
  final TextScaler textScaler;

  const LcdStatusIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.style,
    this.textScaler = TextScaler.noScaling,
  });

  @override
  Widget build(BuildContext context) {
    // 실제 Text처럼 주변 기본 글자 스타일을 합친다 — 앱에서는 줄 높이(height) 등이 상속된다.
    final merged = DefaultTextStyle.of(context).style.merge(style);
    final resolved = merged.fontSize != null
        ? merged
        : merged.copyWith(fontSize: CalcTheme.lcdStatusStyle.fontSize);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
        final metrics = LcdStatusIconMetrics.of(
          resolved,
          textScaler,
          size.height,
        );
        final drawing = CustomPaint(
          size: size,
          painter: _LcdStatusIconPainter(
            icon: icon,
            color: color,
            metrics: metrics,
          ),
        );
        if (icon != LcdIndicatorIcon.storeArrow) return drawing;
        // →x: 화살표는 직접 그리고, x는 글자 슬롯과 같은 방식으로 두 번째 칸에 글자로 그린다.
        return Stack(
          children: [
            Positioned.fill(child: drawing),
            Positioned(
              left: metrics.advance,
              top: 0,
              bottom: 0,
              width: metrics.advance,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'x',
                  style: style.copyWith(color: color),
                  textScaler: textScaler,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 상태 아이콘을 그릴 치수 (상자 왼쪽 위에서 잰 dp)
@immutable
class LcdStatusIconMetrics {
  /// 실제로 그려지는 글자 크기 (글자 배율·상자 맞춤 축소 반영)
  final double fontSize;

  /// 대문자 윗선
  final double capTop;

  /// x높이 윗선
  final double xTop;

  /// 기준선
  final double baseline;

  /// 글자 한 칸의 글리프 폭
  final double cell;

  /// 글자 한 칸의 진행 폭 (글리프 폭 + 자간) — 슬롯 폭은 칸 수 × 이 값이다
  final double advance;

  const LcdStatusIconMetrics({
    required this.fontSize,
    required this.capTop,
    required this.xTop,
    required this.baseline,
    required this.cell,
    required this.advance,
  });

  /// [style](주변 기본 스타일을 합친 것)·[textScaler]로 그린 한 줄 글자가 높이 [boxHeight] 상자에
  /// `FittedBox(scaleDown)`로 맞춰 줄고 세로 가운데 놓일 때의 치수.
  factory LcdStatusIconMetrics.of(
    TextStyle style,
    TextScaler textScaler,
    double boxHeight,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: 'S', style: style),
      textScaler: textScaler,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final shrink = painter.height > boxHeight
        ? boxHeight / painter.height
        : 1.0;
    final baseline =
        (boxHeight - painter.height * shrink) / 2 +
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic) *
            shrink;
    painter.dispose();
    final scaled = textScaler.scale(style.fontSize!);
    final fontSize = scaled * shrink;
    // 슬롯 폭 계산(LcdStatusBar)과 같은 한 칸 폭 — 상자 맞춤 축소와 무관하다.
    final glyph = scaled * CalcTheme.lcdStatusCharWidthRatio;
    final advance = math.max(0.0, glyph + (style.letterSpacing ?? 0));
    return LcdStatusIconMetrics(
      fontSize: fontSize,
      capTop: baseline - fontSize * CalcTheme.lcdStatusCapHeightRatio,
      xTop: baseline - fontSize * CalcTheme.lcdStatusXHeightRatio,
      baseline: baseline,
      cell: math.min(glyph, advance),
      advance: advance,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LcdStatusIconMetrics &&
      other.fontSize == fontSize &&
      other.capTop == capTop &&
      other.xTop == xTop &&
      other.baseline == baseline &&
      other.cell == cell &&
      other.advance == advance;

  @override
  int get hashCode =>
      Object.hash(fontSize, capTop, xTop, baseline, cell, advance);
}

class _LcdStatusIconPainter extends CustomPainter {
  final LcdIndicatorIcon icon;
  final Color color;
  final LcdStatusIconMetrics metrics;

  const _LcdStatusIconPainter({
    required this.icon,
    required this.color,
    required this.metrics,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final m = metrics;
    if (m.fontSize <= 0 || m.cell <= 0) return;
    double x(int column, double fraction) =>
        column * m.advance + fraction * m.cell;

    final sw = m.fontSize * CalcTheme.lcdStatusIconStrokeRatio;
    final half = sw / 2;
    final ct = m.capTop;
    final bl = m.baseline;
    final cap = bl - ct;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.save();
    // 좌표는 띠·슬롯 안에서 계산한다. 세로 띠 클립은 반올림 오차에 대한 안전장치이고, 가로는 클립하지
    // 않는다 — 슬롯 밖으로 나가는 좌표 실수를 테스트가 픽셀로 잡을 수 있게 한다.
    canvas.clipRect(Rect.fromLTRB(-size.width, ct, size.width * 2, bl));
    switch (icon) {
      case LcdIndicatorIcon.multiStatement:
        // ‖ — 대문자 높이의 세로 이중선
        canvas.drawPath(
          Path()
            ..moveTo(x(0, 0.3), ct)
            ..lineTo(x(0, 0.3), bl)
            ..moveTo(x(0, 0.7), ct)
            ..lineTo(x(0, 0.7), bl),
          stroke,
        );
      case LcdIndicatorIcon.storeArrow:
        // → — x높이 가운데의 화살표 (x는 위젯이 글자로 그린다)
        final mid = (m.xTop + bl) / 2;
        final tip = x(0, 0.94);
        final head = (bl - m.xTop) * 0.42;
        canvas.drawPath(
          Path()
            ..moveTo(x(0, 0.06), mid)
            ..lineTo(tip - half, mid)
            ..moveTo(tip - head, mid - head)
            ..lineTo(tip - half, mid)
            ..lineTo(tip - head, mid + head),
          stroke,
        );
      case LcdIndicatorIcon.mathInput:
        // √▭ — 근호의 윗선이 칸(▭)을 덮는다 (1~2칸)
        canvas.drawPath(
          Path()
            ..moveTo(x(0, 0.04), bl - cap * 0.42)
            ..lineTo(x(0, 0.22), bl - cap * 0.52)
            ..lineTo(x(0, 0.42), bl - half)
            ..lineTo(x(0, 0.72), ct + half)
            ..lineTo(x(1, 0.98), ct + half)
            ..addRect(
              Rect.fromLTRB(x(0, 0.92), ct + cap * 0.36, x(1, 0.8), bl - half),
            ),
          stroke,
        );
        _paintPencil(canvas, fill, ct, bl, x);
    }
    canvas.restore();
  }

  /// ✎ — 3칸째에 오른쪽 위에서 왼쪽 아래로 기운 연필 (몸통 + 뾰족한 촉).
  /// 몸통 윗변 꼭짓점이 대문자 윗선 아래·칸 오른쪽 안에 들도록 축 위쪽 끝을 안쪽으로 옮긴다.
  void _paintPencil(
    Canvas canvas,
    Paint fill,
    double ct,
    double bl,
    double Function(int, double) x,
  ) {
    final halfWidth = metrics.cell * 0.18;
    final right = x(2, 1.0);
    final point = Offset(x(2, 0.08), bl);
    var top = Offset(right, ct);
    var normal = Offset.zero;
    for (var i = 0; i < 3; i++) {
      final axis = point - top;
      final unit = axis / axis.distance;
      normal = Offset(-unit.dy, unit.dx);
      top = Offset(
        right - normal.dx.abs() * halfWidth,
        ct + normal.dy.abs() * halfWidth,
      );
    }
    final body = top + (point - top) * 0.66;
    final a = top + normal * halfWidth;
    final b = top - normal * halfWidth;
    final c = body - normal * halfWidth;
    final d = body + normal * halfWidth;
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..lineTo(point.dx, point.dy)
        ..lineTo(d.dx, d.dy)
        ..close(),
      fill,
    );
  }

  @override
  bool shouldRepaint(_LcdStatusIconPainter oldDelegate) =>
      oldDelegate.icon != icon ||
      oldDelegate.color != color ||
      oldDelegate.metrics != metrics;
}
