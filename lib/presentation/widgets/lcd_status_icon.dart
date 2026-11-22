import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';
import '../../domain/models/lcd_status.dart';

/// LCD 상태 표시줄에서 글자 대신 직접 그리는 아이콘 (#57).
///
/// 글꼴 글자로는 실물 모양·크기가 맞지 않는 표시기(`→x`, `√▭✎`, `‖`)를 그린다. 세로 기준은 같은
/// [style]·[textScaler]의 글자를 이 상자에 세로 가운데로 배치했을 때의 기준선과, 글꼴의 대문자·x높이
/// ([CalcTheme.lcdStatusCapHeightRatio]·[CalcTheme.lcdStatusXHeightRatio])로 정한다 — 옆 슬롯의 글자
/// (`LcdStatusBar`가 `FittedBox` 가운데 정렬로 그림)와 기준선·대문자 높이가 같다. 잉크는 대문자 높이
/// 띠(대문자 윗선 ~ 기준선) 밖으로 나가지 않는다(테스트가 실제 글자와 픽셀로 대조).
///
/// 가로는 슬롯 칸([LcdIndicatorSlot.columns])마다 글자 한 칸(글리프 폭 + 자간)을 쓴다.
class LcdStatusIcon extends StatelessWidget {
  /// 그릴 아이콘
  final LcdIndicatorIcon icon;

  /// 선·면 색 (켜짐 [CalcTheme.lcdStatusActive] / 꺼짐 [CalcTheme.lcdStatusInactive])
  final Color color;

  /// 옆 슬롯 글자와 같은 스타일 (글자 크기·자간·글꼴)
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
    return CustomPaint(
      painter: _LcdStatusIconPainter(
        icon: icon,
        color: color,
        style: style,
        textScaler: textScaler,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// 상태 표시 글자의 세로 기준 (상자 위쪽에서 잰 dp)
@immutable
class LcdStatusGlyphBand {
  /// 대문자 윗선
  final double capTop;

  /// x높이 윗선
  final double xTop;

  /// 기준선
  final double baseline;

  const LcdStatusGlyphBand({
    required this.capTop,
    required this.xTop,
    required this.baseline,
  });

  /// [style]·[textScaler]로 그린 한 줄 글자가 높이 [boxHeight] 상자에 세로 가운데로 놓일 때의 기준.
  factory LcdStatusGlyphBand.of(
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
    final fontSize = textScaler.scale(style.fontSize!);
    final baseline =
        (boxHeight - painter.height) / 2 +
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    painter.dispose();
    return LcdStatusGlyphBand(
      capTop: baseline - fontSize * CalcTheme.lcdStatusCapHeightRatio,
      xTop: baseline - fontSize * CalcTheme.lcdStatusXHeightRatio,
      baseline: baseline,
    );
  }
}

class _LcdStatusIconPainter extends CustomPainter {
  final LcdIndicatorIcon icon;
  final Color color;
  final TextStyle style;
  final TextScaler textScaler;

  const _LcdStatusIconPainter({
    required this.icon,
    required this.color,
    required this.style,
    required this.textScaler,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fontSize = textScaler.scale(style.fontSize!);
    if (fontSize <= 0 || size.isEmpty) return;
    final band = LcdStatusGlyphBand.of(style, textScaler, size.height);
    // 글자 한 칸: 글리프 폭 + 자간 (LcdStatusBar의 슬롯 폭 계산과 같다)
    final glyph = fontSize * CalcTheme.lcdStatusCharWidthRatio;
    final advance = math.max(0.0, glyph + (style.letterSpacing ?? 0));
    final cell = math.min(glyph, advance);
    double x(int column, double fraction) => column * advance + fraction * cell;

    final sw = fontSize * CalcTheme.lcdStatusIconStrokeRatio;
    final half = sw / 2;
    final ct = band.capTop;
    final bl = band.baseline;
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
    // 잉크는 대문자 높이 띠 안에만 둔다 (글자와 같은 높이 — 기준선 아래로 내려가지 않는다).
    canvas.clipRect(Rect.fromLTRB(0, ct, size.width, bl));
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
        // → (x높이 가운데) + x (x높이 띠를 채우는 두 대각선)
        final xt = band.xTop;
        final mid = (xt + bl) / 2;
        final tip = x(0, 0.92);
        final head = (bl - xt) * 0.42;
        // 대각선 끝(butt)의 모서리는 세로로 반폭 × (방향의 가로 성분)만큼 나간다 — 그만큼만 들여
        // x의 잉크가 x높이 윗선과 기준선에 정확히 닿게 한다.
        final dx = x(1, 0.88) - x(1, 0.12);
        final inset = half * dx / Offset(dx, bl - xt).distance;
        canvas.drawPath(
          Path()
            ..moveTo(x(0, 0.06), mid)
            ..lineTo(tip - half, mid)
            ..moveTo(tip - head, mid - head)
            ..lineTo(tip - half, mid)
            ..lineTo(tip - head, mid + head)
            ..moveTo(x(1, 0.12), xt + inset)
            ..lineTo(x(1, 0.88), bl - inset)
            ..moveTo(x(1, 0.88), xt + inset)
            ..lineTo(x(1, 0.12), bl - inset),
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
        // ✎ — 오른쪽 위에서 왼쪽 아래로 기운 연필 (3칸째): 몸통 + 뾰족한 촉
        final top = Offset(x(2, 0.92), ct);
        final point = Offset(x(2, 0.12), bl);
        final axis = point - top;
        final unit = axis / axis.distance;
        final normal = Offset(-unit.dy, unit.dx);
        final width = cell * 0.36;
        final body = top + axis * 0.66;
        final a = top + normal * (width / 2);
        final b = top - normal * (width / 2);
        final c = body - normal * (width / 2);
        final d = body + normal * (width / 2);
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
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LcdStatusIconPainter oldDelegate) =>
      oldDelegate.icon != icon ||
      oldDelegate.color != color ||
      oldDelegate.style != style ||
      oldDelegate.textScaler != textScaler;
}
