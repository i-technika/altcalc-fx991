import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState;

import 'package:material_ui/material_ui.dart';

import '../../core/layout/form_factor.dart';
import '../../core/theme/calc_theme.dart';
import '../l10n/settings_strings.dart';
import 'focus_ring.dart';
import 'handedness_dialog.dart';

/// 설정 진입 버튼 (#24). 누르면 키패드 위치(손잡이) 선택 대화상자([HandednessDialog])를 띄운다.
///
/// 크기는 부모가 정한다(`CalculatorScreen`은 [CalcTheme.settingsButtonSize] 정사각형 자리를 준다).
/// 모든 배치에 하나씩 있다 — 좌우 분할·접힘선 기준 배치는 LCD 아래 등 #24·#25의 자리, 위아래 배치는 LCD 위
/// 상단 띠의 오른쪽 끝이다 (#41, `CalcTopStripLayout`).
///
/// ## 낮은 상단 띠 (#41)
/// 띠가 버튼보다 낮은 폰에서는 이 위젯의 자리(터치 영역)가 띠 윗변에서 아래로 LCD 위쪽에 겹친다.
/// 이때 [visualHeight]를 주면 아이콘·눌림 표시·포커스 테두리는 자리 위쪽 그 높이(띠) 안에만 그리고,
/// 그 아래 겹친 곳은 보이지 않는 터치 영역으로만 둔다(눌러도 같은 대화상자가 열린다).
/// 겹친 곳은 아이콘과 다음이 다르다: 눌림 표시·마우스 호버 표시·툴팁이 없고, 길게 눌렀다 떼도(아이콘은 툴팁만
/// 띄운다) 대화상자가 열린다. 보이지 않는 영역이라 눌림·툴팁을 그릴 자리가 없고, 길게 누름을 따로 막으면
/// 손가락을 오래 댄 사용자에게 아무 반응이 없어 보인다.
/// 스크린리더가 보는 버튼 영역은 보이는 부분(줄 높이, 최소 띠에서 48×20dp)뿐이다. 겹친 곳은 LCD 상태 표시기의
/// 영역으로 남아, 화면을 더듬어 읽을 때 표시기가 가려지지 않는다(접근성 검사기의 터치 대상 크기 판정은 이 영역을
/// 기준으로 하므로 48dp 미만으로 보고될 수 있다 — 실제 터치 영역은 48dp다).
///
/// ## 접힘선이 있을 때 대화상자 위치 (#25)
/// 대화상자는 이 버튼이 있는 쪽 절반에 뜬다(`showDialog`의 `anchorPoint` → `DisplayFeatureSubScreen`).
/// Flutter는 반 접힘·물리 힌지만 화면을 나누는 것으로 보지만, 앱은 펼친 폭 0 세로 접힘선에서도 화면을 나눈다
/// (`FormFactor.arrangementOf`). 그 경우 대화상자가 주름을 가로지르지 않도록 같은 기준으로 한 번 더 나눈다.
/// 다만 다음 두 조건을 모두 만족할 때만이다 (#41 R1·R2).
/// - 실제로 그린 배치([arrangement])가 세로 접힘선 기준 배치다. 키가 터치 하한보다 낮아 위아래 배치로 그렸다면
///   앱도 화면을 나누지 않았으므로 대화상자를 한쪽 절반에 가두지 않는다.
/// - 버튼 쪽 절반이 그쪽 시스템 인셋을 빼고 [FormFactor.hingeMinPanelExtent] 이상이다. 그보다 좁으면 대화상자
///   카드가 150dp 안팎으로 줄어 읽기 어려우므로, 주름을 가로지르더라도 화면 전체에 띄운다.
///
/// ## 대화상자가 열린 동안 배치가 바뀌면
/// 회전·접기·창 크기 변경으로 [arrangement]·[handednessApplies]가 바뀌면 다음 프레임에 열린 대화상자에도
/// 반영된다(나뉨 여부와 그 기준 위치, 적용 안내 글). 대화상자는 다른 경로라 이 위젯이 다시 빌드되는 중에는 바꿀 수
/// 없어 한 프레임 늦다. 나뉨 여부가 바뀌어 대화상자를 감싸는 위젯이 달라져도 대화상자는 같은 [GlobalKey]로 옮겨
/// 가므로 키보드 포커스·스크롤 위치가 유지된다.
/// 다시 잰 기준 위치는 앱만 나누는 펼친 폭 0 세로 접힘선에만 쓰인다. Flutter도 나누는 반 접힘·물리 힌지는
/// `showDialog` 경로가 연 시점의 `anchorPoint`로 절반을 고르고, 그 값은 경로가 열린 동안 바뀌지 않는다.
///
/// ## 대화상자가 열린 채 손잡이를 바꾸면 (#94)
/// 세로 접힘선 기준 배치는 그대로이고 손잡이만 바뀌어 버튼이 반대쪽 절반으로 옮겨 가도, 대화상자는 연 자리(연 시점의
/// 버튼 쪽 절반)에 남는다. 고른 뒤에는 버튼과 대화상자가 서로 다른 절반에 있고 옮겨 간 키패드를 대화상자가
/// 가리지만, 고르는 순간 반대쪽 절반에서 키패드가 빠지고 LCD가 들어오는 것은 대화상자 바깥에서 보인다(미리 보기).
/// 닫았다가 다시 열면 지금 버튼이 있는 절반에 뜬다. 다른 두 방식을 쓰지 않는 이유:
/// - 버튼 쪽으로 따라가기: 키보드 화살표로 선택지를 옮기면 선택도 바뀌므로([HandednessDialog]) 화살표를 누를
///   때마다 대화상자가 접힘선 건너로 뛴다. 손가락·스크린리더 터치 탐색 위치에서도 대화상자가 사라진다.
///   (반 접힘·물리 힌지까지 따라가게 하려면 `showDialog` 대신 `anchorPoint`를 바꿀 수 있는 `DialogRoute`를
///   직접 띄워야 한다 — 위 절.)
/// - 고르면 바로 닫기: 화살표 한 번에 설정이 바뀌고 대화상자가 닫힌다([HandednessDialog]).
///
/// 다른 화면에서도 대화상자는 연 자리에 남는다.
/// - 손잡이를 바꾸면 배치까지 바뀌는 비대칭 세로 접힘선(키패드가 들어갈 절반 폭이 손잡이마다 다르다): 반 접힘·물리
///   힌지는 연 시점의 `anchorPoint`가 고정이라, 버튼이 반대쪽 절반으로 가도 옮겨 가지 않는다. 펼친 폭 0 접힘선은
///   위 절대로 버튼 중심을 다시 재지만, 접힘선 기준 배치일 때 버튼이 있는 LCD 쪽은 키패드가 들어가지 못한 좁은
///   절반이라 하한([FormFactor.hingeMinPanelExtent])보다 늘 좁아, 대화상자는 화면 전체에 그대로 뜬다
///   (하한 폭 절반에는 키패드가 늘 들어간다는 전제는 `split_layout_test`가 검사한다).
/// - 가로 접힘선 기준 배치(테이블톱): 버튼은 키패드 옆 자리면 아래 절반, 폭이 모자라면 위 절반 위쪽 모서리이고
///   어느 쪽인지는 손잡이와 무관하다(`CalcTabletopLayout`) — 손잡이를 바꾸면 같은 절반 안에서 좌우로만 옮겨 간다.
/// - 좌우 분할 배치(접힘선 없음): 대화상자가 화면 가운데 한 자리다.
class SettingsButton extends StatefulWidget {
  /// 이 버튼이 놓인 화면의 실제 배치 (`CalculatorScreen`이 그린 배치 — 접힘선 기준 배치를 쓸 수 없어 위아래
  /// 배치로 그렸으면 [ScreenArrangement.stacked])
  final ScreenArrangement arrangement;

