import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';
import '../../domain/models/lcd_status.dart';

/// LCD 상태 표시줄에서 글자 대신 직접 그리는 아이콘 (#57).
///
/// 글꼴 글자로는 실물 모양·크기가 맞지 않는 표시기(`→x`, `√▭✎`, `‖`)를 그린다. 모양은 실물 사진·ClassWiz LCD
/// 스프라이트와 대조하고, User's Guide 표시기 표의 아이콘 구조를 따랐다(#160 — 근거는 `LcdIndicatorSlot` 문서).
/// - 치수([LcdStatusIconMetrics])는 옆 슬롯 글자(`LcdStatusBar`가 `FittedBox` 가운데 정렬로 그림)와 같은
///   방식으로 정한다 — 글자를 이 상자에 맞춰 줄이고 가운데 놓았을 때의 기준선, 그 축소율, 글꼴의
///   대문자·x높이([CalcTheme.lcdStatusCapHeightRatio]·[CalcTheme.lcdStatusXHeightRatio] — 상태 표시 글꼴
///   Noto Sans Mono SemiBold 전용 값). 글자가 줄면 아이콘도 가로·세로 같은 비율로 줄어 슬롯 가운데에 놓인다.
/// - 잉크는 대문자 높이 띠(대문자 윗선 ~ 기준선) 안, 슬롯 폭 안에 그린다. 좌표를 그 안에서 계산하고,
///   세로 띠 클립은 반올림 오차에 대한 안전장치로만 둔다(가로는 클립하지 않아 테스트가 픽셀로 검증한다).
/// - `→x`의 x는 글꼴 글자를 줄여 상자 안에 그린다(직접 그린 대각선은 곱셈 기호 ×처럼 읽힌다).
/// - 굵은 글씨 접근성 설정(`MediaQuery.boldText`): 반전 상자 글자(S·A·D·R·G)는 늘 굵게(w700) 그려 설정과 같다.
///   한계: 직접 그린 획과 `→x`의 x는 그대로다 — x를 굵게 그리면 작은 크기에서 팔이 테두리에 붙는다(#160 리뷰 R2).
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
/// 상자는 슬롯 한 칸의 글리프 폭 × 대문자 높이 띠(옆 글자와 같은 높이)다. 글자는 굵게(w700), 상자 높이의
/// [CalcTheme.lcdStatusBoxedLetterRatio]로 줄여 가운데에 놓고, 그 모양대로 상자를 비운다. 그러면 배경이
/// 비쳐 보이므로 LCD 배경색을 몰라도 되고, 고대비 색에서도 같다. 꺼진 상태도 같은 모양을 꺼진 색으로 그린다.
/// 꺼진 상자는 면이라 글자 획보다 넓게 보인다(고대비 15%에서 특히). 꺼진 표시기를 흐리게 보이는 것은 앱의 선택이고(#44),
/// 켜짐(100%)과의 구별은 충분하다.
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

