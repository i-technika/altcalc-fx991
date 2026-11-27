import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/models/calc_state.dart';
import '../l10n/calc_semantic_strings.dart';
import '../providers/calc_provider.dart';

/// 앱 화면(루트 Navigator, [child]) 위에 스크린리더 알림 노드([ScreenReaderAnnouncer])를 얹는다 (#20, #207).
///
/// 알림 노드를 계산기 화면 안이 아니라 **루트 Navigator 바깥**에 두는 이유: 설정 대화상자 같은 모달 경로는 장벽
/// (`ModalBarrier`의 `BlockSemantics`)으로 그 아래 경로의 의미 노드를 모두 의미 트리에서 뺀다. 알림 노드가 화면 안에
/// 있으면, SHIFT 대기 중 설정 키(ON)를 누른 프레임에 "시프트 꺼짐"으로 라벨이 바뀌는 그 노드가 대화상자와 함께
/// 빠져서 Android가 읽지 않았다(#207 에뮬레이터 실측). Navigator보다 뒤에 그려지는 형제는 막히지 않는다.
///
/// 노드는 화면 왼쪽 위 1dp에 두고 터치를 받지 않는다. 알린 뒤에는 라벨을 비우므로([ScreenReaderAnnouncer.clearDelay])
/// 평소에는 스크린리더가 초점을 줄 수 없는 빈 노드다.
class ScreenReaderAnnouncerLayer extends StatelessWidget {
  /// 앱 화면 (루트 Navigator)
  final Widget child;

  const ScreenReaderAnnouncerLayer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        // Navigator 뒤(위)에 그린다 — 앞에 그리면 모달 장벽이 이 노드도 막는다.
        const Positioned(
          left: 0,
          top: 0,
          width: 1,
          height: 1,
          child: IgnorePointer(child: ScreenReaderAnnouncer()),
        ),
      ],
    );
  }
}

/// 계산기 상태 변화를 스크린리더로 알린다 (#20). 무엇을 알릴지는 [announcementFor]가 정한다.
/// 모달 대화상자에 막히지 않도록 [ScreenReaderAnnouncerLayer]로 루트 Navigator 바깥에 둔다.
///
/// 플랫폼마다 알리는 방법이 다르다 — Flutter 자체 위젯(InputDecorator)과 같은 기준
/// (`MediaQuery.supportsAnnounceOf`)으로 나눈다.
/// - **알림 지원(iOS 등)**: `SemanticsService.sendAnnouncement`. 스크린리더가 꺼져 있으면 보내지 않는다.
/// - **알림 미지원(Android)**: 이 위젯의 liveRegion 노드 라벨을 바꾼다. Android 엔진은 알림을 지원하지 않고
///   (Android 16부터 API 폐기 예정), liveRegion 노드는 **라벨이 바뀔 때만** 읽힌다. 같은 말이 이어져도
///   ("7" → "7") 읽히도록 매번 보이지 않는 문자(U+200B)를 붙였다 뗐다 해 라벨을 바꾼다.
///   - 알린 뒤 [clearDelay]가 지나면 라벨을 비운다(#207). 라벨이 남아 있으면 이 노드가 TalkBack 쓸어 넘기기 초점
///     자리가 되어, 지난 알림(예: 이미 꺼진 시프트의 "시프트 켜짐")을 지금 상태처럼 읽었고 1dp 초점 테두리가 점처럼
///     보였다(#140 에뮬레이터 실측). 비울 때도 liveRegion 변경이 나가지만, 빈 라벨은 읽을 말이 없어 TalkBack이
///     아무것도 말하지 않고 말하던 것도 끊지 않는다(#207 실측).
///
/// 상태 표시줄·입력 줄을 liveRegion으로 두지 않는 이유: 상태 표시줄 전체가 매번 다시 읽히고, 켜짐/꺼짐
/// 의미가 전달되지 않으며, 같은 입력이 이어지면 입력 줄 라벨이 그대로라 읽히지 않는다(리뷰 R2).
class ScreenReaderAnnouncer extends ConsumerStatefulWidget {
  const ScreenReaderAnnouncer({super.key});