  /// 손잡이 설정을 바꾸면 이 화면의 배치가 달라지는지. 아니면 대화상자에 그 안내 글을 보인다.
  ///
  /// 그린 배치만으로는 정할 수 없다 — 세로 접힘선 기준 배치는 키패드가 들어갈 절반의 폭이 손잡이마다 달라,
  /// 지금 손잡이로는 위아래 배치로 대체했어도 반대 손잡이로는 접힘선 기준 배치가 될 수 있다(#41 R2).
  /// `CalculatorScreen`이 두 손잡이로 모두 판정해 넘긴다.
  final bool handednessApplies;

  /// 자리 위쪽에서 버튼을 그리는 구간 높이 (dp). `null`이거나 자리 높이 이상이면 자리 전체에 그린다.
  final double? visualHeight;

  /// 아이콘 크기 (dp). `null`이면 [CalcTheme.settingsIconSize].
  final double? iconSize;

  const SettingsButton({
    super.key,
    required this.arrangement,
    required this.handednessApplies,
    this.visualHeight,
    this.iconSize,
  }) : assert(visualHeight == null || visualHeight >= 0),
       assert(iconSize == null || iconSize > 0);

  /// 버튼 위젯 키
  static const Key buttonKey = ValueKey('settings-button');

  /// 낮은 상단 띠에서 보이는 버튼 아래로 넓힌 터치 영역의 위젯 키
  static const Key touchExtensionKey = ValueKey('settings-button-touch');

