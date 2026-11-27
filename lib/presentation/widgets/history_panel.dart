import 'package:material_ui/material_ui.dart';

import '../l10n/calc_semantic_strings.dart';
import 'lcd_display.dart';

/// 계산 기록 영역 (#142, #143) — 놓이는 곳:
/// - 가로형 배치(`CalcLandscapeLayout`)와 가로 접힘선의 넓은 배열(`CalcTabletopLayout`): 위 띠(위 패널)에서 함수부 위,
///   활성 LCD 옆
/// - 책 자세(`CalcHingeSplitLayout`): 손 쪽 반대 패널 전체 (손 쪽 패널이 짧은 창은 그 패널의 활성 LCD 아래)
/// - 가로 접힘선의 실물 배열(Flip 내부, `CalcTabletopLayout`): 위 패널에서 활성 LCD 아래
///
/// LCD와 같은 바탕·베젤로 그린다 — 기록은 LCD 자리가 실물 비율보다 넓게 남는 곳에 두는 "LCD의 연장"이다(#141 결정).
/// 점 격자는 그리지 않아 지금 입력 중인 활성 LCD와 구별된다.
///
/// 가로형에서는 위 띠 높이 전체를 쓴다 — 옆의 활성 LCD는 실물 비율 높이까지만이라 위 띠가 높으면 기록 영역이 더 높다(#142 R2).
///
/// M1에서는 비어 있다. 이전 계산 목록(최근 순)·스크롤·스크린리더가 기록을 읽는 방식은 #145에서 정한다.
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
