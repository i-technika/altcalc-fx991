import 'package:material_ui/material_ui.dart';

import '../l10n/calc_semantic_strings.dart';
import 'lcd_display.dart';

/// 계산 기록 영역 (#142, #143) — 지금 놓이는 곳은 책 자세(`CalcHingeSplitLayout`)뿐이다: 손 쪽 반대 패널 전체 (손 쪽 패널이
/// 짧은 창은 그 패널의 활성 LCD 아래).
///
/// 2026-11-28 사용자 결정으로 계산 기록 목록(#145)은 하지 않고 기록 영역은 없앤다. 가로형·가로 접힘선 배치는 #284에서 기록
/// 영역 자리를 LCD에 붙였고, 책 자세는 #285에서 태블릿 가로형처럼 바꾸며 이 위젯을 지운다.
///
/// LCD와 같은 바탕·베젤로 그린다. 점 격자는 그리지 않아 활성 LCD와 구별된다. 내용은 없다(빈 영역).
/// 스크린리더에는 빈 영역임을 알리는 노드 하나로 보인다([CalcSemanticStrings.historyEmpty]).
/// 터치는 받지 않는다.
class HistoryPanel extends StatelessWidget {
  const HistoryPanel({super.key});

  /// 기록 영역 위젯 키 (테스트용)
  static const Key panelKey = ValueKey('history-panel');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: panelKey,
      container: true,
      label: CalcSemanticStrings.of(context).historyEmpty,
      child: const DecoratedBox(
        decoration: lcdBezelDecoration,
        child: SizedBox.expand(),
      ),
    );
  }
}
