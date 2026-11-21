import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';

import '../support/bundled_fonts.dart';

/// #11 메모(#16): 키패드는 라벨 폭을 글꼴로 재서 캐시한다(`_LabelWidthLimits._emWidthCache`).
/// 글꼴이 나중에 로드되면 캐시가 비워져 새 글꼴로 다시 재야 한다.
///
/// 앱 번들 글꼴은 엔진이 시작할 때 등록하지만, 글꼴을 동적으로 로드하는 경로(`FontLoader`,
/// 웹의 지연 로드)는 `fontsChange` 시스템 메시지로 [PaintingBinding.systemFonts]를 알린다.
/// 이 파일은 "번들 글꼴 로드 전" 상태가 필요하므로 다른 글꼴 테스트와 분리한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('글꼴을 나중에 로드하면 라벨 폭 캐시가 갱신되어 글자 크기가 다시 계산된다', () async {
    // 테스트 글꼴은 모든 글자가 1em 정사각형이라 `SHIFT`가 5em으로 넓다 → 폭 기준에 걸린다.
    const size = Size(360, 420);
    final before = KeypadMetrics.compute(size, TextScaler.noScaling);

    var notified = 0;
    void listener() => notified++;
    PaintingBinding.instance.systemFonts.addListener(listener);
    addTearDown(
      () => PaintingBinding.instance.systemFonts.removeListener(listener),
    );

    await loadBundledFonts();
    await pumpEventQueue();
    expect(notified, greaterThan(0), reason: 'fontsChange → systemFonts 알림');

    // Noto Sans Mono는 0.6em 고정폭이라 같은 라벨이 좁아져 더 큰 글자가 들어간다.
    // 캐시가 비워지지 않았다면 테스트 글꼴 폭으로 잰 값이 남아 크기가 그대로였을 것이다.
    final after = KeypadMetrics.compute(size, TextScaler.noScaling);
    expect(after.mainLabelFontSize, greaterThan(before.mainLabelFontSize));
  });
}
