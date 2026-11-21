import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/key_definitions.dart';
import '../../domain/models/calc_state.dart';
import '../../domain/models/lcd_status.dart';

/// 계산기 전체 상태 provider.
final calcProvider = NotifierProvider<CalcNotifier, CalcState>(
  CalcNotifier.new,
);

/// LCD 상태 표시줄 스냅샷. 모디파이어 등 표시와 관련된 값이 바뀔 때만 갱신된다.
final lcdStatusProvider = Provider<LcdStatus>(
  (ref) => ref.watch(calcProvider.select((s) => s.lcdStatus)),
);

/// 키 입력을 상태 전이([CalcState.pressKey]/[CalcState.repeatKey])로 연결하는 notifier.
///
/// 상태 전이 규칙은 [CalcState]에 순수 함수로 있다. 이 클래스는 UI 이벤트 진입점만 제공한다.
class CalcNotifier extends Notifier<CalcState> {
  @override
  CalcState build() => CalcState.initial;

  /// 키를 한 번 눌렀을 때 (`CalcKeyButton.onPressed`)
  void pressKey(CalcKeyId id) => _update(state.pressKey(id));

  /// 길게 눌러 반복 입력이 발생했을 때 (`CalcKeyButton.onRepeat`)
  void repeatKey(CalcKeyId id) => _update(state.repeatKey(id));

  /// 실제로 바뀐 경우에만 상태를 교체해 불필요한 알림·리빌드를 막는다.
  void _update(CalcState next) {
    if (next != state) state = next;
  }
}
