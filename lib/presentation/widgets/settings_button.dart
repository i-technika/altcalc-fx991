import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';
import '../l10n/settings_strings.dart';
import 'handedness_dialog.dart';
import 'screen_coordinate_root.dart';

/// 설정 진입 버튼 (#24). 누르면 키패드 위치(손잡이) 선택 대화상자([HandednessDialog])를 띄운다.
///
/// 크기는 부모가 정한다(`CalculatorScreen`은 [CalcTheme.settingsButtonSize] 정사각형 자리를 준다).
/// 지금은 손잡이 설정이 좌우 분할·접힘선 기준 배치(#25)에만 영향이 있어 그 배치에서만 쓴다.
/// 위아래 배치(폰)의 설정 진입은 상단 띠 활용과 함께 정한다 — TODO(#41).
///
/// 화면이 접힘선으로 나뉘어 있으면(반 접힘·물리 힌지) 대화상자는 이 버튼이 있는 쪽 절반에 뜬다
/// (`showDialog`의 `anchorPoint` — `DisplayFeatureSubScreen`이 고른다, #25).
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  /// 버튼 위젯 키
  static const Key buttonKey = ValueKey('settings-button');

  /// 이 버튼 중심의 화면 좌표 (배치 전이면 `null`). 접힘 정보와 같은 좌표계라야 하므로
  /// [ScreenCoordinateRoot.globalToScreen]을 거친다.
  static Offset? _anchorOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return ScreenCoordinateRoot.globalToScreen(
      context,
      box.localToGlobal(box.size.center(Offset.zero)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = SettingsStrings.of(context);
    return IconButton(
      key: buttonKey,
      tooltip: strings.settingsButton,
      color: CalcTheme.settingsIcon,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: const Icon(Icons.settings),
      onPressed: () => showDialog<void>(
        context: context,
        anchorPoint: _anchorOf(context),
        builder: (_) => const HandednessDialog(),
      ),
    );
  }
}
