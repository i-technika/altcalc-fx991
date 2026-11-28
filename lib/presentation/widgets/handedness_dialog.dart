import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/models/handedness.dart';
import '../l10n/settings_strings.dart';
import '../providers/settings_provider.dart';
import 'focus_ring.dart';

/// 키패드 위치(손잡이) 선택 대화상자 (#24).
///
/// 손잡이가 지금 배치의 키패드 위치에 영향이 없으면([showLayoutNote] — 위아래 배치, 실물 배열 키패드가 아래 패널 폭을
/// 다 쓰는 가로 접힘선 기준 배치(Flip 내부, #143)) 선택지 아래에 그 안내
/// ([SettingsStrings.handednessNote])를 둔다 — 설정(ON 키, #190)은 폰의 위아래 배치에서도 열리는데, 그 배치에서는
/// 손잡이를 바꿔도 달라지는 것이 없다. 선택지 아래에 두어 작은 창에서도 선택지가 먼저 보이게 하고, 라디오 그룹
/// 밖에 두어 그룹의 일부로 읽히지 않게 한다.
///
/// 가로형 배치(#142)와 가로 접힘선의 넓은 배열(#143)에서는 숫자부가 고른 손 쪽으로, 함수부가 반대쪽으로 옮겨 간다(LCD는
/// 본체 폭 전체라 그대로다, #284). 책 자세(#143)는 키패드(와 활성 LCD)가 고른 손 쪽 패널로, 기록이 반대쪽 패널로 옮겨 간다 — 손 쪽
/// 패널이 짧은 창은 키패드만 손 쪽 패널이고 활성 LCD·기록은 반대쪽 패널이다.
///
/// 고르면 설정을 바로 저장하고, 대화상자 뒤의 키패드도 바로 옮겨진다(미리 보기). 닫기는 "닫기" 버튼이나
/// 바깥 탭·뒤로가기로 한다 — 고를 때 닫지 않는 이유: 표준 라디오 그룹([RadioGroup])은 키보드 화살표로
/// 포커스를 옮기면 선택도 함께 바뀌므로, 고를 때 닫으면 화살표 한 번에 설정이 바뀌고 대화상자가 닫힌다.
/// 스크린리더에는 단일 선택 그룹·선택 상태로 알려진다.
/// 세로 접힘선 기준 배치에서 고르면 키패드(와 ON 키)는 반대쪽 절반으로 옮겨 가지만 대화상자는 연 자리에 남는다
/// (#94, `SettingsLauncher` "대화상자가 열린 채 손잡이를 바꾸면").
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
      // 작은 창·큰 글자 배율에서도 넘치지 않게 제목·안내 글·선택지를 함께 스크롤한다 — 닫기 버튼은 고정
      // (#72, 열린 채 창이 줄어드는 경우 포함). 제목까지 스크롤하는 이유(#38): 제목을 고정하면 짧은 창에서
      // 제목·닫기 버튼만으로 높이가 모자라 넘친다(360×300 글자 배율 2.0에서 20dp, 320×260 배율 1.3에서 2.2dp).
      scrollable: true,
      content: Column(
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
