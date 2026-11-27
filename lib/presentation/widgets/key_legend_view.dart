import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/key_legend.dart';
import '../../core/theme/calc_theme.dart';

/// 키캡 각인([KeyLegend])을 실물처럼 2차원으로 그리는 위젯 (#155).
///
/// 분수는 위아래로 쌓고 가로줄을 긋고, 위첨자·아래첨자는 작게 올리거나 내리며, 근호는 가로줄이 피개법수를
/// 덮는 모양으로 그린다. ∑는 끝 칸을 기호 위·아래에 쌓고(#169), 입력 칸([LegendBox])은 모두 글자 대신 자리별 비율의
/// 직사각형으로 직접 그린다(#186). 글자는 [style]의 글꼴(번들 Noto Sans Mono, ∫·∑는 대체 글꼴 Noto Sans Math)로,
/// 가로줄·근호·칸은 같은 색으로 그린다. 픽셀 이미지를 쓰지 않으므로 글자 배율·고대비 색 전환에도 선명하다.
///
/// ## 크기·기준선
/// - 크기는 [textScaler]를 반영한 글자 크기로 배치한 각인의 폭과, **한 줄 상자**(같은 글자 크기의
///   strut 한 줄)와 모든 잉크(첨자·분수·근호 선 포함)를 합친 높이다. 그래서 잉크가 상자 밖에 그려지지 않는다.
///   키 버튼은 `Text`와 같은 방식(`FittedBox`)으로 줄인다.
/// - 글자만 있는 각인([LegendText])은 한 줄 상자만 쓴다 — 같은 스타일의 `Text`(strut 고정)와 크기·기준선이 같다
///   (`g` 같은 내림 글자도 `Text`처럼 상자 밖으로 조금 나가 그려진다).
/// - 기준선은 한 줄 상자의 기준선이다. 분수가 아래로 더 나가면 그만큼 상자가 아래로 커지므로, 아래 정렬한
///   각인 띠에서는 기준선이 그만큼(가장 많은 `d/dx◼`도 0.08em 미만, 테스트로 고정) 이웃 각인보다 올라간다.
///
/// [KeypadMetrics] 같은 측정 쪽은 그리지 않고 [emSize]로 크기를 잰다.
class KeyLegendView extends LeafRenderObjectWidget {
  /// 그릴 각인
  final KeyLegend legend;

  /// 바탕 글자 스타일 (`fontSize`·`color` 포함 — 첨자·분수는 이 크기의 비율로 그린다)
  final TextStyle style;

  /// 시스템 글자 배율 (글자 크기에만 반영한다)
  final TextScaler textScaler;

  const KeyLegendView({
    super.key,
    required this.legend,
    required this.style,
    this.textScaler = TextScaler.noScaling,
  });

  /// 잉크 범위 표 — 2차원 각인에 쓰는 글자의 세로 잉크 범위 `(아래끝, 위끝)` (글자 크기 대비, 기준선 위가 +).
  ///
  /// Flutter는 글리프의 잉크 범위를 알려 주지 않으므로 번들 글꼴의 `glyf` 값(SemiBold·Medium의 평균,
  /// ∫·∑는 Noto Sans Math)을 적어 둔다. 실제 글꼴과 맞는지, 2차원 각인의 모든 글자가 표에 있는지
  /// 테스트로 검증한다(`test/widget/key_legend_view_test.dart`). 표에 없는 글자는 한 줄 상자를 잉크로 본다.
  ///
  /// `◼`는 직접 그리는 칸의 기본 높이로 쓴다. `◻`는 그리는 데 쓰지 않지만, 칸의 한 줄 표기 글자([LegendBox.texts])라
  /// "2차원 각인의 모든 글자가 표에 있다" 검사가 찾으므로 함께 둔다(글자 조각으로 다시 쓰일 때도 맞는 값이다).
  static const Map<String, (double, double)> glyphInk = {
    '◼': (0.0, 0.482),
    '◻': (0.0, 0.482),
    '0': (-0.01, 0.724),
    '1': (0.0, 0.714),
    '2': (0.0, 0.724),
    '3': (-0.01, 0.724),
    'x': (0.0, 0.54),
    'a': (-0.01, 0.55),
    'b': (-0.01, 0.76),
    'c': (-0.01, 0.55),
    'd': (-0.01, 0.76),
    'e': (-0.01, 0.55),
    'g': (-0.245, 0.551),
    'i': (0.0, 0.768),
    'l': (0.0, 0.76),
    'n': (0.0, 0.55),
    'o': (-0.01, 0.55),
    's': (-0.01, 0.55),
    't': (-0.01, 0.68),
    '−': (0.294, 0.396),
    '×': (0.136, 0.57),
    '⇔': (-0.02, 0.358),
    '∫': (-0.238, 0.893),
    '∑': (-0.24, 0.714),
  };

