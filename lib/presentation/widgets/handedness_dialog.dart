import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/models/handedness.dart';
import '../l10n/settings_strings.dart';
import '../providers/settings_provider.dart';

/// 키패드 위치(손잡이) 선택 대화상자 (#24). 고르면 설정을 저장하고 닫는다.
///
/// 표준 라디오 그룹([RadioGroup] + [RadioListTile])이라 스크린리더에는 단일 선택 그룹·선택 상태로 알려지고,
/// 키보드 화살표로 선택지를 옮길 수 있다.
class HandednessDialog extends ConsumerWidget {
  const HandednessDialog({super.key});

  /// [value] 선택지의 위젯 키
  static Key optionKeyOf(Handedness value) =>
      ValueKey('handedness-option-${value.storageValue}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = SettingsStrings.of(context);
    return SimpleDialog(
      title: Text(strings.handednessTitle),
      children: [
        RadioGroup<Handedness>(
          groupValue: ref.watch(handednessProvider),
          // 현재 선택을 다시 누르면(toggleable) null이 온다 — 설정은 그대로 두고 닫기만 한다.
          onChanged: (value) {
            if (value != null) {
              ref.read(handednessProvider.notifier).set(value);
            }
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final value in Handedness.values)
                RadioListTile<Handedness>(
                  key: optionKeyOf(value),
                  value: value,
                  toggleable: true,
                  title: Text(strings.handedness(value)),
                  subtitle: Text(strings.handednessDetail(value)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
