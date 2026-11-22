import 'dart:io';

import 'package:yaml/yaml.dart';

/// CI 워크플로 구성 테스트(`flutter_sdk_pin_test`, `ci_actions_test`, `ci_android_unit_test_test`)가 함께 쓰는 도구.
/// 경로는 패키지 루트(= `flutter test`의 작업 디렉터리) 기준이다.

/// `.github/workflows/`의 워크플로 파일 (경로순)
List<File> workflowFiles() =>
    Directory('.github/workflows')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// YAML 파일을 맵으로 읽는다 (오류 위치에 파일 경로가 나오게 `sourceUrl`을 붙인다)
YamlMap loadYamlFile(String path) =>
    loadYaml(File(path).readAsStringSync(), sourceUrl: Uri.file(path))
        as YamlMap;
