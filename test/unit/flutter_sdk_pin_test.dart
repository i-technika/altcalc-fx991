import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../support/bash.dart';
import '../support/workflows.dart';

/// CI·로컬의 Flutter SDK 버전 고정(#78)이 깨지지 않게 지킨다.
/// 기준값은 `pubspec.yaml`의 `environment.flutter` 하나이고, CI 워크플로의 모든 잡이 이 값을 스크립트로 읽어
/// SDK 설치 단계에 넘기는지(#90), 스크립트가 YAML 해석과 같은 값을 읽는지, README가 같은 버전을 적는지 확인한다.
/// 실제로 그 버전이 설치되는지는 CI의 `flutter-action`과 pub의 SDK 제약 검사가 지킨다
/// (다른 버전이 설치되면 `flutter pub get`이 실패한다).
/// `pubspec.lock` 커밋 누락은 여기서 검사하지 않는다 — `flutter test`가 먼저 pub get으로 lock을 다시 쓰므로
/// 작업 트리 파일로는 알 수 없고, CI의 작업 트리 검사(`.github/scripts/verify-clean-tree.sh`)가 잡는다.

/// 정확한 버전 `X.Y.Z` (범위·`^`·프리릴리스 표기 금지 — flutter-action이 정확한 버전만 받는다)
final _exactVersion = RegExp(r'^\d+\.\d+\.\d+$');

/// Flutter SDK를 설치하는 액션
const _flutterAction = 'subosito/flutter-action@';

/// 저장소를 받는 액션 — 버전을 읽으려면 먼저 `pubspec.yaml`이 있어야 한다
const _checkoutAction = 'actions/checkout@';

/// 고정 버전을 읽는 스크립트 (#90). 액션의 `flutter-version-file`은 yq가 필요해 쓰지 않는다
/// (Windows 러너는 yq를 매번 Chocolatey로 설치했다).
const _pinScript = '.github/scripts/read-flutter-version.sh';

/// 버전을 읽는 단계의 id와, 설치 단계가 그 출력을 받는 식
const _pinStepId = 'flutter-pin';
const _pinOutputRef = '\${{ steps.$_pinStepId.outputs.version }}';

/// 버전을 읽는 단계의 모양(`name` 제외). `if`·`continue-on-error`·`working-directory` 같은 키가 붙으면
/// 출력이 비어 액션이 최신 stable을 설치할 수 있으므로 정확히 이 키만 허용한다.
/// `shell: bash`는 Windows 러너(기본 셸 pwsh)에서도 같은 bash로 돌리기 위한 것이다.
const _pinStep = {'id': _pinStepId, 'shell': 'bash', 'run': 'bash $_pinScript'};

/// `pubspec.yaml`의 `environment.flutter` 고정값
String _pinnedVersion() {
  final env = loadYamlFile('pubspec.yaml')['environment'] as YamlMap?;
  final flutter = env?['flutter'];
  expect(
    flutter,
    isA<String>(),
    reason: 'pubspec.yaml에 environment.flutter가 없다',
  );
  return flutter as String;
}

