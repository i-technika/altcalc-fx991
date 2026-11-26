import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 폴더블 기기 여부 (#24). `main()`이 `DeviceOrientationLock.foldableDevice`로 override한다 — 앱 시작 시 판정
/// (`FormFactor.queryFoldableDevice`)에, 그 뒤 화면 정보로 알아본 값(접히는 부분이 보고됨, 커버 ↔ 내부 화면 전환)이
/// 더해진다 (#70). 기본값은 늘 `false` — 테스트·개발 도구는 일반 기기로 본다.
///
/// 값이 아니라 [ValueListenable]인 것은 화면 정보 변화를 받은 그 프레임에 화면 배치가 따라가게 하려는 것이다
/// (`CalculatorScreen`이 [ValueListenableBuilder]로 듣는다).
///
/// 폴더블 기기는 접힘 정보(접힘선)가 오기 전까지 가로형(#142) 대신 위아래 배치를 쓴다(`FormFactor.arrangementOf`, #25).
/// 단 짧은 변 600dp 미만 창은 화면이 짧은 창 규칙으로 키가 큰 가로형을 고를 수 있다(`CalculatorScreen`, #38).
final foldableDeviceProvider = Provider<ValueListenable<bool>>(
  (ref) => const _NotFoldable(),
);

/// 늘 `false`인 [ValueListenable] (기본값 — 바뀌지 않으므로 듣는 쪽을 기억하지 않는다)
class _NotFoldable implements ValueListenable<bool> {
  const _NotFoldable();

  @override
  bool get value => false;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