  /// 측정 기준 글자 크기 — 크기는 글자 크기에 비례한다고 보고 1dp당 크기(em 크기)를 구한다.
  static const double _probeFontSize = 100;

  /// em 치수 캐시. 화면 크기와 무관하므로 각인·스타일별로 한 번만 잰다. 시스템 글꼴이 바뀌면 비운다.
  /// 키는 글자 크기·색을 지운 스타일과 각인(구조 동등성)이다 — 크기·색만 다른 스타일로 재도 늘어나지 않는다.
  static final Map<(KeyLegend, TextStyle), KeyLegendEmMetrics> _emCache = {};
  static bool _listeningSystemFonts = false;

  /// [legend]를 [style]로 그렸을 때의 크기를 글자 크기 1dp당 값(em)으로 잰다 (배율 반영 전).
  ///
  /// 키패드 통일 글자 크기 계산(`KeypadMetrics`)과 각인 띠 폭 배분이 쓴다. [style]의 `fontSize`·`color`는 무시한다.
  static Size emSize(KeyLegend legend, TextStyle style) =>
      emMetrics(legend, style).size;

  /// [legend]를 [style]의 글자 크기(배율 반영 후) 그대로 배치했을 때의 실제 크기 (캐시하지 않는다).
  ///
  /// [emSize]는 큰 글자 크기로 잰 비율이라, 작은 글자에서 한 줄 상자 반올림만큼 실제와 다를 수 있다.
  /// 그 차이를 판정하는 테스트가 쓴다.
  static Size layoutSize(KeyLegend legend, TextStyle style) {
    final layout = _LegendLayout.build(legend, style);
    final size = layout.size;
    layout.dispose();
    return size;
  }

  /// em 치수 [legends]의 각인을 [style]의 글꼴, 배율 반영 글자 크기 [scaledFontSize]로 그렸을 때 가장 높은 높이.
  ///
  /// 실제 배치([layoutSize])와 같은 값을 한 줄 상자 하나만 재어 구한다 — 글자 크기를 찾는 이분 탐색
  /// (`KeypadMetrics`의 높이 기준)에서 매번 각인 전체를 배치하지 않기 위해서다.
  static double tallestAt(
    Iterable<KeyLegendEmMetrics> legends,
    TextStyle style,
    double scaledFontSize,
  ) {
    final (lineAscent, lineDescent) = _Builder(style)
        .lineMetrics(scaledFontSize);
    var tallest = 0.0;
    for (final m in legends) {
      final height = m.plain
          ? lineAscent + lineDescent
          : math.max(lineAscent, m.inkTop * scaledFontSize) +
                math.max(lineDescent, -m.inkBottom * scaledFontSize);
      tallest = math.max(tallest, height);
    }
    return tallest;
  }

  /// [emSize]와 함께, 위에서 기준선까지 거리와 잉크 범위(em)를 잰다.
  static KeyLegendEmMetrics emMetrics(KeyLegend legend, TextStyle style) {
    if (!_listeningSystemFonts) {
      _listeningSystemFonts = true;
      PaintingBinding.instance.systemFonts.addListener(_emCache.clear);
    }
    final key = style.copyWith(
      fontSize: _probeFontSize,
      color: const Color(0xFF000000),
    );
    return _emCache.putIfAbsent((legend, key), () {
      final layout = _LegendLayout.build(legend, key);
      final metrics = (
        size: layout.size / _probeFontSize,
        baseline: layout.baseline / _probeFontSize,
        inkTop: layout.inkTop / _probeFontSize,
        inkBottom: layout.inkBottom / _probeFontSize,
        plain: legend is LegendText,
      );
      layout.dispose();
      return metrics;
    });
  }

  @override
  RenderKeyLegend createRenderObject(BuildContext context) =>
      RenderKeyLegend(legend, style, textScaler);

  @override
  void updateRenderObject(BuildContext context, RenderKeyLegend renderObject) {
    renderObject
      ..legend = legend
      ..style = style
      ..textScaler = textScaler;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('legend', legend.plainText));
  }
}

/// 각인의 em 치수: 크기와 위에서 기준선까지 거리 (글자 크기 1dp당 값)
///
/// [inkTop]·[inkBottom]은 잉크(첨자·분수·근호 선 포함)의 위끝·아래끝(기준선 위가 +)이고, [plain]이면 글자만 있는
/// 각인이라 크기는 한 줄 상자로만 정해진다. 잉크는 글자 크기에 정확히 비례하지만 한 줄 상자는 작은 글자에서
/// 반올림되므로, 실제 글자 크기의 높이는 [KeyLegendView.tallestAt]이 한 줄 상자만 그 크기로 재어 합친다.
typedef KeyLegendEmMetrics = ({
  Size size,
  double baseline,
  double inkTop,
  double inkBottom,
  bool plain,
});

