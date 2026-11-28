import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/models/calc_state.dart';
import '../l10n/calc_semantic_strings.dart';
import '../providers/calc_provider.dart';

/// 앱 화면(루트 Navigator, [child]) 위에 스크린리더 알림 노드([ScreenReaderAnnouncer])를 얹는다 (#20, #207).
///
/// 알림 노드를 계산기 화면 안이 아니라 **루트 Navigator 바깥**(Navigator 다음 형제)에 두는 이유: 설정 대화상자 같은
/// 모달 경로의 장벽(`ModalBarrier`의 `BlockSemantics`)은 의미 경계를 만날 때까지 위로 올라가며 **자기보다 앞에 그려진
/// 노드를 모두** 의미 트리에서 뺀다 — 아래 경로뿐 아니라 Navigator 앞에 그려진 형제도 빠진다. 알림 노드가 화면 안에
/// 있으면, SHIFT 대기 중 설정 키(ON)를 누른 프레임에 "시프트 꺼짐"으로 라벨이 바뀌는 그 노드가 대화상자와 함께
/// 빠져서 Android가 읽지 않았다(#207 에뮬레이터 실측). 그래서 이 층은 Navigator **뒤**에 그린다 — 앞으로 Navigator
/// 바깥에 무엇을 더하더라도(예: 광고 영역 #18) 알림 노드가 그것보다도 뒤에 그려져야 한다.
///
/// 노드는 화면 오른쪽 아래 1dp에 두고 터치를 받지 않는다 — 위치 기준 읽기 순서의 맨 뒤라, 알리는 동안 스크린리더를
/// 켜거나 쓸어 넘겨도 다른 노드보다 먼저 초점을 받지 않는다. 알릴 말이 없을 때는 의미 노드 자체를 두지 않는다
/// ([ScreenReaderAnnouncer.clearDelay]).
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
          right: 0,
          bottom: 0,
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
///   - 알린 뒤 [clearDelay]가 지나면 의미 노드를 없앤다(#207). 라벨이 남아 있으면 이 노드가 TalkBack 쓸어 넘기기 초점
///     자리가 되어, 지난 알림(예: 이미 꺼진 시프트의 "시프트 켜짐")을 지금 상태처럼 읽었고 1dp 초점 테두리가 점처럼
///     보였다(#140 에뮬레이터 실측). 라벨만 비우면 빈 라벨로의 liveRegion 변경이 한 번 더 나가므로, 노드를 아예 빼서
///     비우는 순간에는 이벤트가 나가지 않게 한다. 다음 알림 때 새로 생기는 liveRegion 노드는 라벨이 있으면 바로
///     읽힌다(창 크기 안내 `WindowTooSmallNotice`와 같은 동작, #207 TalkBack 16 에뮬레이터 실측).
///
/// 상태 표시줄·입력 줄을 liveRegion으로 두지 않는 이유: 상태 표시줄 전체가 매번 다시 읽히고, 켜짐/꺼짐
/// 의미가 전달되지 않으며, 같은 입력이 이어지면 입력 줄 라벨이 그대로라 읽히지 않는다(리뷰 R2).
class ScreenReaderAnnouncer extends ConsumerStatefulWidget {
  const ScreenReaderAnnouncer({super.key});

  /// 연속된 같은 말을 구분하려고 번갈아 붙이는 글자 (스크린리더는 읽지 않는다)
  static const String repeatMarker = '\u200B';

  /// 알린 뒤 알림 노드를 없애기까지의 시간 (Android). TalkBack은 liveRegion 변경 이벤트를 받는 즉시(실측 수 ms) 노드
  /// 라벨을 읽어 말할 문장을 만들므로, 말하는 동안 노드를 없애도 끊기지 않는다. 앱이나 TalkBack이 바빠 이벤트 처리가
  /// 늦어지는 경우를 넉넉히 덮는 값이다. 이보다 짧은 동안만 지난 문구가 초점 자리에 남는다.
  /// 그 사이 사용자가 쓸어 넘겨 이 노드에 스크린리더 초점을 두었으면, 초점이 떠날 때까지 없애기를 미룬다 — 초점이 있는
  /// 노드를 없애면 초점이 지워져 다음 쓸어 넘기기가 처음부터 다시 시작한다(#207 R2).
  static const Duration clearDelay = Duration(seconds: 2);

  @override
  ConsumerState<ScreenReaderAnnouncer> createState() =>
      _ScreenReaderAnnouncerState();
}

class _ScreenReaderAnnouncerState extends ConsumerState<ScreenReaderAnnouncer> {
  String _message = '';
  bool _marked = false;
  Timer? _clearTimer;

  /// 스크린리더 초점이 이 노드에 있는지 (Android 접근성 초점)
  bool _focused = false;

  /// [ScreenReaderAnnouncer.clearDelay]가 지났지만 초점이 있어 아직 없애지 않았는지
  bool _clearPending = false;

  void _clear() {
    if (!mounted) return;
    if (_focused) {
      _clearPending = true;
      return;
    }
    setState(() {
      _clearPending = false;
      _message = '';
    });
  }

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
          _clearPending = false;
          _clearTimer?.cancel();
          _clearTimer = Timer(ScreenReaderAnnouncer.clearDelay, _clear);
        }
      },
    );
    if (supportsAnnounce) return const SizedBox.shrink();
    // 알릴 말이 없으면 의미 노드를 두지 않는다 — 스크린리더가 초점을 줄 자리도, 비울 때의 변경 이벤트도 없다.
    if (_message.isEmpty) {
      _focused = false;
      return const SizedBox.expand();
    }
    return Semantics(
      key: const ValueKey('screen-reader-announcer'),
      container: true,
      liveRegion: true,
      label: _message,
      onDidGainAccessibilityFocus: () => _focused = true,
      onDidLoseAccessibilityFocus: () {
        _focused = false;
        if (_clearPending) _clear();
      },
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
