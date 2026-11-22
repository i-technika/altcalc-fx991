import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/models/handedness.dart';
import '../l10n/settings_strings.dart';
import '../providers/settings_provider.dart';
import 'focus_ring.dart';

/// 키패드 위치(손잡이) 선택 대화상자 (#24).
///
/// 손잡이가 지금 배치에 영향이 없으면([showLayoutNote], 위아래 배치) 선택지 아래에 그 안내
/// ([SettingsStrings.handednessNote])를 둔다 — 설정 버튼은 폰의 위아래 배치에도 있는데(#41), 그 배치에서는
/// 손잡이를 바꿔도 달라지는 것이 없다. 선택지 아래에 두어 작은 창에서도 선택지가 먼저 보이게 하고, 라디오 그룹
/// 밖에 두어 그룹의 일부로 읽히지 않게 한다.
///
/// 고르면 설정을 바로 저장하고, 대화상자 뒤의 키패드도 바로 옮겨진다(미리 보기). 닫기는 "닫기" 버튼이나
/// 바깥 탭·뒤로가기로 한다 — 고를 때 닫지 않는 이유: 표준 라디오 그룹([RadioGroup])은 키보드 화살표로
/// 포커스를 옮기면 선택도 함께 바뀌므로, 고를 때 닫으면 화살표 한 번에 설정이 바뀌고 대화상자가 닫힌다.
/// 스크린리더에는 단일 선택 그룹·선택 상태로 알려진다.
///
/// 키보드 포커스가 있는 선택지·닫기 버튼에는 [FocusRing] 테두리를 그린다 (고대비 #97, 일반 모드 #106).
class HandednessDialog extends ConsumerWidget {
  /// 손잡이 설정이 지금 배치에 영향이 없다는 안내를 보일지
  final bool showLayoutNote;

  const HandednessDialog({super.key, this.showLayoutNote = false});

  /// [value] 선택지의 위젯 키
  static Key optionKeyOf(Handedness value) =>
      ValueKey('handedness-option-${value.storageValue}');

  /// 닫기 버튼 위젯 키
  static const Key closeKey = ValueKey('handedness-dialog-close');

  /// 적용 화면 안내 글 위젯 키
  static const Key noteKey = ValueKey('handedness-dialog-note');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = SettingsStrings.of(context);
    // 대화상자 가장자리 선(고대비)은 내용 위에 그려지므로, 선택지 포커스 테두리를 선이 안쪽으로 들어오는 폭만큼
    // 안쪽에 그린다. 선이 없는 일반 모드는 0 — 테두리가 타일 전체를 두른다.
    // 대화상자 모양은 테마에서 온다 — 아래 AlertDialog에 shape를 따로 주면 여기서도 그 모양을 읽어야 한다.
    final dialogEdge = switch (DialogTheme.of(context).shape) {
      OutlinedBorder(:final side) when side.style != BorderStyle.none =>
        side.strokeInset,
      _ => 0.0,
    };
    return AlertDialog(
      title: Text(strings.handednessTitle),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      // 작은 창·큰 글자 배율에서도 넘치지 않게 안내 글·선택지만 스크롤한다 — 제목·닫기 버튼은 고정 (#72, 열린 채
      // 창이 줄어드는 경우 포함). AlertDialog는 content를 남는 높이 안에 두므로 스크롤 뷰가 그 높이를 받는다.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _options(ref, strings, dialogEdge),
            if (showLayoutNote)
              // 좌우 여백은 AlertDialog 제목과 같은 24dp (M3 기본값)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Text(
                  strings.handednessNote,
                  key: noteKey,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
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

  /// 손잡이 선택지 라디오 그룹. [dialogEdge]는 포커스 테두리를 대화상자 가장자리 선 안쪽으로 들일 폭이다.
  Widget _options(WidgetRef ref, SettingsStrings strings, double dialogEdge) {
    return RadioGroup<Handedness>(
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
                        alignmentPolicy:
                            ScrollPositionAlignmentPolicy.keepVisibleAtStart,
                      );
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