/// [KeyLegendView]의 렌더 객체.
///
/// 시스템 글꼴이 바뀌면(글꼴 지연 로드 등) `Text`(`RenderParagraph`)처럼 다시 배치한다.
class RenderKeyLegend extends RenderBox
    with RelayoutWhenSystemFontsChangeMixin {
  /// 그릴 각인 [_legend], 바탕 글자 스타일 [_style], 글자 배율 [_textScaler]로 만든다.
  RenderKeyLegend(this._legend, this._style, this._textScaler);

  KeyLegend _legend;
  TextStyle _style;
  TextScaler _textScaler;
  _LegendLayout? _layout;

  KeyLegend get legend => _legend;
  set legend(KeyLegend value) {
    if (value == _legend) return;
    _legend = value;
    _invalidate();
  }

  TextStyle get style => _style;
  set style(TextStyle value) {
    if (value == _style) return;
    final layoutChanged = value.copyWith(color: _style.color) != _style;
    _style = value;
    if (layoutChanged) {
      _invalidate();
    } else {
      // 색만 바뀌면(눌림 애니메이션) 배치는 그대로 두고 글자·선 색만 바꿔 다시 그린다.
      _layout?.recolor(value.color);
      markNeedsPaint();
    }
  }

  TextScaler get textScaler => _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _invalidate();
  }

  void _invalidate() {
    _layout?.dispose();
    _layout = null;
    markNeedsLayout();
  }

  @override
  void systemFontsDidChange() {
    _layout?.dispose();
    _layout = null;
    super.systemFontsDidChange();
  }

  /// 각인을 배치(글자 조각 `TextPainter` 생성·배치)한 횟수 — 색만 바뀔 때 다시 배치하지 않는지 테스트가 본다.
  @visibleForTesting
  int get debugLayoutBuildCount => _layoutBuildCount;
  int _layoutBuildCount = 0;

  _LegendLayout get _resolved => _layout ??= () {
    _layoutBuildCount++;
    return _LegendLayout.build(
      _legend,
      _style.copyWith(fontSize: _textScaler.scale(_style.fontSize ?? 14)),
    );
  }();

  @override
  double computeMinIntrinsicWidth(double height) => _resolved.size.width;

  @override
  double computeMaxIntrinsicWidth(double height) => _resolved.size.width;

  @override
  double computeMinIntrinsicHeight(double width) => _resolved.size.height;

  @override
  double computeMaxIntrinsicHeight(double width) => _resolved.size.height;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _resolved.baseline;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.constrain(_resolved.size);

  @override
  void performLayout() {
    size = constraints.constrain(_resolved.size);
  }

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    _resolved.paint(context.canvas, offset);
  }

  @override
  void detach() {
    _layout?.dispose();
    _layout = null;
    super.detach();
  }
}

/// 그리기 명령 하나 (조각 원점 = 왼쪽 기준선 기준 좌표, 세로는 위가 +)
sealed class _Op {
  const _Op();
}

final class _TextOp extends _Op {
  final TextPainter painter;

  /// 글자 상자 왼쪽 위 (조각 원점 기준, 위가 +)
  final Offset topLeft;

  const _TextOp(this.painter, this.topLeft);
}

final class _BarOp extends _Op {
  /// 가로줄 사각형 (조각 원점 기준, 위가 +: left, bottom, right, top)
  final Rect rect;

  const _BarOp(this.rect);
}

final class _PathOp extends _Op {
  /// 선으로 그릴 꺾은선의 점들 (조각 원점 기준, 위가 +)
  final List<Offset> points;
  final double strokeWidth;

  /// 마지막 점에서 첫 점으로 닫는지 (빈 칸 테두리)
  final bool closed;

  const _PathOp(this.points, this.strokeWidth, {this.closed = false});
}

/// 배치한 조각: 폭과 잉크 위끝·아래끝(기준선 기준, 위가 +), 그리기 명령.
class _Piece {
  final double width;
  final double inkTop;
  final double inkBottom;
  final List<(Offset, _Op)> ops;

  const _Piece(this.width, this.inkTop, this.inkBottom, this.ops);

  /// [dx]·[dy]만큼 옮긴 명령들
  Iterable<(Offset, _Op)> shifted(double dx, double dy) =>
      ops.map((e) => (e.$1 + Offset(dx, dy), e.$2));
}

/// 각인 하나의 배치 결과.
class _LegendLayout {
  /// 전체 크기 (한 줄 상자 ∪ 잉크)
  final Size size;

  /// 위에서 기준선까지 거리
  final double baseline;

  /// 잉크 위끝·아래끝 (기준선 위가 +)
  final double inkTop;
  final double inkBottom;

  final List<(Offset, _Op)> _ops;
  Color color;

  _LegendLayout._(
    this.size,
    this.baseline,
    this.inkTop,
    this.inkBottom,
    this._ops,
    this.color,
  );

