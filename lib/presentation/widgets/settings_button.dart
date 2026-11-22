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
/// 그 아래 겹친 곳은 보이지 않는 터치 영역으로만 둔다(눌러도 같은 대화상자가 열린다 — 눌림 표시는 없다).
/// 스크린리더가 보는 버튼 영역은 보이는 부분뿐이다. 겹친 곳은 LCD 상태 표시기의 영역으로 남아, 화면을 더듬어
/// 읽을 때 표시기가 가려지지 않는다.
///
/// ## 접힘선이 있을 때 대화상자 위치 (#25)
/// 대화상자는 이 버튼이 있는 쪽 절반에 뜬다(`showDialog`의 `anchorPoint` → `DisplayFeatureSubScreen`).
/// Flutter는 반 접힘·물리 힌지만 화면을 나누는 것으로 보지만, 앱은 펼친 폭 0 세로 접힘선에서도 화면을 나눈다
/// (`FormFactor.arrangementOf`). 그 경우 대화상자가 주름을 가로지르지 않도록 같은 기준으로 한 번 더 나눈다.
class SettingsButton extends StatelessWidget {
  /// 자리 위쪽에서 버튼을 그리는 구간 높이 (dp). `null`이거나 자리 높이 이상이면 자리 전체에 그린다.
  final double? visualHeight;

  /// 아이콘 크기 (dp). `null`이면 [CalcTheme.settingsIconSize].
  final double? iconSize;

  const SettingsButton({super.key, this.visualHeight, this.iconSize})
    : assert(visualHeight == null || visualHeight >= 0),
      assert(iconSize == null || iconSize > 0);

  /// 버튼 위젯 키
  static const Key buttonKey = ValueKey('settings-button');

  /// 낮은 상단 띠에서 보이는 버튼 아래로 넓힌 터치 영역의 위젯 키
  static const Key touchExtensionKey = ValueKey('settings-button-touch');

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
  static List<DisplayFeature>? _splitLikeApp(MediaQueryData media) {
    bool splitByAppOnly(DisplayFeature f) =>
        !FormFactor.separates(f) &&
        FormFactor.hingeOf(media.size, [f]) != null &&
        FormFactor.isVerticalHinge(f.bounds);
    if (!media.displayFeatures.any(splitByAppOnly)) return null;
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
    showDialog<void>(
      context: context,
      anchorPoint: anchor,
      builder: (dialogContext) {
        const dialog = HandednessDialog();
        final media = MediaQuery.of(dialogContext);
        final features = _splitLikeApp(media);
        if (features == null) return dialog;
        // 바깥 `DisplayFeatureSubScreen`이 나누지 않아 화면 전체(경로 좌표 = 이 좌표)를 받았으므로,
        // 같은 anchor로 앱 기준 절반을 고른다.
        return MediaQuery(
          data: media.copyWith(displayFeatures: features),
          child: DisplayFeatureSubScreen(anchorPoint: anchor, child: dialog),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = SettingsStrings.of(context);
    // 고대비 키보드 포커스 테두리 (#97) — IconButton의 M3 기본 모양(정사각형 자리에서는 원, 낮은 띠에서는 알약)
    final button = FocusRing(
      shape: const StadiumBorder(),
      child: IconButton(
        key: buttonKey,
        tooltip: strings.settingsButton,
        color: CalcPalette.of(context).settingsIcon,
        iconSize: iconSize ?? CalcTheme.settingsIconSize,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: const Icon(Icons.settings),
        onPressed: () => _open(context),
      ),
    );
    // 구조를 [visualHeight] 유무·값과 무관하게 같게 둔다 — 배치나 띠 높이가 바뀌어도(회전·창 크기 변경) 버튼
    // element와 키보드 포커스가 유지된다.
    return LayoutBuilder(
      builder: (context, constraints) {
        final visualHeight = math.min(
          this.visualHeight ?? double.infinity,
          constraints.maxHeight,
        );
        if (!visualHeight.isFinite) return button;
        return Stack(
          children: [
            // 보이는 버튼 아래(LCD 위쪽에 겹친 곳)의 터치 영역. 시맨틱에는 넣지 않는다 — 버튼은 위의 IconButton 하나다.
            Positioned.fill(
              child: GestureDetector(
                key: touchExtensionKey,
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
