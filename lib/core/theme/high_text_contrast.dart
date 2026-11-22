import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Android 접근성 "고대비 텍스트"(Android 15 이상 이름은 "텍스트 대비 최대화") 켜짐 여부 (#95).
///
/// 이 설정은 시스템이 그리는 글자에 외곽선을 넣는 기능이라 글자를 직접 그리는 Flutter 화면에는 효과가 없고,
/// Flutter 엔진은 이 설정을 `MediaQuery.highContrast`에 넣지 않는다(엔진은 Android 14 이상 "색상 대비"만 읽는다).
/// 그래서 이 설정을 켠 사용자에게도 고대비 팔레트를 주도록 앱이 직접 읽는다 — Android 13 이하에서는 대비에 관한
/// 시스템 신호가 이것뿐이다. [CalcPalette.of]가 `MediaQuery.highContrast`와 함께 쓴다.
///
/// Android 쪽(`HighTextContrastStreamHandler.kt`)이 구독 시작 때 지금 값을 한 번, 그 뒤 바뀔 때마다 보낸다.
/// Android가 아닌 플랫폼(iOS·웹·데스크톱)에서는 구독하지 않고 늘 `false`다.
class SystemHighTextContrast extends ValueNotifier<bool> {
  /// 테스트는 따로 만든 인스턴스를 쓴다. 앱은 [instance] 하나만 쓴다.
  @visibleForTesting
  SystemHighTextContrast() : super(false);

  /// 앱 전체에서 하나만 쓴다 (`main()`이 [start]한다)
  static final SystemHighTextContrast instance = SystemHighTextContrast();

  /// 설정 값 이벤트 채널 (값: `bool`)
  static const EventChannel channel = EventChannel(
    'altcalc/accessibility/high_text_contrast',
  );

  /// [start]가 첫 값을 기다리는 최대 시간. 넘기면 꺼진 것으로 시작하고, 값이 늦게 오면 그때 바꾼다.
  static const Duration firstValueTimeout = Duration(milliseconds: 500);

  StreamSubscription<Object?>? _subscription;

  /// 구독 중인지 여부
  @visibleForTesting
  bool get isListening => _subscription != null;

  /// 설정 구독을 시작하고 첫 값(또는 [firstValueTimeout])을 기다린다. 첫 화면부터 맞는 팔레트로 그리기 위해
  /// `main()`이 앱 시작 전에 기다린다. 여러 번 불러도 구독은 한 번이다. 실패해도 오류를 내보내지 않는다(꺼짐 유지).
  Future<void> start() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_subscription != null) return;
    final first = Completer<void>();
    void completeFirst() {
      if (!first.isCompleted) first.complete();
    }

    _subscription = channel.receiveBroadcastStream().listen(
      (event) {
        // bool이 아닌 값은 무시한다 (채널 규약 위반)
        if (event is bool) value = event;
        completeFirst();
      },
      onError: (Object error) {
        debugPrint('고대비 텍스트 설정 수신 실패: $error');
        completeFirst();
      },
    );
    await first.future.timeout(firstValueTimeout, onTimeout: () {});
  }

  /// 구독을 끝내고 값을 꺼짐으로 되돌린다 (테스트용). 플랫폼 쪽 구독 해제 응답은 기다리지 않는다.
  @visibleForTesting
  void stop() {
    _cancel();
    value = false;
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  void _cancel() {
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
  }
}

/// 하위 위젯에 시스템 "고대비 텍스트" 켜짐 여부([SystemHighTextContrast])를 알리고, 바뀌면 의존하는 위젯만
/// 다시 빌드한다 (#95). 앱 루트(`MaterialApp.builder`)에 한 번 둔다.
class HighTextContrastScope extends InheritedNotifier<ValueListenable<bool>> {
  const HighTextContrastScope({
    super.key,
    required ValueListenable<bool> super.notifier,
    required super.child,
  });

  /// 가장 가까운 범위의 값. 범위 밖(위젯 단독 테스트·개발 도구 등)이면 `false`.
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<HighTextContrastScope>()
          ?.notifier
          ?.value ??
      false;
}
