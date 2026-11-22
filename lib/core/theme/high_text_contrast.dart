import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Android 접근성 "고대비 텍스트"(설정 키 `high_text_contrast_enabled`) 켜짐 여부 (#95).
///
/// 이 설정은 시스템이 그리는 글자에 외곽선 등을 넣는 기능이라 글자를 직접 그리는 Flutter 화면에는 효과가 없고,
/// Flutter 엔진은 이 설정을 `MediaQuery.highContrast`에 넣지 않는다(엔진은 Android 14 이상 "색상 대비"만 읽는다).
/// 그래서 이 설정을 켠 사용자에게도 고대비 팔레트를 주도록 앱이 직접 읽는다 — Android 13 이하에서는 대비에 관한
/// 시스템 신호가 이것뿐이다. [CalcPalette.of]가 `MediaQuery.highContrast`와 함께 쓴다.
///
/// Android 쪽(`HighTextContrastStreamHandler.kt`)이 구독 시작 때 지금 값을 한 번, 그 뒤 바뀔 때마다 보낸다.
/// Android가 아닌 플랫폼(iOS·웹·데스크톱)에서는 구독하지 않고 늘 `false`다.
/// 값은 플랫폼만 바꾼다 — 밖에는 읽기 전용([ValueListenable])으로만 내보낸다.
class SystemHighTextContrast implements ValueListenable<bool> {
  /// 테스트는 따로 만든 인스턴스를 쓴다. 앱은 [instance] 하나만 쓴다.
  @visibleForTesting
  SystemHighTextContrast();

  /// 앱 전체에서 하나만 쓴다 (`main()`이 [start]한다)
  static final SystemHighTextContrast instance = SystemHighTextContrast();

  /// 설정 값 이벤트 채널 (값: `bool`)
  static const EventChannel channel = EventChannel(
    'altcalc/accessibility/high_text_contrast',
  );

  /// [start]가 첫 값을 기다리는 최대 시간. 넘기면 꺼진 것으로 시작하고, 값이 늦게 오면 그때 바꾼다.
  static const Duration firstValueTimeout = Duration(milliseconds: 500);

  final ValueNotifier<bool> _value = ValueNotifier(false);
  StreamSubscription<Object?>? _subscription;

  /// 시작 중이거나 끝난 [start]의 첫 값 대기. 다시 부른 [start]도 같은 대기를 돌려준다.
  Future<void>? _started;

  /// 첫 값 대기를 끝내는 신호. 구독을 끝낼 때도 완료해 남은 대기가 시간 초과까지 남지 않게 한다.
  Completer<void>? _firstValue;

  bool _disposed = false;

  @override
  bool get value => _value.value;

  @override
  void addListener(VoidCallback listener) => _value.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _value.removeListener(listener);

  /// 구독 중인지 여부
  @visibleForTesting
  bool get isListening => _subscription != null;

  /// 설정 구독을 시작하고 첫 값(또는 [firstValueTimeout])을 기다린다. 첫 화면부터 맞는 팔레트로 그리기 위해
  /// `main()`이 앱 시작 전에 기다린다. 여러 번 불러도 구독은 한 번이고, 첫 호출이 끝나기 전에 다시 불러도
  /// 같은 첫 값을 기다린다. 실패해도 오류를 내보내지 않는다(꺼짐 유지):
  /// - 플랫폼이 보낸 오류 이벤트: 기록하고 첫 값 대기를 끝낸다. 구독은 남아 다음 값을 받는다.
  /// - 구독 요청(`listen`) 자체의 실패(채널 미등록·플랫폼 쪽 예외): Flutter가 `FlutterError.reportError`로만
  ///   알리고 스트림에는 오지 않으므로, [firstValueTimeout] 뒤 꺼짐으로 시작한다.
  Future<void> start() {
    assert(!_disposed, 'dispose()한 SystemHighTextContrast는 다시 시작할 수 없다');
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return Future.value();
    }
    return _started ??= _listen();
  }

  Future<void> _listen() async {
    final first = _firstValue = Completer<void>();
    var timedOut = false;
    void completeFirst() {
      if (!first.isCompleted) first.complete();
    }

    _subscription = channel.receiveBroadcastStream().listen(
      (event) {
        // bool이 아닌 값은 무시한다 (채널 규약 위반)
        if (event is bool) _value.value = event;
        completeFirst();
      },
      onError: (Object error) {
        debugPrint('고대비 텍스트 설정 수신 실패: $error');
        completeFirst();
      },
    );
    await first.future.timeout(
      firstValueTimeout,
      onTimeout: () => timedOut = true,
    );
    if (identical(_firstValue, first)) _firstValue = null;
    if (timedOut) {
      debugPrint(
        '고대비 텍스트 설정 첫 값이 ${firstValueTimeout.inMilliseconds}ms 안에 오지 않아 꺼짐으로 시작한다',
      );
    }
  }

  /// 구독을 끝내고 값을 꺼짐으로 되돌린다 (테스트용). 플랫폼 쪽 구독 해제 응답은 기다리지 않는다.
  @visibleForTesting
  void stop() {
    _cancel();
    _value.value = false;
  }

  /// 구독을 끝내고 정리한다 (테스트용 인스턴스 정리)
  @visibleForTesting
  void dispose() {
    _cancel();
    _disposed = true;
    _value.dispose();
  }

  void _cancel() {
    final subscription = _subscription;
    _subscription = null;
    _started = null;
    // 첫 값을 기다리던 start()도 바로 끝낸다 (멈춘 수신기가 시간 초과 기록을 남기지 않게)
    final first = _firstValue;
    _firstValue = null;
    if (first != null && !first.isCompleted) first.complete();
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

  /// 가장 가까운 범위의 값. 범위 밖(위젯 단독 테스트 등)이면 `false`. 개발용 미리보기는 범위 안이지만
  /// 수신을 시작하지 않으므로([SystemHighTextContrast.start]는 `main()`만 부른다) `false`다.
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<HighTextContrastScope>()
          ?.notifier
          ?.value ??
      false;
}
