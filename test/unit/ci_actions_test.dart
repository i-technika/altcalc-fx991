import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// CI 워크플로가 Node.js 20 런타임 액션으로 되돌아가지 않게 지킨다 (#79).
/// GitHub Actions는 Node 20 지원을 끝내는 중이라, Node 20을 대상으로 하는 액션은
/// 지금은 경고와 함께 Node 24로 강제 실행되지만 지원이 끝나면 CI가 깨질 수 있다.
/// 여기서는 워크플로가 쓰는 모든 액션이 아래 목록에 있고, 목록의 최소 버전 이상인지만 본다.
/// 실제로 경고 없이 도는지는 CI 실행 로그(주석 annotation)로 확인한다.

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

/// 워크플로 줄의 `uses: <액션>@<ref>`와 끝 주석 (`@<sha> # v2.23.0`처럼 SHA로 고정할 때 태그를 주석에 적는다)
final _usesLine = RegExp(
  r'''^\s*(?:-\s+)?uses:\s*['"]?([^@\s'"]+)@([^\s'"#]+)['"]?\s*(?:#\s*(\S+))?''',
  multiLine: true,
);

/// 버전 태그 `v2`, `v2.23`, `v2.23.0`
final _versionTag = RegExp(r'^v(\d+)(?:\.(\d+))?(?:\.(\d+))?$');

/// 커밋 SHA 전체(40자리)
final _commitSha = RegExp(r'^[0-9a-f]{40}$');

/// `.github/workflows/`의 워크플로 파일
List<File> _workflowFiles() =>
    Directory('.github/workflows')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// YAML로 읽은 워크플로의 모든 `uses:` 값 (잡 수준 재사용 워크플로 호출 포함)
List<String> _yamlUses(File file) {
  final doc = loadYaml(
    file.readAsStringSync(),
    sourceUrl: Uri.file(file.path),
  ) as YamlMap;
  final jobs = doc['jobs'] as YamlMap;
  return [
    for (final job in jobs.values.cast<YamlMap>()) ...[
      if (job['uses'] != null) '${job['uses']}',
      for (final step
          in (job['steps'] as YamlList? ?? YamlList()).cast<YamlMap>())
        if (step['uses'] != null) '${step['uses']}',
    ],
  ];
}

/// 버전 태그를 `[주, 부?]`로 바꾼다. 주 버전만 적은 태그(`v2`)는 그 주 버전의 최신 릴리스를 가리킨다.
List<int>? _parseVersion(String tag) {
  final m = _versionTag.firstMatch(tag);
  if (m == null) return null;
  return [int.parse(m[1]!), if (m[2] != null) int.parse(m[2]!)];
}

/// 쓰는 버전이 최소 버전 이상인지. 주 버전만 적었으면 주 버전만 비교한다
/// (움직이는 주 버전 태그는 그 주 버전의 최신 릴리스이므로 최소 부 버전 이상이다).
bool _atLeast(List<int> used, List<int> min) {
  if (used[0] != min[0]) return used[0] > min[0];
  if (used.length < 2) return true;
  return used[1] >= min[1];
}

void main() {
  test('최소 버전 비교 규칙', () {
    expect(_atLeast([7], [5, 0]), isTrue);
    expect(_atLeast([4], [5, 0]), isFalse);
    expect(_atLeast([2], [2, 22]), isTrue, reason: '움직이는 v2 태그는 최신 2.x');
    expect(_atLeast([2, 21], [2, 22]), isFalse);
    expect(_atLeast([2, 23], [2, 22]), isTrue);
    expect(_atLeast([3, 0], [2, 22]), isTrue);
    expect(_parseVersion('v2.23.0'), [2, 23]);
    expect(_parseVersion('v7'), [7]);
    expect(_parseVersion('main'), isNull);
  });

  test('워크플로의 모든 액션이 Node 24로 실행되는 확인된 버전 이상이다', () {
    final files = _workflowFiles();
    expect(files, isNotEmpty, reason: '.github/workflows에 워크플로가 없다');

    for (final file in files) {
      final text = file.readAsStringSync();
      final matches = _usesLine.allMatches(text).toList();
      // 줄 단위 추출이 YAML 해석과 같은 목록을 내는지 확인한다 (흐름 표기 등으로 놓친 `uses:`가 없게)
      expect(
        [for (final m in matches) '${m[1]}@${m[2]}'],
        _yamlUses(file),
        reason: '${file.path}: 줄 단위로 읽은 uses:가 YAML 해석 결과와 다르다',
      );

      for (final m in matches) {
        final action = m[1]!;
        final ref = m[2]!;
        final comment = m[3];
        final where = '${file.path}: $action@$ref';

        // 로컬 액션(./...)·Docker 이미지(docker://...)는 지금 쓰지 않는다 — 쓰게 되면 이 검사를 넓힌다
        final min = _minVersions[action];
        expect(
          min,
          isNotNull,
          reason: '$where: 확인하지 않은 액션이다 — runs.using을 확인하고 _minVersions에 추가할 것',
        );

        // 태그로 쓰면 ref에서, 커밋 SHA로 고정하면 끝 주석의 태그에서 버전을 읽는다
        final tag = _commitSha.hasMatch(ref) ? comment : ref;
        final used = tag == null ? null : _parseVersion(tag);
        expect(
          used,
          isNotNull,
          reason:
              '$where: 버전을 알 수 없다 — 버전 태그(v<주>)를 쓰거나 SHA 뒤에 "# v<주>.<부>.<수>" 주석을 적을 것',
        );
        expect(
          _atLeast(used!, min!),
          isTrue,
          reason: '$where: Node 20 대상 버전이다 — v${min.join('.')} 이상을 쓸 것',
        );
      }
    }
  });
}
