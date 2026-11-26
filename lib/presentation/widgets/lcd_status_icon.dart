import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';
import '../../domain/models/lcd_status.dart';

/// LCD 상태 표시줄에서 글자 대신 직접 그리는 아이콘 (#57).
///
/// 글꼴 글자로는 실물 모양·크기가 맞지 않는 표시기(`→x`, `√▭✎`, `‖`)를 그린다. 모양은 실물 사진·ClassWiz LCD
/// 스프라이트와 대조해 맞췄다(#160 — 근거는 `LcdIndicatorSlot` 문서).
/// - 치수([LcdStatusIconMetrics])는 옆 슬롯 글자(`LcdStatusBar`가 `FittedBox` 가운데 정렬로 그림)와 같은
///   방식으로 정한다 — 글자를 이 상자에 맞춰 줄이고 가운데 놓았을 때의 기준선, 그 축소율, 글꼴의
///   대문자·x높이([CalcTheme.lcdStatusCapHeightRatio]·[CalcTheme.lcdStatusXHeightRatio] — 상태 표시 글꼴
///   Noto Sans Mono SemiBold 전용 값). 글자가 줄면 아이콘도 가로·세로 같은 비율로 줄어 슬롯 가운데에 놓인다.
/// - 잉크는 대문자 높이 띠(대문자 윗선 ~ 기준선) 안, 슬롯 폭 안에 그린다. 좌표를 그 안에서 계산하고,
///   세로 띠 클립은 반올림 오차에 대한 안전장치로만 둔다(가로는 클립하지 않아 테스트가 픽셀로 검증한다).
/// - `→x`의 x는 글꼴 글자를 줄여 테두리 상자 안에 그린다(직접 그린 대각선은 곱셈 기호 ×처럼 읽힌다).
/// - 한계: 굵은 글씨 접근성 설정(`MediaQuery.boldText`)에서 옆 글자는 굵어지지만 직접 그린 획과 x는
///   그대로다(기준선·높이는 영향 없음). 고대비(#54)와 함께 다룬다.
///
/// 상태 표시줄 안에서는 `LcdStatusBar`가 치수를 한 번 계산해 [metrics]로 넘긴다. 단독으로 쓰면 이 위젯이
/// 자기 크기에서 계산한다(이때 [style]에 글자 크기가 없으면 [CalcTheme.lcdStatusStyle]의 크기를 쓰고,
/// 주변 기본 글자 스타일과 합친다).
class LcdStatusIcon extends StatelessWidget {
  /// 그릴 아이콘
  final LcdIndicatorIcon icon;

  /// 선·면·글자 색 (켜짐 [CalcTheme.lcdStatusActive] / 꺼짐 [CalcPalette.lcdStatusInactive] — 고대비 설정에 따라 다르다)
  final Color color;

  /// 옆 슬롯 글자와 같은 스타일 ([metrics]가 없을 때만 쓴다)
  final TextStyle style;

  /// 시스템 글자 배율 ([metrics]가 없을 때만 쓴다)
  final TextScaler textScaler;

  /// 미리 계산한 치수. `null`이면 자기 크기에서 계산한다.
  final LcdStatusIconMetrics? metrics;

  const LcdStatusIcon({
    super.key,
    required this.icon,
    required this.color,
    this.style = CalcTheme.lcdStatusStyle,
    this.textScaler = TextScaler.noScaling,
    this.metrics,
  });

  @override
  Widget build(BuildContext context) => _withMetrics(
    context,
    style,
    textScaler,
    metrics,
    (m) => _LcdStatusIconPainter(icon: icon, color: color, metrics: m),
  );
}

/// 반전 상자 글자 — 어두운 상자 안에 글자를 밝게 그린다 (#160, 실물 S·A·D·R·G).
///
/// 상자는 슬롯 한 칸의 글리프 폭 × 대문자 높이 띠(옆 글자와 같은 높이)다. 글자는 상자 높이의
/// [CalcTheme.lcdStatusBoxedLetterRatio]로 줄여 가운데에 놓고, 그 모양대로 상자를 비운다. 그러면 배경이
/// 비쳐 보이므로 LCD 배경색을 몰라도 되고, 고대비 색에서도 같다. 꺼진 상태도 같은 모양을 꺼진 색으로 그린다.
///
/// 치수·단독 사용 규칙은 [LcdStatusIcon]과 같다.
class LcdStatusBoxedLetter extends StatelessWidget {
  /// 상자 안 글자 (한 글자)
  final String letter;

