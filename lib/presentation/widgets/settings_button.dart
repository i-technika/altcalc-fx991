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
/// 지금은 손잡이 설정이 좌우 분할·접힘선 기준 배치(#25)에만 영향이 있어 그 배치에서만 쓴다.
/// 위아래 배치(폰)의 설정 진입은 상단 띠 활용과 함께 정한다 — TODO(#41).
///
/// ## 접힘선이 있을 때 대화상자 위치 (#25)
/// 대화상자는 이 버튼이 있는 쪽 절반에 뜬다(`showDialog`의 `anchorPoint` → `DisplayFeatureSubScreen`).
/// Flutter는 반 접힘·물리 힌지만 화면을 나누는 것으로 보지만, 앱은 펼친 폭 0 세로 접힘선에서도 화면을 나눈다
/// (`FormFactor.arrangementOf`). 그 경우 대화상자가 주름을 가로지르지 않도록 같은 기준으로 한 번 더 나눈다.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  /// 버튼 위젯 키
  static const Key buttonKey = ValueKey('settings-button');

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
    // 고대비 키보드 포커스 테두리 (#97) — IconButton의 M3 기본 모양(정사각형 자리에서는 원)
    return FocusRing(
      shape: const StadiumBorder(),
      child: IconButton(
        key: buttonKey,
        tooltip: strings.settingsButton,
        color: CalcPalette.of(context).settingsIcon,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: const Icon(Icons.settings),
        onPressed: () => _open(context),
      ),
    );
  }
}
