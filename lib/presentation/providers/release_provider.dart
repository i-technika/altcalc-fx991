import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/key_definitions.dart';

/// 키패드 각인 띠에 인쇄할 기능 (#267) — 값은 배포된 기능([releasedKeyFeatures]) 그대로다.
///
/// 배포 목록은 [releasedKeyFeatures] 한 곳에서 정한다. 이 provider는 그 값을 화면(`CalculatorScreen`의 키패드)에 건네는
/// 통로이고, 테스트가 override해 배포 뒤 모습(예: Base-N의 파랑 각인이 되살아난 v1.3)이나 실물 인쇄 전체를 그려 놓고
/// 배치를 검사한다. 제품 코드에는 override하는 곳이 없다.
/// override는 **그리는 각인만** 바꾼다 — 입력 해석(`CalcState.pressKey`)과 스크린리더 문구는 [releasedKeyFeatures]를 따르므로,
/// 화면에 보이는 각인과 동작이 어긋난다. 개발 도구에서 쓰려면 그 사실을 화면에 알린다.
final releasedKeyFeaturesProvider = Provider<Set<KeyFeature>>(
  (ref) => releasedKeyFeatures,
);
