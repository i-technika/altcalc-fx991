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
/// - 테두리는 [shape] 모양으로 [inset]만큼 안쪽에 그리고, 터치를 가로채지 않는다.
class FocusRing extends StatefulWidget {
  /// 포커스를 받는 위젯
  final Widget child;

  /// 테두리 모양 (기본: 직사각형). 버튼은 그 버튼의 모양(예: [StadiumBorder])을 준다.
  final OutlinedBorder shape;

  /// [child] 가장자리에서 테두리까지 안쪽 여백 — 테두리가 바깥 선(대화상자 가장자리 등)에 덮이지 않게 할 때 쓴다.
  final EdgeInsets inset;

  const FocusRing({
    super.key,
    required this.child,
    this.shape = const RoundedRectangleBorder(),
    this.inset = EdgeInsets.zero,
  });

  /// 지금 테두리를 그리고 있는지 (테스트용) — [ringKey] 위젯의 장식으로 판단한다.
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

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChanged);
    super.dispose();
  }

  void _onHighlightModeChanged(FocusHighlightMode mode) {
    final traditional = mode == FocusHighlightMode.traditional;
    if (traditional != _traditional) {
      setState(() => _traditional = traditional);
    }
  }

  void _onFocusChange(bool focused) {
    if (focused != _focused) setState(() => _focused = focused);
  }

  @override
  Widget build(BuildContext context) {
    final color = CalcPalette.of(context).materialFocusRing;
    final visible = _focused && _traditional;
    // 켜고 끌 때 트리 구조가 바뀌지 않게 장식만 바꾼다. [child]가 받는 제약은 그대로 넘긴다(passthrough).
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: _onFocusChange,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: widget.inset,
                child: DecoratedBox(
                  key: FocusRing.ringKey,
                  decoration: visible
                      ? ShapeDecoration(
                          shape: widget.shape.copyWith(
                            side: BorderSide(
                              color: color,
                              width: CalcTheme.materialFocusRingWidth,
                            ),
                          ),
                        )
                      : const BoxDecoration(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
