import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// `analysis_options.yaml`의 `analyzer.exclude` 불변식 (#66).
///
/// VS Code Dart 확장(Dart-Code 3.146 `getAnalysisOptionsExcludedFolders`)은 이 목록으로 작업 영역 안의
/// 하위 프로젝트를 걸러 낸다. 걸러진 워크트리는 확장의 프로젝트 목록(시작 pub get 알림 등)에서 빠진다
/// (README "작업 영역 안의 git 워크트리").
/// 확장은 끝의 `/**`를 뗀 뒤 `*`가 남지 않는 항목만 폴더 제외로 쓰므로, analyzer는 받아들여도
/// 확장이 무시하는 표기(`.claude/worktrees/*` 등)로 바뀌면 이 테스트가 잡는다.
/// 지키는 것은 저장소 쪽 표기다. 확장 쪽 규칙이 바뀌는 것은 잡지 못한다(규칙은 3.146 소스를 옮긴 것이다).
/// 경로는 `flutter test`의 작업 디렉터리인 패키지 루트 기준이다.

/// Claude Code가 워크트리를 만드는 작업 영역 안 폴더
const _worktreesDir = '.claude/worktrees';

/// 판정에 쓰는 가상의 프로젝트 루트 — 확장은 상대 항목을 프로젝트 폴더에 `path.join`한다
final _root = p.posix.join('/', 'ws', 'app');

/// `analyzer.exclude` 목록. Dart-Code처럼 YAML 파서로 읽는다(중복 키는 파서가 예외로 알린다).
/// 확장은 문자열이 아닌 항목(따옴표 없는 `123`·`true`·`~`)에서 예외가 나
/// 그 항목 뒤의 제외를 모두 잃으므로 실패로 본다.
List<String> analyzerExcludes(String source) {
  final doc = loadYaml(source);
  final exclude = doc is YamlMap && doc['analyzer'] is YamlMap
      ? (doc['analyzer'] as YamlMap)['exclude']
      : null;
  if (exclude is! YamlList) {
    throw const FormatException('analyzer.exclude 목록이 없다');
  }
  return [
    for (final e in exclude)
      if (e is String)
        e
      else
        throw FormatException('문자열이 아닌 exclude 항목 — 확장이 제외 목록 전체를 버린다', '$e'),
  ];
}

/// Dart-Code와 같은 규칙으로 항목을 [_root] 기준 절대 폴더로 바꾼다. 폴더 제외로 쓰이지 않으면 `null`.
/// 확장 순서: 끝 `/**`를 뗀다 → `/`로 시작하지 않으면 프로젝트 폴더에 `join`(정규화 포함) → `*`가 남으면 버린다.
String? dartCodeExcludedFolder(String entry) {
  var e = entry;
  if (e.endsWith('/**')) e = e.substring(0, e.length - 3);
  if (!e.startsWith('/')) e = p.posix.join(_root, e);
  e = p.posix.normalize(e);
  return e.contains('*') ? null : e;
}

/// 루트 기준 상대경로 [path]가 폴더 [folder]와 같거나 그 안에 있는가. 확장처럼 대소문자를 무시한다.
bool isWithinOrEqual(String path, String folder) {
  final full = p.posix.normalize(p.posix.join(_root, path)).toLowerCase();
  final f = folder.toLowerCase();
  return full == f || p.posix.isWithin(f, full);
}

/// [excludes] 중 [path]를 빼는 폴더 제외
List<String> excludersOf(List<String> excludes, String path) => [
  for (final e in excludes)
    if (dartCodeExcludedFolder(e) case final f? when isWithinOrEqual(path, f))
      e,
];

void main() {
  group('analyzerExcludes', () {
    test('주석·따옴표를 처리하고 analyzer 아래의 exclude만 읽는다', () {
      const src = '''
include: package:x/y.yaml

analyzer: # 줄 끝 주석
  plugins:
    x:
      exclude:
        - nested/**
  exclude:
    # 주석 줄
    - build/**
    - "web/ #/**"
    - '.claude/worktrees/**'	# 탭 뒤 주석
linter:
  rules:
    - exclude_me
''';
      expect(analyzerExcludes(src), [
        'build/**',
        'web/ #/**',
        '.claude/worktrees/**',
      ]);
    });

    test('목록이 없거나, 문자열이 아닌 항목·중복 키가 있으면 오류로 알린다', () {
      expect(() => analyzerExcludes('linter: {}\n'), throwsFormatException);
      expect(
        () => analyzerExcludes('analyzer:\n  errors: {}\n'),
        throwsFormatException,
      );
      expect(
        () =>
            analyzerExcludes('analyzer:\n  exclude:\n    - a/**\n    - 123\n'),
        throwsFormatException,
      );
      expect(
        () => analyzerExcludes(
          'analyzer:\n  exclude:\n    - a/**\nanalyzer:\n  exclude: []\n',
        ),
        throwsA(isA<YamlException>()),
      );
    });
  });

  test('Dart-Code 폴더 제외 규칙: /**로 끝나고 다른 *가 없어야 하며 상대경로는 정규화된다', () {
    expect(
      dartCodeExcludedFolder('.claude/worktrees/**'),
      '$_root/.claude/worktrees',
    );
    expect(
      dartCodeExcludedFolder('./.claude/worktrees'),
      '$_root/.claude/worktrees',
    );
    expect(dartCodeExcludedFolder('lib/..'), _root);
    expect(dartCodeExcludedFolder('/abs/x/**'), '/abs/x');
    expect(dartCodeExcludedFolder('.claude/worktrees/*'), isNull);
    expect(dartCodeExcludedFolder('**/*.g.dart'), isNull);
    expect(dartCodeExcludedFolder('.claude/*/**'), isNull);
  });

  test('isWithinOrEqual은 대소문자를 무시하고 이름이 겹치는 형제 폴더는 넘긴다', () {
    final wt = '$_root/.claude/worktrees';
    expect(isWithinOrEqual('.claude/worktrees/issue-1', wt), isTrue);
    expect(isWithinOrEqual('.Claude/Worktrees/x', wt), isTrue);
    expect(isWithinOrEqual('.claude/worktrees', wt), isTrue);
    expect(isWithinOrEqual('.claude/worktrees-old', wt), isFalse);
    expect(isWithinOrEqual('lib', _root), isTrue);
  });

  group('analysis_options.yaml', () {
    late List<String> excludes;
    setUpAll(() {
      excludes = analyzerExcludes(
        File('analysis_options.yaml').readAsStringSync(),
      );
    });

    test('Dart 확장이 작업 영역 안 워크트리를 프로젝트 목록에서 뺀다', () {
      // 확장의 탐색 깊이(dart.projectSearchDepth 기본 5, 루트가 1단계) 안의 워크트리와 그 하위 패키지
      for (final worktree in [
        '$_worktreesDir/issue-66',
        '$_worktreesDir/issue-66/sub',
      ]) {
        expect(
          excludersOf(excludes, worktree),
          isNotEmpty,
          reason: '$worktree를 빼는 폴더 제외가 없다: $excludes',
        );
      }
    });

    test('기기마다 다른 절대경로가 없고, 패키지 루트·소스 폴더를 빼지 않는다', () {
      for (final e in excludes) {
        expect(
          e.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(e),
          isFalse,
          reason: e,
        );
      }
      // 루트가 빠지면 확장이 이 앱 자체를 프로젝트로 보지 않는다
      for (final kept in ['.', 'lib', 'test', 'preview', '.claude/scripts']) {
        expect(
          excludersOf(excludes, kept),
          isEmpty,
          reason: '$kept가 폴더 제외에 걸린다',
        );
      }
    });
  });
}
