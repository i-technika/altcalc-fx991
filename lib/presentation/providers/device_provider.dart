import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 폴더블 기기 여부 (#24). `main()`이 앱 시작 시 힌지 센서로 판정해 override한다
/// (`FormFactor.queryHingeSensor`). 기본값 `false` — 테스트·개발 도구는 일반 기기로 본다.
///
/// 폴더블 기기는 접힘 정보(접힘선)가 오기 전까지 좌우 분할 대신 위아래 배치를 쓴다(`FormFactor.arrangementOf`, #25).
final foldableDeviceProvider = Provider<bool>((ref) => false);
