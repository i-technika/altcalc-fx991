import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../support/workflows.dart';

/// CI 워크플로의 액션 참조를 지킨다.
///
/// - 커밋 SHA 고정 (#88): 모든 `uses:`는 `<액션>@<40자리 SHA> # vX.Y.Z`로 적는다. 태그(`v2`)·브랜치는 움직여서
///   가리키는 커밋이 바뀌면 CI 동작도 조용히 바뀐다(빌드 재현성·공급망 위험). 같은 액션은 모든 워크플로에서 같은 SHA로 고정한다
///   (한쪽만 올리면 서브이슈 검사와 `main`으로 가는 검사가 다른 액션을 돌린다).
/// - Node 24 런타임 (#79): GitHub Actions는 Node 20 지원을 끝내는 중이라, 모든 액션이 아래 목록에 있고
///   끝 주석의 버전이 목록의 최소 버전 이상이어야 한다.
///
/// 오프라인 검사라 다음은 확인하지 못한다.
/// - 커밋 SHA가 정말 끝 주석의 태그를 가리키는지 — CI의 Linux 잡이 `.github/scripts/action-pins.sh verify`로
///   GitHub API에 물어 확인한다(아래 마지막 테스트가 그 단계가 있는지 본다).
/// - composite 액션 내부에서 쓰는 액션의 버전 — 예: flutter-action v2.23.0은 안에서 `actions/cache@v5`(움직이는 태그)를 쓴다.
///   바깥 SHA를 고정해도 안쪽 참조는 그 액션이 고정하지 않는 한 움직인다(README "CI 액션 고정 버전 올리기").
///
/// 지금 쓰지 않아 다루지 않는 형태: 로컬 액션(`./…`)·Docker 이미지(`docker://…`)·흐름 표기(`{uses: …}`)는
/// 줄 단위 추출에 걸리지 않아 YAML 대조에서 실패한다. 하위 경로 액션(`owner/repo/path`)·재사용 워크플로는
/// `_minVersions`의 owner/repo 키와 맞지 않는다. 쓰게 되면 이 검사를 넓힌다.

/// 워크플로에서 쓰도록 확인한 액션과, Node 24로 실행되는 최소 버전 `[주, 부]`.
/// 새 액션을 쓰거나 주 버전을 바꿀 때는 그 버전 `action.yml`의 `runs.using`을 확인하고 여기에 적는다
/// (`node24`이거나, `composite`면 내부에서 쓰는 액션들이 node24여야 한다).
const _minVersions = <String, List<int>>{
  // v5.0.0부터 runs.using: node24
  'actions/checkout': [5, 0],
  // v5.0.0부터 runs.using: node24
  'actions/setup-java': [5, 0],
  // v5.0.0부터 runs.using: node24 (v4는 node20) — Android 단위 테스트 잡의 NDK 캐시 (#108)
  'actions/cache': [5, 0],
  // composite 액션 — 내부의 actions/cache가 v2.22.0부터 v5(node24)다 (v2.21.0까지는 v4, node20)
  'subosito/flutter-action': [2, 22],
};

/// 고정 SHA를 GitHub API로 확인하는 CI 단계의 명령 (#88)
const _verifyPinsCommand = 'bash .github/scripts/action-pins.sh verify';

/// 워크플로 줄의 `uses: <액션>@<ref>`와 같은 줄 끝 주석 (`@<sha> # v2.23.0`).
/// 공백은 줄 안(`[ \t]`)으로만 제한해 다음 줄의 주석을 끝 주석으로 읽지 않는다.
/// YAML과 같은 규칙을 따른다: `uses:` 뒤에 공백이 있어야 키이고, 앞에 공백이 있는 `#`만 주석이다
/// (`@<sha>#v2.23.0`의 `#`은 ref의 일부로 읽혀 SHA가 아닌 ref로 거부된다).
/// `.github/scripts/action-pins.sh`도 같은 규칙으로 줄을 읽는다.
final _usesLine = RegExp(
  r'''^[ \t]*(?:-[ \t]+)?uses:[ \t]+(['"]?)([^@\s'"#]+)@([^\s'"]+)\1(?:[ \t]+#[ \t]*(\S+))?''',
  multiLine: true,
);

/// 전체 버전 태그 `v2.23.0` — 고정한 줄의 주석은 이 형식이어야 한다
final _fullVersionTag = RegExp(r'^v(\d+)\.(\d+)\.(\d+)$');

/// 커밋 SHA 전체(40자리, 소문자)
final _commitSha = RegExp(r'^[0-9a-f]{40}$');

/// 워크플로의 `uses:` 한 줄
typedef _Uses = ({String action, String ref, String? comment});

/// 워크플로 본문에서 `uses:` 줄을 순서대로 뽑는다
List<_Uses> _extractUses(String text) => [
  for (final m in _usesLine.allMatches(text))
    (action: m[2]!, ref: m[3]!, comment: m[4]),
];

