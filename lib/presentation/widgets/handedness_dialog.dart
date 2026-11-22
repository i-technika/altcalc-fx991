import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/models/handedness.dart';
import '../l10n/settings_strings.dart';
import '../providers/settings_provider.dart';

/// 키패드 위치(손잡이) 선택 대화상자 (#24).
///
/// 고르면 설정을 바로 저장하고, 대화상자 뒤의 키패드도 바로 옮겨진다(미리 보기). 닫기는 "닫기" 버튼이나
/// 바깥 탭·뒤로가기로 한다 — 고를 때 닫지 않는 이유: 표준 라디오 그룹([RadioGroup])은 키보드 화살표로
/// 포커스를 옮기면 선택도 함께 바뀌므로, 고를 때 닫으면 화살표 한 번에 설정이 바뀌고 대화상자가 닫힌다.
/// 스크린리더에는 단일 선택 그룹·선택 상태로 알려진다.
class HandednessDialog extends ConsumerWidget {
  const HandednessDialog({super.key});

  /// [value] 선택지의 위젯 키
  static Key optionKeyOf(Handedness value) =>
      ValueKey('handedness-option-${value.storageValue}');

  /// 닫기 버튼 위젯 키
  static const Key closeKey = ValueKey('handedness-dialog-close');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = SettingsStrings.of(context);
    return AlertDialog(
      // 작은 창·큰 글자 배율에서도 넘치지 않게 제목·내용을 스크롤한다 (#72 R1 — 열린 채 창이 줄어드는 경우 포함).
      scrollable: true,
      title: Text(strings.handednessTitle),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: RadioGroup<Handedness>(
        groupValue: ref.watch(handednessProvider),
        onChanged: (value) {
          if (value != null) ref.read(handednessProvider.notifier).set(value);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final value in Handedness.values)
              RadioListTile<Handedness>(
                key: optionKeyOf(value),
                value: value,
                title: Text(strings.handedness(value)),
                subtitle: Text(strings.handednessDetail(value)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: closeKey,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.close),
        ),
      ],
    );
  }
}