  @override
  State<SettingsButton> createState() => _SettingsButtonState();
}

/// 열린 대화상자가 보는 화면 상태 — 배치, 손잡이 적용 여부, 버튼 중심(Navigator 좌표, 나눌 절반을 고르는 기준)
typedef _DialogLayout = ({
  ScreenArrangement arrangement,
  bool handednessApplies,
  Offset? anchor,
});

class _SettingsButtonState extends State<SettingsButton> {
  /// 열린 대화상자가 보는 화면 상태 ([SettingsButton]의 값을 한 프레임 늦게 따른다)
  late final ValueNotifier<_DialogLayout> _layout = ValueNotifier((
    arrangement: widget.arrangement,
    handednessApplies: widget.handednessApplies,
    anchor: null,
  ));

  @override
  void didUpdateWidget(SettingsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.arrangement != oldWidget.arrangement ||
        widget.handednessApplies != oldWidget.handednessApplies) {
      // 대화상자 경로는 이 위젯의 자손이 아니라 빌드 중에 다시 빌드하라고 표시할 수 없다 — 프레임이 끝난 뒤
      // (버튼이 새 자리에 놓인 뒤) 알린다. 버튼 중심도 그때 다시 잰다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final navigator = Navigator.maybeOf(context, rootNavigator: true);
        _layout.value = (
          arrangement: widget.arrangement,
          handednessApplies: widget.handednessApplies,
          anchor: navigator == null
              ? _layout.value.anchor
              : _anchorIn(context, navigator),
        );
      });
    }
  }

  @override
  void dispose() {
    _layout.dispose();
    super.dispose();
  }

  /// 이 버튼 중심을 [navigator] 좌표로 바꾼 값 (배치 전이면 `null`).
  ///
  /// 대화상자 경로는 그 Navigator 안에서 그려지고, `DisplayFeatureSubScreen`은 그 위치의 MediaQuery
  /// (접힘 정보 포함)와 경로 좌표로 절반을 고른다. 실제 앱에서는 Navigator가 화면 전체를 채워 경로 좌표가
  /// 곧 화면 좌표다.
  static Offset? _anchorIn(BuildContext context, NavigatorState navigator) {
    final box = context.findRenderObject();
    final navigatorBox = navigator.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || navigatorBox is! RenderBox) {
      return null;
    }
    return navigatorBox.globalToLocal(
      box.localToGlobal(box.size.center(Offset.zero)),
    );
  }

  /// 앱이 화면을 나누는데 Flutter는 나누지 않는 접힘선(펼친 폭 0 세로 접힘선)을, 대화상자 배치에서는
  /// 나누는 접힘선(반 접힘)으로 바꾼다. 바꿀 것이 없으면 `null`.
  /// 앱이 실제로 세로 접힘선 기준 배치로 그렸고([arrangement]), [anchor] 쪽 절반이 충분히 넓을 때만 바꾼다
  /// ([SettingsButton] "접힘선이 있을 때 대화상자 위치").
  ///
  /// [screenPadding]은 화면의 시스템 인셋이다. 대화상자 내용은 `showDialog`의 SafeArea 안이라 [media]의 인셋이
  /// 이미 0이므로 Navigator의 MediaQuery 값을 따로 받는다.
  static List<DisplayFeature>? _splitLikeApp(
    MediaQueryData media,
    ScreenArrangement arrangement,
    Offset? anchor,
    EdgeInsets screenPadding,
  ) {
    if (arrangement != ScreenArrangement.hingeSplit) return null;
    bool splitByAppOnly(DisplayFeature f) =>
        !FormFactor.separates(f) &&
        FormFactor.hingeOf(media.size, [f]) != null &&
        FormFactor.isVerticalHinge(f.bounds);
    final hinge = media.displayFeatures.where(splitByAppOnly).firstOrNull;
    if (hinge == null) return null;
    // 버튼 쪽 절반의 폭 (그쪽 시스템 인셋 제외) — 버튼 위치를 모르면 좁은 쪽으로 본다.
    final left = hinge.bounds.left - screenPadding.left;
    final right = media.size.width - hinge.bounds.right - screenPadding.right;
    final half = anchor == null
        ? math.min(left, right)
        : (anchor.dx < hinge.bounds.center.dx ? left : right);
    if (half < FormFactor.hingeMinPanelExtent) return null;
    return [
      for (final f in media.displayFeatures)
        splitByAppOnly(f)
            ? DisplayFeature(
                bounds: f.bounds,
                type: f.type,
                state: DisplayFeatureState.postureHalfOpened,
              )
            : f,
    ];
  }

  void _open(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    final anchor = _anchorIn(context, navigator);
    _layout.value = (
      arrangement: widget.arrangement,
      handednessApplies: widget.handednessApplies,
      anchor: anchor,
    );
    // 나뉨 여부가 바뀌어 감싸는 위젯이 달라져도 대화상자 element(포커스·스크롤)를 옮겨 유지한다.
    final dialogKey = GlobalKey(debugLabel: 'handedness-dialog');
    showDialog<void>(
      context: context,
      anchorPoint: anchor,
      builder: (dialogContext) => ValueListenableBuilder<_DialogLayout>(
        valueListenable: _layout,
        builder: (dialogContext, layout, _) {
          final dialog = HandednessDialog(
            key: dialogKey,
            showLayoutNote: !layout.handednessApplies,
          );
          final media = MediaQuery.of(dialogContext);
          final features = _splitLikeApp(
            media,
            layout.arrangement,
            layout.anchor,
            MediaQuery.paddingOf(navigator.context),
          );
          if (features == null) return dialog;
          // 바깥 `DisplayFeatureSubScreen`이 나누지 않아 화면 전체(경로 좌표 = 이 좌표)를 받았으므로,
          // 지금 버튼 중심으로 앱 기준 절반을 고른다.
          return MediaQuery(
            data: media.copyWith(displayFeatures: features),
            child: DisplayFeatureSubScreen(
              anchorPoint: layout.anchor,
              child: dialog,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = SettingsStrings.of(context);
    // 키보드 포커스 테두리 (고대비 #97, 일반 모드 #106) — IconButton의 M3 기본 모양(정사각형 자리에서는 원,
    // 낮은 띠에서는 알약)
    final button = FocusRing(
      shape: const StadiumBorder(),
      child: IconButton(
        key: SettingsButton.buttonKey,
        tooltip: strings.settingsButton,
        color: CalcPalette.of(context).settingsIcon,
        iconSize: widget.iconSize ?? CalcTheme.settingsIconSize,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: const Icon(Icons.settings),
        onPressed: () => _open(context),
      ),
    );
    // 구조를 [SettingsButton.visualHeight] 유무·값과 무관하게 같게 둔다 — 배치나 띠 높이가 바뀌어도(회전·창 크기
    // 변경) 버튼 element와 키보드 포커스가 유지된다. 넓힌 터치 영역은 늘 자리 전체를 차지하고, 그리는 구간이 자리
    // 전체이면 그 위의 IconButton이 모두 덮어 넓힌 영역에는 터치가 닿지 않는다.
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : (widget.visualHeight ?? CalcTheme.settingsButtonSize);
        final visualHeight = math.min(widget.visualHeight ?? height, height);
        return Stack(
          children: [
            // 보이는 버튼 아래(LCD 위쪽에 겹친 곳)의 터치 영역. 시맨틱에는 넣지 않는다 — 버튼은 위의 IconButton 하나다.
            Positioned.fill(
              child: GestureDetector(
                key: SettingsButton.touchExtensionKey,
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: () => _open(context),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: visualHeight,
              child: button,
            ),
          ],
        );
      },
    );
  }
}