/// YAML로 읽은 워크플로의 모든 `uses:` 값 (잡 수준 재사용 워크플로 호출 포함)
List<String> _yamlUses(String path) {
  final jobs = loadYamlFile(path)['jobs'] as YamlMap;
  return [
    for (final job in jobs.values.cast<YamlMap>()) ...[
      if (job['uses'] != null) '${job['uses']}',
      for (final step in job['steps'] as YamlList? ?? YamlList())
        if (_stepMap(path, step)['uses'] != null) '${step['uses']}',
    ],
  ];
}

/// 단계가 맵이 아니면(예: 콜론 뒤 공백 없는 `- uses:x@v7`은 문자열이다) 위치와 함께 실패한다
YamlMap _stepMap(String path, Object? step) {
  expect(step, isA<YamlMap>(), reason: '$path: 맵이 아닌 단계 — $step');
  return step as YamlMap;
}

/// 전체 버전 태그를 `[주, 부, 수]`로 바꾼다. 형식이 아니면 null.
List<int>? _parseVersion(String tag) {
  final m = _fullVersionTag.firstMatch(tag);
  if (m == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(m[i]!)];
}

/// 쓰는 버전이 최소 버전 이상인지 앞자리부터 비교한다 (최소 버전에 없는 뒷자리는 보지 않는다)
bool _atLeast(List<int> used, List<int> min) {
  for (var i = 0; i < min.length; i++) {
    if (used[i] != min[i]) return used[i] > min[i];
  }
  return true;
}

/// `uses:` 한 줄의 문제를 돌려준다. 문제가 없으면 null.
String? _problem(_Uses u) {
  final min = _minVersions[u.action];
  if (min == null) {
    return '확인하지 않은 액션이다 — runs.using을 확인하고 _minVersions에 추가할 것';
  }
  if (!_commitSha.hasMatch(u.ref)) {
    return '커밋 SHA(40자리)로 고정할 것 — 태그·브랜치는 움직인다. '
        '`@<sha> # vX.Y.Z` (README "CI 액션 고정 버전 올리기")';
  }
  // SHA는 버전을 알려 주지 않으므로 주석에 정확한 릴리스를 적어야 버전을 판단할 수 있다
  final used = u.comment == null ? null : _parseVersion(u.comment!);
  if (used == null) {
    return 'SHA로 고정한 줄은 같은 줄 끝에 "# v<주>.<부>.<수>" 주석을 적을 것';
  }
  if (!_atLeast(used, min)) {
    return 'Node 20 대상 버전이다 — v${min.join('.')} 이상을 쓸 것';
  }
  return null;
}