  /// 연속된 같은 말을 구분하려고 번갈아 붙이는 글자 (스크린리더는 읽지 않는다)
  static const String repeatMarker = '​';

  /// 알린 뒤 라벨을 비우기까지의 시간 (Android). TalkBack은 liveRegion 변경 이벤트를 받는 즉시(실측 수 ms) 노드 라벨을
  /// 읽어 말할 문장을 만들므로, 말하는 동안 라벨을 비워도 끊기지 않는다. 앱이나 TalkBack이 바빠 이벤트 처리가 늦어지는
  /// 경우를 넉넉히 덮는 값이다. 이보다 짧은 동안만 지난 문구가 초점 자리에 남는다.
  static const Duration clearDelay = Duration(seconds: 2);

  @override
  ConsumerState<ScreenReaderAnnouncer> createState() =>
      _ScreenReaderAnnouncerState();
}

class _ScreenReaderAnnouncerState extends ConsumerState<ScreenReaderAnnouncer> {
  String _message = '';
  bool _marked = false;
  Timer? _clearTimer;

  @override
  void dispose() {
    _clearTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = CalcSemanticStrings.of(context);
    final supportsAnnounce = MediaQuery.supportsAnnounceOf(context);
    final view = View.of(context);
    final direction = Directionality.of(context);
    ref.listen(
      calcProvider.select((s) => (s.modifier, s.inputCount, s.lastInput)),
      (previous, next) {
        // 직전 선택 값이 없으면(오류 등) 비교할 수 없으므로 알리지 않는다.
        if (previous == null) return;
        final message = announcementFor(strings, previous, next);
        if (message == null) return;
        if (supportsAnnounce) {
          if (!SemanticsBinding.instance.semanticsEnabled) return;
          unawaited(
            SemanticsService.sendAnnouncement(view, message, direction),
          );
        } else {
          setState(() {
            _marked = !_marked;
            _message = _marked
                ? message
                : '$message${ScreenReaderAnnouncer.repeatMarker}';
          });
          _clearTimer?.cancel();
          _clearTimer = Timer(ScreenReaderAnnouncer.clearDelay, () {
            if (mounted) setState(() => _message = '');
          });
        }
      },
    );
    if (supportsAnnounce) return const SizedBox.shrink();
    return Semantics(
      key: const ValueKey('screen-reader-announcer'),
      container: true,
      liveRegion: true,
      label: _message,
      child: const SizedBox.expand(),
    );
  }
}

/// 상태 변화([previous] → [next])에 대해 스크린리더로 알릴 말. 알릴 것이 없으면 `null`. (#20)
///
/// 상태는 `(모디파이어 대기, 입력 수, 마지막 입력)`이다.
/// - 기능이 입력되면(입력 수 증가) 그 기능 이름을 알린다. 시프트·알파 대기가 그 입력으로 풀렸다는 것도
///   이것으로 전달된다(예: 시프트 → sin → "아크사인"). 길게 눌러 반복되는 입력은 알리지 않는다.
/// - 입력 없이 대기만 바뀌면: 켜짐("시프트 켜짐"), 또는 꺼짐(같은 키를 다시 누름, 기능 없는 층의 키, 설정 키).
@visibleForTesting
String? announcementFor(
  CalcSemanticStrings strings,
  (KeyModifier, int, KeyInput?) previous,
  (KeyModifier, int, KeyInput?) next,
) {
  final (before, countBefore, _) = previous;
  final (after, countAfter, input) = next;
  if (countAfter != countBefore) {
    if (input == null || input.isRepeat) return null;
    return strings.keyFunction(input.id, input.layer);
  }
  if (before == after) return null;
  if (after != KeyModifier.none) {
    return strings.modifierChanged(after, on: true);
  }
  return strings.modifierChanged(before, on: false);
}