/// 경로를 bash가 읽는 `/` 구분자로 바꾼다 (Windows의 `\`는 셸에서 이스케이프 문자다)
String _posix(String path) => path.replaceAll(r'\', '/');

void main() {
  test('environment.flutter는 정확한 버전(X.Y.Z) 하나다', () {
    expect(_pinnedVersion(), matches(_exactVersion));
  });

  test('워크플로의 모든 잡이 pubspec.yaml 고정 버전으로 Flutter를 설치한다', () {
    final files = workflowFiles();
    expect(files, isNotEmpty, reason: '.github/workflows에 워크플로가 없다');
    expect(File(_pinScript).existsSync(), isTrue, reason: '$_pinScript가 없다');

    for (final file in files) {
      final jobs = loadYamlFile(file.path)['jobs'] as YamlMap;
      for (final MapEntry(key: jobId, value: job) in jobs.entries) {
        final where = '${file.path} → $jobId';
        final rawSteps = (job as YamlMap)['steps'];
        // 재사용 워크플로를 부르는 잡(잡 수준 `uses:`)은 steps가 없다 — 그쪽 워크플로의 고정을 따로 확인해야 한다
        expect(
          rawSteps,
          isA<YamlList>(),
          reason: '$where: steps가 없는 잡은 이 검사가 다루지 않는다',
        );
        final steps = (rawSteps as YamlList).cast<YamlMap>().toList();

        // 조건에 맞는 단계의 위치들
        List<int> indexesWhere(bool Function(YamlMap step) test) => [
          for (var i = 0; i < steps.length; i++)
            if (test(steps[i])) i,
        ];
        bool uses(YamlMap step, String action) =>
            '${step['uses'] ?? ''}'.startsWith(action);

        final setups = indexesWhere((s) => uses(s, _flutterAction));
        // 지금은 모든 잡이 flutter 명령을 쓴다. Flutter가 필요 없는 잡이 생기면 여기서 예외로 둔다.
        expect(setups, hasLength(1), reason: '$where: Flutter 설치 단계가 하나여야 한다');

        // 버전을 읽는 단계: 스크립트를 실행하는 단계와 id가 같은 단계를 모두 세어, 하나뿐이고 정해진 모양인지 본다
        final pins = indexesWhere(
          (s) =>
              s['id'] == _pinStepId || '${s['run'] ?? ''}'.contains(_pinScript),
        );
        expect(pins, hasLength(1), reason: '$where: 고정 버전을 읽는 단계가 하나여야 한다');
        expect(
          Map.of(steps[pins.single])..remove('name'),
          _pinStep,
          reason: '$where: 버전을 읽는 단계는 id·shell·run만 정해진 값으로 둔다',
        );

        // 순서: 체크아웃(pubspec.yaml) → 버전 읽기 → 설치
        final checkouts = indexesWhere((s) => uses(s, _checkoutAction));
        expect(checkouts, isNotEmpty, reason: '$where: 체크아웃 단계가 없다');
        expect(
          checkouts.first < pins.single && pins.single < setups.single,
          isTrue,
          reason: '$where: 체크아웃 → 버전 읽기 → Flutter 설치 순서여야 한다',
        );

        final withMap = steps[setups.single]['with'] as YamlMap?;
        expect(
          withMap?['flutter-version'],
          _pinOutputRef,
          reason: '$where: flutter-version은 버전을 읽는 단계의 출력이어야 한다',
        );
        // 버전 파일(yq 필요, #90)이나 채널을 함께 지정하면 외부 의존이 되살아나거나 고정값과 어긋난다
        // (flutter-version-file은 flutter-version과 함께 쓰면 액션이 오류를 내고, channel은 기본값 stable이면 충분하다)
        for (final key in ['flutter-version-file', 'channel']) {
          expect(
            withMap!.containsKey(key),
            isFalse,
            reason: '$where: $key를 함께 지정하지 않는다',
          );
        }
      }
    }
  });

  group('고정 버전을 읽는 스크립트', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('flutter_pin_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    // 단계 출력 파일(`GITHUB_OUTPUT`) — 테스트마다 새 임시 폴더에 둔다.
    // CI에서는 `flutter test` 단계 자신의 `GITHUB_OUTPUT`이 환경에 있으므로, 항상 덮어써서 그 파일을 건드리지 않는다.
    File outputFile() => File('${tmp.path}/github_output');

    // 스크립트를 실행한다. [pubspec]이 없으면 인자 없이(패키지 루트의 pubspec.yaml) 실행한다.
    ProcessResult run([String? pubspec]) => runBashScript(
      _pinScript,
      [?pubspec],
      environment: {'GITHUB_OUTPUT': _posix(outputFile().path)},
    );

    // 임시 pubspec을 쓰고 경로를 돌려준다
    String fixture(String text) {
      final file = File('${tmp.path}/pubspec.yaml')..writeAsStringSync(text);
      return _posix(file.path);
    }

    test('실제 pubspec.yaml에서 YAML 해석과 같은 값을 읽어 표준 출력과 단계 출력으로 낸다', () {
      final pinned = _pinnedVersion();
      // 이미 있는 단계 출력은 지우지 않고 덧붙인다
      outputFile().writeAsStringSync('other=1\n');

      final result = run();
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(result.stdout, '$pinned\n');
      expect(result.stderr, isEmpty);
      expect(outputFile().readAsStringSync(), 'other=1\nversion=$pinned\n');
    });

    test('GITHUB_OUTPUT이 없어도(로컬 실행) 버전을 출력한다', () {
      final result = runBashScript(
        _pinScript,
        [fixture('environment:\n  flutter: 1.2.3\n')],
        environment: {'GITHUB_OUTPUT': ''},
      );
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(result.stdout, '1.2.3\n');
    });

    // 받아들이는 표기 — 표본의 YAML 해석 결과와 같은 값을 읽어야 한다
    const accepted = <String, (String, String)>{
      '기본': ('environment:\n  sdk: ^3.14.0\n  flutter: 3.50.0\n', '3.50.0'),
      'CRLF (core.autocrlf=true 체크아웃)': (
        'name: x\r\nenvironment:\r\n  sdk: ^3.14.0\r\n  flutter: 3.50.0\r\n\r\ndependencies:\r\n',
        '3.50.0',
      ),
      '줄 끝 주석·뒤 공백': (
        'environment:\n  flutter: 3.50.0 \t# 고정 버전 (#78)\n  sdk: ^3.14.0\n',
        '3.50.0',
      ),
      '큰따옴표': ('environment:\n  flutter: "10.0.12"\n', '10.0.12'),
      '작은따옴표와 주석': ("environment:\n  flutter: '3.50.1' # c\n", '3.50.1'),
      '네 칸 들여쓰기': (
        'environment:\n    sdk: ^3.14.0\n    flutter: 3.50.0\n',
        '3.50.0',
      ),
      '마지막 줄에 줄바꿈 없음': ('environment:\n  flutter: 3.50.0', '3.50.0'),
      '블록 안의 빈 줄·주석 줄, 주석 처리된 값': (
        'environment: # SDK 고정\n\n  # flutter: 1.2.3\n# flutter: 4.5.6\n  sdk: ^3.14.0\n\n  flutter: 3.50.0\n',
        '3.50.0',
      ),
      '다른 블록의 flutter 키와 섞이지 않는다': (
        'other:\n  flutter: 9.9.9\n'
            'environment:\n  sdk: ^3.14.0\n  flutter: 3.50.0\n'
            'dependencies:\n  flutter:\n    sdk: flutter\n'
            'another:\n  flutter: 8.8.8\n'
            'flutter:\n  uses-material-design: true\n',
        '3.50.0',
      ),
      '더 깊은 줄(여러 줄 값)은 키가 아니다': (
        'environment:\n  sdk: >-\n    flutter: 1.2.3\n  flutter: 3.50.0\n',
        '3.50.0',
      ),
    };
    for (final MapEntry(key: name, value: (text, expected))
        in accepted.entries) {
      test('읽는다: $name', () {
        final env = (loadYaml(text) as YamlMap)['environment'] as YamlMap;
        expect(env['flutter'], expected, reason: '표본의 YAML 해석이 기대값과 다르다');

        final result = run(fixture(text));
        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(result.stdout, '$expected\n');
        expect(outputFile().readAsStringSync(), 'version=$expected\n');
      });
    }

    // 추측하지 않고 실패해야 하는 표기 — 빈 값이 넘어가면 액션이 최신 stable을 설치한다
    const rejected = <String, String>{
      'environment 없음':
          'name: x\ndependencies:\n  flutter:\n    sdk: flutter\n',
      'environment에 flutter 없음': 'environment:\n  sdk: ^3.14.0\n',
      '다른 최상위 키 아래에만 있음':
          'environment:\n  sdk: ^3.14.0\nother:\n  flutter: 3.50.0\n',
      '더 깊은 곳에만 있음': 'environment:\n  sdk:\n    flutter: 3.50.0\n',
      '범위 ^': 'environment:\n  flutter: ^3.50.0\n',
      '범위 >=': 'environment:\n  flutter: ">=3.50.0"\n',
      '두 자리 버전': 'environment:\n  flutter: 3.50\n',
      '네 자리 버전': 'environment:\n  flutter: 3.50.0.1\n',
      'x 표기': 'environment:\n  flutter: 3.50.x\n',
      'v 접두사': 'environment:\n  flutter: v3.50.0\n',
      '프리릴리스': 'environment:\n  flutter: 3.50.0-1.0.pre\n',
      '채널 이름': 'environment:\n  flutter: stable\n',
      '값 뒤의 다른 글자': 'environment:\n  flutter: 3.50.0 beta\n',
      '빈 값': 'environment:\n  flutter:\n  sdk: ^3.14.0\n',
      '값 없이 주석만': 'environment:\n  flutter: # 3.50.0\n',
      '짝이 맞지 않는 따옴표': 'environment:\n  flutter: "3.50.0\n',
      '흐름 표기': 'environment: {sdk: ^3.14.0, flutter: 3.50.0}\n',
      '같은 키 두 번': 'environment:\n  flutter: 3.50.0\n  flutter: 3.50.0\n',
      'environment 블록 두 번': 'environment:\n  flutter: 3.50.0\nother: 1\nenvironment:\n  flutter: 3.50.0\n',
    };
    for (final MapEntry(key: name, value: text) in rejected.entries) {
      test('거부한다: $name', () {
        final result = run(fixture(text));
        expect(result.exitCode, 1, reason: '${result.stdout}');
        expect(result.stdout, isEmpty);
        expect(result.stderr, startsWith('::error::'));
        expect(
          outputFile().existsSync(),
          isFalse,
          reason: '실패하면 단계 출력을 쓰지 않는다',
        );
      });
    }

    test('거부한다: 파일 없음', () {
      final result = run('${_posix(tmp.path)}/없는-pubspec.yaml');
      expect(result.exitCode, 1);
      expect(result.stdout, isEmpty);
      expect(result.stderr, startsWith('::error::'));
      expect(outputFile().existsSync(), isFalse);
    });
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
