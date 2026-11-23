import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/bash.dart';
import '../support/workflows.dart';

/// `.github/scripts/action-pins.sh`(커밋 SHA로 고정한 액션의 온라인 확인·새 릴리스 조회, #88)를
/// 가짜 gh로 실행해 검사한다. 실제 GitHub API 응답과의 일치는 CI의 `Verify Action Pins` 잡이 확인한다.
///
/// 가짜 gh는 인자 전체를 키로 응답 표에서 출력을 찾고(없으면 실패 — 조회 실패 흉내), 받은 인자를 기록한다.
/// 실패 경로 테스트도 기록을 확인한다 — gh가 아예 실행되지 않아도(예: 실행 권한 없음) 종료 코드만으로는 통과하기 때문이다.

const _script = '.github/scripts/action-pins.sh';

const _shaA = '1111111111111111111111111111111111111111';
const _shaB = '2222222222222222222222222222222222222222';
const _shaC = '3333333333333333333333333333333333333333';

/// 응답 표의 키: 태그가 가리키는 커밋 조회
String _commitKey(String repo, String tag) =>
    'api repos/$repo/commits/refs/tags/$tag --jq .sha';

/// 응답 표의 키: 릴리스 목록 조회
String _releasesKey(String repo) =>
    'api repos/$repo/releases?per_page=100 --jq '
    '.[] | select((.draft or .prerelease) | not) | .tag_name';

/// 응답 표의 키: 그 버전에 해당하는 보안 권고 조회 (버전은 `v`를 뗀 semver)
String _advisoryKey(String repo, String tag) =>
    'api advisories?ecosystem=actions&affects=$repo@${tag.substring(1)}'
    '&per_page=100 --jq .[] | "\\(.ghsa_id) (\\(.severity)) \\(.summary)"';

/// 확인이 통과하는 응답 (커밋 일치 + 권고 없음)
Map<String, String> _okVerify(String repo, String sha, String tag) => {
  _commitKey(repo, tag): sha,
  _advisoryKey(repo, tag): '',
};

/// 가짜 gh 본문 — 응답 표(`키<TAB>출력`, 출력의 줄바꿈은 `\n`)에서 찾아 내보낸다
const _fakeGh = r'''#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_GH_LOG"
while IFS=$'\t' read -r key out; do
  if [ "$key" = "$*" ]; then
    printf '%b\n' "$out"
    exit 0
  fi
done <"$FAKE_GH_RESPONSES"
echo "HTTP 404: Not Found" >&2
exit 1
''';

late Directory _tmp;