  /// 배치는 그대로 두고 색만 바꾼다. 글자 스타일의 색만 바뀌면 `TextPainter`는 다시 배치하지 않는다.
  void recolor(Color? value) {
    color = value ?? const Color(0xFF000000);
    for (final (_, op) in _ops) {
      if (op is _TextOp) {
        final span = op.painter.text! as TextSpan;
        op.painter.text = TextSpan(
          text: span.text,
          style: span.style!.copyWith(color: color),
        );
      }
    }
  }

  /// [style]의 글자 크기(배율 반영 후)로 [legend]를 배치한다.
  factory _LegendLayout.build(KeyLegend legend, TextStyle style) {
    final fontSize = style.fontSize ?? 14;
    final builder = _Builder(style);
    // 각인 전체가 분수 하나면(분수 키 `◼/◻`) 옆에 맞출 글자가 없으므로 분자·분모를 크게 그려 한 줄 높이를 채운다
    // (조판의 디스플레이 분수). 다른 조각 사이의 분수(`d/dx◼`, `a b/c`)는 작게 그린다.
    final piece = legend is LegendFraction
        ? builder.fraction(
            legend.numerator,
            legend.denominator,
            fontSize,
            partScale: CalcTheme.keyLegendDisplayFractionScale,
            overhangRatio: CalcTheme.keyLegendDisplayFractionOverhang,
          )
        : builder.layout(legend, fontSize);
    // 한 줄 상자: 바탕 글자 크기의 strut 한 줄 (글자만 있는 각인의 `Text`와 같은 상자).
    // 글자만 있는 각인은 `Text`와 같게 한 줄 상자만 쓴다.
    final (lineAscent, lineDescent) = builder.lineMetrics(fontSize);
    final plain = legend is LegendText;
    final top = plain ? lineAscent : math.max(lineAscent, piece.inkTop);
    final bottom = plain
        ? lineDescent
        : math.max(lineDescent, -piece.inkBottom);
    return _LegendLayout._(
      Size(piece.width, top + bottom),
      top,
      piece.inkTop,
      piece.inkBottom,
      piece.ops,
      style.color ?? const Color(0xFF000000),
    );
  }

  void paint(Canvas canvas, Offset offset) {
    // 조각 좌표(위가 +)를 캔버스 좌표(아래가 +)로: y_canvas = baseline − y
    final origin = offset + Offset(0, baseline);
    Offset toCanvas(Offset p) => Offset(origin.dx + p.dx, origin.dy - p.dy);
    final fill = Paint()..color = color;
    for (final (at, op) in _ops) {
      switch (op) {
        case _TextOp(:final painter, :final topLeft):
          painter.paint(canvas, toCanvas(at + topLeft));
        case _BarOp(:final rect):
          canvas.drawRect(
            Rect.fromPoints(
              toCanvas(at + Offset(rect.left, rect.top)),
              toCanvas(at + Offset(rect.right, rect.bottom)),
            ),
            fill,
          );
        case _PathOp(:final points, :final strokeWidth, :final closed):
          final path = Path();
          for (final (i, p) in points.indexed) {
            final c = toCanvas(at + p);
            if (i == 0) {
              path.moveTo(c.dx, c.dy);
            } else {
              path.lineTo(c.dx, c.dy);
            }
          }
          if (closed) path.close();
          canvas.drawPath(
            path,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              // 근호 꺾임은 둥글게, 빈 칸 테두리는 실물처럼 각지게
              ..strokeJoin = closed ? StrokeJoin.miter : StrokeJoin.round
              ..strokeCap = StrokeCap.butt,
          );
      }
    }
  }

  void dispose() {
    for (final (_, op) in _ops) {
      if (op is _TextOp) op.painter.dispose();
    }
  }
}

/// 각인 조각을 재귀로 배치한다. 크기 비율은 [CalcTheme]의 "2차원 각인 배치" 상수이고,
/// 근호 모양의 세부 비율(꺾은선 꼭짓점 위치)만 아래 `_radical*` 상수로 둔다.
class _Builder {
  final TextStyle style;

  _Builder(this.style);

  // ── 근호 모양 (글자 크기 대비, 근호 왼쪽 부분 폭은 [CalcTheme.keyLegendRadicalSignWidth]) ──

  /// 근호 아래 끝이 피개법수 잉크 아래끝(또는 기준선)보다 더 내려가는 길이
  static const double _radicalBottomDrop = 0.03;

  /// 머리(왼쪽 시작점) 높이 — 근호 아래 끝에서 위끝까지의 비율
  static const double _radicalHookHeight = 0.42;

  /// 머리가 짧게 올라가는 끝점: 왼쪽 부분 폭 대비 가로 위치, 글자 크기 대비 올라가는 높이
  static const double _radicalHookPeakX = 0.2;
  static const double _radicalHookRise = 0.06;

  /// 근호가 내려가 닿는 아래 꼭짓점의 가로 위치 (왼쪽 부분 폭 대비)
  static const double _radicalTickX = 0.48;

