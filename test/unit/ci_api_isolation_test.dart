import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../support/workflows.dart';

/// 릴리스 APK의 새 API 참조 격리 검사(#109)의 CI 잡 구성과 규칙 파일을 지킨다.
///
/// - Sub-issue CI와 Milestone CI에 같은 잡을 둔다.
/// - 잡은 R8이 도는 릴리스 APK를 빌드한 뒤 검사 스크립트를 그 APK와 mapping.txt로 돌린다.
/// - 규칙 파일(`.github/api-isolation-rules`)의 allow가 Kotlin 소스의 격리 object와 맞는다:
///   guard-api 이상의 `object Api<N>`마다 그 object와 합성 람다가 허용되고, 앱 패키지의 allow는 소스에 있는 object를 가리킨다.
///
/// 스크립트 동작은 `api_isolation_script_test.dart`가, 실제 R8 결과물과의 대조는 CI 실행이 확인한다.

const _jobId = 'android-release-api-isolation';

const _workflows = [
  '.github/workflows/subissue-linux-ci.yml',
  '.github/workflows/milestone-full-ci.yml',
];

const _rulesPath = '.github/api-isolation-rules';

const _verifyCommand =
    'bash .github/scripts/verify-api-isolation.sh '
    'build/app/outputs/flutter-apk/app-release.apk '
    'build/app/outputs/mapping/release/mapping.txt';

const _kotlinRoot = 'android/app/src/main/kotlin';

YamlMap _job(String workflow) {
  final jobs = loadYamlFile(workflow)['jobs'] as YamlMap;
  expect(jobs[_jobId], isA<YamlMap>(), reason: '$workflow: $_jobId 잡이 없다');
  return jobs[_jobId] as YamlMap;
}

List<YamlMap> _steps(String workflow) =>
    (_job(workflow)['steps'] as YamlList).cast<YamlMap>().toList();

int _stepIndex(List<YamlMap> steps, bool Function(String run) test) =>
    steps.indexWhere((s) => test('${s['run'] ?? ''}'.trim()));

/// 규칙 파일: guard-api 값과 allow glob 목록 (형식 오류는 스크립트가 실패시키지만 여기서도 먼저 잡는다)
({int guard, List<String> allows}) _rules() {
  int? guard;
  final allows = <String>[];
  for (final raw in File(_rulesPath).readAsLinesSync()) {
    final line = raw.split('#').first.trim();
    if (line.isEmpty) continue;
    final parts = line.split(RegExp(r'\s+'));
    expect(parts, hasLength(2), reason: '형식: "$raw"');
    switch (parts.first) {
      case 'guard-api':
        expect(guard, isNull, reason: 'guard-api가 두 번 있다');
        guard = int.parse(parts[1]);
      case 'allow':
        allows.add(parts[1]);
      default:
        fail('모르는 지시어: "$raw"');
    }
  }
  expect(guard, isNotNull, reason: 'guard-api가 없다');
  return (guard: guard!, allows: allows);
}

/// 앱 Kotlin 소스의 `Api<N>` 격리 object: `<패키지>.<바깥 클래스>$Api<N>` → N
Map<String, int> _isolationObjects() {
  final result = <String, int>{};
  for (final file in Directory(
    _kotlinRoot,
  ).listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.kt')) continue;
    final source = file.readAsStringSync();
    final package = RegExp(
      r'^package ([\w.]+)',
      multiLine: true,
    ).firstMatch(source)?[1];
    // 맨 앞 열의 클래스 선언 = 바깥 클래스 (격리 object는 그 안에 들여 쓴다)
    final outer = RegExp(
      r'^(?:\w+ )*class (\w+)',
      multiLine: true,
    ).firstMatch(source)?[1];
    for (final m in RegExp(
      r'^[ \t]+(?:private |internal )?object (Api(\d+))\b',
      multiLine: true,
    ).allMatches(source)) {
      expect(package, isNotNull, reason: '${file.path}: package 선언이 없다');
      expect(outer, isNotNull, reason: '${file.path}: 바깥 클래스를 찾지 못했다');
      result['$package.$outer\$${m[1]}'] = int.parse(m[2]!);
    }
  }
  return result;
}

