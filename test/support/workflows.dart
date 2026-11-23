import 'dart:io';

import 'package:yaml/yaml.dart';

/// CI 워크플로 구성 테스트(`flutter_sdk_pin_test`, `ci_actions_test`, `ci_android_unit_test_test`)가 함께 쓰는 도구.
/// 경로는 패키지 루트(= `flutter test`의 작업 디렉터리) 기준이다.

/// `.github/workflows/`의 워크플로 파일 (경로순)
List<File> workflowFiles() =>
    Directory('.github/workflows')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// YAML 파일을 맵으로 읽는다 (오류 위치에 파일 경로가 나오게 `sourceUrl`을 붙인다)
YamlMap loadYamlFile(String path) =>
    loadYaml(File(path).readAsStringSync(), sourceUrl: Uri.file(path))
        as YamlMap;

/// 워크플로 줄의 `uses: <액션>@<ref>`와 같은 줄 끝 주석 (`@<sha> # v2.23.0`).
/// 공백은 줄 안(`[ \t]`)으로만 제한해 다음 줄의 주석을 끝 주석으로 읽지 않는다.
/// YAML과 같은 규칙을 따른다: `uses:` 뒤에 공백이 있어야 키이고, 앞에 공백이 있는 `#`만 주석이다
/// (`@<sha>#v2.23.0`의 `#`은 ref의 일부로 읽혀 SHA가 아닌 ref로 거부된다). 여닫는 따옴표는 같은 종류여야 한다.
/// `.github/scripts/action-pins.sh`도 같은 줄을 받아들이는지 `action_pins_script_test`가 같은 표본으로 대조한다.
final _usesLine = RegExp(
  r'''^[ \t]*(?:-[ \t]+)?uses:[ \t]+(['"]?)([^@\s'"#]+)@([^\s'"]+)\1(?:[ \t]+#[ \t]*(\S+))?''',
  multiLine: true,
);

/// 전체 버전 태그 `v2.23.0` — 고정한 줄의 주석은 이 형식이어야 한다
final _fullVersionTag = RegExp(r'^v(\d+)\.(\d+)\.(\d+)$');

/// 커밋 SHA 전체(40자리, 소문자)
final _commitSha = RegExp(r'^[0-9a-f]{40}$');

/// 워크플로의 `uses:` 한 줄
typedef ActionUses = ({String action, String ref, String? comment});

/// 워크플로 본문에서 `uses:` 줄을 순서대로 뽑는다
List<ActionUses> extractUses(String text) => [
  for (final m in _usesLine.allMatches(text))
    (action: m[2]!, ref: m[3]!, comment: m[4]),
];

/// 전체 버전 태그를 `[주, 부, 수]`로 바꾼다. 형식이 아니면 null.
List<int>? parseVersionTag(String tag) {
  final m = _fullVersionTag.firstMatch(tag);
  if (m == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(m[i]!)];
}

/// 커밋 SHA 고정 형식(#88)의 문제를 돌려준다. 문제가 없으면 null.
String? pinFormatProblem(ActionUses u) {
  if (!_commitSha.hasMatch(u.ref)) {
    return '커밋 SHA(40자리)로 고정할 것 — 태그·브랜치는 움직인다. '
        '`@<sha> # vX.Y.Z` (README "CI 액션 고정 버전 올리기")';
  }
  // SHA는 버전을 알려 주지 않으므로 주석에 정확한 릴리스를 적어야 버전을 판단할 수 있다
  if (u.comment == null || parseVersionTag(u.comment!) == null) {
    return 'SHA로 고정한 줄은 같은 줄 끝에 "# v<주>.<부>.<수>" 주석을 적을 것';
  }
  return null;
}

/// 액션 이름의 owner/repo 부분 (하위 경로 액션 `owner/repo/path`도 태그·릴리스는 owner/repo의 것이다)
String actionRepo(String action) => action.split('/').take(2).join('/');