  /// 상자 색 (켜짐 [CalcTheme.lcdStatusActive] / 꺼짐 [CalcPalette.lcdStatusInactive])
  final Color color;

  /// 옆 슬롯 글자와 같은 스타일 ([metrics]가 없을 때만 쓴다)
  final TextStyle style;

  /// 시스템 글자 배율 ([metrics]가 없을 때만 쓴다)
  final TextScaler textScaler;

  /// 미리 계산한 치수. `null`이면 자기 크기에서 계산한다.
  final LcdStatusIconMetrics? metrics;

  const LcdStatusBoxedLetter({
    super.key,
    required this.letter,
    required this.color,
    this.style = CalcTheme.lcdStatusStyle,
    this.textScaler = TextScaler.noScaling,
    this.metrics,
  });

  @override
  Widget build(BuildContext context) => _withMetrics(
    context,
    style,
    textScaler,
    metrics,
    (m) => _BoxedLetterPainter(letter: letter, color: color, metrics: m),
  );
}

/// [metrics]가 있으면 그대로, 없으면 자기 크기·[style]에서 치수를 계산해 [painter]로 그린다.
Widget _withMetrics(
  BuildContext context,
  TextStyle style,
  TextScaler textScaler,
  LcdStatusIconMetrics? metrics,
  CustomPainter Function(LcdStatusIconMetrics) painter,
) {
  Widget paint(LcdStatusIconMetrics m) =>
      CustomPaint(painter: painter(m), child: const SizedBox.expand());
  if (metrics != null) return paint(metrics);
  final sized = style.fontSize != null
      ? style
      : style.copyWith(fontSize: CalcTheme.lcdStatusStyle.fontSize);
  final resolved = DefaultTextStyle.of(context).style.merge(sized);
  return LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
      return paint(LcdStatusIconMetrics.of(resolved, textScaler, size.height));
    },
  );
}

/// 상태 아이콘을 그릴 치수 (상자 왼쪽 위에서 잰 dp)
@immutable
class LcdStatusIconMetrics {
  /// 글자 스타일 (주변 기본 글자 스타일을 합친 것) — `→x`의 x를 이 스타일로 그린다
  final TextStyle style;

  /// 시스템 글자 배율
  final TextScaler textScaler;

  /// 글자가 상자 높이에 맞춰 줄어든 비율 (`FittedBox(scaleDown)`, 1 이하)
  final double shrink;

  /// 실제로 그려지는 글자 크기 (글자 배율·[shrink] 반영)
  final double fontSize;

  /// 대문자 윗선
  final double capTop;

  /// x높이 윗선
  final double xTop;

  /// 기준선
  final double baseline;

  /// 글자 한 칸의 글리프 폭 ([shrink] 반영 전)
  final double cell;

  /// 글자 한 칸의 진행 폭 (글리프 폭 + 자간, [shrink] 반영 전) — 슬롯 폭은 칸 수 × 이 값이다
  final double advance;

  const LcdStatusIconMetrics({
    required this.style,
    required this.textScaler,
    required this.shrink,
    required this.fontSize,
    required this.capTop,
    required this.xTop,
    required this.baseline,
    required this.cell,
    required this.advance,
  });

