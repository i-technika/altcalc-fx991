import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/models/handedness.dart';
import '../l10n/settings_strings.dart';
import '../providers/settings_provider.dart';
import 'focus_ring.dart';

/// 키패드 위치(손잡이) 선택 대화상자 (#24).
///
/// 고르면 설정을 바로 저장하고, 대화상자 뒤의 키패드도 바로 옮겨진다(미리 보기). 닫기는 "닫기" 버튼이나
/// 바깥 탭·뒤로가기로 한다 — 고를 때 닫지 않는 이유: 표준 라디오 그룹([RadioGroup])은 키보드 화살표로
/// 포커스를 옮기면 선택도 함께 바뀌므로, 고를 때 닫으면 화살표 한 번에 설정이 바뀌고 대화상자가 닫힌다.
/// 스크린리더에는 단일 선택 그룹·선택 상태로 알려진다.
///
/// 키보드 포커스가 있는 선택지·닫기 버튼에는 [FocusRing] 테두리를 그린다 (고대비 #97, 일반 모드 #106).
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
    // 대화상자 가장자리 선(고대비)은 내용 위에 그려지므로, 선택지 포커스 테두리를 그 굵기만큼 안쪽에 그린다.
    // 선이 없는 일반 모드는 0 — 테두리가 타일 전체를 두른다.
    final dialogEdge = switch (DialogTheme.of(context).shape) {
      OutlinedBorder(:final side) when side.style != BorderStyle.none =>
        side.width,
      _ => 0.0,
    };
    return AlertDialog(
      title: Text(strings.handednessTitle),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      // 작은 창·큰 글자 배율에서도 넘치지 않게 선택지만 스크롤한다 — 제목·닫기 버튼은 고정 (#72, 열린 채
      // 창이 줄어드는 경우 포함). AlertDialog는 content를 남는 높이 안에 두므로 스크롤 뷰가 그 높이를 받는다.
      content: SingleChildScrollView(
        child: RadioGroup<Handedness>(
          groupValue: ref.watch(handednessProvider),
          onChanged: (value) {
            if (value != null) ref.read(handednessProvider.notifier).set(value);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final value in Handedness.values)
                // 키보드 화살표로 포커스가 옮겨 가면 그 선택지를 화면 안으로 스크롤한다 — RadioGroup의 화살표
                // 이동은 포커스만 옮기고 스크롤하지 않는다.
                FocusRing(
                  inset: EdgeInsets.symmetric(horizontal: dialogEdge),
                  child: Builder(
                    builder: (tileContext) => RadioListTile<Handedness>(
                      key: optionKeyOf(value),
                      value: value,
                      title: Text(strings.handedness(value)),
                      subtitle: Text(strings.handednessDetail(value)),
                      onFocusChange: (focused) {
                        if (focused) {
                          Scrollable.ensureVisible(
                            tileContext,
                            alignmentPolicy:
                                ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                          );
                          Scrollable.ensureVisible(
                            tileContext,
                            alignmentPolicy: ScrollPositionAlignmentPolicy
                                .keepVisibleAtStart,
                          );
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        // TextButton의 M3 기본 모양
        FocusRing(
          shape: const StadiumBorder(),
          child: TextButton(
            key: closeKey,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.close),
          ),
        ),
      ],
    );
  }
}
