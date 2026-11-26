import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';
import '../l10n/calc_semantic_strings.dart';

/// 계산 기록 영역 (#142) — 가로형 배치(`CalcLandscapeLayout`)의 위 띠에서 함수부 위, 활성 LCD 옆에 놓는다.
///
/// LCD와 같은 바탕·베젤로 그린다 — 기록은 LCD 자리가 실물 비율보다 넓게 남는 곳에 두는 "LCD의 연장"이다(#141 결정).
/// 점 격자는 그리지 않아 지금 입력 중인 활성 LCD와 구별된다.
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
        decoration: BoxDecoration(
          color: CalcTheme.lcdBackground,
          border: Border.fromBorderSide(
            BorderSide(
              color: CalcTheme.lcdFrame,
              width: CalcTheme.lcdFrameWidth,
            ),
          ),
          borderRadius: BorderRadius.all(
            Radius.circular(CalcTheme.lcdBorderRadius),
          ),
        ),
        child: SizedBox.expand(),
      ),
    );
  }
}
