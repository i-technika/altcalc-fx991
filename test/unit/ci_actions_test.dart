import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../support/workflows.dart';

/// CI 워크플로가 Node.js 20 런타임 액션으로 되돌아가지 않게 지킨다 (#79).
/// GitHub Actions는 Node 20 지원을 끝내는 중이라, Node 20을 대상으로 하는 액션은
/// 지금은 경고와 함께 Node 24로 강제 실행되지만 지원이 끝나면 CI가 깨질 수 있다.
/// 여기서는 워크플로가 쓰는 모든 액션이 아래 목록에 있고, 목록의 최소 버전 이상인지만 본다.
///
/// 오프라인 검사라 다음은 확인하지 못한다 — CI 실행의 주석(annotation)에 Node 20 경고가 없는지로 확인한다.
/// - 커밋 SHA가 정말 끝 주석의 태그를 가리키는지 (SHA 고정 자체의 검사는 #88)
/// - 움직이는 주 버전 태그(`v2`)가 지금 가리키는 릴리스와, composite 액션 내부에서 쓰는 액션의 버전

/// 워크플로에서 쓰도록 확인한 액션과, Node 24로 실행되는 최소 버전 `[주, 부]`.
/// 새 액션을 쓰거나 주 버전을 바꿀 때는 그 버전 `action.yml`의 `runs.using`을 확인하고 여기에 적는다
/// (`node24`이거나, `composite`면 내부에서 쓰는 액션들이 node24여야 한다).
const _minVersions = <String, List<int>>{
  // v5.0.0부터 runs.using: node24
  'actions/checkout': [5, 0],
  // v5.0.0부터 runs.using: node24
  'actions/setup-java': [5, 0],
  // composite 액션 — 내부의 actions/cache가 v2.22.0부터 v5(node24)다 (v2.21.0까지는 v4, node20)
  'subosito/flutter-action': [2, 22],
};

/// 워크플로 줄의 `uses: <액션>@<ref>`와 같은 줄 끝 주석
/// (`@<sha> # v2.23.0`처럼 SHA로 고정할 때 태그를 주석에 적는다).
/// 공백은 줄 안(`[ \t]`)으로만 제한해 다음 줄의 주석을 끝 주석으로 읽지 않는다.
final _usesLine = RegExp(
  r'''^[ \t]*(?:-[ \t]+)?uses:[ \t]*(['"]?)([^@\s'"#]+)@([^\s'"#]+)\1[ \t]*(?:#[ \t]*(\S+))?''',
  multiLine: true,
);

/// 버전 태그 `v2`, `v2.23`, `v2.23.0`
final _versionTag = RegExp(r'^v(\d+)(?:\.(\d+))?(?:\.(\d+))?$');

/// 전체 버전 태그 `v2.23.0` — SHA로 고정한 줄의 주석은 이 형식이어야 한다
final _fullVersionTag = RegExp(r'^v\d+\.\d+\.\d+$');

/// 커밋 SHA 전체(40자리)
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
      for (final step
          in (job['steps'] as YamlList? ?? YamlList()).cast<YamlMap>())
        if (step['uses'] != null) '${step['uses']}',
    ],
  ];
}

/// 버전 태그를 숫자 목록(1~3개)으로 바꾼다. 태그가 아니면 null.
List<int>? _parseVersion(String tag) {
  final m = _versionTag.firstMatch(tag);
  if (m == null) return null;
  return [
    for (var i = 1; i <= 3; i++)
      if (m[i] != null) int.parse(m[i]!),
  ];
}

/// 쓰는 버전이 최소 버전 이상인지 앞자리부터 비교한다.
/// 움직이는 태그(`v2`, `v2.23`)는 적은 자리까지만 비교한다 — 그 범위의 최신 릴리스를 가리키기 때문이다.
/// SHA로 고정한 줄은 전체 버전(`v2.23.0`)을 요구하므로 이 완화를 받지 않는다.
bool _atLeast(List<int> used, List<int> min) {
  for (var i = 0; i < min.length; i++) {
    if (i >= used.length) return true;
    if (used[i] != min[i]) return used[i] > min[i];
  }
  return true;
}