/// Windows의 Git Bash에도 넘길 수 있게 경로 구분자를 `/`로 바꾼다
String _posix(String path) => path.replaceAll(r'\', '/');

/// 워크플로 조각들을 파일로 쓰고 가짜 gh로 스크립트를 돌린다 ([workflows]가 null이면 파일 인자 없이 — 저장소 워크플로)
({ProcessResult result, List<String> calls}) _run(
  String mode,
  List<String>? workflows,
  Map<String, String> responses, {
  String? gh,
}) {
  final files = <String>[];
  for (var i = 0; i < (workflows?.length ?? 0); i++) {
    final file = File('${_tmp.path}/w$i.yml')..writeAsStringSync(workflows![i]);
    files.add(_posix(file.path));
  }
  File('${_tmp.path}/responses.tsv').writeAsStringSync(
    responses.entries.map((e) => '${e.key}\t${e.value}\n').join(),
  );
  final log = File('${_tmp.path}/calls.log')..writeAsStringSync('');
  final result = runBashScript(
    _script,
    [mode, ...files],
    environment: {
      'ACTION_PINS_GH': gh ?? _posix('${_tmp.path}/gh'),
      'ACTION_PINS_RETRY_DELAY': '0',
      'FAKE_GH_RESPONSES': _posix('${_tmp.path}/responses.tsv'),
      'FAKE_GH_LOG': _posix(log.path),
    },
    // 로컬 출력 형식(`오류:`)을 본다 — CI 안에서 돌아도 같게
    unset: ['GITHUB_ACTIONS'],
  );
  return (result: result, calls: log.readAsLinesSync());
}

String _uses(String action, String sha, String tag, {String eol = '\n'}) =>
    '      - uses: $action@$sha # $tag$eol';

void main() {
  setUp(() {
    _tmp = Directory.systemTemp.createTempSync('action_pins_test');
    final gh = File('${_tmp.path}/gh')..writeAsStringSync(_fakeGh);
    // Dart가 만드는 파일은 실행 권한이 없다(0644). Git Bash는 shebang만 보고 실행하지만 Linux·macOS는 권한이 있어야 한다.
    if (!Platform.isWindows) {
      final chmod = Process.runSync('chmod', ['+x', gh.path]);
      expect(chmod.exitCode, 0, reason: '${chmod.stderr}');
    }
  });
  tearDown(() => _tmp.deleteSync(recursive: true));

  test('모드가 없거나 잘못되면 사용법과 함께 2로 끝난다', () {
    for (final args in [
      <String>[],
      ['foo'],
      ['--verify'],
    ]) {
      final result = runBashScript(_script, args);
      expect(result.exitCode, 2, reason: '$args');
      expect(result.stderr, contains('사용:'), reason: '$args');
    }
  });

  test('가짜 gh가 실행된다 (이 파일의 다른 검사의 전제)', () {
    final run = _run('verify', [
      _uses('actions/checkout', _shaA, 'v7.0.1'),
    ], _okVerify('actions/checkout', _shaA, 'v7.0.1'));
    expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
    expect(run.calls, hasLength(2));
  });

  group('verify', () {
    test('SHA가 태그와 같고 권고가 없으면 통과하고, 같은 고정은 한 번만 조회한다', () {
      final run = _run(
        'verify',
        [
          _uses('actions/checkout', _shaA, 'v7.0.1') +
              _uses('actions/checkout', _shaA, 'v7.0.1'),
          // CRLF 체크아웃·하위 경로 액션(태그·권고는 owner/repo의 것)
          _uses('actions/cache/restore', _shaB, 'v5.1.0', eol: '\r\n'),
        ],
        {
          ..._okVerify('actions/checkout', _shaA, 'v7.0.1'),
          ..._okVerify('actions/cache', _shaB, 'v5.1.0'),
        },
      );
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      expect(run.result.stdout, contains('보안 권고가 없다'));
      expect(run.calls, [
        _commitKey('actions/checkout', 'v7.0.1'),
        _advisoryKey('actions/checkout', 'v7.0.1'),
        _commitKey('actions/cache', 'v5.1.0'),
        _advisoryKey('actions/cache', 'v5.1.0'),
      ]);
    });

    test('SHA 불일치·조회 실패·보안 권고를 모두 알리고 실패한다', () {
      final run = _run(
        'verify',
        [
          _uses('actions/checkout', _shaA, 'v7.0.1') +
              _uses('actions/setup-java', _shaB, 'v6.3.0') +
              _uses('actions/cache', _shaC, 'v5.1.0') +
              _uses('subosito/flutter-action', _shaA, 'v2.23.0'),
        ],
        {
          _commitKey('actions/checkout', 'v7.0.1'): _shaC,
          // setup-java는 응답 없음 = 태그 없음·조회 실패
          ..._okVerify('actions/cache', _shaC, 'v5.1.0'),
          _commitKey('subosito/flutter-action', 'v2.23.0'): _shaA,
          _advisoryKey('subosito/flutter-action', 'v2.23.0'): r'GHSA-aaaa-bbbb-cccc (high) 첫 권고\nGHSA-dddd-eeee-ffff (low) 둘째 권고',
        },
      );
      expect(run.result.exitCode, 1);
      final err = run.result.stderr as String;
      expect(err, contains('actions/checkout 의 v7.0.1 는 $_shaC'));
      expect(err, contains('actions/setup-java 의 태그 v6.3.0'));
      expect(err, contains('GHSA-aaaa-bbbb-cccc (high) 첫 권고'));
      expect(err, contains('GHSA-dddd-eeee-ffff (low) 둘째 권고'));
      expect(err, contains('실패 3건'));
      expect(
        err,
        isNot(contains('::error::')),
        reason: 'Actions 밖에서는 주석 문법을 쓰지 않는다',
      );
      expect(run.result.stdout, contains('확인: actions/cache@$_shaC = v5.1.0'));
      // 조회 실패는 세 번 시도하고, SHA가 다르면 권고는 조회하지 않는다
      expect(run.calls, [
        _commitKey('actions/checkout', 'v7.0.1'),
        for (var i = 0; i < 3; i++) _commitKey('actions/setup-java', 'v6.3.0'),
        _commitKey('actions/cache', 'v5.1.0'),
        _advisoryKey('actions/cache', 'v5.1.0'),
        _commitKey('subosito/flutter-action', 'v2.23.0'),
        _advisoryKey('subosito/flutter-action', 'v2.23.0'),
      ]);
    });

    test('일시 실패는 다시 시도해 통과한다', () {
      // 첫 두 번은 실패하고 세 번째에 응답하는 gh
      final flaky = File('${_tmp.path}/flaky-gh')
        ..writeAsStringSync(
          '#!/usr/bin/env bash\n'
          'n=\$(wc -l <"\$FAKE_GH_LOG")\n'
          '[ "\$n" -ge 2 ] || { printf \'%s\\n\' "\$*" >>"\$FAKE_GH_LOG"; exit 1; }\n'
          'exec "${_posix('${_tmp.path}/gh')}" "\$@"\n',
        );
      if (!Platform.isWindows) Process.runSync('chmod', ['+x', flaky.path]);
      final run = _run(
        'verify',
        [_uses('actions/checkout', _shaA, 'v7.0.1')],
        _okVerify('actions/checkout', _shaA, 'v7.0.1'),
        gh: _posix(flaky.path),
      );
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      expect(run.calls, [
        for (var i = 0; i < 3; i++) _commitKey('actions/checkout', 'v7.0.1'),
        _advisoryKey('actions/checkout', 'v7.0.1'),
      ]);
    });

    test('Actions 안에서는 오류에 ::error:: 주석 문법을 붙인다', () {
      File('${_tmp.path}/w.yml')
          .writeAsStringSync(_uses('actions/checkout', _shaA, 'v7.0.1'));
      File('${_tmp.path}/none.tsv').createSync();
      final result = runBashScript(
        _script,
        ['verify', _posix('${_tmp.path}/w.yml')],
        environment: {
          'GITHUB_ACTIONS': 'true',
          'ACTION_PINS_GH': _posix('${_tmp.path}/gh'),
          'ACTION_PINS_RETRY_DELAY': '0',
          'FAKE_GH_RESPONSES': _posix('${_tmp.path}/none.tsv'),
          'FAKE_GH_LOG': _posix('${_tmp.path}/calls.log'),
        },
      );
      expect(result.exitCode, 1);
      expect(result.stderr, contains('::error::actions/checkout 의 태그 v7.0.1'));
    });

    test('gh가 없으면 조회 실패로 끝난다', () {
      final run = _run(
        'verify',
        [_uses('actions/checkout', _shaA, 'v7.0.1')],
        {},
        gh: _posix('${_tmp.path}/no-such-gh'),
      );
      expect(run.result.exitCode, 1);
      expect(run.result.stderr, contains('조회하지 못했다'));
    });

    test('SHA 고정 형식이 아닌 uses: 줄은 조회 없이 실패한다', () {
      for (final line in [
        '      - uses: actions/checkout@v7\n',
        '      - uses: actions/checkout@$_shaA\n',
        '      - uses: actions/checkout@$_shaA # v7\n',
        '      - uses: actions/checkout@${_shaA.substring(0, 7)} # v7.0.1\n',
        '      - uses: actions/checkout@$_shaA#v7.0.1\n',
        '      - uses: actions/checkout@$_shaA\' # v7.0.1\n',
        '      - uses: \'actions/checkout@$_shaA" # v7.0.1\n',
      ]) {
        final run = _run('verify', [line], {});
        expect(run.result.exitCode, 1, reason: line);
        expect(run.result.stderr, contains('w0.yml:1:'), reason: line);
        expect(run.calls, isEmpty, reason: line);
      }
    });

    test('없는 파일·uses: 없는 워크플로는 실패한다', () {
      final missing = runBashScript(_script, [
        'verify',
        _posix('${_tmp.path}/none.yml'),
      ]);
      expect(missing.exitCode, 1);
      expect(missing.stderr, contains('none.yml 이 없다'));

      final empty = _run('verify', ['jobs: {}\n'], {});
      expect(empty.result.exitCode, 1);
      expect(empty.result.stderr, contains('고정된 액션'));
    });

    test('받아들이는 uses: 줄이 ci_actions_test의 줄 추출·형식 판정과 같다', () {
      const sha = _shaA;
      for (final line in [
        '      - uses: actions/checkout@$sha # v7.0.1',
        '        uses: actions/checkout@$sha # v7.0.1',
        "        uses: 'actions/checkout@$sha' # v7.0.1",
        '        uses: "actions/checkout@$sha" # v7.0.1',
        '        uses: actions/checkout@$sha #v7.0.1 설명',
        '        uses: actions/checkout@$sha # v7.0.1 # 두 번째 주석',
        '        uses: actions/checkout@$sha\t# v7.0.1',
        '        uses: actions/checkout@$sha # v7.0.1설명',
        '        uses: actions/checkout@$sha # v7.0',
        '        uses: actions/checkout@$sha # V7.0.1',
        '        uses: actions/checkout@$sha',
        '        uses: actions/checkout@$sha#v7.0.1',
        "        uses: 'actions/checkout@$sha\" # v7.0.1",
        "        uses: actions/checkout@$sha' # v7.0.1",
        "        uses: 'actions/checkout@$sha # v7.0.1",
        '        uses: actions/checkout@v7 # v7.0.1',
        '        uses: actions/checkout@${sha.toUpperCase()} # v7.0.1',
        '        uses: actions/checkout@$sha@x # v7.0.1',
      ]) {
        final found = extractUses('$line\n');
        final dartAccepts =
            found.length == 1 && pinFormatProblem(found.single) == null;
        final responses = dartAccepts
            ? _okVerify(
                actionRepo(found.single.action),
                found.single.ref,
                found.single.comment!,
              )
            : <String, String>{};
        final run = _run('verify', ['$line\n'], responses);
        expect(
          run.result.exitCode == 0,
          dartAccepts,
          reason: '$line\n${run.result.stderr}',
        );
      }
    });

    test('파일을 주지 않으면 저장소의 모든 워크플로를 본다', () {
      final responses = <String, String>{};
      for (final file in workflowFiles()) {
        for (final u in extractUses(file.readAsStringSync())) {
          responses.addAll(_okVerify(actionRepo(u.action), u.ref, u.comment!));
        }
      }
      expect(responses, isNotEmpty);
      final run = _run('verify', null, responses);
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      expect(run.calls.toSet(), responses.keys.toSet());
    });
  });

  group('outdated', () {
    test('같은 주 버전의 새 릴리스와 새 주 버전을 따로 알리고, 최신이면 최신이라고 한다', () {
      final run = _run(
        'outdated',
        [
          _uses('actions/checkout', _shaA, 'v7.0.1') +
              _uses('actions/cache', _shaB, 'v5.0.5') +
              _uses('subosito/flutter-action', _shaC, 'v2.22.0'),
        ],
        {
          // 최신 버전이 목록 맨 앞이 아니어도(v5 유지 릴리스가 나중에 나온 경우) 버전 순으로 고른다.
          // 버전 형식이 아닌 태그는 무시한다.
          _releasesKey('actions/checkout'): r'v7.0.1\nv7.0.0\nv6.0.2',
          _releasesKey('actions/cache'):
              r'v5.1.0\nv6.1.0\nv6.0.0\nv5.0.5\nnightly',
          _releasesKey('subosito/flutter-action'): r'v2.23.0\nv2.22.0',
          _commitKey('actions/cache', 'v5.1.0'): _shaA,
          _commitKey('actions/cache', 'v6.1.0'): _shaC,
          _commitKey('subosito/flutter-action', 'v2.23.0'): _shaB,
          _advisoryKey('actions/checkout', 'v7.0.1'): '',
          _advisoryKey('actions/cache', 'v5.0.5'): '',
          _advisoryKey('subosito/flutter-action', 'v2.22.0'):
              'GHSA-aaaa-bbbb-cccc (medium) 권고',
        },
      );
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      final lines = (run.result.stdout as String).trim().split('\n');
      expect(lines, [
        'actions/checkout: 고정 v7.0.1 — 최신',
        'actions/cache: 고정 v5.0.5 → v5.1.0 ($_shaA) → v6.1.0 ($_shaC, '
            '주 버전 변경 — 그 버전 action.yml의 runs.using 확인·_minVersions 갱신)',
        'subosito/flutter-action: 고정 v2.22.0 → v2.23.0 ($_shaB)',
        '  ! v2.22.0 보안 권고: GHSA-aaaa-bbbb-cccc (medium) 권고',
        '새 릴리스 3건 — README "CI 액션 고정 버전 올리기" 절차로 올린다',
        '보안 권고가 있는 고정 1건 — 마일스톤 점검을 기다리지 말고 바로 서브이슈로 올린다',
      ]);
    });

    test('모두 최신이면 그렇게 알리고, 액션마다 릴리스 목록을 한 번만 조회한다', () {
      final run = _run(
        'outdated',
        [
          _uses('actions/checkout', _shaA, 'v7.0.1'),
          _uses('actions/checkout', _shaA, 'v7.0.1'),
        ],
        {
          _releasesKey('actions/checkout'): 'v7.0.1',
          _advisoryKey('actions/checkout', 'v7.0.1'): '',
        },
      );
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      expect(run.result.stdout, contains('모든 액션이 최신 릴리스로 고정돼 있다'));
      expect(run.calls, [
        _releasesKey('actions/checkout'),
        _advisoryKey('actions/checkout', 'v7.0.1'),
      ]);
    });

    test('워크플로마다 고정이 다르면 모두 보여 주고 가장 높은 고정의 주 버전으로 비교한다', () {
      final run = _run(
        'outdated',
        [
          _uses('actions/cache', _shaA, 'v4.2.2'),
          _uses('actions/cache', _shaB, 'v5.0.0'),
        ],
        {
          _releasesKey('actions/cache'):
              r'v6.1.0\nv5.1.0\nv5.0.0\nv4.3.0\nv4.2.2',
          _commitKey('actions/cache', 'v5.1.0'): _shaB,
          _commitKey('actions/cache', 'v6.1.0'): _shaC,
          _advisoryKey('actions/cache', 'v4.2.2'): '',
          _advisoryKey('actions/cache', 'v5.0.0'): '',
        },
      );
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      expect(
        run.result.stdout,
        contains(
          'actions/cache: 고정 v4.2.2 v5.0.0 → v5.1.0 ($_shaB) → v6.1.0 ($_shaC,',
        ),
      );
    });

    test('릴리스 목록을 조회하지 못하면 세 번 시도한 뒤 실패한다', () {
      final run = _run('outdated', [
        _uses('actions/checkout', _shaA, 'v7.0.1'),
      ], {});
      expect(run.result.exitCode, 1);
      expect(run.result.stderr, contains('릴리스 목록을 조회하지 못했다'));
      expect(run.calls, [
        for (var i = 0; i < 3; i++) _releasesKey('actions/checkout'),
      ]);
    });
  });
}
