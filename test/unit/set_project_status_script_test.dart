import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/bash.dart';

/// `.claude/scripts/set-project-status.sh`(프로젝트 보드 Status 변경, #250)를 가짜 gh로 실행해 검사한다.
///
/// 스크립트는 프로젝트 항목 전체(`gh project item-list`)를 읽지 않고, 이슈·PR 쪽의 `projectItems`에서 항목을 찾는다.
/// 가짜 gh는 GraphQL 문서 안의 연산 이름(`issueOrPullRequest`·`addProjectV2ItemById`·`updateProjectV2ItemFieldValue`)으로
/// 호출을 가려 정해 둔 출력(실제 gh가 `--jq`를 적용한 뒤의 출력)을 내고, 받은 인자를 기록한다.
/// `--jq` 필터와 GraphQL 문서가 실제 API에서 맞는지는 PR #250에서 실제 이슈·PR로 돌려 확인했다.
/// 실패 경로 테스트도 기록을 확인한다 — gh가 아예 실행되지 않아도(예: 실행 권한 없음) 종료 코드만으로는 통과하기 때문이다.

const _script = '.claude/scripts/set-project-status.sh';

const _projectId = 'PVT_kwHOBMwL0c4BsMze';
const _statusFieldId = 'PVTSSF_lAHOBMwL0c4BsMzezhqcBOI';
const _contentId = 'I_kwDOtest250';
const _itemId = 'PVTI_ours';

/// 가짜 gh — 호출 하나를 한 줄로 기록하고(`CALL` 뒤에 인자마다 구분 문자 0x1F + 인자, 인자 안의 줄바꿈은 0x1E로 바꿈),
/// 연산별 환경 변수의 출력·실패를 따른다.
/// `FAKE_<연산>_OUT`의 `\n`·`\t`는 printf `%b`로 풀린다. `FAKE_<연산>_FAIL`이 있으면 그 메시지를 내고 1로 끝난다.
const _fakeGh = r'''#!/usr/bin/env bash
us=$'\037'; rs=$'\036'
{ printf 'CALL'; for a in "$@"; do printf '%s%s' "$us" "$a"; done; } | tr '\n' "$rs" >>"$FAKE_GH_LOG"
printf '\n' >>"$FAKE_GH_LOG"
case "$*" in
  *issueOrPullRequest*)            op=LOOKUP ;;
  *addProjectV2ItemById*)          op=ADD ;;
  *updateProjectV2ItemFieldValue*) op=UPDATE ;;
  *) echo "가짜 gh: 예상하지 못한 호출: $*" >&2; exit 99 ;;
esac
fail_var="FAKE_${op}_FAIL"; out_var="FAKE_${op}_OUT"
if [ -n "${!fail_var:-}" ]; then echo "${!fail_var}" >&2; exit 1; fi
printf '%b' "${!out_var:-}"
''';

late Directory _tmp;