  /// [style](주변 기본 스타일을 합친 것, 글자 크기 필수)·[textScaler]로 그린 한 줄 글자가 높이
  /// [boxHeight] 상자에 `FittedBox(scaleDown)`로 맞춰 줄고 세로 가운데 놓일 때의 치수.
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
    // 슬롯 폭 계산(LcdStatusBar)과 같은 한 칸 폭
    final glyph = scaled * CalcTheme.lcdStatusCharWidthRatio;
    final advance = math.max(0.0, glyph + (style.letterSpacing ?? 0));
    return LcdStatusIconMetrics(
      style: style,
      textScaler: textScaler,
      shrink: shrink,
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
      other.style == style &&
      other.textScaler == textScaler &&
      other.shrink == shrink &&
      other.fontSize == fontSize &&
      other.capTop == capTop &&
      other.xTop == xTop &&
      other.baseline == baseline &&
      other.cell == cell &&
      other.advance == advance;

  @override
  int get hashCode => Object.hash(
    style,
    textScaler,
    shrink,
    fontSize,
    capTop,
    xTop,
    baseline,
    cell,
    advance,
  );
}

/// 슬롯 안 좌표: 글자가 줄면 아이콘도 같은 비율로 줄여 슬롯 가운데에 놓는다 (옆 글자의 FittedBox와 같게).
/// `column`째 칸의 글리프 폭 안 비율 `fraction` 위치의 x.
double Function(int column, double fraction) _columnX(
  LcdStatusIconMetrics m,
  Size size,
) {
  final left = size.width * (1 - m.shrink) / 2;
  return (column, fraction) =>
      left + (column * m.advance + fraction * m.cell) * m.shrink;
}

/// 상자 안 글자 — [text]를 상자 높이의 [CalcTheme.lcdStatusBoxedLetterRatio] 크기로, 잉크가 [box] 가운데에
/// 오도록 그린다. [inkHeightRatio]는 글자 크기 대비 잉크 높이(대문자 높이 또는 x높이)다.
void _paintBoxedGlyph(
  Canvas canvas,
  LcdStatusIconMetrics m,
  Rect box,
  String text,
  double inkHeightRatio,
  Paint foreground,
) {
  // 글자의 대문자 높이 = 상자 높이(대문자 높이 띠) × 비율
  final fontSize = m.fontSize * CalcTheme.lcdStatusBoxedLetterRatio;
  final base = m.style;
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: base.fontFamily,
        fontFamilyFallback: base.fontFamilyFallback,
        fontWeight: base.fontWeight,
        fontStyle: base.fontStyle,
        fontSize: fontSize,
        height: 1,
        foreground: foreground,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final ascent = painter.computeDistanceToActualBaseline(
    TextBaseline.alphabetic,
  );
  final baseline = box.center.dy + fontSize * inkHeightRatio / 2;
  painter.paint(
    canvas,
    Offset(box.center.dx - painter.width / 2, baseline - ascent),
  );
  painter.dispose();
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
    final x = _columnX(m, size);

    final sw = m.fontSize * CalcTheme.lcdStatusIconStrokeRatio;
    final half = sw / 2;
    final ct = m.capTop;
    final bl = m.baseline;
    final cap = bl - ct;

    Paint stroke(StrokeJoin join) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = join
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
        // ‖ — 어두운 상자(한 칸 × 대문자 높이)에 밝은 세로 두 획을 비운다. 획은 위아래 1/7씩 띄운다
        // (실물 7도트 상자의 둘째·넷째 도트 열 — 스프라이트).
        final inset = cap / 7;
        Rect bar(double fraction) => Rect.fromLTRB(
          x(0, fraction) - half,
          ct + inset,
          x(0, fraction) + half,
          bl - inset,
        );
        canvas.drawPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addRect(Rect.fromLTRB(x(0, 0), ct, x(0, 1), bl))
            ..addRect(bar(0.33))
            ..addRect(bar(0.67)),
          fill,
        );
      case LcdIndicatorIcon.storeArrow:
        // → — 대문자 높이 가운데에서 둘째 칸의 상자를 가리키는 화살표
        final mid = (ct + bl) / 2;
        final tip = x(0, 0.94);
        final head = cap * 0.32;
        canvas.drawPath(
          Path()
            ..moveTo(x(0, 0.06), mid)
            ..lineTo(tip - half, mid)
            ..moveTo(tip - head, mid - head)
            ..lineTo(tip - half, mid)
            ..lineTo(tip - head, mid + head),
          stroke(StrokeJoin.round),
        );
        // 둘째 칸: 테두리 상자 안의 x (스프라이트에서 x가 상자 안에 있다)
        final box = Rect.fromLTRB(x(1, 0), ct, x(1, 1), bl);
        canvas.drawRect(box.deflate(half), stroke(StrokeJoin.miter));
        _paintBoxedGlyph(
          canvas,
          m,
          box,
          'x',
          CalcTheme.lcdStatusXHeightRatio,
          Paint()..color = color,
        );
      case LcdIndicatorIcon.mathInput:
        // √▭ — 근호의 오른쪽 획이 대문자 윗선까지 오르고, 그 윗선이 그대로 칸(▭)의 윗변이 된다.
        // 칸은 대문자 높이 전체다(실물 사진: 근호와 칸의 높이가 같다). 근호 왼쪽 획은 짧은 꺾임 없이
        // 대문자 높이의 55%에서 시작한다. 가로 비율(근호 : 틈 : 칸 : 연필 ≈ 0.9 : 0.3 : 0.8 : 1칸)도 사진에서 쟀다.
        final boxLeft = x(1, 0.2);
        final boxRight = x(1, 0.98);
        canvas.drawPath(
          Path()
            // 시작점은 슬롯 왼쪽 끝에서 선 굵기 절반만큼 안쪽 — 대각선 획의 모서리가 슬롯 밖으로 나가지 않게.
            ..moveTo(x(0, 0) + half, bl - cap * 0.55)
            ..lineTo(x(0, 0.42), bl - half)
            ..lineTo(x(0, 0.88), ct + half)
            ..lineTo(boxRight - half, ct + half)
            ..lineTo(boxRight - half, bl - half)
            ..lineTo(boxLeft, bl - half)
            ..lineTo(boxLeft, ct + half),
          stroke(StrokeJoin.miter),
        );
        _paintPencil(canvas, fill, ct, bl, x);
    }
    canvas.restore();
  }

  /// ✎ — 3칸째에서 촉을 칸 오른쪽 변 옆(대문자 높이의 아래 30%)에 두고 오른쪽 위로 뻗은 연필 (몸통 + 뾰족한 촉).
  /// 실물 사진에서 연필은 기준선까지 내려오지 않고, 칸 오른쪽 변의 아래 1/3쯤에 촉이 닿는다.
  /// 몸통 윗변 꼭짓점이 대문자 윗선 아래·칸 오른쪽 안에 들도록 축 위쪽 끝을 안쪽으로 옮긴다.
  void _paintPencil(
    Canvas canvas,
    Paint fill,
    double ct,
    double bl,
    double Function(int, double) x,
  ) {
    final halfWidth = metrics.cell * metrics.shrink * 0.18;
    final right = x(2, 1.0);
    final point = Offset(x(2, 0.04), bl - (bl - ct) * 0.3);
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

class _BoxedLetterPainter extends CustomPainter {
  final String letter;
  final Color color;
  final LcdStatusIconMetrics metrics;

  const _BoxedLetterPainter({
    required this.letter,
    required this.color,
    required this.metrics,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final m = metrics;
    if (m.fontSize <= 0 || m.cell <= 0) return;
    final x = _columnX(m, size);
    final box = Rect.fromLTRB(x(0, 0), m.capTop, x(0, 1), m.baseline);
    // 아이콘과 같이 대문자 높이 띠로 자른다(반올림 오차에 대한 안전장치 — 옆 글자와 아랫변이 맞는다).
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(-size.width, m.capTop, size.width * 2, m.baseline),
    );
    // 상자를 칠한 레이어에서 글자 모양을 지워(dstOut) 배경이 비치게 한다.
    canvas.saveLayer(box.inflate(1), Paint());
    canvas.drawRect(box, Paint()..color = color);
    _paintBoxedGlyph(
      canvas,
      m,
      box,
      letter,
      CalcTheme.lcdStatusCapHeightRatio,
      Paint()..blendMode = BlendMode.dstOut,
    );
    canvas
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(_BoxedLetterPainter oldDelegate) =>
      oldDelegate.letter != letter ||
      oldDelegate.color != color ||
      oldDelegate.metrics != metrics;
}
