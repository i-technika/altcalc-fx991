import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';
import '../l10n/settings_strings.dart';
import 'handedness_dialog.dart';

/// 설정 진입 버튼 (#24). 누르면 키패드 위치(손잡이) 선택 대화상자([HandednessDialog])를 띄운다.
///
/// 크기는 부모가 정한다(`CalculatorScreen`은 [CalcTheme.settingsButtonSize] 정사각형 자리를 준다).
/// 지금은 손잡이 설정이 좌우 분할 배치에만 영향이 있어 좌우 분할 배치에서만 쓴다.
/// 위아래 배치(폰)의 설정 진입은 상단 띠 활용과 함께 정한다 — TODO(#41).
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  /// 버튼 위젯 키
  static const Key buttonKey = ValueKey('settings-button');

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
      // 가장 가까운 Navigator에 띄운다. 앱은 Navigator가 하나라 같지만, 화면을 흉내 내는 곳(개발용
      // 미리보기의 기기 틀)은 자기 Navigator를 두어 대화상자가 그 화면 안에 그 화면의 MediaQuery로 뜬다 (#72).
      onPressed: () => showDialog<void>(
        context: context,
        useRootNavigator: false,
        builder: (_) => const HandednessDialog(),
      ),
    );
  }
}
