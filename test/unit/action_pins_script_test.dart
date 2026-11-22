import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/bash.dart';

/// `.github/scripts/action-pins.sh`(커밋 SHA로 고정한 액션의 온라인 확인·새 릴리스 조회, #88)를
/// 가짜 gh로 실행해 검사한다. 실제 GitHub API 응답과의 일치는 CI의 `Verify action pins` 단계가 확인한다.
///
/// 가짜 gh는 인자 전체를 키로 응답 표에서 출력을 찾고(없으면 실패 — 조회 실패 흉내), 받은 인자를 기록한다.

const _script = '.github/scripts/action-pins.sh';

const _shaA = '1111111111111111111111111111111111111111';
const _shaB = '2222222222222222222222222222222222222222';
const _shaC = '3333333333333333333333333333333333333333';

/// 응답 표 한 줄의 키: 태그가 가리키는 커밋 조회
String _commitKey(String repo, String tag) =>
    'api repos/$repo/commits/refs/tags/$tag --jq .sha';

/// 응답 표 한 줄의 키: 릴리스 목록 조회
String _releasesKey(String repo) =>
    'api repos/$repo/releases?per_page=100 --jq '
    '.[] | select((.draft or .prerelease) | not) | .tag_name';

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

/// 워크플로 조각들을 파일로 쓰고 가짜 gh로 스크립트를 돌린다
({ProcessResult result, List<String> calls}) _run(
  String mode,
  List<String> workflows,
  Map<String, String> responses,
) {
  final files = <String>[];
  for (var i = 0; i < workflows.length; i++) {
    final file = File('${_tmp.path}/w$i.yml')..writeAsStringSync(workflows[i]);
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
      'ACTION_PINS_GH': _posix('${_tmp.path}/gh'),
      'FAKE_GH_RESPONSES': _posix('${_tmp.path}/responses.tsv'),
      'FAKE_GH_LOG': _posix(log.path),
    },
  );
  return (result: result, calls: log.readAsLinesSync());
}

String _uses(String action, String sha, String tag, {String eol = '\n'}) =>
    '      - uses: $action@$sha # $tag$eol';

void main() {
  setUp(() {
    _tmp = Directory.systemTemp.createTempSync('action_pins_test');
    File('${_tmp.path}/gh').writeAsStringSync(_fakeGh);
  });
  tearDown(() => _tmp.deleteSync(recursive: true));

  test('모드 없이 실행하면 사용법과 함께 2로 끝난다', () {
    final result = runBashScript(_script, []);
    expect(result.exitCode, 2);
    expect(result.stderr, contains('사용:'));
  });

  group('verify', () {
    test('모든 SHA가 태그와 같으면 통과하고, 같은 고정은 한 번만 조회한다', () {
      final run = _run(
        'verify',
        [
          _uses('actions/checkout', _shaA, 'v7.0.1') +
              _uses('actions/checkout', _shaA, 'v7.0.1'),
          // CRLF 체크아웃·하위 경로 액션(태그는 owner/repo의 것)
          _uses('actions/cache/restore', _shaB, 'v5.1.0', eol: '\r\n'),
        ],
        {
          _commitKey('actions/checkout', 'v7.0.1'): _shaA,
          _commitKey('actions/cache', 'v5.1.0'): _shaB,
        },
      );
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      expect(run.result.stdout, contains('모두 태그와 일치'));
      expect(run.calls, [
        _commitKey('actions/checkout', 'v7.0.1'),
        _commitKey('actions/cache', 'v5.1.0'),
      ]);
    });

    test('SHA가 태그와 다르거나 조회하지 못하면 모두 알리고 실패한다', () {
      final run = _run(
        'verify',
        [
          _uses('actions/checkout', _shaA, 'v7.0.1') +
              _uses('actions/setup-java', _shaB, 'v6.3.0') +
              _uses('actions/cache', _shaC, 'v5.1.0'),
        ],
        {
          _commitKey('actions/checkout', 'v7.0.1'): _shaC,
          // setup-java는 응답 없음 = 태그 없음·조회 실패
          _commitKey('actions/cache', 'v5.1.0'): _shaC,
        },
      );
      expect(run.result.exitCode, 1);
      expect(run.result.stdout, contains('actions/checkout 의 v7.0.1 는 $_shaC'));
      expect(run.result.stdout, contains('actions/setup-java 의 태그 v6.3.0'));
      expect(run.result.stdout, contains('확인: actions/cache@$_shaC = v5.1.0'));
      expect(run.result.stderr, contains('2건'));
    });

    test('SHA 고정 형식이 아닌 uses: 줄은 조회 없이 실패한다', () {
      for (final line in [
        '      - uses: actions/checkout@v7\n',
        '      - uses: actions/checkout@$_shaA\n',
        '      - uses: actions/checkout@$_shaA # v7\n',
        '      - uses: actions/checkout@${_shaA.substring(0, 7)} # v7.0.1\n',
        '      - uses: actions/checkout@$_shaA#v7.0.1\n',
      ]) {
        final run = _run('verify', [line], {});
        expect(run.result.exitCode, 1, reason: line);
        expect(run.result.stderr, contains('w0.yml:1:'), reason: line);
        expect(run.calls, isEmpty, reason: line);
      }
    });

    test('uses: 줄이 하나도 없으면 실패한다', () {
      final run = _run('verify', ['jobs: {}\n'], {});
      expect(run.result.exitCode, 1);
      expect(run.result.stderr, contains('고정된 액션'));
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
        },
      );
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      final lines = (run.result.stdout as String).trim().split('\n');
      expect(lines, [
        'actions/checkout: 고정 v7.0.1 — 최신',
        'actions/cache: 고정 v5.0.5 → v5.1.0 ($_shaA) → v6.1.0 ($_shaC, '
            '주 버전 변경 — 그 버전 action.yml의 runs.using 확인·_minVersions 갱신)',
        'subosito/flutter-action: 고정 v2.22.0 → v2.23.0 ($_shaB)',
        '새 릴리스 3건 — README "CI 액션 고정 버전 올리기" 절차로 올린다',
      ]);
    });

    test('모두 최신이면 그렇게 알리고, 액션마다 릴리스 목록을 한 번만 조회한다', () {
      final run = _run(
        'outdated',
        [
          _uses('actions/checkout', _shaA, 'v7.0.1'),
          _uses('actions/checkout', _shaA, 'v7.0.1'),
        ],
        {_releasesKey('actions/checkout'): 'v7.0.1'},
      );
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      expect(run.result.stdout, contains('모든 액션이 최신 릴리스로 고정돼 있다'));
      expect(run.calls, [_releasesKey('actions/checkout')]);
    });

    test('워크플로마다 고정이 다르면 모두 보여 주고 가장 높은 것과 비교한다', () {
      final run = _run(
        'outdated',
        [
          _uses('actions/checkout', _shaA, 'v7.0.0'),
          _uses('actions/checkout', _shaB, 'v7.0.1'),
        ],
        {_releasesKey('actions/checkout'): r'v7.0.1\nv7.0.0'},
      );
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      expect(
        run.result.stdout,
        contains('actions/checkout: 고정 v7.0.0 v7.0.1 — 최신'),
      );
    });

    test('릴리스 목록을 조회하지 못하면 실패한다', () {
      final run = _run('outdated', [
        _uses('actions/checkout', _shaA, 'v7.0.1'),
      ], {});
      expect(run.result.exitCode, 1);
      expect(run.result.stderr, contains('릴리스 목록을 조회하지 못했다'));
    });
  });
}
