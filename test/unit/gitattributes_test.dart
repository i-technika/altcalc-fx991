import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 생성 플러그인 파일의 줄바꿈 고정(#67)이 깨지지 않게 지킨다.
/// 속성 해석은 git 자신(`git check-attr`)에 맡겨 `.gitattributes` 패턴 문법을 그대로 따른다.
/// 경로는 `flutter test`의 작업 디렉터리인 패키지 루트 기준이다.

/// Flutter가 다시 쓰는 생성 플러그인 파일 이름 (`ios/`·`android/`의 것은 `.gitignore`로 추적하지 않는다)
final _generatedName = RegExp(
  r'(^|/)(generated_plugin[^/]*|GeneratedPluginRegistrant\.[^/]+)$',
);

List<String> _git(List<String> args) {
  final result = Process.runSync('git', args);
  expect(result.exitCode, 0, reason: 'git ${args.join(' ')}: ${result.stderr}');
  return (result.stdout as String)
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty)
      .toList();
}

void main() {
  test('추적 중인 생성 플러그인 파일은 모두 text eol=lf 속성을 받는다', () {
    final generated = _git(['ls-files'])
        .where(_generatedName.hasMatch)
        .toList();
    // 데스크톱 3개 플랫폼의 생성 파일 7개 — 하나라도 빠지면 경로·이름이 바뀐 것이다
    expect(generated, hasLength(7), reason: '$generated');

    // 출력 형식: "<경로>: <속성>: <값>"
    final attrs = _git(['check-attr', 'text', 'eol', '--', ...generated]);
    for (final path in generated) {
      expect(attrs, contains('$path: text: set'), reason: path);
      expect(attrs, contains('$path: eol: lf'), reason: path);
    }
  });

  test('생성 파일이 아닌 파일에는 줄바꿈 속성을 걸지 않는다 (범위를 생성 파일로 한정)', () {
    final attrs = _git([
      'check-attr',
      'eol',
      '--',
      'lib/main.dart',
      'README.md',
      'linux/CMakeLists.txt',
      'windows/runner/main.cpp',
    ]);
    for (final line in attrs) {
      expect(line, endsWith(': eol: unspecified'), reason: line);
    }
  });
}