/// `uses:` 한 줄의 문제를 돌려준다. 문제가 없으면 null.
String? _problem(_Uses u) {
  // 로컬 액션(./...)·Docker 이미지(docker://...)는 지금 쓰지 않는다 — 쓰게 되면 이 검사를 넓힌다
  final min = _minVersions[u.action];
  if (min == null) {
    return '확인하지 않은 액션이다 — runs.using을 확인하고 _minVersions에 추가할 것';
  }

  final List<int> used;
  if (_commitSha.hasMatch(u.ref)) {
    // SHA는 움직이지 않으므로 주석에 정확한 릴리스를 적어야 버전을 판단할 수 있다
    final comment = u.comment;
    if (comment == null || !_fullVersionTag.hasMatch(comment)) {
      return 'SHA로 고정한 줄은 같은 줄 끝에 "# v<주>.<부>.<수>" 주석을 적을 것';
    }
    used = _parseVersion(comment)!;
  } else {
    final parsed = _parseVersion(u.ref);
    if (parsed == null) {
      return '버전을 알 수 없는 ref다 — 버전 태그(v<주>)나 커밋 SHA를 쓸 것';
    }
    // 태그 ref에 버전 주석을 달았다면 ref와 어긋나지 않아야 한다 (예: `@v7 # v4` 금지)
    final commented = u.comment == null ? null : _parseVersion(u.comment!);
    if (commented != null &&
        (commented.length < parsed.length ||
            !_listEquals(commented.sublist(0, parsed.length), parsed))) {
      return '끝 주석의 버전(${u.comment})이 ref(${u.ref})와 맞지 않는다';
    }
    used = parsed;
  }

  if (!_atLeast(used, min)) {
    return 'Node 20 대상 버전이다 — v${min.join('.')} 이상을 쓸 것';
  }
  return null;
}

bool _listEquals(List<int> a, List<int> b) =>
    a.length == b.length &&
    [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((e) => e);

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
    expect(_atLeast([7], [5, 0]), isTrue);
    expect(_atLeast([4], [5, 0]), isFalse);
    expect(_atLeast([2], [2, 22]), isTrue, reason: '움직이는 v2 태그는 최신 2.x');
    expect(_atLeast([2, 21], [2, 22]), isFalse);
    expect(_atLeast([2, 21, 9], [2, 22]), isFalse);
    expect(_atLeast([2, 22, 0], [2, 22]), isTrue);
    expect(_atLeast([3, 0], [2, 22]), isTrue);
    expect(_parseVersion('v2.23.0'), [2, 23, 0]);
    expect(_parseVersion('v7'), [7]);
    expect(_parseVersion('main'), isNull);
  });

  group('uses: 줄 추출·판정', () {
    const sha = '1a449444c387b1966244ae4d4f8c696479add0b2';

    /// 한 줄짜리 워크플로 조각에서 뽑은 `uses:` 하나
    _Uses single(String text) {
      final found = _extractUses(text);
      expect(found, hasLength(1), reason: text);
      return found.single;
    }

    test('목록 항목·단독 키·따옴표 형태를 모두 읽는다', () {
      for (final line in [
        '      - uses: actions/checkout@v7\n',
        '        uses: actions/checkout@v7\n',
        "        uses: 'actions/checkout@v7'\n",
        '        uses: "actions/checkout@v7"\n',
      ]) {
        final u = single(line);
        expect(
          (u.action, u.ref, u.comment),
          ('actions/checkout', 'v7', null),
          reason: line,
        );
        expect(_problem(u), isNull, reason: line);
      }
    });

    test('SHA 고정 + 전체 버전 주석을 읽는다 (CRLF 포함)', () {
      for (final eol in ['\n', '\r\n']) {
        final u = single(
          '      - uses: subosito/flutter-action@$sha # v2.23.0$eol',
        );
        expect((u.ref, u.comment), (sha, 'v2.23.0'));
        expect(_problem(u), isNull);
      }
    });

    test('SHA 고정은 같은 줄의 전체 버전 주석이 있어야 한다', () {
      // 주 버전만 적은 주석은 움직이는 태그 완화를 받지 못한다
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

    test('최소 버전 미만·주석 불일치·알 수 없는 ref·미확인 액션을 거부한다', () {
      for (final line in [
        '  uses: actions/checkout@v4\n',
        '  uses: actions/setup-java@v4.9.1\n',
        '  uses: subosito/flutter-action@$sha # v2.21.0\n',
        '  uses: actions/checkout@v7 # v4\n',
        '  uses: actions/checkout@main\n',
        '  uses: actions/cache@v5\n',
      ]) {
        expect(_problem(single(line)), isNotNull, reason: line);
      }
      // 태그 ref와 맞는 버전 주석·버전이 아닌 주석은 허용한다
      expect(
        _problem(single('  uses: actions/checkout@v7 # v7.0.1\n')),
        isNull,
      );
      expect(_problem(single('  uses: actions/checkout@v7 # 체크아웃\n')), isNull);
    });
  });

  test('워크플로의 모든 액션이 Node 24로 실행되는 확인된 버전 이상이다', () {
    final files = workflowFiles();
    expect(files, isNotEmpty, reason: '.github/workflows에 워크플로가 없다');

    for (final file in files) {
      final uses = _extractUses(file.readAsStringSync());
      // 줄 단위 추출이 YAML 해석과 같은 목록을 내는지 확인한다 (흐름 표기 등으로 놓친 `uses:`가 없게)
      expect(
        [for (final u in uses) '${u.action}@${u.ref}'],
        _yamlUses(file.path),
        reason: '${file.path}: 줄 단위로 읽은 uses:가 YAML 해석 결과와 다르다',
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
}
