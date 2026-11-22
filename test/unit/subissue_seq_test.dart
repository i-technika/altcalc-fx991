import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 서브이슈 순번 도우미 `.claude/scripts/subissue-seq.sh`(#110)의 회귀 테스트.
/// 실제 GitHub 대신 상태 파일(한 줄에 `번호<TAB>제목[<TAB>CLOSED]`)을 읽고 쓰는 가짜 gh를 끼워
/// (`SUBISSUE_SEQ_FAKE_GH`) 순번 추출 경계, 종료 코드(0/1/2/3/4), 생성·양보 경쟁, 부분 실패를 검사한다.

const _script = '.claude/scripts/subissue-seq.sh';

/// 가짜 gh: issue list/create/edit만 흉내 낸다. 호출마다 `<상태>.calls`에 "issue list" 등을 기록한다.
/// - `--state all`이 아니면 닫힌 이슈를 뺀다 (실제 gh 기본값은 열린 이슈만)
/// - FAKE_GH_FAIL: 모든 호출 실패 / FAKE_GH_FAIL_LIST: 목록 조회만 실패 / FAKE_GH_FAIL_EDIT: 제목 수정만 실패
/// - FAKE_GH_FAIL_LIST_AFTER_CREATE: 이슈를 만든 뒤의 목록 조회 실패
/// - FAKE_GH_CREATE_THEN_FAIL: 이슈를 만든 뒤 실패(프로젝트 추가 실패 흉내 — URL을 내지 않는다)
/// - FAKE_GH_HIDE_NEW=N: 이슈를 만든 뒤 N번의 목록 조회에서 새 이슈를 숨긴다 (목록 반영 지연)
/// - FAKE_GH_RACE_CREATE: 생성 직전에 다른 세션이 같은 순번으로 먼저 만든다
/// - FAKE_GH_RACE_EDIT: 첫 제목 수정 직전에 다른 세션이 그 새 순번으로 더 큰 번호 이슈를 먼저 만든다
/// - FAKE_GH_LOCKSTEP=<번호>: 제목을 고칠 때마다 그 이슈도 같은 순번으로 바뀐다 (동시에 양보하는 상대)
/// - FAKE_GH_LOCKSTEP_ONCE=<번호>: 위와 같되 첫 수정 때 한 번만
/// - FAKE_GH_PARTNER=<번호>: 제목을 고칠 때마다 그 이슈가 (수정 직전 상태 기준) 최댓값 + 1로 먼저 양보한다
///   — 같은 박자로 양보하면서 오프셋 없이 최댓값 + 1만 고르는 상대 (재시도 오프셋이 없으면 영원히 충돌)
const _fakeGh = r'''#!/usr/bin/env bash
set -euo pipefail
state="$FAKE_GH_STATE"
sub="$1 $2"; shift 2
echo "$sub" >> "$state.calls"
if [ -n "${FAKE_GH_FAIL:-}" ]; then echo "fake gh failure" >&2; exit 1; fi
title=""; num=""; st="open"
while [ $# -gt 0 ]; do
  case "$1" in
    --title) title="$2"; shift 2 ;;
    --state) st="$2"; shift 2 ;;
    -R|-L|--json|--jq|--body-file|--label|--milestone|--project) shift 2 ;;
    *) if [ -z "$num" ]; then num="$1"; fi; shift ;;
  esac
done
max=$(cut -f1 "$state" | sort -n | tail -1); max=${max:-0}
retitle() { # retitle <번호> <제목>
  awk -F'\t' -v n="$1" -v t="$2" 'BEGIN { OFS = "\t" } $1 == n { $2 = t } { print }' "$state" > "$state.tmp"
  mv "$state.tmp" "$state"
}
case "$sub" in
  "issue list")
    if [ -n "${FAKE_GH_FAIL_LIST:-}" ]; then echo "fake list failure" >&2; exit 1; fi
    if [ -e "$state.created" ] && [ -n "${FAKE_GH_FAIL_LIST_AFTER_CREATE:-}" ]; then exit 1; fi
    hide=""
    if [ -e "$state.created" ] && [ -n "${FAKE_GH_HIDE_NEW:-}" ]; then
      seen=$(cat "$state.hidden" 2>/dev/null || echo 0)
      if [ "$seen" -lt "$FAKE_GH_HIDE_NEW" ]; then
        echo $((seen + 1)) > "$state.hidden"; hide=$(cat "$state.created")
      fi
    fi
    awk -F'\t' -v st="$st" -v hide="$hide" \
      '(st == "all" || $3 != "CLOSED") && $1 != hide { print $1 "\t" $2 }' "$state" ;;
  "issue create")
    n=$((max + 1))
    if [ -n "${FAKE_GH_RACE_CREATE:-}" ]; then
      printf '%s\t%s\n' "$n" "${title%% *} 끼어든 이슈" >> "$state"; n=$((n + 1))
    fi
    printf '%s\t%s\n' "$n" "$title" >> "$state"
    echo "$n" > "$state.created"
    if [ -n "${FAKE_GH_CREATE_THEN_FAIL:-}" ]; then echo "project add failed" >&2; exit 1; fi
    echo "https://github.com/i-technika/altcalc-fx991/issues/$n" ;;
  "issue edit")
    if [ -n "${FAKE_GH_FAIL_EDIT:-}" ]; then echo "fake edit failure" >&2; exit 1; fi
    if [ -n "${FAKE_GH_RACE_EDIT:-}" ] && [ ! -e "$state.raced" ]; then
      touch "$state.raced"
      printf '%s\t%s\n' "$((max + 1))" "${title%% *} 끼어든 이슈" >> "$state"
    fi
    partner="${FAKE_GH_LOCKSTEP:-}"
    if [ -n "${FAKE_GH_LOCKSTEP_ONCE:-}" ] && [ ! -e "$state.locked" ]; then
      touch "$state.locked"; partner="$FAKE_GH_LOCKSTEP_ONCE"
    fi
    if [ -n "$partner" ]; then retitle "$partner" "${title%% *} 상대"; fi
    if [ -n "${FAKE_GH_PARTNER:-}" ]; then
      ms=$(printf '%s\n' "$title" | sed -nE 's/^\[(M[0-9]+)-[0-9]+\] .*/\1/p')
      top=$(cut -f2 "$state" | sed -nE "s/^\[$ms-([0-9]+)\] .*/\1/p" | sort -n | tail -1)
      retitle "$FAKE_GH_PARTNER" "[$ms-$((top + 1))] 상대"
    fi
    retitle "$num" "$title" ;;
  *) echo "fake gh: 지원하지 않는 명령 $sub" >&2; exit 1 ;;
esac
''';

/// 이 스크립트를 돌릴 bash. Windows에서는 Git for Windows의 bash를 쓴다
/// (System32의 bash.exe는 WSL 실행기라 Windows 경로·환경 변수를 그대로 받지 못한다). 못 찾으면 null.
String? _findBash() {
  if (!Platform.isWindows) return 'bash';
  try {
    final r = Process.runSync('git', ['--exec-path']);
    if (r.exitCode == 0) {
      // 예: C:/Program Files/Git/mingw64/libexec/git-core → C:/Program Files/Git/bin/bash.exe
      final root = Directory((r.stdout as String).trim()).parent.parent.parent;
      final bash = File('${root.path}/bin/bash.exe');
      if (bash.existsSync()) return bash.path;
    }
  } on ProcessException {
    // git이 없으면 아래에서 건너뛴다
  }
  return null;
}

/// bash에 넘길 경로 (Git Bash는 `C:/...` 형태를 받는다)
String _posix(String path) => path.replaceAll(r'\', '/');

class _Result {
  _Result(this.code, this.stdout, this.stderr);
  final int code;
  final String stdout;
  final String stderr;

  /// stdout 마지막 줄 (`이슈번호 순번` 또는 순번)
  String get last => stdout.trim().split('\n').last.trim();

  @override
  String toString() => 'exit=$code\nstdout: $stdout\nstderr: $stderr';
}

void main() {
  final bash = _findBash();
  late Directory tmp;
  late File state;
  late File fakeGh;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('subissue_seq_');
    state = File('${tmp.path}/issues.tsv')..writeAsStringSync('');
    fakeGh = File('${tmp.path}/fake_gh.sh')..writeAsStringSync(_fakeGh);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  /// 상태 파일을 {번호: 제목}으로 채운다. [closed]의 번호는 닫힌 이슈로 둔다.
  void seed(
    Map<int, String> issues, {
    Set<int> closed = const {},
  }) => state.writeAsStringSync(
    issues.entries
        .map(
          (e) =>
              '${e.key}\t${e.value}${closed.contains(e.key) ? '\tCLOSED' : ''}\n',
        )
        .join(),
  );

  /// 상태 파일을 {번호: 제목}으로 읽는다.
  Map<int, String> issues() => {
    for (final line in state.readAsLinesSync().where((l) => l.isNotEmpty))
      int.parse(line.split('\t')[0]): line.split('\t')[1],
  };

  /// 가짜 gh가 받은 호출 ("issue list" 등)
  List<String> calls() {
    final f = File('${state.path}.calls');
    return f.existsSync() ? f.readAsLinesSync() : const [];
  }

  /// 같은 순번이 두 이슈에 쓰이지 않았는지 (이 도우미가 지키려는 불변식)
  void expectNoDuplicateSeq() {
    final seqs = issues().values
        .map((t) => RegExp(r'^\[(M\d+-\d+)\] ').firstMatch(t)?.group(1))
        .whereType<String>()
        .toList();
    expect(seqs.toSet().length, seqs.length, reason: '순번 중복: ${issues()}');
  }

  _Result run(List<String> args, [Map<String, String> env = const {}]) {
    final r = Process.runSync(
      bash!,
      [_script, ...args],
      workingDirectory: Directory.current.path,
      environment: {
        'SUBISSUE_SEQ_FAKE_GH': _posix(fakeGh.path),
        'FAKE_GH_STATE': _posix(state.path),
        'SUBISSUE_SEQ_RETRY_DELAY': '0',
        // 안전장치: 훅이 깨져 실제 gh가 불려도 실제 저장소에 닿지 못하게 한다
        'GH_HOST': 'invalid.invalid',
        'GH_TOKEN': 'invalid-token-for-test',
        'GH_ENTERPRISE_TOKEN': 'invalid-token-for-test',
        ...env,
      },
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    return _Result(r.exitCode, r.stdout as String, r.stderr as String);
  }

  final skip = bash == null ? 'Git for Windows의 bash를 찾지 못함' : null;

  group('next', skip: skip, () {
    test('이슈가 없으면 1번', () {
      final r = run(['next', 'M1']);
      expect(r.code, 0, reason: '$r');
      expect(r.last, 'M1-1');
    });

    test('접두 경계: [M1-5]·[M1-56]은 M1, [M10-]·[M2-]·접두사 없는 제목은 제외', () {
      seed({
        1: '[M1] 에픽',
        2: '[M1-5] 다섯',
        3: '[M1-56] 쉰여섯',
        4: '[M10-99] 다른 마일스톤',
        5: '[M2-70] 다른 마일스톤',
        6: 'M1-80 접두사 아님',
      });
      expect(run(['next', 'M1']).last, 'M1-57');
      expect(run(['next', 'M10']).last, 'M10-100');
      expect(run(['next', 'M3']).last, 'M3-1');
    });

    test('닫힌 이슈의 순번도 센다 (--state all)', () {
      seed({1: '[M1-5] 열림', 2: '[M1-60] 닫힘'}, closed: {2});
      expect(run(['next', 'M1']).last, 'M1-61');
    });

    test('형식이 틀린 인자는 exit 2', () {
      for (final args in [
        <String>[],
        ['next'],
        ['next', 'm1'],
        ['next', 'M1-'],
        ['next', 'M[0-9]'],
        ['next', 'M1', 'M2'],
        ['bogus'],
      ]) {
        expect(run(args).code, 2, reason: '$args');
      }
    });

    test('목록 조회 실패는 exit 1이고 순번을 내지 않는다', () {
      final r = run(['next', 'M1'], {'FAKE_GH_FAIL_LIST': '1'});
      expect(r.code, 1, reason: '$r');
      expect(r.stdout.trim(), isEmpty);
    });

    test('조회 한도에 닿으면 일부가 빠졌을 수 있어 실패한다', () {
      seed({1: '[M1-1] 하나', 2: '[M1-2] 둘'});
      final r = run(['next', 'M1'], {'SUBISSUE_SEQ_LIMIT': '2'});
      expect(r.code, 1, reason: '$r');
    });
  });

  group('check', skip: skip, () {
    test('먼저 만든(작은 번호) 이슈와 겹치면 충돌 exit 3', () {
      seed({10: '[M1-7] 먼저', 11: '[M1-7] 나중'});
      expect(run(['check', 'M1-7', '11']).code, 3);
    });

    test('나중에 만든(큰 번호) 쪽 중복은 통과하되 경고한다', () {
      seed({10: '[M1-7] 먼저', 11: '[M1-7] 나중'});
      final r = run(['check', 'M1-7', '10']);
      expect(r.code, 0, reason: '$r');
      expect(r.stderr, contains('경고'));
      expect(r.stderr, contains('#11'));
    });

    test('닫힌 이슈와의 충돌도 잡는다', () {
      seed({10: '[M1-7] 닫힘', 11: '[M1-7] 열림'}, closed: {10});
      expect(run(['check', 'M1-7', '11']).code, 3);
    });

    test('--strict는 큰 번호 쪽과 겹쳐도 충돌', () {
      seed({10: '[M1-7] 먼저', 11: '[M1-7] 나중'});
      expect(run(['check', 'M1-7', '10', '--strict']).code, 3);
    });

    test('겹치지 않으면 통과', () {
      seed({10: '[M1-7] 하나', 11: '[M1-8] 둘', 12: '[M1-70] 접두 경계'});
      final r = run(['check', 'M1-7', '10', '--strict']);
      expect(r.code, 0, reason: '$r');
      expect(r.stderr, isNot(contains('경고')));
    });

    test('이슈 제목이 그 순번이 아니면(번호를 잘못 넣음) 기다리지 않고 exit 2', () {
      seed({10: '[M1-7] 하나', 11: '[M1-7] 둘'});
      final watch = Stopwatch()..start();
      // 재조회 간격을 길게 줘도 재시도 없이 한 번 조회로 끝나야 한다
      final env = {'SUBISSUE_SEQ_RETRY_DELAY': '3'};
      expect(run(['check', 'M1-8', '10'], env).code, 2);
      expect(run(['check', 'M1-7', '99'], env).code, 2);
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    });

    test('형식이 틀린 인자는 exit 2 (조용히 통과하지 않는다)', () {
      seed({10: '[M1-7] 하나'});
      for (final args in [
        ['check', '[M1-7]', '10'],
        ['check', 'm1-7', '10'],
        ['check', 'M1-7', 'abc'],
        ['check', 'M1-7', '0'],
        ['check', 'M1-7'],
        ['check', 'M1-7', '10', '--loose'],
      ]) {
        expect(run(args).code, 2, reason: '$args');
      }
    });

    test('gh 실패는 충돌(3)이 아니라 1', () {
      seed({10: '[M1-7] 하나'});
      expect(run(['check', 'M1-7', '10'], {'FAKE_GH_FAIL': '1'}).code, 1);
    });
  });

  group('create', skip: skip, () {
    test('다음 순번으로 만들고 "번호 순번"을 출력한다', () {
      seed({1: '[M1] 에픽', 5: '[M1-56] 기존'});
      final r = run([
        'create',
        'M1',
        '새 후속 이슈',
        '--body-file',
        'body.md',
        '--label',
        'sub-issue',
      ]);
      expect(r.code, 0, reason: '$r');
      expect(r.last, '6 M1-57');
      expect(issues()[6], '[M1-57] 새 후속 이슈');
    });

    test('다른 세션이 같은 순번을 먼저 만들면 나중 이슈가 새 순번으로 양보한다', () {
      seed({5: '[M1-56] 기존'});
      final r = run(['create', 'M1', '내 이슈'], {'FAKE_GH_RACE_CREATE': '1'});
      expect(r.code, 0, reason: '$r');
      expect(issues()[6], '[M1-57] 끼어든 이슈', reason: '먼저 만든 쪽은 그대로');
      expect(issues()[7], '[M1-58] 내 이슈');
      expect(r.last, '7 M1-58');
      expectNoDuplicateSeq();
    });

    test('목록 반영이 늦어도 기다렸다가 검사를 마친다', () {
      seed({5: '[M1-56] 기존'});
      final r = run(['create', 'M1', '내 이슈'], {'FAKE_GH_HIDE_NEW': '2'});
      expect(r.code, 0, reason: '$r');
      expect(r.last, '6 M1-57');
    });

    test('제목 접두사·제목/저장소 인자는 exit 2, gh를 부르지 않는다', () {
      seed({5: '[M1-56] 기존'});
      for (final args in [
        ['create', 'M1', '[M1-57] 중복 접두사'],
        ['create', 'M1', ''],
        ['create', 'm1', '제목'],
        ['create', 'M1', '제목', '--title', '다른 제목'],
        ['create', 'M1', '제목', '-t', '다른 제목'],
        ['create', 'M1', '제목', '-R', 'other/repo'],
        ['create', 'M1', '제목', '--repo=other/repo'],
      ]) {
        expect(run(args).code, 2, reason: '$args');
      }
      expect(calls(), isEmpty);
      expect(issues().length, 1);
    });

    test('목록 조회만 실패해도 빈 목록으로 M1-1을 만들지 않는다 (\$(...) set -e 회귀)', () {
      seed({5: '[M1-56] 기존'});
      final r = run(['create', 'M1', '내 이슈'], {'FAKE_GH_FAIL_LIST': '1'});
      expect(r.code, 1, reason: '$r');
      expect(calls(), isNot(contains('issue create')));
      expect(issues().length, 1);
    });

    test('gh 실패로 아무것도 만들지 못하면 exit 1', () {
      seed({5: '[M1-56] 기존'});
      final r = run(['create', 'M1', '내 이슈'], {'FAKE_GH_FAIL': '1'});
      expect(r.code, 1, reason: '$r');
      expect(issues().length, 1);
    });

    test('만든 뒤 gh가 실패하면(프로젝트 추가 등) 목록에서 찾아 exit 4와 번호를 낸다', () {
      seed({5: '[M1-56] 기존'});
      final r = run(
        ['create', 'M1', '내 이슈'],
        {'FAKE_GH_CREATE_THEN_FAIL': '1'},
      );
      expect(r.code, 4, reason: '$r');
      expect(r.last, '6 M1-57');
      expect(issues()[6], '[M1-57] 내 이슈');
      expect(r.stderr, contains('ensure 6'));
    });

    test('만든 뒤 목록 조회가 실패하면 exit 4와 번호를 낸다', () {
      seed({5: '[M1-56] 기존'});
      final r = run(
        ['create', 'M1', '내 이슈'],
        {'FAKE_GH_FAIL_LIST_AFTER_CREATE': '1'},
      );
      expect(r.code, 4, reason: '$r');
      expect(r.last, '6 M1-57');
    });
  });

  group('ensure', skip: skip, () {
    test('겹치지 않으면 제목을 바꾸지 않는다', () {
      seed({200: '[M1-57] A', 201: '[M1-58] B'});
      final r = run(['ensure', '201']);
      expect(r.code, 0, reason: '$r');
      expect(r.last, '201 M1-58');
      expect(issues()[201], '[M1-58] B');
      expect(calls(), isNot(contains('issue edit')));
    });

    test('나중에 만든 쪽이 양보하고, 먼저 만든 쪽은 그대로 둔다', () {
      seed({200: '[M1-57] A', 201: '[M1-57] B'});
      expect(run(['ensure', '200']).last, '200 M1-57');
      expect(issues()[200], '[M1-57] A');
      final r = run(['ensure', '201']);
      expect(r.code, 0, reason: '$r');
      expect(r.last, '201 M1-58');
      expect(issues()[201], '[M1-58] B');
      expectNoDuplicateSeq();
    });

    test('양보한 순번을 더 큰 번호 이슈가 먼저 가져가도 중복이 남지 않는다 (R1 #1 셋째 세션)', () {
      // #201이 M1-58로 양보하는 사이 다른 세션이 #202 [M1-58]을 만들고 검사를 통과한 상황
      seed({200: '[M1-57] A', 201: '[M1-57] B'});
      final r = run(['ensure', '201'], {'FAKE_GH_RACE_EDIT': '1'});
      expect(r.code, 0, reason: '$r');
      expect(issues()[202], '[M1-58] 끼어든 이슈', reason: '검사를 통과한 쪽은 그대로');
      expect(r.last, startsWith('201 M1-'));
      expect(issues()[201], startsWith('[${r.last.split(' ').last}] B'));
      expectNoDuplicateSeq();
    });

    test('두 이슈가 같은 박자로 한 번 양보해도 재시도에서 갈라진다', () {
      seed({200: '[M1-57] A', 201: '[M1-57] B'});
      final r = run(['ensure', '201'], {'FAKE_GH_LOCKSTEP_ONCE': '200'});
      expect(r.code, 0, reason: '$r');
      expectNoDuplicateSeq();
    });

    test('매번 최댓값 + 1을 고르는 상대와 함께 양보해도 무작위 오프셋으로 갈라진다 (R2 #1)', () {
      // 시드를 바꿔 가며 여러 번 — 오프셋이 없으면 모든 시도가 상대와 같은 순번을 골라 소진(exit 4)된다
      for (final seed_ in ['1', '7', '42', '1234', '31337']) {
        seed({100: '[M1-50] 기존', 200: '[M1-57] A', 201: '[M1-57] B'});
        final r = run(
          ['ensure', '201'],
          {'FAKE_GH_PARTNER': '200', 'SUBISSUE_SEQ_RANDOM_SEED': seed_},
        );
        expect(r.code, 0, reason: 'seed=$seed_\n$r');
        expectNoDuplicateSeq();
      }
    });

    test('계속 같은 박자로 충돌하면 재시도 상한에서 exit 4와 현재 순번을 낸다', () {
      seed({200: '[M1-57] A', 201: '[M1-57] B'});
      final r = run(['ensure', '201'], {'FAKE_GH_LOCKSTEP': '200'});
      expect(r.code, 4, reason: '$r');
      expect(r.last, matches(RegExp(r'^201 M1-\d+$')));
      expect(issues()[201], startsWith('[${r.last.split(' ').last}] B'));
      expect(r.stderr, contains('ensure 201'));
    });

    test('제목 수정이 실패하면 exit 1, 제목은 그대로', () {
      seed({200: '[M1-57] A', 201: '[M1-57] B'});
      final r = run(['ensure', '201'], {'FAKE_GH_FAIL_EDIT': '1'});
      expect(r.code, 1, reason: '$r');
      expect(issues()[201], '[M1-57] B');
    });

    test('순번이 없는 제목·없는 이슈는 exit 2', () {
      seed({1: '[M1] 에픽'});
      expect(run(['ensure', '1']).code, 2);
      expect(run(['ensure', '99']).code, 2);
    });
  });

  group('안전장치', skip: skip, () {
    test('가짜 gh 훅 파일이 없으면 실제 gh로 넘어가지 않고 실패한다', () {
      final r = run(
        ['next', 'M1'],
        {'SUBISSUE_SEQ_FAKE_GH': _posix('${tmp.path}/없는_파일.sh')},
      );
      expect(r.code, 1, reason: '$r');
      expect(r.stderr, contains('훅 파일이 없습니다'));
    });
  });
}
