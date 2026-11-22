import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';

/// [child]에 키보드 포커스가 있으면 테두리를 겹쳐 그린다 (고대비 #97, 일반 모드 #106).
///
/// Material 기본 포커스 표시(겹침색)는 일반·고대비 모두 주변과 1.3~1.5:1뿐이라 키보드 사용자가 포커스 위치를 찾기 어렵다.
/// 테마로는 고칠 수 없다 — ListTile은 상태별 모양을 받지 않고, 버튼의 `WidgetState.focused`는 포커스 표시 방식과
/// 관계없이 포커스를 **가지면** 켜져 터치 조작 중에도 테두리가 남는다. 그래서 이 위젯이 직접 그린다.
/// - 색·굵기: [CalcPalette.materialFocusRing]·[CalcTheme.materialFocusRingWidth]. Material 기본 포커스 겹침은
///   그대로 두고 그 위에 그린다.
/// - Material 포커스 겹침과 같이 키보드 조작 중(`FocusHighlightMode.traditional`)에만 보인다.
/// - [child] 안의 포커스 노드(버튼·타일의 InkWell)가 포커스를 가지면 켜진다. 이 위젯은 포커스를 받지 않고,
///   포커스 이동 순서·스크린리더 시맨틱에 끼어들지 않는다.
/// - 테두리는 [child] 전체가 아니라 **포커스를 가진 노드의 영역**(InkWell = 보이는 버튼·타일)에 맞춰 그린다.
///   버튼은 터치 영역을 48dp로 넓히는 여백(`MaterialTapTargetSize.padded`) 안에 보이는 면이 있으므로, [child] 전체에
///   그리면 테두리가 버튼 모양과 어긋난다(R1, #106). 그 영역에서 [inset]만큼 안쪽에 [shape] 모양으로 그리고,
///   터치를 가로채지 않는다.
class FocusRing extends StatefulWidget {
  /// 포커스를 받는 위젯
  final Widget child;

  /// 테두리 모양 (기본: 직사각형). 버튼은 그 버튼의 모양(예: [StadiumBorder])을 준다.
  final OutlinedBorder shape;

  /// 포커스 노드 영역 가장자리에서 테두리까지 안쪽 여백 — 테두리가 바깥 선(대화상자 가장자리 등)에 덮이지 않게 할 때 쓴다.
  final EdgeInsets inset;

  const FocusRing({
    super.key,
    required this.child,
    this.shape = const RoundedRectangleBorder(),
    this.inset = EdgeInsets.zero,
  });

  /// 테두리를 그리는 렌더 객체([RenderFocusRing])의 위젯 키 (테스트용)
  static const Key ringKey = ValueKey('focus-ring');

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  /// [FocusRing.child] 안에 포커스가 있는지
  bool _focused = false;

  /// 키보드 조작 중인지 (포커스 표시를 보일지)
  bool _traditional =
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  /// 포커스를 가진 노드 — [FocusRing.child] 안에서 포커스가 다른 노드로 옮겨 가도(`onFocusChange`는 다시 불리지 않는다)
  /// 테두리가 따라가도록 [FocusManager]의 알림으로 갱신한다.
  FocusNode? _primary;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChanged);
    FocusManager.instance.addListener(_onPrimaryFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChanged);
    FocusManager.instance.removeListener(_onPrimaryFocusChanged);
    super.dispose();
  }

  void _onHighlightModeChanged(FocusHighlightMode mode) {
    final traditional = mode == FocusHighlightMode.traditional;
    if (traditional != _traditional) {
      setState(() => _traditional = traditional);
    }
  }

  void _onPrimaryFocusChanged() {
    if (!_focused) return;
    final primary = FocusManager.instance.primaryFocus;
    if (primary != _primary) setState(() => _primary = primary);
  }

  void _onFocusChange(bool focused) {
    if (focused != _focused) {
      setState(() {
        _focused = focused;
        _primary = focused ? FocusManager.instance.primaryFocus : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _focused && _traditional;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: _onFocusChange,
      child: _FocusRingPaint(
        key: FocusRing.ringKey,
        side: visible
            ? BorderSide(
                color: CalcPalette.of(context).materialFocusRing,
                width: CalcTheme.materialFocusRingWidth,
              )
            : null,
        target: visible ? _primary : null,
        shape: widget.shape,
        inset: widget.inset,
        child: widget.child,
      ),
    );
  }
}

/// [RenderFocusRing]을 만드는 위젯 — 켜고 끌 때 트리 구조가 바뀌지 않게 속성만 바꾼다.
class _FocusRingPaint extends SingleChildRenderObjectWidget {
  final BorderSide? side;
  final FocusNode? target;
  final OutlinedBorder shape;
  final EdgeInsets inset;

  const _FocusRingPaint({
    super.key,
    required this.side,
    required this.target,
    required this.shape,
    required this.inset,
    required super.child,
  });

  @override
  RenderFocusRing createRenderObject(BuildContext context) =>
      RenderFocusRing(side: side, target: target, shape: shape, inset: inset);

  @override
  void updateRenderObject(BuildContext context, RenderFocusRing renderObject) {
    renderObject
      ..side = side
      ..target = target
      ..shape = shape
      ..inset = inset;
  }
}

/// [FocusRing]의 테두리를 자식 위에 그리는 렌더 객체. 크기·터치·시맨틱은 자식 그대로다(테두리는 그리기만 한다).
class RenderFocusRing extends RenderProxyBox {
  RenderFocusRing({
    required this._side,
    required this._target,
    required this._shape,
    required this._inset,
  });

  /// 테두리 선 — `null`이면 그리지 않는다
  BorderSide? get side => _side;
  BorderSide? _side;
  set side(BorderSide? value) {
    if (value == _side) return;
    _side = value;
    markNeedsPaint();
  }

  /// 포커스를 가진 노드 — 이 노드의 렌더 영역에 맞춰 그린다
  FocusNode? get target => _target;
  FocusNode? _target;
  set target(FocusNode? value) {
    if (value == _target) return;
    _target = value;
    markNeedsPaint();
  }

  OutlinedBorder get shape => _shape;
  OutlinedBorder _shape;
  set shape(OutlinedBorder value) {
    if (value == _shape) return;
    _shape = value;
    markNeedsPaint();
  }

  EdgeInsets get inset => _inset;
  EdgeInsets _inset;
  set inset(EdgeInsets value) {
    if (value == _inset) return;
    _inset = value;
    markNeedsPaint();
  }

  /// 테두리를 그릴 영역 (이 렌더 객체 좌표). 그리지 않으면 `null`.
  ///
  /// 포커스 노드의 렌더 박스가 이 객체의 자손이면 그 박스 영역, 아니면(아직 배치 전 등) 자식 전체 영역을 쓰고,
  /// 거기서 [inset]만큼 안쪽이다.
  Rect? get ringRect {
    if (_side == null) return null;
    var area = Offset.zero & size;
    final box = _target?.context?.findRenderObject();
    if (box is RenderBox && box.attached && box.hasSize && _isDescendant(box)) {
      area = MatrixUtils.transformRect(
        box.getTransformTo(this),
        Offset.zero & box.size,
      );
    }
    return _inset.deflateRect(area);
  }

  bool _isDescendant(RenderObject node) {
    RenderObject? current = node;
    while (current != null) {
      if (identical(current, this)) return true;
      current = current.parent;
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final side = _side;
    final rect = ringRect;
    if (side == null || rect == null) return;
    _shape.copyWith(side: side).paint(context.canvas, rect.shift(offset));
  }
}
