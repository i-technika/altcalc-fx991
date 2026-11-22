import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// CI·로컬의 Flutter SDK 버전 고정(#78)이 깨지지 않게 지킨다.
/// 기준값은 `pubspec.yaml`의 `environment.flutter` 하나이고, CI 워크플로의 모든 SDK 설치 단계가
/// `flutter-version-file`로 이 값을 읽는지, README가 같은 버전을 적는지 확인한다.
/// 실제로 그 버전이 설치되는지는 CI의 `flutter-action`과 pub의 SDK 제약 검사가 지킨다.
/// `pubspec.lock` 커밋 누락은 여기서 검사하지 않는다 — `flutter test`가 먼저 pub get으로 lock을 다시 쓰므로
/// 작업 트리 파일로는 알 수 없고, CI의 작업 트리 검사(`.github/scripts/verify-clean-tree.sh`)가 잡는다.

/// 정확한 버전 `X.Y.Z` (범위·`^`·프리릴리스 표기 금지 — flutter-action이 정확한 버전만 받는다)
final _exactVersion = RegExp(r'^\d+\.\d+\.\d+$');

/// Flutter SDK를 설치하는 액션
const _flutterAction = 'subosito/flutter-action@';

YamlMap _loadYaml(String path) =>
    loadYaml(File(path).readAsStringSync(), sourceUrl: Uri.file(path))
        as YamlMap;

/// `pubspec.yaml`의 `environment.flutter` 고정값
String _pinnedVersion() {
  final env = _loadYaml('pubspec.yaml')['environment'] as YamlMap?;
  final flutter = env?['flutter'];
  expect(
    flutter,
    isA<String>(),
    reason: 'pubspec.yaml에 environment.flutter가 없다',
  );
  return flutter as String;
}

/// `.github/workflows/`의 워크플로 파일
List<File> _workflowFiles() {
  final files =
      Directory('.github/workflows')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}

void main() {
  test('environment.flutter는 정확한 버전(X.Y.Z) 하나다', () {
    expect(_pinnedVersion(), matches(_exactVersion));
  });

  test('워크플로의 모든 잡이 pubspec.yaml 고정 버전으로 Flutter를 설치한다', () {
    final files = _workflowFiles();
    expect(files, isNotEmpty, reason: '.github/workflows에 워크플로가 없다');

    for (final file in files) {
      final jobs = _loadYaml(file.path)['jobs'] as YamlMap;
      for (final MapEntry(key: jobId, value: job) in jobs.entries) {
        final where = '${file.path} → $jobId';
        final rawSteps = (job as YamlMap)['steps'];
        // 재사용 워크플로를 부르는 잡(잡 수준 `uses:`)은 steps가 없다 — 그쪽 워크플로의 고정을 따로 확인해야 한다
        expect(
          rawSteps,
          isA<YamlList>(),
          reason: '$where: steps가 없는 잡은 이 검사가 다루지 않는다',
        );
        final steps = (rawSteps as YamlList).cast<YamlMap>();
        final setups = steps
            .where((s) => '${s['uses'] ?? ''}'.startsWith(_flutterAction))
            .toList();
        // 지금은 모든 잡이 flutter 명령을 쓴다. Flutter가 필요 없는 잡이 생기면 여기서 예외로 둔다.
        expect(setups, hasLength(1), reason: '$where: Flutter 설치 단계가 하나여야 한다');

        final withMap = setups.single['with'] as YamlMap?;
        expect(
          withMap?['flutter-version-file'],
          'pubspec.yaml',
          reason: '$where: flutter-version-file: pubspec.yaml로 버전을 읽어야 한다',
        );
        // 버전을 따로 적거나 채널만 지정하면 고정값과 어긋날 수 있다
        // (flutter-version과 함께 쓰면 액션이 오류를 내고, channel은 기본값 stable이면 충분하다)
        for (final key in ['flutter-version', 'channel']) {
          expect(
            withMap!.containsKey(key),
            isFalse,
            reason: '$where: $key를 함께 지정하지 않는다',
          );
        }
      }
    }
  });

  test('README 개발 환경 절이 고정 버전을 적는다', () {
    final readme = File('README.md')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    final start = RegExp(
      r'^## 개발 환경[ \t]*$',
      multiLine: true,
    ).firstMatch(readme);
    expect(start, isNotNull, reason: 'README에 "## 개발 환경" 절이 없다');
    final next = RegExp(
      r'^## ',
      multiLine: true,
    ).allMatches(readme).where((m) => m.start > start!.start).firstOrNull;
    final section = readme.substring(
      start!.start,
      next?.start ?? readme.length,
    );
    // README에서 구체 버전을 적는 곳은 이 한 줄뿐이다 (다른 문서는 pubspec.yaml을 가리킨다)
    final versions = [
      for (final m in RegExp(
        r'^- Flutter (\S+) — ',
        multiLine: true,
      ).allMatches(section))
        m[1],
    ];
    expect(versions, [
      _pinnedVersion(),
    ], reason: 'README "개발 환경"의 Flutter 버전 줄을 pubspec.yaml 고정값과 맞출 것');
  });
}