/// 상자 안 글자 — [text]를 옆 글자 크기의 [sizeRatio]배로, 잉크가 [box] 가운데에 오도록 그린다.
/// [inkHeightRatio]는 글자 크기 대비 잉크 높이(대문자 높이 또는 x높이)다. [bold]면 굵게(w700) 그린다.
void _paintBoxedGlyph(
  Canvas canvas,
  LcdStatusIconMetrics m,
  Rect box,
  String text,
  double sizeRatio,
  double inkHeightRatio,
  Paint foreground, {
  required bool bold,
}) {
  final fontSize = m.fontSize * sizeRatio;
  final base = m.style;
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: base.fontFamily,
        fontFamilyFallback: base.fontFamilyFallback,
        fontWeight: bold ? FontWeight.bold : base.fontWeight,
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
        // ‖ — 어두운 상자(한 칸 × 대문자 높이)에 밝은 세로 두 획을 비운다. 획은 칸의 37%·63%에 두고
        // 위아래를 1/7씩 띄운다(가이드 표시기 표·스프라이트).
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
            ..addRect(bar(0.37))
            ..addRect(bar(0.63)),
          fill,
        );
      case LcdIndicatorIcon.storeArrow:
        // ➔ — 대문자 높이 가운데의 굵은 화살표(몸통 + 삼각형 머리)가 x 상자의 왼쪽 열린 곳으로 들어간다.
        // 가이드 실측(대문자 높이 대비): 몸통 굵기 0.26, 머리 높이 0.53·길이 0.27, 열린 곳 0.59 — 머리가 열린 곳보다
        // 작아 그 안으로 들어간다.
        // 가로(#183): 잉크 전체는 [CalcTheme.lcdStatusStoreInkCells]칸(상자 한 칸 + 화살표)이고 그리는 상자(슬롯)
        // 가운데에 놓는다 — 실물 잉크 가운데가 세그먼트 가운데([LcdIndicatorSlot.dotCenter])다. 머리
        // ([CalcTheme.lcdStatusStoreHeadCells]) 끝은 상자 안 [CalcTheme.lcdStatusStoreTipDepthCells]칸까지 들어가고,
        // 나머지(1.5칸이면 0.3칸)가 몸통이다.
        // 칸 폭 단위 좌표: 그리는 상자의 가로 가운데를 [x]의 칸 폭 단위로 바꾼다(슬롯 폭 = 2 × 진행 폭이면 진행 폭 ÷ 칸 폭).
        final center = (size.width / 2 - x(0, 0)) / (m.cell * m.shrink);
        const inkCells = CalcTheme.lcdStatusStoreInkCells;
        final boxLeft = center + inkCells / 2 - 1;
        final mid = (ct + bl) / 2;
        final shaft = cap * 0.13;
        final head = cap * 0.265;
        final start = x(0, center - inkCells / 2);
        final tip = x(0, boxLeft + CalcTheme.lcdStatusStoreTipDepthCells);
        final neck = x(
          0,
          boxLeft +
              CalcTheme.lcdStatusStoreTipDepthCells -
              CalcTheme.lcdStatusStoreHeadCells,
        );
        canvas.drawPath(
          Path()
            ..moveTo(start, mid - shaft)
            ..lineTo(neck, mid - shaft)
            ..lineTo(neck, mid - head)
            ..lineTo(tip, mid)
            ..lineTo(neck, mid + head)
            ..lineTo(neck, mid + shaft)
            ..lineTo(start, mid + shaft)
            ..close(),
          fill,
        );
        // 왼쪽 변 가운데가 열린 상자(위아래 짧은 변만 남는다, 한 칸 폭) 안의 x
        final box = Rect.fromLTRB(x(0, boxLeft), ct, x(0, boxLeft + 1), bl);
        final inner = box.deflate(half);
        // 위아래 짧은 변: 바깥 테두리에서 대문자 높이의 0.2 (선 중심 기준으로 반 획 뺀다)
        final stub = cap * 0.2 - half;
        canvas.drawPath(
          Path()
            ..moveTo(inner.left, inner.top + stub)
            ..lineTo(inner.left, inner.top)
            ..lineTo(inner.right, inner.top)
            ..lineTo(inner.right, inner.bottom)
            ..lineTo(inner.left, inner.bottom)
            ..lineTo(inner.left, inner.bottom - stub),
          stroke(StrokeJoin.miter),
        );
        _paintBoxedGlyph(
          canvas,
          m,
          box,
          'x',
          CalcTheme.lcdStatusStoreXRatio,
          CalcTheme.lcdStatusXHeightRatio,
          Paint()..color = color,
          // 굵은 글씨 설정을 따르지 않는다 — 굵게 그리면 작은 크기에서 x 팔이 테두리에 붙는다(#160 리뷰 R2).
          bold: false,
        );
      case LcdIndicatorIcon.mathInput:
        // √▭ — 근호 오른쪽 획이 대문자 윗선까지 오르고 윗선이 칸 위를 덮는다. 칸은 윗선 아래에 띄워 매달린
        // "⊏" 모양(위·왼쪽·아래 변, 오른쪽은 위에 짧은 변만 남기고 열림)이고, 연필 촉이 열린 곳으로 들어간다.
        // 가이드 표시기 표의 아이콘 구조를 따랐다(실물 사진의 "√E✎"처럼 보이는 모양과도 맞다).
        // 근호 왼쪽 획은 짧은 꺾임 없이 대문자 높이의 절반쯤에서 시작한다. 윗선 끝과 칸 오른쪽 끝은 같은 x다(가이드).
        final boxLeft = x(1, 0.1);
        final boxRight = x(1, 0.9);
        final boxTop = ct + cap * 0.3;
        canvas
          ..drawPath(
            Path()
              // 시작점은 슬롯 왼쪽 끝에서 선 굵기 절반만큼 안쪽 — 대각선 획의 모서리가 슬롯 밖으로 나가지 않게.
              ..moveTo(x(0, 0) + half, bl - cap * 0.52)
              ..lineTo(x(0, 0.4), bl - half)
              ..lineTo(x(0, 0.85), ct + half)
              ..lineTo(boxRight, ct + half),
            // 뾰족한 V 꼭짓점은 miter 비율(약 2.2)이 한계 1.5를 넘어 잘린 모서리(bevel)로 그려진다 — 기준선 아래로
            // 나가 띠 클립에 잘리지 않는다. 윗선 모서리(둔각)는 한계 안이라 각진 채로 남는다(#160 리뷰 R1·R2).
            stroke(StrokeJoin.miter)..strokeMiterLimit = 1.5,
          )
          ..drawPath(
            Path()
              // 오른쪽 위 짧은 변: 바깥 윗변에서 대문자 높이의 0.21까지 (연필과 떨어지도록 가이드의 0.2쯤)
              ..moveTo(boxRight - half, boxTop + cap * 0.21)
              ..lineTo(boxRight - half, boxTop + half)
              ..lineTo(boxLeft + half, boxTop + half)
              ..lineTo(boxLeft + half, bl - half)
              ..lineTo(boxRight, bl - half),
            stroke(StrokeJoin.miter),
          );
        // 연필: 촉은 칸 안 오른쪽 아래(기준선 위 0.25), 위 끝은 셋째 칸 오른쪽·대문자 윗선 아래 0.2(가이드 0.3과 사진의
        // 윗선 사이), 굵기는 대문자 높이의 0.22(가이드 0.21). 짧은 변·아랫변과 대문자 높이의 약 0.09씩 떨어진다.
        _paintPencil(
          canvas,
          fill,
          Offset(x(1, 0.72), bl - cap * 0.25),
          Offset(x(2, 1.0), ct + cap * 0.2),
          cap * 0.11,
        );
    }
    canvas.restore();
  }

  /// ✎ — 촉을 [point]에 두고 [corner](위 끝의 오른쪽·위 한계) 쪽으로 뻗은 연필 (몸통 + 뾰족한 촉, 몸통 반폭
  /// [halfWidth]). 몸통 윗변 꼭짓점이 [corner]의 위·오른쪽 안에 들도록 축 위쪽 끝을 안쪽으로 옮긴다.
  void _paintPencil(
    Canvas canvas,
    Paint fill,
    Offset point,
    Offset corner,
    double halfWidth,
  ) {
    var top = corner;
    var normal = Offset.zero;
    for (var i = 0; i < 3; i++) {
      final axis = point - top;
      final unit = axis / axis.distance;
      normal = Offset(-unit.dy, unit.dx);
      top = Offset(
        corner.dx - normal.dx.abs() * halfWidth,
        corner.dy + normal.dy.abs() * halfWidth,
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
      CalcTheme.lcdStatusBoxedLetterRatio,
      CalcTheme.lcdStatusCapHeightRatio,
      Paint()..blendMode = BlendMode.dstOut,
      // 늘 굵게: 지운 획이 가늘면 작은 크기(6dp·2x)에서 1물리 픽셀도 안 돼 상자만 남는다. 가이드 표시기 표의
      // 상자 글자도 굵다. 그래서 굵은 글씨 접근성 설정을 켜도 더 굵어지지 않는다.
      bold: true,
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