  /// 근호 선과 피개법수 사이, 피개법수와 가로줄 오른쪽 끝 사이 여백
  static const double _radicalPadding = 0.04;

  /// 지수 오른쪽 끝과 아래 꼭짓점 사이 여백, 지수 잉크 아래끝을 머리 위로 띄우는 높이
  static const double _radicalIndexGap = 0.04;
  static const double _radicalIndexLift = 0.10;

  StrutStyle _strut(double fontSize) => StrutStyle.fromTextStyle(
    style.copyWith(fontSize: fontSize),
    forceStrutHeight: true,
  );

  TextPainter _painter(String text, double fontSize) => TextPainter(
    text: TextSpan(
      text: text,
      style: style.copyWith(fontSize: fontSize),
    ),
    strutStyle: _strut(fontSize),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  /// 글자 크기 [fontSize]의 strut 한 줄의 (기준선 위 높이, 기준선 아래 깊이)
  (double, double) lineMetrics(double fontSize) {
    final painter = _painter(' ', fontSize);
    final ascent = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final result = (ascent, painter.height - ascent);
    painter.dispose();
    return result;
  }

  /// 선을 칠할 두께 — 비율 두께가 [CalcTheme.keyLegendMinStroke]보다 가늘면 그 두께로 칠한다.
  ///
  /// 배치(분자·분모·피개법수 위치와 각인 크기)는 비율 두께로만 정한다. 그래야 각인 크기가 글자 크기에
  /// 비례해 [KeyLegendView.emSize]로 잰 크기와 같다. 굵게 칠한 만큼은 선 가운데를 기준으로 위아래 간격에 겹친다.
  static double _paintStroke(double layoutStroke) =>
      math.max(layoutStroke, CalcTheme.keyLegendMinStroke);

  _Piece layout(KeyLegend legend, double fontSize) => switch (legend) {
    LegendText(:final text) => _text(text, fontSize),
    LegendRow(:final children) => _row(children, fontSize),
    LegendScript(
      :final base,
      :final superscript,
      :final subscript,
      :final subscriptOnBaseline,
      :final subscriptFollowsSlant,
    ) =>
      _script(
        base,
        superscript,
        subscript,
        fontSize,
        subscriptOnBaseline: subscriptOnBaseline,
        subscriptFollowsSlant: subscriptFollowsSlant,
      ),
    LegendBox(:final shape, :final filled) => _box(shape, filled, fontSize),
    LegendLimits(:final base, :final over, :final under) => _limits(
      base,
      over,
      under,
      fontSize,
    ),
    LegendFraction(:final numerator, :final denominator) => fraction(
      numerator,
      denominator,
      fontSize,
      partScale: CalcTheme.keyLegendFractionScale,
    ),
    LegendRadical(:final radicand, :final index) => _radical(
      radicand,
      index,
      fontSize,
    ),
  };

  _Piece _text(String text, double fontSize) {
    final painter = _painter(text, fontSize);
    final ascent = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    var top = double.negativeInfinity;
    var bottom = double.infinity;
    for (final ch in text.split('')) {
      final ink = KeyLegendView.glyphInk[ch];
      if (ink == null) {
        // 표에 없는 글자는 한 줄 상자 전체를 잉크로 본다 (보수적으로 크게).
        top = math.max(top, ascent);
        bottom = math.min(bottom, ascent - painter.height);
      } else {
        bottom = math.min(bottom, ink.$1 * fontSize);
        top = math.max(top, ink.$2 * fontSize);
      }
    }
    if (top == double.negativeInfinity) (top, bottom) = (0, 0);
    return _Piece(painter.width, top, bottom, [
      (Offset.zero, _TextOp(painter, Offset(0, ascent))),
    ]);
  }

  _Piece _row(List<KeyLegend> children, double fontSize) {
    var x = 0.0;
    var top = double.negativeInfinity;
    var bottom = double.infinity;
    final ops = <(Offset, _Op)>[];
    for (final child in children) {
      final piece = layout(child, fontSize);
      ops.addAll(piece.shifted(x, 0));
      x += piece.width;
      top = math.max(top, piece.inkTop);
      bottom = math.min(bottom, piece.inkBottom);
    }
    return _Piece(x, top, bottom, ops);
  }

  _Piece _script(
    KeyLegend base,
    KeyLegend? superscript,
    KeyLegend? subscript,
    double fontSize, {
    bool subscriptOnBaseline = false,
    bool subscriptFollowsSlant = false,
  }) {
    final basePiece = layout(base, fontSize);
    final scriptSize = fontSize * CalcTheme.keyLegendScriptScale;
    final gap = fontSize * CalcTheme.keyLegendScriptGap;
    final ops = <(Offset, _Op)>[...basePiece.ops];
    var top = basePiece.inkTop;
    var bottom = basePiece.inkBottom;
    var scriptWidth = 0.0;
    final x = basePiece.width + gap;
    if (superscript != null) {
      final sup = layout(superscript, scriptSize);
      // 기본 높이에 두되, 바탕 잉크가 더 높으면(∫·10) 위첨자 위끝을 바탕 위끝에 맞춘다.
      final raise = math.max(
        fontSize * CalcTheme.keyLegendSuperscriptRaise,
        basePiece.inkTop - sup.inkTop,
      );
      ops.addAll(sup.shifted(x, raise));
      top = math.max(top, raise + sup.inkTop);
      bottom = math.min(bottom, raise + sup.inkBottom);
      scriptWidth = math.max(scriptWidth, sup.width);
    }
    if (subscript != null) {
      final sub = layout(subscript, scriptSize);
      // 기본 깊이에 두되, 바탕 잉크가 더 깊으면(∫) 아래첨자 아래끝을 바탕 아래끝에 맞춘다.
      // 기준선에 두는 아래첨자(`log`의 밑 칸 — #169 사진 대조)는 아래끝을 기준선에 둔다.
      final drop = subscriptOnBaseline
          ? sub.inkBottom
          : math.max(
              fontSize * CalcTheme.keyLegendSubscriptDrop,
              sub.inkBottom - basePiece.inkBottom,
            );
      // 기울어진 바탕(∫)은 아래첨자를 바탕 아래쪽 끝을 따라 왼쪽으로 당긴다(#186 사진 대조). 당기는 길이는 ∫ 기준
      // 상수다(이 표시를 쓰는 바탕은 ∫뿐 — 테스트로 고정). 첨자가 조각 왼쪽 밖으로 나가지 않게 [x]를 넘지 않는다.
      final pull = subscriptFollowsSlant
          ? math.min(fontSize * CalcTheme.keyLegendIntegralSubscriptShift, x)
          : 0.0;
      ops.addAll(sub.shifted(x - pull, -drop));
      top = math.max(top, sub.inkTop - drop);
      bottom = math.min(bottom, sub.inkBottom - drop);
      scriptWidth = math.max(scriptWidth, sub.width - pull);
    }
    return _Piece(x + scriptWidth, top, bottom, ops);
  }

  /// 직접 그리는 칸 ([LegendBox], #169·#186). [fontSize]는 칸이 놓인 자리의 글자 크기(첨자·분수 안이면 줄인 크기)다.
  /// 폭은 높이 × 자리별 사진 비([CalcTheme.keyLegendBoxAspectRatio])이고, 높이·자리는 모양에 따라:
  /// - [LegendBoxShape.sumLimit]·[LegendBoxShape.sumOperand]: ∑ 잉크 높이(글자 크기 × [CalcTheme.keyLegendLimitBaseScale]
  ///   × ∑ 잉크 범위)에 [CalcTheme.keyLegendSumBoxHeightRatio]를 곱한 높이. 끝 칸은 아래끝이 기준선이고 [_limits]가
  ///   ∑ 위·아래로 옮기며, 본문 칸은 세로 가운데가 분수 축 높이([CalcTheme.keyLegendFractionAxis] — 쌓은 ∑의 가운데)다.
  /// - [LegendBoxShape.logArgument]: 기준선에서 `l` 윗끝까지(근접 사진 — 진수 칸이 log 글자 높이만큼 선다).
  /// - [LegendBoxShape.integralOperand]: [CalcTheme.keyLegendIntegralOperandHeight] — 사진의 ∫ 본문 칸 높이(R1 #186:
  ///   글꼴 칸 높이면 ∫ 끝 칸보다 1.5배 높고 각인이 사진보다 24% 넓다).
  /// - 그 밖: 글꼴 `◼`·`◻`의 잉크 높이로 기준선에 앉는다.
  /// ∑ 칸 말고는 좌우에 글꼴 칸과 같은 여백([CalcTheme.keyLegendBoxSideBearing])을 두어, 비가 1이면 글꼴 칸과 같은
  /// 자리·폭이다. 다만 앞에 칸이 붙는 자리(log 진수 칸, ∫ 본문 칸)는 왼쪽 여백이 없다 — 사진에서 두 칸이 거의 맞닿는다.
  /// 빈 칸은 테두리 선(바깥 끝이 칸 크기)으로, 채운 칸은 칸 전체를 칠한다.
  _Piece _box(LegendBoxShape shape, bool filled, double fontSize) {
    final sigma = KeyLegendView.glyphInk['∑']!;
    final sumHeight =
        (sigma.$2 - sigma.$1) *
        fontSize *
        CalcTheme.keyLegendLimitBaseScale *
        CalcTheme.keyLegendSumBoxHeightRatio;
    final glyphHeight = fontSize * KeyLegendView.glyphInk['◼']!.$2;
    final bearing = fontSize * CalcTheme.keyLegendBoxSideBearing;
    // (높이, 아래끝, 왼쪽 여백, 오른쪽 여백) — 모양마다 빠짐없이 정한다(새 모양은 여기서 규칙을 고른다).
    final (height, bottom, left, right) = switch (shape) {
      LegendBoxShape.sumLimit => (sumHeight, 0.0, 0.0, 0.0),
      // 본문 칸은 세로 가운데가 분수 축이고, 쌓은 ∑와 끝 칸 간격만큼 띄운다(사진 약 1px).
      LegendBoxShape.sumOperand => (
        sumHeight,
        fontSize * CalcTheme.keyLegendFractionAxis - sumHeight / 2,
        fontSize * CalcTheme.keyLegendLimitGap,
        0.0,
      ),
      LegendBoxShape.logArgument => (
        fontSize * KeyLegendView.glyphInk['l']!.$2,
        0.0,
        0.0,
        bearing,
      ),
      LegendBoxShape.integralOperand => (
        fontSize * CalcTheme.keyLegendIntegralOperandHeight,
        0.0,
        0.0,
        bearing,
      ),
      LegendBoxShape.integralLimit ||
      LegendBoxShape.derivativeOperand ||
      LegendBoxShape.fractionPart ||
      LegendBoxShape.mixedWhole ||
      LegendBoxShape.mixedFractionPart ||
      LegendBoxShape.squareRootRadicand ||
      LegendBoxShape.cubeRootRadicand ||
      LegendBoxShape.rootIndex ||
      LegendBoxShape.rootRadicand ||
      LegendBoxShape.powerExponent ||
      LegendBoxShape.tenPowerExponent ||
      LegendBoxShape.ePowerExponent ||
      LegendBoxShape.logBase => (glyphHeight, 0.0, bearing, bearing),
    };
    final width = height * CalcTheme.keyLegendBoxAspectRatio(shape);
    // 조각 좌표(위가 +): rect.top이 아래끝, rect.bottom이 위끝이다(`_BarOp`와 같은 규칙).
    final rect = Rect.fromLTRB(left, bottom, left + width, bottom + height);
    final _Op op;
    if (filled) {
      op = _BarOp(rect);
    } else {
      // 선 가운데를 반 두께만큼 안쪽에 두어 칠한 테두리 바깥 끝이 칸 크기와 같게 한다. 테두리는 칸 안쪽에 칠하므로
      // 남는 구멍은 `칸 − 2 × 두께`다 — 최소 두께로 굵어져도 두께를 칸의 1/4 이하로 두어 구멍이 칸의 절반 이상 남게
      // 한다(작은 각인에서 빈 칸이 채운 칸처럼 메워지지 않게, #169 R2).
      final stroke = math.min(
        _paintStroke(fontSize * CalcTheme.keyLegendBoxStroke),
        math.min(width, height) / 4,
      );
      final r = rect.deflate(stroke / 2);
      op = _PathOp(
        [
          Offset(r.left, r.top),
          Offset(r.right, r.top),
          Offset(r.right, r.bottom),
          Offset(r.left, r.bottom),
        ],
        stroke,
        closed: true,
      );
    }
    return _Piece(rect.right + right, rect.bottom, rect.top, [
      (Offset.zero, op),
    ]);
  }

  /// 위아래 끝 — 바탕을 [CalcTheme.keyLegendLimitBaseScale]배로 줄이고, 끝 칸을 바탕 잉크 위·아래에
  /// [CalcTheme.keyLegendLimitGap]만큼 띄워 가운데로 쌓는다(#169 — 실물 ∑ 각인).
  /// 쌓은 전체 잉크의 가운데를 분수 가로줄 높이([CalcTheme.keyLegendFractionAxis])에 맞춘다 — 옆 칸(◼)과 분수
  /// 각인처럼 같은 높이에 놓이고, 전체 높이가 가장 높은 각인(`d/dx◼`)을 넘지 않는다(테스트로 고정).
  _Piece _limits(
    KeyLegend base,
    LegendBox over,
    LegendBox under,
    double fontSize,
  ) {
    final basePiece = layout(
      base,
      fontSize * CalcTheme.keyLegendLimitBaseScale,
    );
    // 끝 칸([LegendBox])은 각인 글자 크기 기준으로 ∑ 크기에 맞춰 그린다(`_box`).
    final overPiece = layout(over, fontSize);
    final underPiece = layout(under, fontSize);
    final gap = fontSize * CalcTheme.keyLegendLimitGap;
    final width = math.max(
      basePiece.width,
      math.max(overPiece.width, underPiece.width),
    );
    // 바탕 기준선을 0으로 놓고 쌓은 뒤, 전체 잉크 가운데가 분수 축에 오도록 옮긴다.
    final overBaseline = basePiece.inkTop + gap - overPiece.inkBottom;
    final underBaseline = basePiece.inkBottom - gap - underPiece.inkTop;
    final top = overBaseline + overPiece.inkTop;
    final bottom = underBaseline + underPiece.inkBottom;
    final lift =
        fontSize * CalcTheme.keyLegendFractionAxis - (top + bottom) / 2;
    return _Piece(width, top + lift, bottom + lift, [
      ...basePiece.shifted((width - basePiece.width) / 2, lift),
      ...overPiece.shifted((width - overPiece.width) / 2, overBaseline + lift),
      ...underPiece.shifted(
        (width - underPiece.width) / 2,
        underBaseline + lift,
      ),
    ]);
  }

  /// 분수 — 분자·분모를 글자 크기의 [partScale]배로 쌓고, 가로줄을 분자·분모 조각 폭보다 좌우로
  /// 글자 크기 × [overhangRatio]만큼 더 긋는다.
  _Piece fraction(
    KeyLegend numerator,
    KeyLegend denominator,
    double fontSize, {
    required double partScale,
    double overhangRatio = CalcTheme.keyLegendFractionOverhang,
  }) {
    final partSize = fontSize * partScale;
    final num = layout(numerator, partSize);
    final den = layout(denominator, partSize);
    final overhang = fontSize * overhangRatio;
    final width = math.max(num.width, den.width) + 2 * overhang;
    final axis = fontSize * CalcTheme.keyLegendFractionAxis;
    final bar = fontSize * CalcTheme.keyLegendFractionBarThickness;
    final paintBar = _paintStroke(bar);
    final gap = fontSize * CalcTheme.keyLegendFractionGap;
    // 분자 잉크 아래끝·분모 잉크 위끝이 가로줄에서 [gap]만큼 떨어지게 한다.
    final numBaseline = axis + bar / 2 + gap - num.inkBottom;
    final denBaseline = axis - bar / 2 - gap - den.inkTop;
    return _Piece(
      width,
      numBaseline + num.inkTop,
      denBaseline + den.inkBottom,
      [
        ...num.shifted((width - num.width) / 2, numBaseline),
        (
          Offset.zero,
          _BarOp(
            Rect.fromLTRB(0, axis - paintBar / 2, width, axis + paintBar / 2),
          ),
        ),
        ...den.shifted((width - den.width) / 2, denBaseline),
      ],
    );
  }

  _Piece _radical(KeyLegend radicand, KeyLegend? index, double fontSize) {
    final rad = layout(radicand, fontSize);
    final stroke = fontSize * CalcTheme.keyLegendRadicalStroke;
    final paintStroke = _paintStroke(stroke);
    // 최소 두께로 굵게 칠하는 만큼(extra)은 선을 안쪽으로 옮겨, 칠한 잉크가 배치한 잉크 범위를 넘지 않게 한다.
    final extra = (paintStroke - stroke) / 2;
    // 근호의 위(가로줄)·아래 끝 — 배치 두께 선 가운데 기준
    final top =
        rad.inkTop + fontSize * CalcTheme.keyLegendRadicalGap + stroke / 2;
    final bottom = math.min(rad.inkBottom, 0.0) - fontSize * _radicalBottomDrop;
    final signWidth = fontSize * CalcTheme.keyLegendRadicalSignWidth;
    final hookY = bottom + (top - bottom) * _radicalHookHeight;
    // 선 끝(butt)이 왼쪽으로 나가지 않도록 반 두께만큼 오른쪽에서 시작한다.
    final left = stroke / 2;
    final tickX = left + signWidth * _radicalTickX;
    final ops = <(Offset, _Op)>[];
    var shift = 0.0;
    var inkTop = top + stroke / 2;
    final inkBottom = bottom - stroke / 2;
    if (index != null) {
      final idx = layout(
        index,
        fontSize * CalcTheme.keyLegendRadicalIndexScale,
      );
      // 지수는 머리 위에 두고 오른쪽 끝을 근호가 내려가는 지점 앞에 맞춘다. 넓으면 근호를 오른쪽으로 민다.
      final right = tickX - fontSize * _radicalIndexGap;
      shift = math.max(0.0, idx.width - right);
      final idxBaseline = hookY + fontSize * _radicalIndexLift - idx.inkBottom;
      ops.addAll(idx.shifted(shift + right - idx.width, idxBaseline));
      inkTop = math.max(inkTop, idxBaseline + idx.inkTop);
    }
    final signRight = left + signWidth;
    final radX = shift + signRight + fontSize * _radicalPadding;
    final end = radX + rad.width + fontSize * _radicalPadding;
    // 근호 모양: 짧게 올라가는 머리 → 아래로 → 길게 위로 → 가로줄
    ops.add((
      Offset(shift, 0),
      _PathOp([
        Offset(left + extra, hookY),
        Offset(
          left + signWidth * _radicalHookPeakX,
          hookY + fontSize * _radicalHookRise,
        ),
        Offset(tickX, bottom + extra),
        Offset(signRight, top - extra),
        Offset(end - shift, top - extra),
      ], paintStroke),
    ));
    ops.addAll(rad.shifted(radX, 0));
    return _Piece(end, inkTop, math.min(inkBottom, rad.inkBottom), ops);
  }
}
