import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `analysis_options.yaml`의 `analyzer.exclude` 불변식 (#66).
///
/// VS Code Dart 확장(Dart-Code 3.146 `getAnalysisOptionsExcludedFolders`)은 이 목록으로 작업 영역 안의
/// 하위 프로젝트를 걸러 낸다. 걸러진 워크트리는 시작 시 pub get 알림·`Get Packages for All Projects`·
/// 프로젝트 선택 목록에서 빠진다 (README "작업 영역 안의 git 워크트리").
/// 확장은 `/**`로 끝나고 그 밖에 `*`가 없는 항목만 폴더 제외로 쓰므로, analyzer는 받아들여도
/// 확장이 무시하는 표기(`.claude/worktrees/*` 등)로 바뀌면 이 테스트가 잡는다.
/// 경로는 `flutter test`의 작업 디렉터리인 패키지 루트 기준이다.

/// Claude Code가 워크트리를 만드는 작업 영역 안 폴더
const _worktreesDir = '.claude/worktrees';

/// 들여쓰기 칸 수
int _indent(String line) => line.length - line.trimLeft().length;

/// 줄 끝 주석(` #`)과 바깥 따옴표를 뗀 YAML 스칼라
String _scalar(String raw) {
  var v = raw;
  final comment = v.indexOf(' #');
  if (comment >= 0) v = v.substring(0, comment);
  v = v.trim();
  if (v.length >= 2 &&
      (v.startsWith('"') && v.endsWith('"') ||
          v.startsWith("'") && v.endsWith("'"))) {
    v = v.substring(1, v.length - 1);
  }
  return v;
}

/// 최상위 `analyzer:` 아래 `exclude:` 블록 목록의 항목.
/// YAML 패키지에 의존하지 않으려고 이 파일이 쓰는 블록 형식(`- 항목` 줄)만 들여쓰기로 읽는다.
/// 흐름 형식(`exclude: [a, b]`)처럼 읽지 못하는 형태는 빈 목록 대신 오류로 알린다.
List<String> analyzerExcludes(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  bool skip(String l) => l.trim().isEmpty || l.trimLeft().startsWith('#');

  final analyzer = lines.indexWhere(
    (l) => RegExp(r'^analyzer:\s*$').hasMatch(l),
  );
  if (analyzer < 0) throw const FormatException('최상위 analyzer: 블록이 없다');

  int? excludeAt;
  for (var i = analyzer + 1; i < lines.length; i++) {
    if (skip(lines[i])) continue;
    if (_indent(lines[i]) == 0) break; // analyzer 블록 끝
    if (RegExp(r'^\s+exclude:').hasMatch(lines[i])) {
      if (!RegExp(r'^\s+exclude:\s*(#.*)?$').hasMatch(lines[i])) {
        throw FormatException('블록 목록이 아닌 exclude 형식', lines[i]);
      }
      excludeAt = i;
      break;
    }
  }
  if (excludeAt == null) throw const FormatException('analyzer.exclude가 없다');

  final keyIndent = _indent(lines[excludeAt]);
  final items = <String>[];
  for (var i = excludeAt + 1; i < lines.length; i++) {
    final l = lines[i];
    if (skip(l)) continue;
    // YAML은 목록 항목을 키와 같은 들여쓰기에 둘 수도 있다
    if (_indent(l) < keyIndent ||
        _indent(l) == keyIndent && !l.trimLeft().startsWith('- ')) {
      break;
    }
    final m = RegExp(r'^\s*-\s+(.*)$').firstMatch(l);
    if (m == null) throw FormatException('exclude 목록 항목이 아니다', l);
    items.add(_scalar(m[1]!));
  }
  return items;
}

/// Dart-Code와 같은 규칙으로 항목을 폴더 제외로 바꾼다. 폴더 제외로 쓰이지 않는 항목이면 `null`.
/// 확장은 끝의 `/**`를 떼고 `*`가 남지 않은 것만 쓰며, 상대경로는 프로젝트 폴더 기준으로 붙인다.
String? dartCodeExcludedFolder(String entry) {
  var e = entry;
  if (e.endsWith('/**')) e = e.substring(0, e.length - 3);
  return e.contains('*') ? null : e;
}

/// 패키지 루트 기준 상대경로 [path]가 폴더 [folder]와 같거나 그 안에 있는가.
/// 확장(`isWithinPathOrEqual`)처럼 대소문자를 무시한다. `./`·`\`를 정규화한다.
bool isWithinOrEqual(String path, String folder) {
  String norm(String p) {
    var s = p.replaceAll(r'\', '/').toLowerCase();
    while (s.startsWith('./')) {
      s = s.substring(2);
    }
    if (s == '.') s = '';
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  final p = norm(path);
  final f = norm(folder);
  return f.isEmpty || p == f || p.startsWith('$f/');
}

void main() {
  group('analyzerExcludes', () {
    test('블록 목록 항목을 주석·따옴표를 떼고 읽고, 다음 키에서 멈춘다', () {
      const src = '''
include: package:x/y.yaml

analyzer:
  errors:
    a: ignore
  exclude:
    # 주석 줄
    - build/**
    - "web/**"   # 줄 끝 주석

    - '.claude/worktrees/**'
  language:
    strict-casts: true
linter:
  rules:
    - exclude_me
''';
      expect(analyzerExcludes(src), [
        'build/**',
        'web/**',
        '.claude/worktrees/**',
      ]);
    });

    test('키와 같은 들여쓰기의 목록 항목도 읽는다', () {
      const src = 'analyzer:\n  exclude:\n  - a/**\n  - b/**\n  plugins: []\n';
      expect(analyzerExcludes(src), ['a/**', 'b/**']);
    });

    test('analyzer·exclude가 없거나 흐름 형식이면 오류로 알린다', () {
      expect(() => analyzerExcludes('linter:\n'), throwsFormatException);
      expect(
        () => analyzerExcludes('analyzer:\n  errors: {}\n'),
        throwsFormatException,
      );
      expect(
        () => analyzerExcludes('analyzer:\n  exclude: [a/**]\n'),
        throwsFormatException,
      );
    });
  });

  test('Dart-Code 폴더 제외 규칙: /**로 끝나고 다른 *가 없어야 폴더 제외다', () {
    expect(dartCodeExcludedFolder('.claude/worktrees/**'), '.claude/worktrees');
    expect(dartCodeExcludedFolder('build/**'), 'build');
    expect(dartCodeExcludedFolder('.claude/worktrees'), '.claude/worktrees');
    expect(dartCodeExcludedFolder('.claude/worktrees/*'), isNull);
    expect(dartCodeExcludedFolder('**/*.g.dart'), isNull);
    expect(dartCodeExcludedFolder('.claude/*/**'), isNull);
  });

  test('isWithinOrEqual', () {
    expect(
      isWithinOrEqual('.claude/worktrees/issue-1', '.claude/worktrees'),
      isTrue,
    );
    expect(
      isWithinOrEqual(r'.Claude\Worktrees\x', '.claude/worktrees/'),
      isTrue,
    );
    expect(isWithinOrEqual('.claude/worktrees', '.claude/worktrees'), isTrue);
    expect(
      isWithinOrEqual('.claude/worktrees-old', '.claude/worktrees'),
      isFalse,
    );
    expect(isWithinOrEqual('lib', '.'), isTrue);
    expect(isWithinOrEqual('lib', './'), isTrue);
  });

  group('analysis_options.yaml', () {
    late List<String> excludes;
    late List<String> folders;
    setUpAll(() {
      excludes = analyzerExcludes(
        File('analysis_options.yaml').readAsStringSync(),
      );
      folders = excludes.map(dartCodeExcludedFolder).nonNulls.toList();
    });

    test('Dart 확장이 작업 영역 안 워크트리를 프로젝트 목록에서 뺀다', () {
      expect(excludes, contains('$_worktreesDir/**'));
      for (final worktree in [
        '$_worktreesDir/issue-66',
        '$_worktreesDir/issue-66/packages/x',
      ]) {
        expect(
          folders.any((f) => isWithinOrEqual(worktree, f)),
          isTrue,
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
      for (final kept in [
        'pubspec.yaml',
        'lib',
        'test',
        'preview',
        '.claude/scripts',
      ]) {
        expect(
          folders.where((f) => isWithinOrEqual(kept, f)),
          isEmpty,
          reason: '$kept가 폴더 제외에 걸린다: $folders',
        );
      }
    });
  });
}
