import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../support/workflows.dart';

/// Android 단위 테스트(Kotlin·Robolectric, #108)를 돌리는 CI 잡의 구성을 지킨다.
///
/// - Sub-issue CI와 Milestone CI에 같은 잡을 둔다. 한쪽만 고치면 `main`으로 가는 검사와
///   서브이슈 검사가 서로 다른 것을 돌리게 된다.
/// - 잡의 Java 버전은 `android/app/build.gradle.kts`의 `minTestJavaVersion` 이상이어야 한다.
///   낮으면 Gradle이 테스트를 시작하기 전에 멈춘다(Robolectric이 API 36 프레임워크에 Java 21을 요구한다).
/// - Gradle 래퍼는 저장소에 없으므로(`android/.gitignore`) 테스트 단계 앞에 Flutter가 래퍼를 만드는 단계가 있어야 한다.
///
/// 오프라인 구성 검사라 잡이 실제로 통과하는지는 CI 실행으로 확인한다.

/// 두 워크플로가 함께 두는 잡 ID
const _jobId = 'android-unit-test';

const _workflows = [
  '.github/workflows/subissue-linux-ci.yml',
  '.github/workflows/milestone-full-ci.yml',
];

/// Gradle 단위 테스트 작업 (디버그 변형 — Flutter 임베딩이 디버그 의존성으로 들어온다)
const _gradleTestCommand = './gradlew :app:testDebugUnitTest';

YamlMap _job(String workflow) {
  final jobs = loadYamlFile(workflow)['jobs'] as YamlMap;
  expect(jobs[_jobId], isA<YamlMap>(), reason: '$workflow: $_jobId 잡이 없다');
  return jobs[_jobId] as YamlMap;
}

List<YamlMap> _steps(String workflow) =>
    (_job(workflow)['steps'] as YamlList).cast<YamlMap>().toList();

/// `android/app/build.gradle.kts`가 요구하는 테스트 JVM 최저 버전
int _minTestJavaVersion() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final matches = RegExp(
    r'^val minTestJavaVersion = (\d+)[ \t]*\r?$',
    multiLine: true,
  ).allMatches(gradle).toList();
  expect(
    matches,
    hasLength(1),
    reason: 'build.gradle.kts에 "val minTestJavaVersion = <숫자>" 줄이 하나 있어야 한다',
  );
  return int.parse(matches.single[1]!);
}

void main() {
  test('두 워크플로의 Android 단위 테스트 잡이 같다', () {
    final jobs = [for (final w in _workflows) _job(w)];
    // YamlMap의 ==는 내용 비교가 아니므로 일반 맵·목록으로 바꿔 비교한다
    expect(_plain(jobs.last), _plain(jobs.first));
  });

  for (final workflow in _workflows) {
    group(workflow, () {
      test('Java 버전이 build.gradle.kts의 최저 버전 이상이다', () {
        final setups = _steps(
          workflow,
        ).where((s) => '${s['uses'] ?? ''}'.startsWith('actions/setup-java@'));
        expect(setups, hasLength(1), reason: 'Java 설치 단계가 하나여야 한다');
        final version = int.tryParse(
          '${(setups.single['with'] as YamlMap)['java-version']}',
        );
        expect(version, isNotNull, reason: 'java-version은 주 버전 숫자로 적는다');
        expect(version, greaterThanOrEqualTo(_minTestJavaVersion()));
      });

      test('Gradle 래퍼를 만든 뒤 android 폴더에서 단위 테스트를 돌린다', () {
        final steps = _steps(workflow);
        final test = steps.indexWhere(
          (s) => '${s['run'] ?? ''}'.trim() == _gradleTestCommand,
        );
        expect(test, isNot(-1), reason: '"$_gradleTestCommand" 단계가 없다');
        expect(steps[test]['working-directory'], 'android');
        // 실패를 삼키는 설정이 붙으면 테스트가 깨져도 잡이 통과한다
        expect(steps[test].containsKey('continue-on-error'), isFalse);
        expect(steps[test].containsKey('if'), isFalse);

        final wrapper = steps.indexWhere(
          (s) =>
              RegExp(r'^flutter build apk\b.*--config-only\b')
                  .hasMatch('${s['run'] ?? ''}'.trim()),
        );
        expect(wrapper, isNot(-1), reason: 'Gradle 래퍼를 만드는 단계가 없다');
        expect(wrapper, lessThan(test), reason: '래퍼를 먼저 만들어야 한다');
      });

      test('잡이 실패를 삼키거나 건너뛰지 않고, 시간 제한이 있다', () {
        final job = _job(workflow);
        expect(job.containsKey('continue-on-error'), isFalse);
        // 같은 워크플로의 다른 잡과 같은 조건 — Draft가 아니면 늘 돈다 (두 워크플로가 같이 틀리면 일치 검사로는 못 잡는다)
        expect(job['if'], 'github.event.pull_request.draft == false');
        // 캐시가 빈 실행(약 12분)이 잘리지 않을 만큼, 멈춘 내려받기가 오래 잡히지 않을 만큼
        expect(
          job['timeout-minutes'],
          isA<int>().having((m) => m, '분', inInclusiveRange(15, 60)),
        );
      });
    });
  }

  test('Gradle 테스트 설정이 실패를 삼키지 않고 Java 버전 검사가 최저 버전을 쓴다', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    // 실패를 무시하거나 테스트 작업을 끄는 설정
    for (final pattern in [
      'ignoreFailures',
      'enabled = false',
      'isEnabled = false',
    ]) {
      expect(gradle, isNot(contains(pattern)), reason: pattern);
    }
    // 최저 버전 값이 실제 검사에 쓰이는지 (값만 있고 검사가 빠지면 위 Java 버전 대조가 헛돈다)
    expect(gradle, contains('val required = minTestJavaVersion'));
    expect(gradle, contains('check(version >= required)'));
  });

  test('Gradle 래퍼는 저장소에 두지 않는다 (CI가 만들어 쓴다)', () {
    // 래퍼를 커밋하게 되면 래퍼 생성 단계와 이 검사를 함께 정리한다
    final ignored = File('android/.gitignore')
        .readAsLinesSync()
        .map((l) => l.trim())
        .toSet();
    expect(ignored, containsAll(['/gradlew', '/gradlew.bat']));
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
