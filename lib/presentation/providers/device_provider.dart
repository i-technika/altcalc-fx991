import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 폴더블 기기 여부 (#24). `main()`이 앱 시작 시 판정해 override한다
/// (`FormFactor.queryFoldableDevice` — 힌지 신호와 창 배치 정보 첫 값, #70). 기본값 `false` — 테스트·개발 도구는 일반 기기로 본다.
///
/// 폴더블 기기는 접힘 정보(접힘선)가 오기 전까지 좌우 분할 대신 위아래 배치를 쓴다(`FormFactor.arrangementOf`, #25).
/// 단 짧은 변 600dp 미만 창은 화면이 짧은 창 규칙으로 키가 큰 좌우 분할을 고를 수 있다(`CalculatorScreen`, #38) —
/// 접힘선이 가운데면 접힘선 기준 좌우 배치와 영역이 같아 접힘 정보가 와도 거의 튀지 않는다.
final foldableDeviceProvider = Provider<bool>((ref) => false);
