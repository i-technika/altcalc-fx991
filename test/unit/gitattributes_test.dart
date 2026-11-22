import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 생성 플러그인 파일의 줄바꿈 고정(#67)이 깨지지 않게 지킨다.
/// 속성 해석은 git 자신(`git check-attr`)에 맡겨 `.gitattributes` 패턴 문법을 그대로 따른다.
/// 실제 불변식("빌드 뒤 작업 트리가 깨끗하다")은 CI의 작업 트리 검사가 지키고, 이 테스트는 대상 누락을 빨리 잡는 보조다.

/// Flutter가 다시 쓰는 생성 플러그인 파일 이름 (`ios/`·`android/`의 것은 `.gitignore`로 추적하지 않는다)
final _generatedName = RegExp(
  r'(^|/)(generated_plugin[^/]*|GeneratedPluginRegistrant\.[^/]+)$',
);

/// 생성 파일이 있는 플랫폼 폴더
const _platformDirs = ['linux/flutter/', 'windows/flutter/', 'macos/Flutter/'];

/// 패키지 루트(= `flutter test`의 작업 디렉터리)에서 git을 실행한다.
List<String> _git(List<String> args) {
  final result = Process.runSync('git', [
    '-C',
    Directory.current.path,
    ...args,
  ]);
  expect(
    result.exitCode,
    0,
    reason: 'git ${args.join(' ')} 실패: ${result.stderr}',
  );
  return (result.stdout as String)
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty)
      .toList();
}

/// `git check-attr <attrs> -- <paths>` → {경로: {속성: 값}}
Map<String, Map<String, String>> _attrs(
  List<String> attrs,
  List<String> paths,
) {
  final out = <String, Map<String, String>>{};
  for (final line in _git(['check-attr', ...attrs, '--', ...paths])) {
    // 출력 형식: "<경로>: <속성>: <값>" (경로에 ': '가 없다고 가정 — 이 저장소의 대상 경로는 그렇다)
    final parts = line.split(': ');
    expect(parts, hasLength(3), reason: line);
    (out[parts[0]] ??= {})[parts[1]] = parts[2];
  }
  return out;
}

void main() {
  late List<String> tracked;

  setUpAll(() {
    // git이 없거나, 저장소가 아니거나(소스 아카이브), 패키지 루트가 저장소 루트가 아니면
    // 아래 검사가 엉뚱한 이유로 실패하므로 먼저 분명한 메시지로 멈춘다.
    final probe = Process.runSync('git', [
      '-C',
      Directory.current.path,
      'rev-parse',
      '--show-toplevel',
    ]);
    if (probe.exitCode != 0) {
      fail('git 저장소에서 실행해야 하는 테스트다 (git 없음 또는 .git 없음): ${probe.stderr}');
    }
    final top = Directory((probe.stdout as String).trim())
        .resolveSymbolicLinksSync();
    expect(
      top.toLowerCase(),
      Directory.current.resolveSymbolicLinksSync().toLowerCase(),
      reason: '패키지 루트에서 flutter test를 실행해야 한다',
    );
    tracked = _git(['ls-files']);
  });

  test('추적 중인 생성 플러그인 파일은 모두 text eol=lf 속성을 받는다', () {
    final generated = tracked.where(_generatedName.hasMatch).toList();
    // 데스크톱 플랫폼마다 최소 하나 — 하나도 없으면 경로·이름 규칙이 바뀐 것이다
    for (final dir in _platformDirs) {
      expect(
        generated.where((p) => p.startsWith(dir)),
        isNotEmpty,
        reason: '$dir 아래 생성 파일을 찾지 못했다: $generated',
      );
    }
    final attrs = _attrs(['text', 'eol'], generated);
    for (final path in generated) {
      expect(attrs[path], {'text': 'set', 'eol': 'lf'}, reason: path);
    }
  });

  test('같은 폴더의 생성 파일이 아닌 형제 파일에는 줄바꿈 속성을 걸지 않는다', () {
    // 패턴이 넓어지면 가장 먼저 걸릴 형제 파일 — 저장소 전체 규칙(* text=auto 등)이 생겨도 잡힌다
    final siblings = [
      for (final dir in _platformDirs)
        ...tracked.where(
          (p) =>
              p.startsWith(dir) &&
              !p.substring(dir.length).contains('/') &&
              !_generatedName.hasMatch(p),
        ),
      'lib/main.dart',
    ];
    expect(siblings.where((p) => p.startsWith('linux/')), isNotEmpty);
    expect(siblings.where((p) => p.startsWith('windows/')), isNotEmpty);
    expect(siblings.where((p) => p.startsWith('macos/')), isNotEmpty);
    expect(tracked, containsAll(siblings), reason: '표본 파일은 추적 중이어야 한다');

    final attrs = _attrs(['text', 'eol'], siblings);
    for (final path in siblings) {
      expect(attrs[path], {
        'text': 'unspecified',
        'eol': 'unspecified',
      }, reason: path);
    }
  });
}