void main() {
  test('두 워크플로의 격리 검사 잡이 같다', () {
    final jobs = [for (final w in _workflows) _job(w)];
    expect(_plain(jobs.last), _plain(jobs.first));
  });

  for (final workflow in _workflows) {
    group(workflow, () {
      test('릴리스 APK(R8)를 빌드한 뒤 그 APK와 mapping.txt로 검사한다', () {
        final steps = _steps(workflow);
        final build = _stepIndex(
          steps,
          (run) => RegExp(r'^flutter build apk\b.*--release\b').hasMatch(run),
        );
        expect(build, isNot(-1), reason: '릴리스 APK 빌드 단계가 없다');
        // --config-only·--debug 빌드는 R8을 돌리지 않는다
        expect('${steps[build]['run']}', isNot(contains('--config-only')));
        expect('${steps[build]['run']}', isNot(contains('--debug')));
        final verify = _stepIndex(steps, (run) => run == _verifyCommand);
        expect(
          verify,
          greaterThan(build),
          reason: '"$_verifyCommand" 단계가 빌드 뒤에 있어야 한다',
        );
        for (final i in [build, verify]) {
          // 실패를 삼키는 설정이 붙으면 격리가 깨져도 잡이 통과한다
          expect(steps[i].containsKey('continue-on-error'), isFalse);
          expect(steps[i].containsKey('if'), isFalse);
        }
        final clean = _stepIndex(
          steps,
          (run) => run == 'bash .github/scripts/verify-clean-tree.sh',
        );
        expect(
          clean,
          greaterThan(verify),
          reason: '빌드 뒤 작업 트리 검사(#67)가 있어야 한다',
        );
      });

      test('잡이 실패를 삼키거나 건너뛰지 않고, 시간 제한이 있다', () {
        final job = _job(workflow);
        expect(job.containsKey('continue-on-error'), isFalse);
        expect(
          job['if'],
          "github.event_name == 'push' || github.event.pull_request.draft == false",
        );
        expect(
          job['timeout-minutes'],
          isA<int>().having((m) => m, '분', inInclusiveRange(15, 60)),
        );
      });
    });
  }

  group('규칙 파일', () {
    test('R8 API 아웃라인을 허용한다', () {
      expect(
        _rules().allows,
        contains(r'*$$ExternalSyntheticApiModelOutline*'),
      );
    });

    test('guard-api 이상의 격리 object마다 그 object와 합성 람다가 허용된다', () {
      final rules = _rules();
      final objects = _isolationObjects();
      // 이 검사가 헛돌지 않게 — 지금 앱에는 고대비 텍스트 API 36 격리가 있다 (#95)
      expect(
        objects,
        contains(
          'com.example.itechnika_altcalc_fx991.HighTextContrastStreamHandler\$Api36',
        ),
      );
      for (final MapEntry(key: name, value: level) in objects.entries) {
        if (level < rules.guard) continue;
        expect(
          rules.allows,
          contains(name),
          reason: '$_rulesPath에 "allow $name"이 없다',
        );
        expect(
          rules.allows,
          contains('$name\$\$*'),
          reason: '$_rulesPath에 "allow $name\$\$*"(합성 람다)가 없다',
        );
      }
    });

    test('앱 패키지를 가리키는 allow는 소스에 있는 격리 object다', () {
      final namespace = RegExp(r'namespace = "([\w.]+)"').firstMatch(
        File('android/app/build.gradle.kts').readAsStringSync(),
      )![1]!;
      final objects = _isolationObjects().keys.toSet();
      for (final allow in _rules().allows) {
        if (!allow.startsWith('$namespace.')) continue;
        final base = allow.endsWith(r'$$*')
            ? allow.substring(0, allow.length - 3)
            : allow;
        // 격리 object를 지우거나 이름을 바꾸고 allow를 남기면 그 이름의 클래스에 무엇이든 허용하게 된다
        expect(
          objects,
          contains(base),
          reason: '"allow $allow"가 가리키는 격리 object가 소스에 없다',
        );
      }
    });
  });
}

/// YAML 노드를 일반 Dart 값으로 바꾼다 (내용 비교용)
Object? _plain(Object? node) => switch (node) {
  YamlMap() => {
    for (final MapEntry(:key, :value) in node.entries)
      _plain(key): _plain(value),
  },
  YamlList() => [for (final v in node) _plain(v)],
  _ => node,
};