void main() {
  test('최소 버전 목록 형식: owner/repo 키, [주, 부] 두 자리', () {
    expect(_minVersions, isNotEmpty);
    for (final MapEntry(key: action, value: min) in _minVersions.entries) {
      expect(action, matches(RegExp(r'^[\w.-]+/[\w.-]+$')), reason: action);
      expect(min, hasLength(2), reason: '$action: [주, 부]로 적을 것');
      expect(min.every((n) => n >= 0), isTrue, reason: action);
    }
  });

  test('최소 버전 비교 규칙', () {
    expect(_atLeast([7, 0, 1], [5, 0]), isTrue);
    expect(_atLeast([4, 9, 9], [5, 0]), isFalse);
    expect(_atLeast([2, 21, 9], [2, 22]), isFalse);
    expect(_atLeast([2, 22, 0], [2, 22]), isTrue);
    expect(_atLeast([3, 0, 0], [2, 22]), isTrue);
    expect(_parseVersion('v2.23.0'), [2, 23, 0]);
    // 움직이는 태그 형태·대문자·접두사 없는 버전은 주석으로 받지 않는다
    for (final tag in ['v2', 'v2.23', 'V2.23.0', '2.23.0', 'main']) {
      expect(_parseVersion(tag), isNull, reason: tag);
    }
  });

  group('uses: 줄 추출·판정', () {
    const sha = '1a449444c387b1966244ae4d4f8c696479add0b2';

    /// 한 줄짜리 워크플로 조각에서 뽑은 `uses:` 하나
    _Uses single(String text) {
      final found = _extractUses(text);
      expect(found, hasLength(1), reason: text);
      return found.single;
    }

    test('목록 항목·단독 키·따옴표 형태를 모두 읽는다 (CRLF 포함)', () {
      for (final eol in ['\n', '\r\n']) {
        for (final line in [
          '      - uses: subosito/flutter-action@$sha # v2.23.0$eol',
          '        uses: subosito/flutter-action@$sha # v2.23.0$eol',
          "        uses: 'subosito/flutter-action@$sha' # v2.23.0$eol",
          '        uses: "subosito/flutter-action@$sha" # v2.23.0$eol',
          '        uses: subosito/flutter-action@$sha #v2.23.0 설명$eol',
        ]) {
          final u = single(line);
          expect(
            (u.action, u.ref, u.comment),
            ('subosito/flutter-action', sha, 'v2.23.0'),
            reason: line,
          );
          expect(_problem(u), isNull, reason: line);
        }
      }
    });

    test('태그·브랜치·짧은 SHA·대문자 SHA는 버전 주석이 있어도 거부한다', () {
      for (final ref in [
        'v2',
        'v2.23.0',
        'main',
        sha.substring(0, 7),
        sha.toUpperCase(),
      ]) {
        final u = single('  uses: subosito/flutter-action@$ref # v2.23.0\n');
        expect(_problem(u), contains('커밋 SHA'), reason: ref);
      }
    });

    test('SHA 고정은 같은 줄의 전체 버전 주석이 있어야 한다', () {
      // 주 버전만 적은 주석은 정확한 릴리스를 알려 주지 않는다
      expect(
        _problem(single('  uses: subosito/flutter-action@$sha # v2\n')),
        isNotNull,
      );
      // 다음 줄의 주석은 끝 주석이 아니다
      final u = single(
        '  uses: subosito/flutter-action@$sha\n\n  # v2.23.0 다음 단계 설명\n',
      );
      expect(u.comment, isNull);
      expect(_problem(u), isNotNull);
      expect(
        _problem(single('  uses: subosito/flutter-action@$sha\n')),
        isNotNull,
      );
    });

    test('최소 버전 미만·미확인 액션·# 앞 공백 없음을 거부한다', () {
      for (final line in [
        '  uses: actions/checkout@$sha # v4.2.2\n',
        '  uses: subosito/flutter-action@$sha # v2.21.0\n',
        '  uses: actions/cache@$sha # v4.3.0\n',
        // 목록에 없는 액션
        '  uses: actions/upload-artifact@$sha # v6.0.0\n',
        // 앞에 공백 없는 `#`은 YAML에서 값의 일부다 — 주석으로 읽지 않는다
        '  uses: subosito/flutter-action@$sha#v2.23.0\n',
      ]) {
        expect(_problem(single(line)), isNotNull, reason: line);
      }
    });

    test('콜론 뒤 공백 없는 uses:x는 키가 아니므로 읽지 않는다', () {
      expect(
        _extractUses('  - uses:actions/checkout@$sha # v7.0.1\n'),
        isEmpty,
      );
    });
  });

  test('워크플로의 모든 액션이 커밋 SHA로 고정되고 Node 24로 실행되는 확인된 버전 이상이다', () {
    final files = workflowFiles();
    expect(files, isNotEmpty, reason: '.github/workflows에 워크플로가 없다');

    for (final file in files) {
      final uses = _extractUses(file.readAsStringSync());
      // 줄 단위 추출이 YAML 해석과 같은 목록을 내는지 확인한다 (흐름 표기 등으로 놓친 `uses:`가 없게)
      expect(
        [for (final u in uses) '${u.action}@${u.ref}'],
        _yamlUses(file.path),
        reason:
            '${file.path}: 줄 단위로 읽은 uses:가 YAML 해석 결과와 다르다 — '
            '`run: |` 같은 블록 스칼라 안의 uses: 글자, 흐름 표기({uses: …}), '
            'docker://·./ ref, 콜론·# 앞뒤 공백을 확인할 것',
      );
      for (final u in uses) {
        expect(
          _problem(u),
          isNull,
          reason: '${file.path}: ${u.action}@${u.ref}',
        );
      }
    }
  });

  test('같은 액션은 모든 워크플로에서 같은 SHA·버전으로 고정한다', () {
    // 액션 → {"sha # 버전" → 쓰는 파일}
    final pins = <String, Map<String, Set<String>>>{};
    for (final file in workflowFiles()) {
      for (final u in _extractUses(file.readAsStringSync())) {
        pins
            .putIfAbsent(u.action, () => {})
            .putIfAbsent('${u.ref} # ${u.comment}', () => {})
            .add(file.path);
      }
    }
    expect(pins, isNotEmpty);
    for (final MapEntry(key: action, value: refs) in pins.entries) {
      expect(
        refs.keys,
        hasLength(1),
        reason: '$action 의 고정이 워크플로마다 다르다 — 한꺼번에 올릴 것: $refs',
      );
    }
  });

  test('flutter test를 돌리는 잡은 고정 SHA 온라인 확인 단계도 돌린다', () {
    for (final file in workflowFiles()) {
      final jobs = loadYamlFile(file.path)['jobs'] as YamlMap;
      var testJobs = 0;
      for (final MapEntry(key: id, value: job as YamlMap) in jobs.entries) {
        final steps = (job['steps'] as YamlList? ?? YamlList())
            .cast<YamlMap>()
            .toList();
        String run(YamlMap s) => '${s['run'] ?? ''}'.trim();
        if (!steps.any((s) => run(s) == 'flutter test')) continue;
        testJobs++;
        final verify = steps.where((s) => run(s) == _verifyPinsCommand);
        expect(
          verify,
          hasLength(1),
          reason: '${file.path} $id: "$_verifyPinsCommand" 단계가 하나 있어야 한다',
        );
        // gh는 토큰이 없으면 조회하지 않는다 (공개 저장소 조회라 기본 토큰이면 된다)
        expect(
          (verify.single['env'] as YamlMap?)?['GH_TOKEN'],
          r'${{ github.token }}',
          reason: '${file.path} $id: 확인 단계에 GH_TOKEN이 필요하다',
        );
      }
      expect(
        testJobs,
        greaterThan(0),
        reason: '${file.path}: flutter test 잡이 없다',
      );
    }
  });
}