/// Windows의 Git Bash에도 넘길 수 있게 경로 구분자를 `/`로 바꾼다
String _posix(String path) => path.replaceAll(r'\', '/');

/// 기록된 gh 호출 하나 — 인자 목록과, `-f`/`-F`로 넘긴 값(`이름=값`)을 이름으로 찾는 도구
class _Call {
  _Call(this.args);
  final List<String> args;

  /// `-f`/`-F` 인자 중 [name]의 값 (없으면 null)
  String? field(String name) {
    for (var i = 0; i + 1 < args.length; i++) {
      if ((args[i] == '-f' || args[i] == '-F') &&
          args[i + 1].startsWith('$name=')) {
        return args[i + 1].substring(name.length + 1);
      }
    }
    return null;
  }

  String get query => field('query') ?? '';

  /// `--jq` 필터 (없으면 null)
  String? get jq {
    final i = args.indexOf('--jq');
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }
}

({ProcessResult result, List<_Call> calls}) _run(
  List<String> args, {
  String? lookupOut,
  String? lookupFail,
  String? addOut,
  String? addFail,
  String? updateFail,
}) {
  final log = File('${_tmp.path}/calls.log')..writeAsStringSync('');
  final result = runBashScript(
    _script,
    args,
    environment: {
      'SET_PROJECT_STATUS_GH': _posix('${_tmp.path}/gh'),
      'FAKE_GH_LOG': _posix(log.path),
      'FAKE_LOOKUP_OUT': ?lookupOut,
      'FAKE_LOOKUP_FAIL': ?lookupFail,
      'FAKE_ADD_OUT': ?addOut,
      'FAKE_ADD_FAIL': ?addFail,
      'FAKE_UPDATE_FAIL': ?updateFail,
    },
  );
  final calls = log.readAsLinesSync().where((line) => line.isNotEmpty).map((
    line,
  ) {
    // 인자 안의 줄바꿈(여러 줄 GraphQL 문서)은 \x1e로 바꿔 기록했다 — 되돌린다
    final parts = line.replaceAll('\x1e', '\n').split('\x1f');
    expect(parts.first, 'CALL');
    return _Call(parts.skip(1).toList());
  }).toList();
  return (result: result, calls: calls);
}

/// 조회 출력: 첫 줄 노드 ID, 다음 줄부터 `프로젝트 ID<TAB>항목 ID`
String _lookup(String contentId, Map<String, String> items) => [
  contentId,
  for (final e in items.entries) '${e.key}\t${e.value}',
].map((line) => '$line\n').join();

void main() {
  setUp(() {
    _tmp = Directory.systemTemp.createTempSync('set_project_status_test');
    final gh = File('${_tmp.path}/gh')..writeAsStringSync(_fakeGh);
    // Dart가 만드는 파일은 실행 권한이 없다(0644). Git Bash는 shebang만 보고 실행하지만 Linux·macOS는 권한이 있어야 한다.
    if (!Platform.isWindows) {
      final chmod = Process.runSync('chmod', ['+x', gh.path]);
      expect(chmod.exitCode, 0, reason: '${chmod.stderr}');
    }
  });
  tearDown(() => _tmp.deleteSync(recursive: true));

  test('프로젝트 항목 전체를 읽는 조회(gh project item-list)를 쓰지 않는다', () {
    // 주석(이전 방식을 설명하는 줄)은 빼고 명령 줄만 본다
    final code = File(_script)
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('#'))
        .join('\n');
    expect(code, isNot(contains('item-list')));
    // gh project 하위 명령은 프로젝트를 번호로 찾는 조회를 따로 하므로 쓰지 않는다(모두 GraphQL 한 번씩으로 한다)
    expect(code, isNot(contains(RegExp(r'gh"?\s+project\b'))));
    expect(code, contains(r'"$gh" api graphql'));
  });

  test('이미 프로젝트에 있으면 조회 1번·상태 변경 1번만 하고, 다른 프로젝트 항목은 건드리지 않는다', () {
    final run = _run(
      ['250', 'In Progress'],
      lookupOut: _lookup(_contentId, {
        'PVT_other': 'PVTI_other',
        _projectId: _itemId,
      }),
    );
    expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
    expect(run.result.stdout, contains('#250 → In Progress (item: $_itemId)'));
    expect(run.calls, hasLength(2));

    final lookup = run.calls[0];
    expect(lookup.args.take(2), ['api', 'graphql']);
    expect(lookup.query, contains('issueOrPullRequest(number:\$number)'));
    expect(lookup.query, contains('... on Issue'));
    expect(lookup.query, contains('... on PullRequest'));
    expect(lookup.query, contains('projectItems('));
    expect(lookup.field('owner'), 'i-technika');
    expect(lookup.field('name'), 'altcalc-fx991');
    expect(lookup.field('number'), '250');
    // 번호는 Int로 넘겨야 한다(-f는 문자열) — 앞의 인자가 -F인지 본다
    expect(lookup.args[lookup.args.indexOf('number=250') - 1], '-F');
    expect(lookup.jq, isNotNull);

    final update = run.calls[1];
    expect(update.query, contains('updateProjectV2ItemFieldValue'));
    expect(update.field('project'), _projectId);
    expect(update.field('item'), _itemId);
    expect(update.field('field'), _statusFieldId);
    expect(update.field('option'), '47fc9ee4');
  });

  test('상태 이름마다 정해진 선택지 ID로 바꾼다', () {
    const options = {
      'Todo': 'f75ad846',
      'In Progress': '47fc9ee4',
      'Done': '98236657',
    };
    for (final MapEntry(key: status, value: option) in options.entries) {
      final run = _run([
        '7',
        status,
      ], lookupOut: _lookup(_contentId, {_projectId: _itemId}));
      expect(run.result.exitCode, 0, reason: '$status: ${run.result.stderr}');
      expect(run.calls.last.field('option'), option, reason: status);
    }
  });

  test('프로젝트에 없으면 노드 ID로 추가한 뒤 그 항목의 상태를 바꾼다', () {
    final run = _run(
      ['251', 'Done'],
      lookupOut: _lookup(_contentId, {'PVT_other': 'PVTI_other'}),
      addOut: 'PVTI_new\n',
    );
    expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
    expect(run.result.stdout, contains('#251 → Done (item: PVTI_new)'));
    expect(run.calls, hasLength(3));

    final add = run.calls[1];
    expect(add.query, contains('addProjectV2ItemById'));
    expect(add.field('project'), _projectId);
    expect(add.field('content'), _contentId);

    final update = run.calls[2];
    expect(update.field('item'), 'PVTI_new');
    expect(update.field('option'), '98236657');
  });

  test('어느 프로젝트에도 없는 이슈(항목 줄 없음)도 추가한다', () {
    final run = _run(
      ['252', 'Todo'],
      lookupOut: _lookup(_contentId, {}),
      addOut: 'PVTI_new\n',
    );
    expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
    expect(run.calls.map((c) => c.query), [
      contains('issueOrPullRequest'),
      contains('addProjectV2ItemById'),
      contains('updateProjectV2ItemFieldValue'),
    ]);
  });

  group('실패하면 상태를 바꾸지 않고 1로 끝난다', () {
    test('조회 실패 (한도 초과 등)', () {
      final run = _run([
        '250',
        'Done',
      ], lookupFail: 'GraphQL: API rate limit already exceeded');
      expect(run.result.exitCode, 1);
      expect(run.result.stderr, contains('#250 조회 실패'));
      expect(run.calls, hasLength(1), reason: '추가·변경을 시도하지 않는다');
    });

    test('이슈/PR이 없음 (노드 ID가 null)', () {
      final run = _run(['999999', 'Done'], lookupOut: 'null\n');
      expect(run.result.exitCode, 1);
      expect(run.result.stderr, contains('찾지 못했다'));
      expect(run.calls, hasLength(1));
    });

    test('조회 출력이 비어 있음', () {
      final run = _run(['250', 'Done'], lookupOut: '');
      expect(run.result.exitCode, 1);
      expect(run.calls, hasLength(1));
    });

    test('추가 실패', () {
      final run = _run(
        ['250', 'Done'],
        lookupOut: _lookup(_contentId, {}),
        addFail: 'HTTP 502',
      );
      expect(run.result.exitCode, 1);
      expect(run.result.stderr, contains('프로젝트 추가 실패'));
      expect(run.calls, hasLength(2), reason: '상태 변경을 시도하지 않는다');
    });

    test('추가 결과에 항목 ID가 없음', () {
      final run = _run(
        ['250', 'Done'],
        lookupOut: _lookup(_contentId, {}),
        addOut: 'null\n',
      );
      expect(run.result.exitCode, 1);
      expect(run.result.stderr, contains('항목 ID가 없다'));
      expect(run.calls, hasLength(2));
    });

    test('상태 변경 실패', () {
      final run = _run(
        ['250', 'Done'],
        lookupOut: _lookup(_contentId, {_projectId: _itemId}),
        updateFail: 'HTTP 502',
      );
      expect(run.result.exitCode, 1);
      expect(run.result.stderr, contains('상태 변경 실패'));
      expect(run.result.stdout, isNot(contains('→')));
    });
  });

  test('인자가 잘못되면 gh를 부르지 않고 실패한다', () {
    for (final args in [
      <String>[],
      ['250'],
      ['250', 'Doing'],
      ['abc', 'Done'],
      ['#250', 'Done'],
      ['0', 'Done'],
    ]) {
      final run = _run(args);
      expect(run.result.exitCode, isNot(0), reason: '$args');
      expect(run.calls, isEmpty, reason: '$args');
    }
  });
}
