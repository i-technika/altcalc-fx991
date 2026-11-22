import 'dart:convert';
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
/// git은 경로를 UTF-8로 내보내므로 시스템 인코딩(Windows 한국어는 cp949) 대신 UTF-8로 읽는다.
ProcessResult _runGit(List<String> args) => Process.runSync(
  'git',
  ['-C', Directory.current.path, ...args],
  stdoutEncoding: utf8,
  stderrEncoding: utf8,
);

/// `-z` 출력(NUL 구분)을 필드 목록으로 돌려준다 — 공백·비ASCII 경로도 따옴표 처리 없이 그대로 받는다.
List<String> _gitZ(List<String> args) {
  final result = _runGit(args);
  expect(
    result.exitCode,
    0,
    reason: 'git ${args.join(' ')} 실패: ${result.stderr}',
  );
  final fields = (result.stdout as String).split('\u0000');
  if (fields.isNotEmpty && fields.last.isEmpty) fields.removeLast();
  return fields;
}

/// `git check-attr -z <attrs> -- <paths>` → {경로: {속성: 값}}
Map<String, Map<String, String>> _attrs(
  List<String> attrs,
  List<String> paths,
) {
  final fields = _gitZ(['check-attr', '-z', ...attrs, '--', ...paths]);
  // 출력 형식: 경로·속성·값이 NUL로 구분되어 이 순서로 반복된다
  expect(fields.length % 3, 0, reason: '$fields');
  final out = <String, Map<String, String>>{};
  for (var i = 0; i < fields.length; i += 3) {
    (out[fields[i]] ??= {})[fields[i + 1]] = fields[i + 2];
  }
  return out;
}

void main() {
  late List<String> tracked;

  setUpAll(() {
    // git이 없거나, 저장소가 아니거나(소스 아카이브), 패키지 루트가 저장소 루트가 아니면
    // 아래 검사가 엉뚱한 이유로 실패하므로 먼저 분명한 메시지로 멈춘다.
    final probe = _runGit(['rev-parse', '--show-toplevel']);
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
    tracked = _gitZ(['ls-files', '-z']);
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

  test('생성 파일·셸 스크립트 외에는 줄바꿈 속성을 걸지 않는다 (저장소 전체 정책 미도입)', () {
    // 저장소 전체 규칙(* text=auto 등)은 다른 파일의 체크아웃 형태까지 바꾸므로 도입하지 않는다(.gitattributes 주석).
    // 표본: 패턴이 넓어지면 가장 먼저 걸릴, 같은 폴더의 생성 파일이 아닌 형제 파일과 일반 소스 하나
    final siblings = [
      for (final dir in _platformDirs)
        ...tracked.where(
          (p) =>
              p.startsWith(dir) &&
              !p.substring(dir.length).contains('/') &&
              !_generatedName.hasMatch(p),
        ),
    ];
    for (final dir in _platformDirs) {
      expect(siblings.where((p) => p.startsWith(dir)), isNotEmpty, reason: dir);
    }
    final samples = [...siblings, 'lib/main.dart', 'README.md'];
    expect(tracked, containsAll(samples), reason: '표본 파일은 추적 중이어야 한다');

    final attrs = _attrs(['text', 'eol'], samples);
    for (final path in samples) {
      expect(attrs[path], {
        'text': 'unspecified',
        'eol': 'unspecified',
      }, reason: path);
    }
  });

  test('셸 스크립트는 LF로 받는다 (WSL bash 등은 CRLF 스크립트를 실행하지 못한다)', () {
    final scripts = tracked.where((p) => p.endsWith('.sh')).toList();
    expect(scripts, isNotEmpty);
    final attrs = _attrs(['eol'], scripts);
    for (final path in scripts) {
      expect(attrs[path], {'eol': 'lf'}, reason: path);
    }
  });
}
