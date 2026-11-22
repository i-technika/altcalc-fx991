import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';
import '../../domain/models/handedness.dart';
import '../l10n/settings_strings.dart';
import '../providers/settings_provider.dart';

/// 키패드 위치(손잡이) 선택 대화상자 (#24).
///
/// 고르면 설정을 바로 저장하고, 대화상자 뒤의 키패드도 바로 옮겨진다(미리 보기). 닫기는 "닫기" 버튼이나
/// 바깥 탭·뒤로가기로 한다 — 고를 때 닫지 않는 이유: 표준 라디오 그룹([RadioGroup])은 키보드 화살표로
/// 포커스를 옮기면 선택도 함께 바뀌므로, 고를 때 닫으면 화살표 한 번에 설정이 바뀌고 대화상자가 닫힌다.
/// 스크린리더에는 단일 선택 그룹·선택 상태로 알려진다.
///
/// 기기 고대비 설정에서는 키보드로 포커스한 선택지에 테두리([CalcPalette.materialFocusRing])를 그린다 —
/// Material 기본 포커스 겹침은 대화상자 면과 1.5:1뿐이고, ListTile은 상태별 모양을 받지 않아 테마로 줄 수 없다 (#97).
/// 테두리는 Material 포커스 겹침과 같이 키보드 조작 중(`FocusHighlightMode.traditional`)에만 보인다.
class HandednessDialog extends ConsumerStatefulWidget {
  const HandednessDialog({super.key});

  /// [value] 선택지의 위젯 키
  static Key optionKeyOf(Handedness value) =>
      ValueKey('handedness-option-${value.storageValue}');

  /// 닫기 버튼 위젯 키
  static const Key closeKey = ValueKey('handedness-dialog-close');

  /// [value] 선택지의 포커스 테두리 위젯 키
  static Key focusRingKeyOf(Handedness value) =>
      ValueKey('handedness-focus-ring-${value.storageValue}');

  @override
  ConsumerState<HandednessDialog> createState() => _HandednessDialogState();
}

class _HandednessDialogState extends ConsumerState<HandednessDialog> {
  /// 포커스를 가진 선택지 (없으면 `null`)
  Handedness? _focused;

  /// 키보드 조작 중인지 (포커스 표시를 보일지)
  bool _traditional =
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChanged);
    super.dispose();
  }

  void _onHighlightModeChanged(FocusHighlightMode mode) {
    final traditional = mode == FocusHighlightMode.traditional;
    if (traditional != _traditional) {
      setState(() => _traditional = traditional);
    }
  }

  void _onFocusChange(Handedness value, bool focused) {
    final next = focused ? value : (_focused == value ? null : _focused);
    if (next != _focused) setState(() => _focused = next);
  }

  @override
  Widget build(BuildContext context) {
    final strings = SettingsStrings.of(context);
    final ring = CalcPalette.of(context).materialFocusRing;
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
                Builder(
                  builder: (tileContext) => DecoratedBox(
                    key: HandednessDialog.focusRingKeyOf(value),
                    position: DecorationPosition.foreground,
                    decoration:
                        ring != null && _traditional && _focused == value
                        ? BoxDecoration(
                            border: Border.all(
                              color: ring,
                              width: CalcTheme.materialFocusRingWidth,
                            ),
                          )
                        : const BoxDecoration(),
                    child: RadioListTile<Handedness>(
                      key: HandednessDialog.optionKeyOf(value),
                      value: value,
                      title: Text(strings.handedness(value)),
                      subtitle: Text(strings.handednessDetail(value)),
                      onFocusChange: (focused) {
                        _onFocusChange(value, focused);
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
        TextButton(
          key: HandednessDialog.closeKey,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.close),
        ),
      ],
    );
  }
}
