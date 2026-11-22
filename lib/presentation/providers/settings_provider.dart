import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/handedness.dart';

/// 앱 설정 저장소. `main()`이 앱 시작 전에 불러와 override한다 (#24).
///
/// `null`이면(테스트·개발 도구, 또는 저장소를 열지 못한 경우) 설정은 기본값으로 시작하고
/// 바꾼 값은 앱이 실행되는 동안만 유지된다.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// 키패드를 주로 쓰는 손 설정 (#24).
final handednessProvider = NotifierProvider<HandednessNotifier, Handedness>(
  HandednessNotifier.new,
);

/// [Handedness] 설정을 읽고, 바꾸면 저장소에 저장한다.
class HandednessNotifier extends Notifier<Handedness> {
  /// 저장소 키
  static const String storageKey = 'handedness';

  @override
  Handedness build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return Handedness.fromStorage(prefs?.getString(storageKey));
  }

  /// 설정을 [value]로 바꾸고 저장한다. 화면에는 바로 반영하고, 저장은 기다리지 않는다.
  /// 저장에 실패해도 이번 실행 동안은 바꾼 값을 쓴다(다음 실행에서 이전 값으로 돌아간다).
  void set(Handedness value) {
    if (value == state) return;
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs == null) return;
    unawaited(
      prefs
          .setString(storageKey, value.storageValue)
          .then<void>((saved) {
            if (!saved) debugPrint('손잡이 설정을 저장하지 못했다: $value');
          })
          .catchError((Object error) {
            debugPrint('손잡이 설정 저장 중 오류: $error');
          }),
    );
  }
}

/// 앱 설정 저장소를 연다. 플랫폼 오류로 열지 못하면 `null` — 설정 없이도 앱은 뜬다.
Future<SharedPreferences?> openSettingsStorage() async {
  try {
    return await SharedPreferences.getInstance();
  } catch (error) {
    debugPrint('설정 저장소를 열지 못했다: $error');
    return null;
  }
}
